// drizzle — a light, sparse rain: a few thin short streaks falling at a slight slant.
// zh: 细雨
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.40;   // overall brightness (0 = off)
const int   LAYERS    = 3;      // near, middle, far
const float DENSITY   = 0.10;   // share of grid cells holding a drop (keep low: drizzle, not a downpour)

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 rain = vec3(0.0);
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float depth = 1.0 - fi * 0.25;                 // far layers: slower, fainter

        // A slight slant: the drops drift right as they fall.
        vec2 q = p;
        q.x += q.y * 0.12;

        // Tall, narrow cells: one possible streak per cell.
        vec2 cell = vec2(9.0 + fi * 5.0, 2.2 + fi * 0.8);
        vec2 g = q * cell;
        g.y += iTime * (1.9 * depth) * cell.y + fi * 3.7;   // falling = scene y decreasing
        g.x += fi * 0.37;

        vec2 id = floor(g);
        vec2 f = fract(g);

        float present = step(1.0 - DENSITY, hash(id + fi * 13.0));
        float x0 = 0.2 + 0.6 * hash(id + 4.1);
        float y0 = 0.15 + 0.4 * hash(id + 8.3);      // where the head sits in the cell
        float len = 0.28 + 0.12 * hash(id + 2.7);    // short streaks

        // Width in cell units, so every layer gets about a 1px line.
        float w = 0.9 * cell.x / iResolution.y;
        float line = smoothstep(w, 0.0, abs(f.x - x0));
        // Brightest at the falling head (bottom), fading up into the tail.
        float t = (f.y - y0) / len;
        float streak = step(0.0, t) * step(t, 1.0) * (1.0 - t);

        rain += vec3(0.75, 0.85, 1.0) * present * line * streak * depth;
    }

    fragColor = vec4(base.rgb + min(rain, vec3(1.0)) * INTENSITY, base.a);
}
