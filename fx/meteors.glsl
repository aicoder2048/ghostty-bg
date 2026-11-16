// meteors — a meteor shower that builds from a few streaks to a dense burst and a splitting fireball, then calms down.
// zh: 流星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 1.0;    // overall brightness (0 = off)
const float CYCLE     = 11.0;   // seconds per shower cycle: quiet -> build-up -> climax -> calm
const float WIDTH     = 1.0;    // meteor thickness multiplier (1 = 2-3 px cores)
const float STARS     = 0.60;   // background starfield brightness (0 = no stars)
const int   QUIET     = 6;      // scattered meteors spread over the whole cycle
const int   BUILD     = 16;     // meteors of the build-up, arriving faster and faster
const int   BURST     = 9;      // meteors of the climax burst
const float FB_TIME   = 7.1;    // when in the cycle the big fireball ignites
const float FB_FLIGHT = 1.6;    // seconds the fireball takes to cross the sky

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 v)  { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453123); }

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// The shower radiant, just outside the top-right corner: every path points
// straight away from it, so the streaks fan out as in a long-exposure photo.
vec2 radiant(float aspect) { return vec2(aspect * 0.95, 1.12); }

// Natural meteor colours: mostly white, some magnesium green, some sodium
// yellow-orange, a few iron/calcium violet-blue tints.
vec3 meteorColour(float h) {
    if (h < 0.45) return vec3(0.92, 0.96, 1.00);
    if (h < 0.72) return vec3(0.60, 1.00, 0.72);
    if (h < 0.88) return vec3(1.00, 0.82, 0.50);
    return vec3(0.72, 0.80, 1.00);
}

// A crisp streak from tail a to head b: a solid core (w = half width) that
// tapers and fades toward the tail, a tight rim of light, and a bright round head.
vec3 streak(vec2 p, vec2 a, vec2 b, float w, float px, vec3 col, float bright, float headB) {
    vec2 s = segment(p, a, b);
    float h = s.y;
    float wt = max(mix(0.25, 1.0, h * h) * w, 0.5 * px);           // taper toward the tail
    float core = smoothstep(wt + 0.8 * px, wt - 0.6 * px, s.x) * pow(h, 1.3);
    float rim  = 0.22 * exp(-s.x / (2.5 * px)) * h * h;            // thin, tight halo
    vec3 tail = mix(col, vec3(1.0, 0.70, 0.45), 0.35 * (1.0 - h));  // the old end cools warmer
    float dh = length(p - b);
    float rh = w * 1.35;                                            // the head is a bit fatter
    float head = smoothstep(rh + px, rh - 0.6 * px, dh) * 1.2 + 0.35 * exp(-dh / (3.0 * px));
    return tail * (core + rim) * bright + mix(col, vec3(1.0), 0.65) * head * headB;
}

// One ordinary meteor of the shower, already known to be alive (0 <= age < life+fade).
vec3 meteor(vec2 p, vec2 R, float px, float aspect, float textZone,
            float seed, float age, float life, float mag) {
    // Path: a ray from the radiant, from steeply down to down-left.
    float ang = mix(0.10, 1.10, hash1(seed + 2.0));                 // radians from straight down
    float d0  = mix(0.12, 0.55, hash1(seed + 3.0));                 // where along the ray it ignites
    vec2 dir = vec2(-sin(ang), -cos(ang));
    float len = mix(0.35, 0.65, hash1(seed + 4.0)) * (0.8 + 0.3 * mag);
    vec2 a0 = R + dir * d0;
    vec2 e0 = a0 + dir * len;
    // Rarely cross the text block: if the end lands top-left, steer it down.
    if (e0.x < 0.55 * aspect && e0.y > 0.45) {
        ang *= 0.5;
        dir = vec2(-sin(ang), -cos(ang));
        a0 = R + dir * d0;
        e0 = a0 + dir * len;
    }
    if (segment(p, a0, e0).x > 0.03) return vec3(0.0);             // pixel far from this path

    float k  = age / life;
    float hk = min(k, 1.0);
    float tk = clamp(k - 0.40, 0.0, 1.0) + max(k - 1.0, 0.0) * 2.5; // tail catches up after burnout
    vec2 head = mix(a0, e0, hk);
    vec2 tail = mix(a0, e0, min(tk, hk));

    float lc   = sin(PI * pow(hk, 1.2)) * 0.7 + 0.3 * smoothstep(0.0, 0.1, hk); // rises, peaks, dims
    float fade = exp(-max(age - life, 0.0) * 10.0);
    float w = px * (1.0 + 0.6 * mag) * WIDTH;                       // 2-3 px wide
    vec3 c = meteorColour(hash1(seed + 6.0));
    float b = (0.75 + 0.45 * mag) * fade;
    return streak(p, tail, head, w, px, c, b * lc, b * lc * (hk < 1.0 ? 1.0 : 0.3))
           * (1.0 - 0.6 * textZone);
}

// Fixed, crisp starfield: one candidate star per grid cell, magnitudes
// following a steep power law (many faint, few bright), real star colours.
vec3 starLayer(vec2 p, float px, float cell, float seed, float density) {
    vec2 g = floor(p / cell);
    float h = hash2(g + seed);
    if (h > density) return vec3(0.0);
    vec2 c = (g + 0.15 + 0.7 * vec2(hash2(g + seed + 3.7), hash2(g + seed + 9.1))) * cell;
    float d = length(p - c);
    float m = pow(hash2(g + seed + 17.3), 6.0);                    // 0 faint .. 1 bright
    float r = px * (0.6 + 0.9 * m);
    float tw = 1.0 + 0.25 * sin(iTime * (1.7 + 2.3 * h) + h * 61.0) * (1.0 - m * 0.5);
    float b = (0.25 + 1.2 * m) * tw;
    float t = hash2(g + seed + 29.0);                              // colour temperature
    vec3 col = t < 0.25 ? vec3(0.78, 0.86, 1.0) : (t > 0.85 ? vec3(1.0, 0.84, 0.64) : vec3(1.0, 0.97, 0.92));
    return col * b * smoothstep(r + px, r - 0.5 * px, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;                                // one pixel in scene units

    // Keep the top-left (where the shell text lives) calmer.
    float textZone = smoothstep(0.62 * aspect, 0.30 * aspect, p.x) * smoothstep(0.45, 0.75, p.y);

    // Start 1.5 s into the cycle so the first streaks appear right away.
    float T = iTime + 1.5;
    float cyc = floor(T / CYCLE);
    float c = T - cyc * CYCLE;                                     // seconds into this cycle

    vec3 col = vec3(0.0);

    // ---- starfield (sparse brighter + dense faint)
    vec3 st = starLayer(p, px, 0.065, 1.0, 0.55) + starLayer(p, px, 0.028, 41.0, 0.45) * 0.55;
    col += st * STARS * (1.0 - 0.6 * textZone);

    vec2 R = radiant(aspect);

    // ---- quiet phase: a few scattered meteors, roughly one every two seconds.
    for (int i = 0; i < QUIET; i++) {
        float fi = float(i);
        float seed = cyc * 91.7 + fi * 13.1;
        float start = (fi + 0.15 + 0.6 * hash1(seed)) * (9.6 / float(QUIET));
        if (cyc < 0.5 && i == 0) start = 1.55;                     // first meteor right at switch-on
        float life = mix(0.55, 0.95, hash1(seed + 1.0));
        float age = c - start;
        if (age < 0.0 || age > life + 0.4) continue;
        col += meteor(p, R, px, aspect, textZone, seed, age, life, 0.3 * hash1(seed + 5.0));
    }

    // ---- build-up: start times bunch up toward the climax (density grows
    // linearly with time), and later meteors are bigger and brighter.
    for (int i = 0; i < BUILD; i++) {
        float fi = float(i);
        float seed = cyc * 57.3 + fi * 7.9 + 400.0;
        float u = (fi + hash1(seed)) / float(BUILD);
        float start = 1.8 + 5.2 * sqrt(u);                         // 1.8 s .. 7 s
        float life = mix(0.45, 0.85, hash1(seed + 1.0));
        float age = c - start;
        if (age < 0.0 || age > life + 0.4) continue;
        float mag = clamp(0.25 + 0.6 * u + 0.3 * hash1(seed + 5.0), 0.0, 1.0);
        col += meteor(p, R, px, aspect, textZone, seed, age, life, mag);
    }

    // ---- climax burst: many bright meteors within about one second.
    for (int i = 0; i < BURST; i++) {
        float fi = float(i);
        float seed = cyc * 33.1 + fi * 5.3 + 900.0;
        float start = FB_TIME - 0.2 + (fi + hash1(seed)) * (1.2 / float(BURST));
        float life = mix(0.45, 0.80, hash1(seed + 1.0));
        float age = c - start;
        if (age < 0.0 || age > life + 0.4) continue;
        col += meteor(p, R, px, aspect, textZone, seed, age, life, 0.7 + 0.3 * hash1(seed + 5.0));
    }

    // ---- the fireball (bolide): a long bright streak across the sky that
    // flares, breaks into glowing fragments and leaves a twisting train.
    float ba = c - FB_TIME;                                        // seconds since it ignited
    if (ba > 0.0) {
        float bs = cyc * 7.77 + 3.0;
        float ang = mix(0.56, 0.66, hash1(bs));
        vec2 dir = vec2(-sin(ang), -cos(ang));
        vec2 nrm = vec2(-dir.y, dir.x);
        vec2 S = R + dir * 0.10;
        float L = mix(1.20, 1.35, hash1(bs + 2.0));
        float kSplit = 0.58;
        vec3 cw = vec3(0.80, 1.0, 0.84);                           // magnesium green-white

        // Persistent train: each bit of it was laid down when the head passed,
        // then widens and is twisted by wind shear as it ages; gone by cycle end.
        vec2 v = p - S;
        float u = dot(v, dir) / L;                                 // 0..1 along the path
        float nOff = dot(v, nrm);
        float headK = min(ba / FB_FLIGHT, 0.95);
        if (u > 0.05 && u < headK && abs(nOff) < 0.10) {
            float ta = ba - u * FB_FLIGHT;                         // age of this part of the train
            float sh = 0.010 * ta;                                 // twist amplitude grows with age
            float o = sh * (sin(u * 9.0 + ta * 0.7 + bs) + 0.5 * sin(u * 23.0 - ta * 0.5 + bs * 2.0));
            float d = abs(nOff - o);
            float wt = px * (1.5 + 1.2 * ta);                      // slowly spreads
            float strength = (0.45 + 0.55 * exp(-pow((u - kSplit) / 0.14, 2.0)))  // densest at the flare
                           * (0.75 + 0.25 * sin(u * 41.0 + bs))                  // knotty, uneven
                           * smoothstep(0.05, 0.15, u)
                           * smoothstep(CYCLE - FB_TIME - 0.1, CYCLE - FB_TIME - 1.1, ba);
            vec3 tc = mix(vec3(0.50, 1.0, 0.70), vec3(1.0, 0.55, 0.45), smoothstep(0.3, 2.5, ta));
            float body = smoothstep(wt + px, wt - px, d) * 0.40 + exp(-d / (wt + 2.0 * px)) * 0.18;
            col += tc * body * strength / (1.0 + 0.2 * ta) * (1.0 - 0.7 * textZone);
        }

        if (ba < FB_FLIGHT + 0.4) {
            float k = ba / FB_FLIGHT;
            float fade = exp(-max(ba - FB_FLIGHT, 0.0) * 8.0);
            float flare = exp(-pow((k - kSplit) / 0.05, 2.0));    // the flash as it breaks apart
            float lc = smoothstep(0.0, 0.15, k) * (1.0 + 1.2 * flare);

            // Main body up to the split.
            float km = min(k, kSplit);
            vec2 headM = S + dir * L * km;
            vec2 tailM = S + dir * L * clamp(min(k, 1.0) - 0.38, 0.0, km);
            float bodyOn = smoothstep(kSplit + 0.12, kSplit, k);
            if (bodyOn > 0.0 && segment(p, tailM, headM).x < 0.05)
                col += streak(p, tailM, headM, px * 3.2 * WIDTH, px, cw, lc * 1.1 * bodyOn * fade,
                              k < kSplit ? lc * 1.3 : 0.0);

            // Fragments fanning out slightly from the break-up point, each
            // burning out at its own time with a last small flash.
            if (k > kSplit) {
                vec2 P0 = S + dir * L * kSplit;
                for (int j = 0; j < 5; j++) {
                    float fj = float(j);
                    float kEnd = 0.88 + 0.06 * fract(fj * 0.618 + 0.3);
                    float fe = min(k, kEnd);
                    float fr = (fe - kSplit) / (1.0 - kSplit);
                    float spread = (fj - 2.0) * 0.06 + 0.012 * (hash1(bs + fj) - 0.5);
                    float slow = 1.0 - 0.08 * abs(fj - 2.0);
                    vec2 fh = P0 + dir * L * (1.0 - kSplit) * fr * slow + nrm * spread * fr;
                    float ft = max(fr - 0.40, 0.0);
                    vec2 ftl = P0 + dir * L * (1.0 - kSplit) * ft * slow + nrm * spread * ft;
                    if (segment(p, ftl, fh).x > 0.04) continue;
                    float alive = smoothstep(kEnd + 0.03, kEnd - 0.05, k) * fade;
                    float term = exp(-pow((k - kEnd + 0.02) / 0.02, 2.0));
                    vec3 fc = j == 2 ? cw : (j == 1 || j == 3 ? vec3(1.0, 0.86, 0.55) : vec3(1.0, 0.66, 0.42));
                    float fb = (1.0 + 0.8 * term) * alive * (j == 2 ? 1.0 : 0.8);
                    col += streak(p, ftl, fh, px * (j == 2 ? 2.4 : 1.8) * WIDTH, px, fc, fb, fb * 1.1);
                }
            }
            // Tight flash at the break-up point (crisp, only a few pixels of bloom).
            vec2 fp = S + dir * L * kSplit;
            float df = length(p - fp);
            col += vec3(0.85, 1.0, 0.88) * flare * fade * (smoothstep(7.0 * px, 4.0 * px, df) * 0.6 + exp(-df / (10.0 * px)) * 0.35);
        }
    }

    // Soft shoulder instead of hard clipping, so bright overlaps never become flat white blobs.
    col = 1.0 - exp(-col * 1.3);
    fragColor = vec4(base.rgb + col * INTENSITY, base.a);
}
