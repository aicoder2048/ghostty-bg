// bees — a few round, striped bees buzz about in loose loops, wings a blur.
// zh: 蜜蜂
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.65;   // overall strength (0 = off)
const int   COUNT     = 7;      // number of bees
const float SIZE      = 0.045;  // one bee unit in window heights (a bee is ~2 units long)

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// Where bee i is at time t: loops around a slowly drifting home spot, plus a
// fast little jitter.
vec2 beePos(float fi, float t, float aspect) {
    float a = hash1(fi * 12.9898 + 1.0);
    float b = hash1(fi * 78.233 + 2.0);
    float c = hash1(fi * 39.425 + 3.0);
    float travel = aspect + 0.3;
    vec2 home = vec2(mod(b * travel + t * 0.015 * (a > 0.5 ? 1.0 : -1.0), travel) - 0.15,
                     mix(0.16, 0.50, a));
    float w = mix(0.9, 1.5, c) * (c > 0.5 ? 1.0 : -1.0);   // some loop the other way
    vec2 loop = vec2(cos(t * w + fi), 0.6 * sin(t * w + fi)) * 0.09
              + vec2(cos(t * 2.3 + c * 9.0), sin(t * 1.7 + a * 9.0)) * 0.035;
    vec2 jitter = vec2(sin(t * 23.0 + fi * 3.0), sin(t * 29.0 + fi * 5.0)) * 0.003;
    return home + loop + jitter;
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

    vec3 rgb = base.rgb;
    float px = 1.5 / (iResolution.y * SIZE);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        vec2 pos = beePos(fi, iTime, aspect);
        vec2 vel = (beePos(fi, iTime + 0.03, aspect) - beePos(fi, iTime - 0.03, aspect)) / 0.06;

        vec2 q = (p - pos) / SIZE;
        if (dot(q, q) > 9.0) continue;                          // too far from this bee

        // Face the way it flies. Near a turn the bee narrows instead of
        // flipping in one frame, as if it were swinging round.
        float face = sign(vel.x) * mix(0.3, 1.0, smoothstep(0.0, 0.06, abs(vel.x)));
        q.x /= face;
        q = rot(q, -0.25 * clamp(vel.y * 4.0, -1.0, 1.0));     // nose up when climbing

        // Body: a plump oval with dark bands, a dark head and a tiny sting.
        float body = smoothstep(px, -px, ellipse(q, vec2(0.0), vec2(0.78, 0.56)));
        float bands = smoothstep(0.2, 0.5, sin(q.x * 11.0 + 0.6)) * smoothstep(0.50, 0.40, q.x);
        float head = smoothstep(px, -px, length(q - vec2(0.82, 0.08)) - 0.30);
        vec2 ab = q - vec2(1.0, 0.30), at = vec2(0.28, 0.32);           // antenna
        float hh = clamp(dot(ab, at) / dot(at, at), 0.0, 1.0);
        head = max(head, smoothstep(px, -px, length(ab - at * hh) - 0.05));
        float sting = smoothstep(px, -px, max(abs(q.y + 0.05) - 0.10 * (q.x + 1.05) / 0.25, abs(q.x + 0.9) - 0.15));

        // Wings: drawn at both ends of the beat, faint, so they read as a blur.
        float beat = sin(iTime * 60.0 + fi * 2.0);
        float wings = 0.0;
        for (int k = 0; k < 2; k++) {
            float ang = (k == 0 ? 0.35 : -0.35) + 0.15 * beat;
            vec2 w = rot(q - vec2(0.05, 0.40), ang);
            wings = max(wings, smoothstep(px, -px, ellipse(w, vec2(-0.20, 0.42), vec2(0.30, 0.48))));
        }

        vec3 yellow = vec3(1.0, 0.80, 0.22);
        vec3 dark = vec3(0.30, 0.20, 0.08);
        vec3 brown = vec3(0.70, 0.48, 0.18);
        rgb = blend(rgb, vec3(0.85, 0.92, 1.0), wings * 0.35 * INTENSITY * (1.0 - body));
        rgb = blend(rgb, mix(yellow, dark, bands), body * INTENSITY);
        rgb = blend(rgb, brown, max(head, sting) * (1.0 - body) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
