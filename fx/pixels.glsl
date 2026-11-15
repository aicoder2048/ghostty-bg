// pixels — chunky coloured pixel squares pop in and out around the edges.
// zh: 像素
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.40;   // overall brightness (0 = off)
const float CELL      = 0.06;   // pixel size, in window-heights
const float REACH     = 0.30;   // how far in from the edges pixels appear

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 palette(float h) {
    return h < 0.17 ? vec3(1.00, 0.25, 0.75)    // magenta
         : h < 0.34 ? vec3(0.20, 0.90, 1.00)    // cyan
         : h < 0.51 ? vec3(1.00, 0.85, 0.20)    // yellow
         : h < 0.68 ? vec3(0.35, 1.00, 0.40)    // green
         : h < 0.85 ? vec3(1.00, 0.50, 0.15)    // orange
                    : vec3(0.40, 0.50, 1.00);   // blue
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 id = floor(p / CELL);
    vec2 f = fract(p / CELL);
    vec2 centre = (id + 0.5) * CELL;

    // Distance of this cell from the nearest window edge: pixels crowd the
    // border and thin out toward the middle, where the text usually is.
    float edge = min(min(centre.x, aspect - centre.x), min(centre.y, 1.0 - centre.y));
    float chance = 0.5 * (1.0 - smoothstep(0.02, REACH, edge));

    // Every cell has its own clock; each round it may or may not light up.
    float period = 2.5 + 4.0 * hash(id + 1.7);
    float t = iTime / period + hash(id + 8.3);
    float n = floor(t);
    float k = fract(t);
    float alive = step(hash(id + n * 13.1), chance) * step(k, 0.4);

    // Pop in and out in a few hard steps, the way old screens would.
    float env = sin(3.14159 * k / 0.4);
    env = floor(env * 3.0 + 0.5) / 3.0;

    // A square with a small gap to the grid, and a slightly brighter rim.
    vec2 a = abs(f - 0.5);
    float m = max(a.x, a.y);
    float square = step(m, 0.40);
    float rim = step(0.30, m) * square;

    vec3 color = palette(hash(id + n * 5.9)) * square * (0.75 + 0.35 * rim);
    fragColor = vec4(base.rgb + color * alive * env * INTENSITY, base.a);
}
