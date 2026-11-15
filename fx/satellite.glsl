// satellite — two satellites with solar panels drift across the sky, panels glinting, lights blinking.
// zh: 卫星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.80;   // overall brightness (0 = off)
const float CROSSING  = 12.0;   // seconds for one pass of the first satellite
const float SIZE      = 0.034;  // half the body height, in screen heights

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

// One satellite at position pos, turned by `turn`, drawn at `size`.
vec3 satellite(vec2 p, vec2 pos, float turn, float size, float phase) {
    vec2 q = rot(p - pos, turn) / size;                  // satellite units: the body is 2 tall
    float aa = 1.5 / (iResolution.y * size);

    float body = box(q, vec2(0.75, 1.0), aa);
    float dish = smoothstep(0.35 + aa, 0.35 - aa, length(q - vec2(0.0, 1.35))) * step(1.15, q.y);
    float strut = box(q, vec2(1.6, 0.09), aa);

    // Two panels, each a grid of cells: the dark gaps make them read as solar cells.
    vec2 pq = vec2(abs(q.x) - 3.4, q.y);                 // mirror: draw one panel
    float panel = box(pq, vec2(1.75, 0.85), aa);
    vec2 cell = abs(fract(vec2(pq.x / 0.58, pq.y / 0.56) + 0.5) - 0.5);
    float grid = smoothstep(0.38, 0.46, max(cell.x, cell.y));
    // A glint sweeps slowly along the panels, as the sun catches them.
    float sweep = mod(iTime * 1.2 + phase, 9.0) - 4.5;
    float glint = exp(-pow((q.x - sweep * 1.4) / 0.9, 2.0));

    vec3 color = vec3(0.95, 0.82, 0.50) * max(body, dish) * 0.85
               + vec3(0.70, 0.72, 0.78) * strut * (1.0 - body) * 0.6
               + vec3(0.35, 0.55, 1.0) * panel * (1.0 - grid * 0.7) * 0.8
               + vec3(0.9, 0.95, 1.0) * panel * glint * 0.7;

    // Blinking red light on top of the dish: a short flash about once a second.
    float b = fract(iTime * 0.8 + phase);
    float blink = smoothstep(0.85, 0.9, b) * smoothstep(1.0, 0.95, b);
    vec2 lamp = pos + rot(vec2(0.0, 1.9) * size, -turn);   // back from satellite units
    float dl = length(p - lamp);
    color += vec3(1.0, 0.25, 0.20) * blink * (smoothstep(0.005, 0.002, dl) + 0.00006 / (dl * dl + 0.0001));
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 color = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float crossing = CROSSING + fi * 3.0;            // 12 s and 15 s: they drift in and out of step
        // The phase offset puts each one already on screen at time zero.
        float t = iTime / crossing + 0.18 + fi * 0.37;
        float n = floor(t);
        float k = fract(t);
        // The upper one runs down a steep diagonal across the right side only, so it
        // never crosses the prompt and output in the upper left. The lower one flies
        // right to left under the text.
        vec2 from, to;
        if (fi < 0.5) {
            float x0 = mix(0.95, 1.04, hash1(n * 3.7 + 1.0)) * aspect;
            from = vec2(x0, 1.20);
            to = vec2(x0 - mix(0.16, 0.24, hash1(n * 5.3 + 2.0)) * aspect, -0.20);
        } else {
            float y0 = mix(0.22, 0.40, hash1(n * 3.7 + 9.0));
            from = vec2(aspect + 0.30, y0);
            to = vec2(-0.30, y0 + mix(-0.08, 0.06, hash1(n * 5.3 + 3.0)));
        }
        vec2 pos = mix(from, to, k);
        float dir = fi < 0.5 ? 1.0 : -1.0;
        float turn = -0.35 * dir - 0.25 * sin(iTime * 0.15 + fi * 2.0);   // slowly turns as it flies
        color += satellite(p, pos, turn, SIZE * (1.0 - 0.2 * fi), fi * 0.5);
    }

    color *= INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
