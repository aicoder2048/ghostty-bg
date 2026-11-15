// dolphins — dolphins leap out of the water near the bottom in arcs, splashing in and out.
// zh: 海豚
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 3;      // number of dolphins
const float WATER     = 0.13;   // height of the water line (fraction of the window height)
const float SIZE      = 0.11;   // half a dolphin's length
const float LEAP      = 1.7;    // seconds a leap takes from leaving the water to diving back
const float SPLASH    = 0.9;    // seconds a splash lasts

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Signed distance to a tapered tube from a (radius ra) to b (radius rb).
float tube(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 s = segment(p, a, b);
    return s.x - mix(ra, rb, s.y);
}

// A dolphin seen from the side, facing +x, about 2 long (tail at x = -1).
float dolphin(vec2 q, float aa) {
    // Body: a rounded melon in front, thickest just behind it, a long thin tail stock.
    float h;
    if (q.x > 0.15) {
        float k = (q.x - 0.15) / 0.62;
        h = 0.20 * sqrt(max(1.0 - k * k, 0.0));
    } else {
        float k = (0.15 - q.x) / 1.0;
        h = 0.03 + 0.17 * pow(max(1.0 - k * k, 0.0), 0.8);
    }
    h *= q.y > 0.0 ? 1.0 : 0.85;
    float d = max(abs(q.y) - h, max(-0.88 - q.x, q.x - 0.77));

    d = min(d, tube(q, vec2(0.62, -0.03), vec2(1.00, -0.07), 0.06, 0.03));   // beak
    // Curved dorsal fin, swept back like a hook.
    d = min(d, tube(q, vec2(0.12, 0.16), vec2(-0.28, 0.42), 0.09, 0.012));
    d = min(d, tube(q, vec2(-0.12, 0.15), vec2(-0.28, 0.42), 0.06, 0.012));
    d = min(d, tube(q, vec2(0.40, -0.13), vec2(0.20, -0.32), 0.05, 0.015)); // flipper
    float shape = smoothstep(aa, -aa, d);

    // Tail flukes: two swept-back lobes.
    float fx = -0.86 - q.x;
    float fy = abs(q.y);
    float fluke = smoothstep(aa, -aa, max(max(0.7 * fy - 0.03 - fx, fx - 0.06 - 0.9 * fy), fy - 0.22));

    float eye = smoothstep(0.035, 0.018, length(q - vec2(0.58, 0.03)));
    return max(shape, fluke) * (1.0 - 0.8 * eye);
}

// A splash at point c on the water line: a few drops thrown up and a flat ring.
float splash(vec2 p, vec2 c, float age, float seed) {
    if (age < 0.0 || age > SPLASH) return 0.0;
    float fade = 1.0 - age / SPLASH;
    float light = 0.0;
    for (int k = 0; k < 8; k++) {
        float fk = float(k) + seed;
        vec2 v = vec2((hash1(fk * 12.99) - 0.5) * 0.35, 0.30 + 0.30 * hash1(fk * 78.23));
        vec2 pos = c + v * age + vec2(0.0, -0.9 * age * age);
        light += smoothstep(0.012, 0.004, length(p - pos)) * step(WATER - 0.005, pos.y);
    }
    vec2 r = (p - c) / vec2(1.0, 0.22);                           // ring flattened onto the water
    light += smoothstep(0.006, 0.0, abs(length(r) - (0.02 + 0.09 * age))) * 0.7;
    return light * fade;
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // A faint, gently rippling water line.
    float wave = WATER + 0.004 * sin(p.x * 40.0 + iTime * 2.0) + 0.003 * sin(p.x * 17.0 - iTime * 1.3);
    float above = smoothstep(wave - 0.004, wave + 0.004, p.y);
    float a = smoothstep(2.0 / iResolution.y, 0.0, abs(p.y - wave)) * 0.35;

    float aa = 1.5 / (iResolution.y * SIZE);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        // Each dolphin leaps on its own beat; the first jumps half a second in.
        float period = 5.5 + 1.1 * fi;
        float lt = iTime + period - 0.5 - 2.0 * fi;
        float n = floor(lt / period) + fi * 17.0;                 // which leap this is
        float f = mod(lt, period);                                // seconds into this leap

        // A new place and direction for every leap.
        float dir = hash1(n * 3.1 + 0.7) > 0.5 ? 1.0 : -1.0;
        float len = 0.75;                                         // horizontal reach of the arc
        float height = 0.26 + 0.08 * hash1(n * 5.3);
        float x0 = 0.1 + hash1(n * 7.7 + 1.0) * max(aspect - len - 0.2, 0.0);
        float xs = dir > 0.0 ? x0 : x0 + len;                     // where it leaves the water
        float xe = dir > 0.0 ? x0 + len : x0;                     // where it dives back in

        float s = f / LEAP;                                       // 0..1 along the arc
        if (s < 1.0) {
            // A parabola that starts and ends a little under the surface.
            float y = WATER - 0.06 + (height + 0.06) * 4.0 * s * (1.0 - s);
            float x = mix(xs, xe, s);
            // Point the body along the arc: nose up on the way up, down on the way down.
            float ang = atan((height + 0.06) * 4.0 * (1.0 - 2.0 * s), len);
            vec2 q = (p - vec2(x, y)) / SIZE;
            q.x *= dir;
            q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * q;
            a = max(a, dolphin(q, aa) * mix(0.2, 1.0, above));    // faint under the water
        }
        a = max(a, splash(p, vec2(xs, WATER), f - 0.15, fi * 7.0));        // leaving
        a = max(a, splash(p, vec2(xe, WATER), f - LEAP + 0.15, fi * 7.0 + 3.0));  // diving in
    }

    vec3 color = vec3(0.72, 0.86, 1.0);
    fragColor = vec4(blend(base.rgb, color, a * INTENSITY), base.a);
}
