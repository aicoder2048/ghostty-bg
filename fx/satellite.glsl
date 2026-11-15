// satellite — a small satellite with solar panels drifts across the sky, its light blinking.
// zh: 卫星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const float CROSSING  = 34.0;   // seconds for one pass across the screen
const float SIZE      = 0.024;  // half the body height, in screen heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Soft-edged box: 1 inside a box of half-size b, 0 outside. aa is the edge width.
float box(vec2 q, vec2 b, float aa) {
    vec2 d = abs(q) - b;
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return smoothstep(aa, -aa, dist);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // One pass at a time, left to right, each on its own slightly sloped line.
    float t = iTime / CROSSING;
    float n = floor(t);
    float k = fract(t);
    float y0 = mix(0.62, 0.90, hash1(n * 3.7 + 1.0));
    float y1 = y0 + mix(-0.18, 0.08, hash1(n * 5.3 + 2.0));
    vec2 pos = vec2(mix(-0.25, aspect + 0.25, k), mix(y0, y1, k));

    // Satellite units: the body is 2 tall. It slowly turns as it flies.
    float turn = -0.35 - 0.25 * sin(iTime * 0.15);
    vec2 q = rot(p - pos, turn) / SIZE;
    float aa = 1.5 / (iResolution.y * SIZE);

    float body = box(q, vec2(0.75, 1.0), aa);
    float dish = smoothstep(0.35 + aa, 0.35 - aa, length(q - vec2(0.0, 1.35))) * step(1.15, q.y);
    float strut = box(q, vec2(1.6, 0.09), aa);

    // Two panels, each a grid of cells: the dark gaps make them read as solar cells.
    vec2 pq = vec2(abs(q.x) - 3.4, q.y);                 // mirror: draw one panel
    float panel = box(pq, vec2(1.75, 0.85), aa);
    vec2 cell = abs(fract(vec2(pq.x / 0.58, pq.y / 0.56) + 0.5) - 0.5);
    float grid = smoothstep(0.38, 0.46, max(cell.x, cell.y));
    float glint = 0.75 + 0.25 * sin(iTime * 0.6 + q.x * 0.3);   // light sweeps over the panels

    vec3 color = vec3(0.95, 0.82, 0.50) * max(body, dish) * 0.85
               + vec3(0.70, 0.72, 0.78) * strut * (1.0 - body) * 0.6
               + vec3(0.35, 0.55, 1.0) * panel * (1.0 - grid * 0.7) * glint;

    // Blinking red light on top of the dish: a short flash about once a second.
    float blink = smoothstep(0.85, 0.9, fract(iTime * 0.8)) * smoothstep(1.0, 0.95, fract(iTime * 0.8));
    vec2 lamp = pos + rot(vec2(0.0, 1.9) * SIZE, -turn);     // back from satellite units
    float dl = length(p - lamp);
    color += vec3(1.0, 0.25, 0.20) * blink * (smoothstep(0.004, 0.0015, dl) + 0.00004 / (dl * dl + 0.0001));

    color *= INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
