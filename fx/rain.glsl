// rain — thin slanted rain streaks.
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.30;   // overall brightness of the streaks (0 = off)
const int   LAYERS    = 3;
const float SLANT     = 0.12;   // how much the rain leans

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, uv.y);

    float rain = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float columns = 34.0 + fi * 22.0;      // streaks across the height unit
        float speed = 1.1 + fi * 0.45;

        vec2 p = p0;
        p.x += p.y * SLANT;                    // lean
        p.y += iTime * speed + fi * 0.31;      // +Y is up: this moves the rain down

        // Tall, narrow cells: one streak per cell at most.
        vec2 g = vec2(p.x * columns, p.y * 2.6);
        vec2 id = floor(g);
        vec2 f = fract(g);

        float present = step(0.72, hash(id + fi * 5.0));            // ~28% of cells
        float x = 0.2 + 0.6 * hash(id + 2.1);
        float line = smoothstep(0.045, 0.0, abs(f.x - x));
        // Fade in at the tail, bright at the head (the lower end).
        float body = smoothstep(1.0, 0.35, f.y) * smoothstep(0.0, 0.12, f.y);

        rain += present * line * body * (0.9 - fi * 0.2);
    }

    vec3 color = vec3(0.62, 0.76, 1.0) * min(rain, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
