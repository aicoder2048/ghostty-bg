// aurora — slow green and violet curtains of light across the upper part.
// zh: 极光
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.42;   // overall brightness (0 = off)
const int   BANDS     = 3;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float x = uv.x * iResolution.x / iResolution.y;
    vec3 glow = vec3(0.0);

    for (int i = 0; i < BANDS; i++) {
        float fi = float(i);
        // The band's height wanders along x and over time.
        float center = 0.66 + fi * 0.09
            + 0.060 * sin(x * (1.6 + fi * 0.7) + iTime * (0.11 + fi * 0.04) + fi * 2.0)
            + 0.025 * sin(x * (4.3 + fi) - iTime * 0.17 + fi);
        float width = 0.055 + 0.02 * sin(x * 2.3 + iTime * 0.09 + fi * 1.7);

        // Soft below the band, a longer tail upward — like a hanging curtain.
        float dy = uv.y - center;
        float band = dy < 0.0 ? exp(-dy * dy / (width * width * 0.35))
                              : exp(-dy * dy / (width * width * 3.0));

        // Vertical rays that shimmer slowly.
        float rays = 0.65 + 0.35 * sin(x * (26.0 + fi * 9.0) + iTime * (0.5 + fi * 0.2)
                                       + 3.0 * sin(x * 3.0 + iTime * 0.13));

        vec3 green  = vec3(0.25, 1.00, 0.55);
        vec3 violet = vec3(0.60, 0.35, 1.00);
        vec3 color = mix(green, violet, clamp(dy / (width * 2.5) + 0.25 + fi * 0.15, 0.0, 1.0));

        glow += color * band * rays * (0.9 - fi * 0.2);
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
