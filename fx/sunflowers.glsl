// sunflowers — a row of sunflowers rises from the bottom edge, heads nodding in the wind.
// zh: 向日葵
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const int   COUNT     = 5;      // number of sunflowers

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 q, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * q.x - s * q.y, s * q.x + c * q.y);
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// A leaf along +x from its stalk: an oval pointed at both ends.
float leaf(vec2 q, float len) {
    float t = q.x / len;
    float w = len * 0.28 * (1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0));
    return step(0.0, t) * step(t, 1.0) * smoothstep(0.003, 0.0, abs(q.y) - w);
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

    vec3 color = vec3(0.0);
    float shape = 0.0;

    if (p.y < 0.50) {                                        // flowers stay in the lower half
        for (int i = 0; i < COUNT; i++) {
            float fi = float(i);
            float x0 = (0.10 + 0.84 * (fi + 0.5 * hash1(fi + 3.0)) / float(COUNT)) * aspect;
            float h = mix(0.22, 0.38, hash1(fi * 7.1 + 1.0));           // different heights
            float R = mix(0.065, 0.085, hash1(fi * 2.3));               // petal ring radius

            // Wind: each flower sways at its own phase; the head lags and nods.
            float sway = 0.6 * sin(iTime * 0.9 + fi * 1.9) + 0.25 * sin(iTime * 2.1 + fi * 0.7);
            vec2 head = vec2(x0 + sway * 0.035, h - abs(sway) * 0.008);
            vec2 mid = vec2(x0 + sway * 0.012, h * 0.5);

            // Stem: two segments bending with the wind.
            float ds = min(segment(p, vec2(x0, -0.01), mid), segment(p, mid, head));
            float stem = smoothstep(0.0055, 0.0035, ds);

            // Two leaves on the stem, one each side, flapping a little.
            vec2 l1 = mix(vec2(x0, 0.0), mid, 0.65);
            vec2 l2 = mix(mid, head, 0.25);
            float flap = 0.12 * sin(iTime * 1.7 + fi);
            float lv = max(leaf(rot(p - l1, -0.45 - flap), h * 0.30),
                           leaf(rot(vec2(-1.0, 1.0) * (p - l2), -0.40 + flap), h * 0.26));

            vec3 green = vec3(0.30, 0.60, 0.25);
            float g = max(stem, lv);
            color = mix(color, green, g);
            shape = max(shape * (1.0 - g), g * 0.75);

            // Head: tilted with the sway and nodding forward (squashed vertically).
            float nod = 0.25 + 0.15 * sin(iTime * 1.3 + fi * 2.7);
            vec2 q = rot(p - head, -sway * 0.35);
            q.y /= cos(nod);
            float r = length(q);
            float a = atan(q.y, q.x);

            // Petals: two staggered rings of pointed petals.
            float n = 18.0;
            float k1 = abs(fract(a / 6.2831 * n) - 0.5) * 2.0;          // 0 mid-petal, 1 between
            float k2 = abs(fract(a / 6.2831 * n + 0.5) - 0.5) * 2.0;
            float ring1 = smoothstep(0.004, 0.0, r - R * (1.0 - 0.45 * k1));
            float ring2 = smoothstep(0.004, 0.0, r - R * 0.85 * (1.0 - 0.45 * k2));
            float petals = max(ring1, ring2);
            vec3 yellow = mix(vec3(1.0, 0.85, 0.15), vec3(0.95, 0.60, 0.05), ring2 * (1.0 - ring1) + 0.3 * smoothstep(R, R * 0.4, r));
            color = mix(color, yellow, petals);
            shape = max(shape * (1.0 - petals), petals);

            // Seed centre: brown with a dotted spiral texture.
            float disc = smoothstep(0.004, 0.0, r - R * 0.42);
            float seeds = 0.75 + 0.25 * sin(r * 260.0 + a * 13.0) * sin(r * 260.0 - a * 21.0);
            vec3 brown = vec3(0.45, 0.25, 0.08) * seeds * (0.7 + 0.5 * smoothstep(R * 0.42, 0.0, r));
            color = mix(color, brown, disc);
            shape = max(shape * (1.0 - disc), disc);
        }
    }

    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
