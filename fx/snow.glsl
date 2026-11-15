// snow — slow snowflakes drifting down over the terminal.
// zh: 雪
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness of the flakes (0 = off)
const int   LAYERS    = 4;      // more layers = more flakes

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Square cells regardless of the window shape. With y up, adding time to y
    // makes the pattern move down.
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, 1.0 - uv.y);

    float snow = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float scale = 7.0 + fi * 5.0;          // far layers: smaller, denser
        float speed = 0.045 + fi * 0.02;

        vec2 p = p0;
        p.x += sin(iTime * 0.25 + fi * 1.7 + p.y * 4.0) * 0.015;   // gentle sway
        p.y += iTime * speed + fi * 0.37;

        vec2 g = p * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.62, hash(id + fi * 13.0));           // ~38% of cells
        vec2 offset = vec2(hash(id + 1.3), hash(id + 7.1)) - 0.5;
        float size = mix(0.035, 0.085, hash(id + 3.7));
        float d = length(f - offset * 0.6);

        snow += present * smoothstep(size, size * 0.25, d) * (0.55 - fi * 0.08);
    }

    vec3 color = vec3(0.92, 0.96, 1.0) * min(snow, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
