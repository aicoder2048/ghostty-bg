// snake — a neon LED Snake game on a faint glass panel in the lower right; the glowing snake glides to each pulsing dot and grows.
// zh: 贪吃蛇
// group: geek
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float CELL      = 0.034;  // grid cell, in window-heights (board is H cells tall)
const float W         = 18.0;   // board size, in cells
const float H         = 11.0;
const float RATE      = 4.5;    // cells per second the snake glides
const float MEAL      = 8.0;    // steps from one dot to the next
const int   MEALS     = 8;      // dots per round; then a soft flash and a new round
const float END       = 9.0;    // steps of fade-out and flash between rounds
const float START_LEN = 4.0;    // body length at the start of a round
const float GLASS     = 0.16;   // how much the glass panel darkens/tints what is behind
const float BLOOM     = 1.0;    // strength of the soft halo around lit things

const int MAXSEG = 12;          // START_LEN + MEALS: longest the snake gets

vec2 gFood[MAXSEG];             // dot positions (cell coords); gFood[0] = start point
vec2 gOff[MAXSEG];              // move from one dot to the next (x leg first, then y)

float hash(float a, float b) {
    return fract(sin(a * 127.1 + b * 311.7) * 43758.5453);
}

// Head position (cell coords, continuous) after t steps of the round. Body
// segment j is simply where the head was j steps ago, so every segment glides
// along the same right-angled path and turns corners exactly like the classic.
vec2 headAt(float t) {
    if (t < 0.0) return gFood[0] - vec2(sign(gOff[0].x) * -t, 0.0);   // starting tail, in line
    int m = int(min(floor(t / MEAL), float(MEALS) - 1.0));
    float u = t - float(m) * MEAL;
    vec2 o = gOff[m];
    float ax = abs(o.x);
    return gFood[m] + (u < ax ? vec2(sign(o.x) * u, 0.0)
                              : vec2(o.x, sign(o.y) * (u - ax)));
}

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Board in the bottom-right corner, clear of the prompt. g = cell coords.
    vec2 origin = vec2(aspect - 0.05 - W * CELL, 0.04);
    vec2 g = (p - origin) / CELL;

    // Glass panel: rounded rectangle a little larger than the board.
    float panel = sdRoundBox(g - vec2(W, H) * 0.5, vec2(W, H) * 0.5 + 0.9, 1.4);
    if (panel > 3.0) { fragColor = base; return; }           // far away: free

    // ---- Replay the round (no memory between frames) ----------------------
    float roundSteps = float(MEALS) * MEAL + END;
    float steps = iTime * RATE;
    float rnd = floor(steps / roundSteps);
    float sRaw = mod(steps, roundSteps);
    float last = float(MEALS) * MEAL;
    float s = min(sRaw, last);                               // head stops at the end
    float endAge = max(sRaw - last, 0.0);                    // steps since the round ended

    // Dot positions. Each leg is MEAL steps; signs are picked so the snake
    // never doubles back across its own body (it may keep its x direction or
    // its y direction, never reverse both) and stays on the board.
    gFood[0] = floor(vec2(6.0 + hash(rnd, 1.0) * 6.0, 3.0 + hash(rnd, 2.0) * 5.0));
    float psx = hash(rnd, 3.0) < 0.5 ? -1.0 : 1.0;
    float psy = hash(rnd, 4.0) < 0.5 ? -1.0 : 1.0;
    for (int i = 0; i < MEALS; i++) {
        float fi = float(i);
        float ax = 3.0 + floor(hash(rnd, fi + 10.0) * 3.0);   // 3..5
        float ay = MEAL - ax;
        float sx = hash(rnd, fi + 20.0) < 0.5 ? -1.0 : 1.0;
        float sy = hash(rnd, fi + 30.0) < 0.5 ? -1.0 : 1.0;
        if (i == 0) sx = psx;
        if (sx != psx && sy != psy) {
            if (hash(rnd, fi + 40.0) < 0.5) sx = psx; else sy = psy;
        }
        vec2 c = gFood[i];
        if (c.x + sx * ax < 0.0 || c.x + sx * ax > W - 1.0) sx = -sx;
        if (c.y + sy * ay < 0.0 || c.y + sy * ay > H - 1.0) sy = -sy;
        gOff[i] = vec2(sx * ax, sy * ay);
        gFood[i + 1] = c + gOff[i];
        psx = sx; psy = sy;
    }

    // Length grows by one smoothly over the step right after each meal.
    float eaten = floor(s / MEAL);
    float since = s - eaten * MEAL;                          // steps since last meal
    float len = START_LEN + max(eaten - 1.0 + min(since, 1.0), 0.0);

    // Fade in at the start of a round, fade out after it ends.
    float life = smoothstep(0.0, 1.5, sRaw) * (1.0 - smoothstep(1.0, 5.0, endAge));

    vec2 q = g - 0.5;                                        // cell centres at integers
    vec3 light = vec3(0.0);
    vec3 halo = vec3(0.0);                                   // wide glow, lights nearby LEDs

    // ---- Snake: chain of rounded LED segments ---------------------------
    vec3 headC = vec3(0.86, 1.00, 0.97);
    vec3 neckC = vec3(0.30, 0.95, 0.90);
    vec3 tailC = vec3(0.45, 0.42, 1.00);
    float nSeg = ceil(len);
    for (int j = 0; j < MAXSEG; j++) {
        float fj = float(j);
        if (fj >= nSeg) break;
        vec2 c = headAt(s - fj);
        vec2 d = q - c;
        if (dot(d, d) > 30.0) continue;                      // too far to matter
        float k = fj / max(len - 1.0, 1.0);                  // 0 head .. 1 tail
        // The newest tail segment grows in rather than popping.
        float grow = clamp(len - fj, 0.0, 1.0);
        float half_ = mix(0.45, 0.32, k) * (0.4 + 0.6 * grow);
        float r = j == 0 ? half_ * 0.85 : half_ * 0.55;
        float sd = sdRoundBox(d, vec2(half_), r);
        vec3 col = j == 0 ? headC : mix(neckC, tailC, smoothstep(0.0, 1.0, k));
        float a = (j == 0 ? 0.95 : mix(0.75, 0.30, k)) * grow;
        float core = smoothstep(0.06, -0.06, sd);
        float inner = smoothstep(0.0, -0.25, sd);            // brighter centre
        light += col * a * (0.60 * core + 0.40 * inner);
        float bl = exp(-max(sd, 0.0) * 1.8);
        halo += col * a * bl * (j == 0 ? 0.55 : 0.30);
    }

    // ---- Food: pulsing dot, plus a burst when eaten ----------------------
    vec3 foodC = vec3(1.00, 0.62, 0.38);
    if (eaten < float(MEALS) && endAge <= 0.0) {
        vec2 f = gFood[int(eaten) + 1];
        float appear = smoothstep(0.0, 1.5, since);          // fades in after the last bite
        float pulse = 0.75 + 0.25 * sin(iTime * 5.0);
        float d = length(q - f);
        light += foodC * smoothstep(0.34, 0.22, d) * 0.9 * pulse * appear;
        halo += foodC * exp(-d * 1.5) * 0.6 * pulse * appear;
    }
    if (eaten >= 1.0) {
        vec2 f = gFood[int(eaten)];                          // the dot just eaten
        float age = (s - eaten * MEAL) / RATE + endAge / RATE; // seconds since the bite
        if (age < 0.9) {
            float d = length(q - f);
            float ringR = 0.4 + age * 4.5;
            float fade = 1.0 - age / 0.9;
            float ring = exp(-pow((d - ringR) / 0.22, 2.0)) * fade * fade;
            // A few short rays, rotated per bite so it doesn't look stamped.
            vec2 v = q - f;
            float ang = atan(v.y, v.x) + eaten * 1.3;
            float rays = pow(abs(cos(ang * 4.0)), 24.0) * exp(-pow((d - ringR * 0.8) / 0.6, 2.0));
            vec3 bc = mix(foodC, vec3(1.0, 0.95, 0.85), 0.4);
            light += bc * (ring * 0.7 + rays * 0.5 * fade);
            halo += bc * exp(-d * 1.6) * fade * fade * 0.6;
        }
    }

    light *= life;
    halo *= life;

    // ---- Glass panel, unlit LED grid, rim, end-of-round flash ------------
    float inPanel = smoothstep(0.15, -0.15, panel);
    float flash = smoothstep(0.0, 1.0, endAge) * exp(-max(endAge - 1.0, 0.0) * 0.9);

    vec3 col = base.rgb;
    col = mix(col, vec3(0.02, 0.05, 0.08), GLASS * inPanel);           // tinted glass

    // Unlit LEDs: faint rounded squares in every cell, warmed by nearby light.
    vec2 cell = floor(g);
    if (cell.x >= 0.0 && cell.y >= 0.0 && cell.x < W && cell.y < H) {
        float led = smoothstep(0.05, -0.05, sdRoundBox(fract(g) - 0.5, vec2(0.30), 0.12));
        col += led * (vec3(0.10, 0.20, 0.24) * 0.22 + halo * 0.35 + vec3(0.6, 0.85, 1.0) * flash * 0.10);
    }

    // Luminous rim light and a soft sheen along the top of the glass.
    float rim = exp(-abs(panel) * 4.0);
    float sheen = inPanel * smoothstep(H * 0.4, H + 1.0, g.y) * 0.05;
    col += vec3(0.45, 0.80, 1.00) * (rim * (0.16 + 0.25 * flash) + sheen);
    col += vec3(0.55, 0.85, 1.0) * flash * 0.10 * inPanel;

    col += (light + halo * 0.6 * BLOOM) * INTENSITY;
    fragColor = vec4(col, base.a);
}
