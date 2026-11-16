// meteors — a realistic meteor shower: thin streaks radiate from a point above the top right, with an occasional fragmenting fireball that leaves a twisting train.
// zh: 流星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.95;   // overall brightness (0 = off)
const int   SLOTS     = 5;      // independent meteor slots (together: one every ~1-2 s)
const float STARS     = 0.55;   // background starfield brightness (0 = no stars)
const float FIREBALL_EVERY = 13.0;   // seconds between bright fireballs (bolides)
const float FIREBALL_FIRST = 4.0;    // time of the first fireball
const float TRAIN_LIFE = 4.0;   // e-folding time of the fireball's persistent train, seconds

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 v)  { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453123); }

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// The shower radiant: every meteor's path points straight away from it
// (perspective of parallel tracks), so the streaks fan out like in a photo.
vec2 radiant(float aspect) { return vec2(aspect * 0.93, 1.28); }

// Natural meteor colours: mostly white, some magnesium green/teal, some
// sodium orange/yellow. Kept fairly pale, as cameras record them.
vec3 meteorColour(float h) {
    if (h < 0.58) return vec3(0.93, 0.96, 1.00);
    if (h < 0.80) return vec3(0.62, 1.00, 0.78);
    if (h < 0.90) return vec3(0.60, 0.95, 1.00);
    return vec3(1.00, 0.80, 0.52);
}

// A thin, crisp streak from tail a to head b: a Gaussian core about one pixel
// wide that tapers and dims toward the tail, plus a tight head point.
vec3 streak(vec2 p, vec2 a, vec2 b, float w, float px, vec3 col, float bright, float headB) {
    vec2 s = segment(p, a, b);
    float h = s.y;
    float wt = max(mix(0.35, 1.0, h) * w, 0.55 * px);            // taper toward the tail
    float core = exp(-(s.x * s.x) / (wt * wt)) * pow(h, 1.6);
    float rim  = 0.10 * exp(-s.x / (2.0 * px)) * h * h;            // slight film bloom, tight
    float dh = length(p - b);
    float head = exp(-(dh * dh) / (1.6 * w * w)) * 1.4 + 0.18 * exp(-dh / (3.0 * px));
    vec3 tail = mix(col, vec3(1.0, 0.82, 0.62), 0.25 * (1.0 - h)); // tails cool a touch warmer
    return tail * (core + rim) * bright + mix(col, vec3(1.0), 0.6) * head * headB;
}

// Fixed, crisp starfield: one candidate star per grid cell, magnitudes
// following a steep power law (many faint, few bright), real star colours.
vec3 starLayer(vec2 p, float px, float cell, float seed, float density) {
    vec2 g = floor(p / cell);
    float h = hash2(g + seed);
    if (h > density) return vec3(0.0);
    vec2 c = (g + 0.15 + 0.7 * vec2(hash2(g + seed + 3.7), hash2(g + seed + 9.1))) * cell;
    float d = length(p - c);
    float m = pow(hash2(g + seed + 17.3), 7.0);                    // 0 faint .. 1 bright
    float r = px * (0.55 + 0.75 * m);
    float tw = 1.0 + 0.22 * sin(iTime * (1.7 + 2.3 * h) + h * 61.0) * (1.0 - m * 0.5);
    float b = (0.20 + 1.3 * m) * tw;
    float t = hash2(g + seed + 29.0);                              // colour temperature
    vec3 col = t < 0.25 ? vec3(0.78, 0.86, 1.0) : (t > 0.85 ? vec3(1.0, 0.84, 0.64) : vec3(1.0, 0.97, 0.92));
    return col * b * (exp(-(d * d) / (r * r)) + 0.06 * m * exp(-d / (2.5 * px)));
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

    vec3 col = vec3(0.0);

    // ---- starfield (two layers: sparse brighter + dense faint)
    vec3 st = starLayer(p, px, 0.060, 1.0, 0.55) + starLayer(p, px, 0.026, 41.0, 0.45) * 0.6;
    col += st * STARS * (1.0 - 0.6 * textZone);

    vec2 R = radiant(aspect);

    // ---- ordinary meteors. Each slot fires once per period at a random moment,
    // so together they arrive irregularly, roughly every 1-2 seconds.
    for (int i = 0; i < SLOTS; i++) {
        float fi = float(i);
        float period = 4.6 + fi * 0.8;
        float t = iTime / period + fi * 0.23;
        float n = floor(t);
        float seed = n * 11.31 + fi * 47.7;
        float life = mix(0.30, 1.20, hash1(seed + 1.0));
        // Random start within the period; the very first meteor fires at once.
        float start = (period - life - 0.3) * hash1(seed);
        if (i == 0 && n < 0.5) start = 0.25;
        float age = fract(t) * period - start;
        if (age < 0.0 || age > life + 0.25) continue;

        // Path: a ray from the radiant, mostly toward down-left / down.
        float ang = mix(0.05, 1.0, hash1(seed + 2.0));               // radians from straight down
        float d0  = mix(0.30, 0.85, hash1(seed + 3.0));              // where along the ray it ignites
        vec2 dir = vec2(-sin(ang), -cos(ang));
        float len = mix(0.18, 0.42, hash1(seed + 4.0)) * (0.7 + 0.6 * life);
        vec2 a0 = R + dir * d0;
        vec2 e0 = a0 + dir * len;
        // Rarely cross the text: if the path would end in the top-left, steer it down.
        if (e0.x < 0.52 * aspect && e0.y > 0.50) {
            ang *= 0.45;
            dir = vec2(-sin(ang), -cos(ang));
            a0 = R + dir * d0;
            e0 = a0 + dir * len;
        }
        // Cheap reject: pixel nowhere near this path.
        if (segment(p, a0, e0).x > 0.03) continue;

        float k  = age / life;
        float hk = min(k, 1.0);
        float tk = clamp(k - 0.45, 0.0, 1.0) + max(k - 1.0, 0.0) * 2.0; // tail catches up after burnout
        vec2 head = mix(a0, e0, hk);
        vec2 tail = mix(a0, e0, min(tk, hk));

        float mag  = hash1(seed + 5.0);                               // brightness class
        float lc   = sin(PI * pow(hk, 1.3));                          // rises, peaks late, burns out
        float fade = exp(-max(age - life, 0.0) * 14.0);
        float trailB = smoothstep(0.0, 0.15, k) * fade * (0.55 + 0.6 * mag);
        float w = px * (0.8 + 0.7 * mag);
        vec3 c = meteorColour(hash1(seed + 6.0));
        col += streak(p, tail, head, w, px, c, trailB * mix(0.6, 1.0, lc), lc * (0.6 + 0.6 * mag))
               * (1.0 - 0.55 * textZone);
    }

    // ---- fireball (bolide): long, bright, flares, breaks into pieces and
    // leaves a faint glowing train that drifts and twists in the upper winds.
    float bn = floor((iTime - FIREBALL_FIRST) / FIREBALL_EVERY);
    if (bn >= 0.0) {
        float ba = mod(iTime - FIREBALL_FIRST, FIREBALL_EVERY);      // seconds since it ignited
        float bs = bn * 7.77 + 3.0;
        float flight = 1.7;
        float ang = mix(0.30, 0.44, hash1(bs));
        vec2 dir = vec2(-sin(ang), -cos(ang));
        vec2 nrm = vec2(-dir.y, dir.x);
        vec2 S = R + dir * mix(0.22, 0.32, hash1(bs + 1.0));
        float L = mix(0.95, 1.10, hash1(bs + 2.0));
        vec2 E = S + dir * L;
        float kSplit = 0.66;

        // Persistent train: formed where the head passed; each bit ages from that moment.
        vec2 v = p - S;
        float u = dot(v, dir) / L;                                   // 0..1 along the path
        float nOff = dot(v, nrm);
        float headK = min(ba / flight, 1.0);
        if (u > 0.08 && u < headK && abs(nOff) < 0.08) {
            float ta = ba - u * flight;                              // age of this part of the train
            float drift = 0.006 * ta;                                // wind shear grows with age
            float o = drift * (sin(u * 11.0 + ta * 0.55 + bs) + 0.6 * sin(u * 27.0 - ta * 0.35 + bs * 2.0))
                    + 0.0025 * ta * (u - 0.5);
            float d = abs(nOff - o);
            float wt = px * (1.0 + 0.9 * ta);                        // slowly spreads
            float strength = (0.5 + 0.5 * exp(-pow((u - 0.62) / 0.12, 2.0)))   // densest at the flare
                           * (0.7 + 0.3 * sin(u * 43.0 + bs))                 // knotty, uneven
                           * exp(-ta / TRAIN_LIFE) * smoothstep(0.08, 0.18, u) * smoothstep(1.0, 0.9, u);
            vec3 tc = mix(vec3(0.55, 1.0, 0.72), vec3(1.0, 0.55, 0.42), smoothstep(0.5, 4.0, ta));
            float glow = exp(-(d * d) / (wt * wt)) * 0.55 / (1.0 + 0.5 * ta);
            col += tc * glow * strength * (1.0 - 0.5 * textZone);
        }

        if (ba < flight + 0.3) {
            float k = ba / flight;
            float fade = exp(-max(ba - flight, 0.0) * 10.0);
            float flare = exp(-pow((k - 0.60) / 0.05, 2.0)) * 2.5;  // the big flash before it breaks up
            float lc = smoothstep(0.0, 0.25, k) * (1.0 + flare);
            vec3 cw = vec3(0.86, 1.0, 0.90);                         // magnesium-green white

            // Main body until the split, then three fragments fanning out slightly.
            float km = min(k, kSplit);
            vec2 headM = mix(S, E, km);
            vec2 tailM = mix(S, E, clamp(min(k, 1.0) - 0.40, 0.0, km));
            if (k < kSplit + 0.25 && segment(p, tailM, headM).x < 0.04)
                col += streak(p, tailM, headM, px * 2.0, px, cw, lc * 1.1 * smoothstep(kSplit + 0.25, kSplit, k) * fade,
                              k < kSplit ? lc * 1.4 : 0.0);

            if (k > kSplit) {
                vec2 P0 = mix(S, E, kSplit);
                for (int j = 0; j < 3; j++) {
                    float fj = float(j);
                    float kEnd = 0.86 + 0.07 * fj;                     // each piece burns out at its own time
                    float f = clamp((k - kSplit) / (1.0 - kSplit), 0.0, 1.0);
                    float fe = min(k, kEnd);
                    float fr = (fe - kSplit) / (1.0 - kSplit);
                    float spread = (fj - 1.0) * 0.045 + 0.01 * (hash1(bs + fj) - 0.5);
                    float slow = 1.0 - 0.12 * abs(fj - 1.0);
                    vec2 fh = P0 + dir * L * (1.0 - kSplit) * fr * slow + nrm * spread * fr * fr;
                    float ft = max(fr - 0.45, 0.0);
                    vec2 ftl = P0 + dir * L * (1.0 - kSplit) * ft * slow + nrm * spread * ft * ft;
                    float alive = smoothstep(kEnd + 0.02, kEnd - 0.06, k) * fade;
                    float term = exp(-pow((k - kEnd + 0.03) / 0.025, 2.0)) * 1.2;   // last little flash
                    vec3 fc = j == 1 ? cw : vec3(1.0, 0.78, 0.50);
                    float fb = (1.0 + term) * alive * (j == 1 ? 1.0 : 0.75);
                    col += streak(p, ftl, fh, px * 1.4, px, fc, fb * 0.9, fb * 1.2) * step(0.001, f);
                }
            }
            // Tight bloom around the flare point (as a camera records a bright bolide).
            vec2 fp = mix(S, E, 0.60);
            float df = length(p - fp);
            col += vec3(0.9, 1.0, 0.92) * flare * fade * (exp(-df / (5.0 * px)) * 0.5 + exp(-df / (18.0 * px)) * 0.08);
        }
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
