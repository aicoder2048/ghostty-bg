// fireflies — a few warm lights wandering slowly and pulsing.
// zh: 萤火虫
// group: animals
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const int   COUNT     = 16;     // number of fireflies

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, uv.y);

    vec3 glow = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        // Each one loops around its own home spot at its own pace.
        vec2 home = vec2(a * aspect, b);
        float t = iTime * (0.04 + 0.07 * c);
        vec2 pos = home + vec2(sin(t * 6.2831 + fi), cos(t * 4.7 + fi * 1.7)) * vec2(0.12, 0.08);

        // Slow pulse; squared so it stays dim most of the time.
        float pulse = 0.5 + 0.5 * sin(iTime * (0.7 + c * 1.4) + fi * 2.3);
        pulse *= pulse;

        float d = length(p - pos);
        float g = 0.00010 / (d * d + 0.00008);     // bright core, soft halo
        glow += vec3(1.0, 0.88, 0.42) * g * pulse;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
