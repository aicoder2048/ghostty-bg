// runes — ancient runes trace themselves stroke by stroke on a slowly turning ring of light, then burn away into embers.
// zh: 符文
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   SLOTS     = 7;      // runes riding the ring
const float PERIOD    = 10.0;   // seconds in one rune's life (draw, hold, burn, rest)
const float STAGGER   = 1.3;    // seconds between the first appearances of neighbouring slots
const float SPIN      = 0.07;   // ring rotation speed (radians per second)
const vec2  CENTER    = vec2(0.76, 0.34);  // ring centre: x as a fraction of width, y up
const vec2  RADII     = vec2(0.25, 0.10);  // ring ellipse radii (screen heights)
const float TILT      = 0.22;   // ring tilt in radians (left side lower)
const float GLYPH     = 0.066;  // rune half-height in screen heights (front of the ring)
const float PI        = 3.14159265;

// Life of each rune, in seconds from its birth.
const float T_DRAW = 2.2;   // strokes are traced during [0, T_DRAW]
const float T_BURN = 7.0;   // starts dissolving here ...
const float T_GONE = 9.0;   // ... and is gone here; embers keep rising a little longer

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

mat2 rot(float a) {
    return mat2(cos(a), -sin(a), sin(a), cos(a));
}

// Distance to segment a-b, plus where along it the closest point lies.
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// Distance to an arc of radius r around c, from angle a0 sweeping `span`.
float arcDist(vec2 p, vec2 c, float r, float a0, float span) {
    vec2 d = p - c;
    float a = mod(atan(d.y, d.x) - a0, 2.0 * PI);
    if (a <= span) return abs(length(d) - r);
    vec2 e0 = c + r * vec2(cos(a0), sin(a0));
    vec2 e1 = c + r * vec2(cos(a0 + span), sin(a0 + span));
    return min(length(p - e0), length(p - e1));
}

// Where a rune slot sits on the ring at angle `ang`; z = 1 front, 0 back.
// The top half of the ellipse is the far side, so it is smaller and dimmer.
vec3 ringPoint(float ang, vec2 c) {
    vec2 l = vec2(RADII.x * cos(ang), RADII.y * sin(ang));
    return vec3(c + rot(TILT) * l, 0.5 - 0.5 * sin(ang));
}

// One rune: four strokes on an Elder-Futhark-like grid (x -0.6..0.6, y -1..1).
// Stroke 0 is the main staff; stroke 1 is a second staff or a diagonal branch;
// stroke 2 often mirrors stroke 1 (arrow / fork shapes like Tiwaz or Algiz);
// stroke 3 is an extra branch, a curved arcane mark, or nothing.
// `t` is the drawing clock: each stroke traces in turn. Returns the distance
// to the drawn part (glyph units) in .x, and the distance to the pen tip in .y.
vec2 rune(vec2 q, float seed, float t) {
    float twin = step(0.72, hash1(seed + 0.11));          // two staves (H / M shapes)
    float sx = twin > 0.5 ? -0.42 : 0.0;
    float d = 1e5, tip = 1e5;

    for (int j = 0; j < 4; j++) {
        float fj = float(j);
        float prog = clamp(t * 4.0 / T_DRAW - fj, 0.0, 1.0);  // 0..1 for this stroke
        if (prog <= 0.0) break;                                 // later strokes not started
        prog = prog * prog * (3.0 - 2.0 * prog);                // eased pen speed
        float s = seed + fj * 7.31;

        vec2 a, b;
        bool arc = false;
        if (j == 0) {
            a = vec2(sx, 1.0); b = vec2(sx, -1.0);
        } else if (j == 1 && twin > 0.5) {
            a = vec2(0.42, 1.0); b = vec2(0.42, -1.0);
        } else {
            // Branch from a point on the staff out to the side, mostly downward
            // diagonals - that is what makes carved letters read as runes.
            float y0 = 1.0 - floor(hash1(s + 0.2) * 3.5) * 0.5;
            float side = hash1(s + 0.4) < 0.5 ? -1.0 : 1.0;
            float dy = -0.35 - 0.35 * floor(hash1(s + 0.5) * 2.0);
            if (hash1(s + 0.6) < 0.25) dy = -dy;                // a few rise instead
            float x0 = twin > 0.5 ? (side > 0.0 ? -0.42 : 0.42) : sx;
            a = vec2(x0, y0);
            b = vec2(twin > 0.5 ? -x0 : side * 0.6, clamp(y0 + dy, -1.0, 1.0));
            if (j == 2 && hash1(seed + 0.33) < 0.55) {
                // Mirror the previous branch (recompute it with j = 1's seed).
                float s1 = seed + 7.31;
                float y1 = 1.0 - floor(hash1(s1 + 0.2) * 3.5) * 0.5;
                float sd1 = hash1(s1 + 0.4) < 0.5 ? -1.0 : 1.0;
                float dy1 = -0.35 - 0.35 * floor(hash1(s1 + 0.5) * 2.0);
                if (hash1(s1 + 0.6) < 0.25) dy1 = -dy1;
                a = vec2(sx, y1);
                b = vec2(-sd1 * 0.6, clamp(y1 + dy1, -1.0, 1.0));
                if (twin > 0.5) { a = vec2(-0.42, y1); b = vec2(0.42, clamp(y1 + dy1, -1.0, 1.0)); }
            }
            if (j == 3) {
                float k = hash1(seed + 0.77);
                if (k < 0.3) break;                             // three-stroke rune
                arc = k > 0.62;                                 // curved arcane mark
            }
        }

        if (arc) {
            // A crescent hugging the staff, swept by the pen like the lines.
            float cy = hash1(s + 0.8) < 0.5 ? 0.45 : -0.45;
            vec2 c = vec2(sx + (twin > 0.5 ? 0.42 : 0.0), cy);
            float a0 = hash1(s + 0.9) * 2.0 * PI;
            float span = 1.5 * PI * prog;
            d = min(d, arcDist(q, c, 0.5, a0, span));
            if (prog < 1.0) tip = length(q - c - 0.5 * vec2(cos(a0 + span), sin(a0 + span)));
        } else {
            vec2 e = mix(a, b, prog);
            d = min(d, segDist(q, a, e));
            if (prog < 1.0) tip = length(q - e);
        }
    }
    return vec2(d, tip);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec2 c = vec2(CENTER.x * aspect, CENTER.y);
    float theta = iTime * SPIN;

    const vec3 GOLD = vec3(1.00, 0.74, 0.38);
    const vec3 BLUE = vec3(0.42, 0.72, 1.00);
    vec3 glow = vec3(0.0);

    // --- Orbit trail: a faint ellipse, brighter in front and pooled under runes.
    vec2 lp = rot(-TILT) * (p - c);
    vec2 ln = lp / RADII;
    float e = length(ln);
    float ed = abs(e - 1.0) * e / max(length(lp / (RADII * RADII)), 1e-4);  // ~distance
    float ringAng = atan(ln.y, ln.x);
    float ringZ = 0.5 - 0.5 * sin(ringAng);
    float pools = pow(0.5 + 0.5 * cos(float(SLOTS) * (ringAng - theta)), 8.0);
    float trail = (0.16 * exp(-ed * 700.0) + 0.07 * exp(-ed * 110.0))
                * mix(0.25, 1.0, ringZ) * (0.55 + 1.2 * pools);
    // The ring breathes in gold and blue, following whichever set is alive.
    float setMix = 0.5 + 0.5 * cos(PI * max(iTime - 1.0, 0.0) / PERIOD);
    vec3 ringCol = mix(BLUE, GOLD, setMix);
    glow += ringCol * trail;

    // --- Invisible centre: just a very soft haze so the ring has a heart.
    vec2 hc = (p - c) / vec2(0.30, 0.18);
    glow += ringCol * 0.035 * exp(-dot(hc, hc));

    // --- Drifting motes around the ring (one cell lookup per pixel).
    vec2 mg = p * 11.0 + vec2(0.0, -iTime * 0.25);
    vec2 mid = floor(mg);
    float mh = hash1(mid.x * 13.7 + mid.y * 71.3);
    if (mh > 0.55) {
        vec2 mp = mid + 0.5 + 0.3 * vec2(sin(iTime * 0.6 + mh * 40.0), cos(iTime * 0.5 + mh * 23.0));
        float md = length(mg - mp) / 11.0;
        vec2 mr = (p - c) / vec2(0.48, 0.30);
        float near = exp(-dot(mr, mr));
        float tw = 0.5 + 0.5 * sin(iTime * 1.7 + mh * 60.0);
        glow += mix(BLUE, GOLD, step(0.78, mh)) * (0.0000035 / (md * md + 0.000006)) * near * tw * 0.5;
    }

    // --- The runes themselves.
    for (int i = 0; i < SLOTS; i++) {
        float fi = float(i);
        float lt = iTime - fi * STAGGER;          // slot i first appears after a delay
        if (lt < 0.0) continue;
        float cyc = floor(lt / PERIOD);
        lt -= cyc * PERIOD;
        if (lt > T_GONE + 1.0) continue;          // resting between runes

        vec3 rp = ringPoint(theta + fi * 2.0 * PI / float(SLOTS), c);
        float z = rp.z;
        float size = GLYPH * mix(0.58, 1.0, z);
        float bright = mix(0.25, 1.0, z);
        vec2 q = (p - rp.xy) / size;

        float seed = fi * 17.3 + cyc * 3.11 + 1.0;
        vec3 col = mod(cyc, 2.0) < 0.5 ? GOLD : BLUE;
        col = mix(col, vec3(0.62, 0.70, 0.85), 0.35 * (1.0 - z));   // far side sinks into haze

        // Embers: while it burns, sparks lift off the rune and fade as they rise.
        if (lt > T_BURN && abs(q.x) < 3.0 && q.y > -1.4 && q.y < 9.0) {
            for (int k = 0; k < 8; k++) {
                float fk = float(k);
                float hs = seed + fk * 5.17;
                float age = lt - T_BURN - hash1(hs + 0.1) * 1.6;
                if (age <= 0.0 || age > 2.4) continue;
                vec2 o = vec2(hash1(hs + 0.2) * 1.2 - 0.6, hash1(hs + 0.3) * 2.0 - 1.0);
                o += vec2(0.25 * sin(age * 2.5 + fk), age * (1.6 + 1.2 * hash1(hs + 0.4)));
                float dd = length(q - o) * size;
                float a = smoothstep(0.0, 0.2, age) * (1.0 - age / 2.4);
                glow += mix(col, vec3(1.0, 0.55, 0.25), 0.4) * (0.000013 / (dd * dd + 0.000009)) * a * bright;
            }
        }

        if (max(abs(q.x), abs(q.y) * 0.8) > 2.2) continue;   // far from this rune: skip strokes

        vec2 r = rune(q, seed, lt);
        float ds = r.x * size;                      // back to screen units for even glow
        float burn = smoothstep(T_BURN, T_GONE, lt);
        float thr = burn * 1.25 - 0.12;
        float n = noise(q * 2.6 + seed);
        float keep = smoothstep(thr, thr + 0.14, n);
        float edge = keep * (1.0 - keep) * 4.0 * step(0.001, burn);   // glowing burn front

        float window = smoothstep(2.2, 1.5, max(abs(q.x), abs(q.y) * 0.8));
        float core = smoothstep(0.0036, 0.0012, ds);
        float halo = 0.40 * exp(-ds * 130.0) + 0.16 * exp(-ds * 40.0) * window;
        float pulse = 0.85 + 0.15 * sin(iTime * 1.3 + fi * 2.1);
        float lit = (core * 0.9 + halo) * pulse;
        // Freshly finished runes flare a little, then settle.
        lit *= 1.0 + 0.6 * exp(-max(lt - T_DRAW, 0.0) * 1.5) * step(T_DRAW * 0.9, lt);
        vec3 lineCol = mix(col, vec3(1.0, 0.97, 0.9), core * 0.5);
        glow += lineCol * lit * keep * bright;
        glow += vec3(1.0, 0.6, 0.3) * edge * (core + halo) * 1.2 * bright;

        // Pen tip: a small white-hot point with a soft flare.
        if (lt < T_DRAW) {
            float td = r.y * size;
            glow += mix(col, vec3(1.0), 0.6) * (0.000014 / (td * td + 0.000007) + 0.18 * exp(-td * 70.0)) * bright;
        }
    }

    // Keep the top-left (where the shell text sits) a touch quieter.
    float tl = smoothstep(0.55, 0.0, length(vec2(uv.x * 1.3, uv.y * 1.6)));
    glow *= 1.0 - 0.6 * tl;

    glow = 1.0 - exp(-glow * 1.4);              // soft bloom-like rolloff, no hard clip
    fragColor = vec4(base.rgb + glow * INTENSITY, base.a);
}
