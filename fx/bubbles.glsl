// bubbles — thin-walled bubbles rising slowly.
// zh: 气泡
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const int   LAYERS    = 3;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, 1.0 - uv.y);

    float light = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float scale = 5.0 + fi * 3.5;
        float speed = 0.05 + fi * 0.025;

        vec2 p = p0;
        p.x += sin(iTime * 0.6 + fi * 2.1 + p.y * 7.0) * 0.012;   // wobble
        p.y -= iTime * speed + fi * 0.41;                          // y is up here: rise

        vec2 g = p * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.70, hash(id + fi * 11.0));           // ~30% of cells
        vec2 offset = (vec2(hash(id + 1.7), hash(id + 6.3)) - 0.5) * 0.5;
        float size = mix(0.08, 0.20, hash(id + 4.9));
        vec2 q = f - offset;
        float d = length(q);

        float wall = smoothstep(0.022, 0.0, abs(d - size));                       // thin ring
        float shine = smoothstep(size * 0.28, 0.0, length(q - vec2(-0.38, 0.38) * size));
        float fill = smoothstep(size, size * 0.2, d) * 0.10;                      // faint body

        light += present * (wall * 0.75 + shine * 0.9 + fill) * (1.0 - fi * 0.22);
    }

    vec3 color = vec3(0.70, 0.90, 1.0) * min(light, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
