// bats — a few bats flit erratically across the upper sky, scalloped wings beating fast.
// zh: 蝙蝠
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 5;      // number of bats
const float SIZE      = 0.062;  // half a wingspan, in window heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0,  v1 = p - p1,  v2 = p - p2;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// A bat seen from the front, wings spread. q is in bat units (wingspan about
// 2). lift (-1..1) swings the wings up or down around the shoulder; fold
// (0..1) narrows them on the upstroke, the way a bat half-closes its wings.
float bat(vec2 q, float lift, float fold) {
    vec2 a = vec2(abs(q.x), q.y);                           // mirror: draw one wing

    // The wing is an oval with three bites taken out of its trailing edge;
    // the points left between the bites are the finger tips.
    vec2 w = rot(a - vec2(0.10, 0.04), -lift * 0.75);
    w.x /= 1.0 - 0.35 * fold;
    float wing = ellipse(w, vec2(0.46, 0.04), vec2(0.48, 0.24));
    wing = max(wing, -(length(w - vec2(0.18, -0.30)) - 0.20));
    wing = max(wing, -(length(w - vec2(0.48, -0.27)) - 0.17));
    wing = max(wing, -(length(w - vec2(0.76, -0.19)) - 0.14));
    wing = max(wing, -w.x);                                 // nothing behind the shoulder

    float d = min(wing, ellipse(a, vec2(0.0, -0.04), vec2(0.12, 0.22)));   // body
    d = min(d, length(a - vec2(0.0, 0.18)) - 0.10);                        // head
    d = min(d, triangle(a, vec2(0.02, 0.22), vec2(0.11, 0.40), vec2(0.10, 0.16)));  // ears
    return d;
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

    float shape = 0.0;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        // Drift across the window, with sines at unrelated rates on top so the
        // path keeps changing direction: that zig-zag is what says "bat".
        float t = iTime + fi * 17.0;
        float dir = a > 0.5 ? 1.0 : -1.0;
        float travel = aspect + 0.4;
        float x = mod(b * travel + iTime * mix(0.05, 0.09, c) * dir, travel) - 0.2;
        x += 0.10 * sin(t * 1.3) + 0.05 * sin(t * 3.7 + 1.0);
        float y = mix(0.66, 0.86, a) + 0.07 * sin(t * 1.1 + b * 6.0) + 0.035 * sin(t * 4.3)
                + 0.02 * sin(t * 7.9 + c * 5.0);

        float s = SIZE * mix(0.8, 1.15, c);
        vec2 q = (p - vec2(x, y)) / s;
        float bank = 0.25 * cos(t * 1.3);                   // roll into the turns
        q = vec2(cos(bank) * q.x - sin(bank) * q.y, sin(bank) * q.x + cos(bank) * q.y);

        float w = sin(iTime * (11.0 + 3.0 * c) + fi * 2.0);
        float d = bat(q, w, 0.5 + 0.5 * w);

        float px = 1.5 / (iResolution.y * s);
        shape = max(shape, smoothstep(px, -px, d));
    }

    vec3 color = vec3(0.82, 0.78, 0.95);
    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
