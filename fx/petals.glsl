// petals — pink petals tumbling down on a breeze.
// zh: 花瓣
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   LAYERS    = 3;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, uv.y);

    float petals = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float scale = 5.5 + fi * 3.0;
        float speed = 0.07 + fi * 0.03;

        vec2 p = p0;
        p.x += iTime * 0.02 + sin(iTime * 0.4 + fi * 1.3 + p.y * 5.0) * 0.03;   // drift + sway
        p.y += iTime * speed + fi * 0.29;                                        // fall

        vec2 g = p * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.68, hash(id + fi * 9.0));            // ~32% of cells
        vec2 offset = (vec2(hash(id + 2.2), hash(id + 5.8)) - 0.5) * 0.5;
        vec2 q = f - offset;

        // Each petal spins at its own rate; an ellipse makes the petal shape.
        float angle = iTime * (0.6 + hash(id + 7.7)) + 6.2831 * hash(id + 3.1);
        float c = cos(angle), s = sin(angle);
        q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
        float size = mix(0.10, 0.17, hash(id + 8.4));
        // Tumbling in 3D looks like the petal getting thinner and wider.
        float thin = 0.30 + 0.25 * sin(iTime * 1.7 + 6.2831 * hash(id + 4.4));
        float d = length(vec2(q.x, q.y / thin));

        petals += present * smoothstep(size, size * 0.55, d) * (0.75 - fi * 0.15);
    }

    vec3 color = vec3(1.0, 0.72, 0.82) * min(petals, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
