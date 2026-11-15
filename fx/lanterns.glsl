// lanterns — warm paper sky lanterns drift slowly upward, swaying, flames flickering.
// zh: 孔明灯
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   COUNT     = 10;     // number of lanterns

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// A sky lantern in lantern units: about 2 tall, wider at the top, open at the
// bottom. Returns (paper, flame): how much of each covers q.
vec2 lantern(vec2 q, float flicker) {
    float halfW = mix(0.55, 0.80, clamp((q.y + 1.0) * 0.5, 0.0, 1.0));
    float side = abs(q.x) - halfW;
    float topCap = q.y - (0.95 - 0.12 * q.x * q.x);    // slightly domed top
    float bottom = -1.0 - q.y;
    float d = max(side, max(topCap, bottom));
    float paper = smoothstep(0.08, -0.02, d);

    // The paper glows brightest just above the flame and dims toward the top.
    float lit = mix(1.0, 0.45, clamp((q.y + 1.0) * 0.5, 0.0, 1.0));

    vec2 f = (q - vec2(0.0, -0.85)) * vec2(1.0, 0.6);
    float flame = 0.06 / (dot(f, f) + 0.06) * flicker;
    return vec2(paper * lit, flame);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 col = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        // Depth: far lanterns are smaller, slower and dimmer.
        float depth = c;
        float size = mix(0.013, 0.038, depth);
        float speed = mix(0.012, 0.030, depth);
        float y = mod(b * 1.4 + iTime * speed, 1.4) - 0.2;
        float x = a * aspect + 0.03 * sin(iTime * 0.35 + fi * 2.1);

        vec2 q = (p - vec2(x, y)) / size;
        // Sway: a little tilt with the breeze.
        float tilt = 0.12 * sin(iTime * 0.5 + fi * 1.3);
        q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;
        if (dot(q, q) > 16.0) {
            // Far from this lantern: only its soft halo.
            float h = 0.6 / dot(q, q);
            col += vec3(1.0, 0.55, 0.2) * h * mix(0.4, 1.0, depth) * smoothstep(1.2, 0.85, y);
            continue;
        }

        float flicker = 0.8 + 0.2 * sin(iTime * 9.0 + fi * 3.0) * sin(iTime * 5.3 + fi);
        vec2 l = lantern(q, flicker);
        float fadeTop = smoothstep(1.2, 0.85, y);         // shrink into the night near the top
        float bright = mix(0.4, 1.0, depth) * fadeTop;

        vec3 paper = vec3(1.0, 0.50, 0.16) * l.x * 0.75 * flicker;
        vec3 flame = vec3(1.0, 0.85, 0.45) * l.y;
        float halo = 0.6 / (dot(q, q) + 1.5);
        col += (paper + flame + vec3(1.0, 0.55, 0.2) * halo) * bright;
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
