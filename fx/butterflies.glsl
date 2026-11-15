// butterflies — a few butterflies flutter around, wings opening and closing.
// zh: 蝴蝶
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 7;      // number of butterflies

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// A butterfly seen from above. q is in butterfly units (about 2 wide when
// open); open runs from ~0.2 (wings nearly shut) to 1 (flat).
float butterfly(vec2 q, float open) {
    vec2 a = vec2(abs(q.x) / open, q.y);                 // mirror + squash = flapping
    float upper = smoothstep(1.0, 0.78, length((a - vec2(0.55, 0.30)) / vec2(0.55, 0.60)));
    float lower = smoothstep(1.0, 0.78, length((a - vec2(0.40, -0.45)) / vec2(0.40, 0.42)));
    float body = smoothstep(0.08, 0.02, abs(q.x)) * smoothstep(0.75, 0.55, abs(q.y));
    return max(max(upper, lower), body * 0.7);
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
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        // Wander in a figure-eight around a home spot, with a quick flutter on top.
        vec2 home = vec2(mix(0.15, 0.85, a) * aspect, mix(0.20, 0.80, b));
        float t = iTime * (0.10 + 0.08 * c) + fi * 3.0;
        vec2 pos = home + vec2(sin(t), sin(t * 2.0) * 0.5) * vec2(0.20, 0.14)
                 + vec2(0.0, sin(iTime * 9.0 + fi * 2.0) * 0.006);

        // Lean into the direction of travel.
        float tilt = 0.5 * cos(t);
        float cs = cos(tilt), sn = sin(tilt);
        vec2 q = (p - pos) / mix(0.026, 0.038, c);
        q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);

        float open = 0.2 + 0.8 * abs(sin(iTime * (7.0 + 3.0 * c) + fi * 1.3));

        vec3 color = c < 0.34 ? vec3(1.0, 0.62, 0.22)        // orange
                   : c < 0.67 ? vec3(1.0, 0.90, 0.42)        // yellow
                              : vec3(0.48, 0.72, 1.0);       // blue
        rgb = blend(rgb, color, butterfly(q, open) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
