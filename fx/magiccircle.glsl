// magiccircle — a glowing summoning circle on the ground near the bottom, slowly turning and pulsing.
// zh: 魔法阵
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.45;   // overall brightness (0 = off)
const float RADIUS    = 0.36;   // circle radius (screen heights, across)
const float TILT      = 0.30;   // how flat the ground makes it look (1 = seen from above)
const float PI        = 3.14159265;

// A thin glowing line at distance d (in circle units).
float line(float d, float w) {
    d = abs(d);
    return smoothstep(w, w * 0.3, d) + 0.25 * exp(-d * 40.0);
}

mat2 rot(float a) {
    return mat2(cos(a), -sin(a), sin(a), cos(a));
}

// Star polygon {n/k}: n chords, each joining vertex i to vertex i+k on a
// circle of radius R. A chord crosses several sectors, so measure all of them.
float starPoly(vec2 g, int n, float k, float R) {
    float d = 1e5;
    for (int i = 0; i < 12; i++) {
        if (i >= n) break;
        float a0 = 2.0 * PI * float(i) / float(n);
        float a1 = a0 + 2.0 * PI * k / float(n);
        vec2 a = R * vec2(cos(a0), sin(a0)), b = R * vec2(cos(a1), sin(a1));
        vec2 pa = g - a, ba = b - a;
        d = min(d, length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)));
    }
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Ground coordinates: squash vertically so the circle lies flat, and narrow
    // the far side a little for perspective. In g the circle has radius 1.
    vec2 g = (p - vec2(aspect * 0.5, 0.17)) / vec2(RADIUS, RADIUS * TILT);
    g.x *= 1.0 + 0.18 * g.y;
    if (dot(g, g) > 1.6) {
        fragColor = base;
        return;
    }

    float t = iTime;
    vec2 g1 = rot(t * 0.08) * g;                     // outer parts turn one way
    vec2 g2 = rot(-t * 0.13) * g;                    // inner parts the other
    float r = length(g);
    float a1 = atan(g1.y, g1.x);

    float v = 0.0;
    v += line(r - 1.0, 0.022) + line(r - 0.93, 0.014);          // outer double ring
    v += line(r - 0.66, 0.016) + line(r - 0.60, 0.012);         // inner double ring
    v += line(r - 0.22, 0.012);                                 // centre ring

    // Tick marks between the outer rings; every sixth one is longer.
    float tick = abs(fract(a1 / (2.0 * PI) * 72.0 + 0.5) - 0.5);
    float longTick = step(abs(fract(a1 / (2.0 * PI) * 12.0 + 0.5) - 0.5), 0.04);
    float tickBand = step(0.93, r) * step(r, 1.0) * step(mix(0.965, 0.93, longTick), r);
    v += smoothstep(0.12, 0.04, tick) * tickBand * 0.8;

    // Twelve small seal circles in the wide band, each with a dot inside.
    float sector = 2.0 * PI / 12.0;
    float sa = mod(a1 + sector * 0.5, sector) - sector * 0.5;
    vec2 sc = r * vec2(cos(sa), sin(sa)) - vec2(0.795, 0.0);
    v += line(length(sc) - 0.075, 0.010) + smoothstep(0.025, 0.01, length(sc));

    // An eight-pointed star inside the inner ring, and a square at the centre.
    v += line(starPoly(g1, 8, 3.0, 0.60), 0.014);
    v += line(starPoly(g2, 4, 1.0, 0.22), 0.012);

    // Breathing pulse, plus a brighter arc chasing around the circle.
    float pulse = 0.7 + 0.3 * sin(t * 1.4);
    float chase = 0.75 + 0.25 * sin(atan(g.y, g.x) - t * 1.5);
    vec3 color = mix(vec3(1.0, 0.65, 0.25), vec3(1.0, 0.90, 0.60), chase - 0.5);
    vec3 glow = color * v * pulse * chase
              + vec3(1.0, 0.6, 0.25) * smoothstep(1.0, 0.0, r) * 0.08 * pulse;   // faint floor glow

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
