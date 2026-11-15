// dragonflies — a few dragonflies dart, hover dead still on shimmering wings, then dart again.
// zh: 蜻蜓
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const int   COUNT     = 4;      // number of dragonflies
const float SIZE      = 0.055;  // half a body length, in window heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 hash2(float n) {
    return vec2(hash1(n * 1.31 + 0.7), hash1(n * 2.17 + 5.3));
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float limb(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(r0, r1, h);
}

// One wing: a long narrow oval reaching out from its root at angle a.
float wing(vec2 q, vec2 root, float a, float len, float wide) {
    vec2 w = rot(q - root, -a);
    return ellipse(w, vec2(0.0, len * 0.5), vec2(wide, len * 0.5));
}

// A dragonfly seen from above, facing +x. q is in body units (about 2 long).
// Returns body distance in .x and the four wings in .y; buzz flutters them.
vec2 dragonfly(vec2 q, float buzz) {
    float body = limb(q, vec2(0.30, 0.0), vec2(-1.10, 0.0), 0.07, 0.035);  // long thin tail
    body = min(body, ellipse(q, vec2(0.42, 0.0), vec2(0.17, 0.10)));        // thorax
    body = min(body, length(vec2(q.x - 0.66, abs(q.y) - 0.07)) - 0.085);   // big eyes

    // Wings mirror across the body. Fore wings lean forward, hind wings back
    // and a little wider; both quiver by a few degrees.
    vec2 m = vec2(q.x, abs(q.y));
    float fw = wing(m, vec2(0.46, 0.04), -0.20 + buzz * 0.10, 0.95, 0.11);
    float hw = wing(m, vec2(0.34, 0.04),  0.25 - buzz * 0.10, 0.90, 0.14);
    return vec2(body, min(fw, hw));
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
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float c = hash1(fi * 39.425 + 3.0);

        // Hop between random spots: a quick dart (first ~0.35 s), then a long
        // hover. Each leg of the trip has its own length so they don't sync.
        float hold = mix(1.6, 2.8, c);
        float t = iTime / hold + fi * 0.37;
        float n = floor(t);
        float f = fract(t);
        // Each one keeps to its own overlapping strip of the window so they
        // spread out instead of bunching up.
        float zone = 1.0 / float(COUNT);
        vec2 lo = vec2(max(0.06, (fi - 0.4) * zone) * aspect, 0.12);
        vec2 hi = vec2(min(0.94, (fi + 1.4) * zone) * aspect, 0.88);
        vec2 prev = mix(lo, hi, hash2(n - 1.0 + fi * 113.7));
        vec2 from = mix(lo, hi, hash2(n + fi * 113.7));
        vec2 to   = mix(lo, hi, hash2(n + 1.0 + fi * 113.7));
        float dart = smoothstep(0.0, 0.35 / hold, f);
        vec2 pos = mix(from, to, dart);
        pos += 0.004 * vec2(sin(iTime * 2.3 + fi), sin(iTime * 3.1 + fi * 2.0)) * (1.0 - dart * (1.0 - dart) * 4.0);

        // Turn to face the new heading in a flick just before darting.
        vec2 h0 = from - prev, h1 = to - from;
        float a0 = atan(h0.y, h0.x), a1 = atan(h1.y, h1.x);
        float da = mod(a1 - a0 + 3.14159, 6.28318) - 3.14159;   // shortest way round
        float ang = a0 + da * smoothstep(0.0, 0.12 / hold, f);

        vec2 q = rot((p - pos) / SIZE, -ang);
        float buzz = sin(iTime * 47.0 + fi * 3.0);
        vec2 d = dragonfly(q, buzz);

        float px = 1.5 / (iResolution.y * SIZE);
        float body = smoothstep(px, -px, d.x);
        float wingFill = smoothstep(px, -px, d.y);
        float wingRim = smoothstep(px * 1.5, 0.0, abs(d.y));       // outline keeps them readable

        // Translucent wings with a slow rainbow shimmer that slides along them.
        float hue = q.x * 2.0 + abs(q.y) * 3.0 + iTime * 1.5 + fi;
        vec3 shimmer = 0.6 + 0.4 * cos(hue + vec3(0.0, 2.1, 4.2));
        float wingA = max(wingFill * 0.28, wingRim * 0.55) * (1.0 - body);

        vec3 bodyColor = mix(vec3(0.30, 0.85, 0.95), vec3(0.55, 0.95, 0.50), c);
        rgb = blend(rgb, shimmer, wingA * INTENSITY);
        rgb = blend(rgb, bodyColor, body * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
