// stars — a still field of small stars that twinkle.
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const int   LAYERS    = 2;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, uv.y);

    float stars = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float grid = 22.0 + fi * 16.0;          // cells across the height

        vec2 g = p0 * grid + fi * 17.0;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.70, hash(id + fi * 3.0));             // ~30% of cells
        vec2 offset = vec2(hash(id + 4.2), hash(id + 8.6)) - 0.5;
        float size = mix(0.035, 0.085, hash(id + 2.4));
        float d = length(f - offset * 0.7);

        // Each star twinkles at its own speed and phase.
        float speed = 0.5 + 2.2 * hash(id + 5.2);
        float twinkle = 0.55 + 0.45 * sin(iTime * speed + 6.2831 * hash(id + 9.1));

        stars += present * smoothstep(size, 0.0, d) * twinkle * (1.0 - fi * 0.35);
    }

    vec3 color = vec3(0.88, 0.93, 1.0) * min(stars, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
