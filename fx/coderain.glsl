// coderain — sparse columns of glowing pseudo-glyphs falling down the window.
// zh: 代码雨
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.65;                     // overall brightness (0 = off)
const float DENSITY   = 0.22;                     // share of columns with a drop at any time
const vec3  COLOR     = vec3(0.25, 1.00, 0.45);   // tail colour (try vec3(0.3, 0.9, 1.0) for cyan)
const vec2  CELL      = vec2(0.024, 0.036);       // glyph cell, in window-heights

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Distance from p to the segment a-b.
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// The strokes a pseudo-glyph can be built from (x is in cell-height units,
// so the box is about 0.67 wide and 1 tall). Each glyph turns on a random few.
const vec4 STROKES[10] = vec4[10](
    vec4(0.14, 0.86, 0.52, 0.86),   // top
    vec4(0.14, 0.50, 0.52, 0.50),   // middle
    vec4(0.14, 0.14, 0.52, 0.14),   // bottom
    vec4(0.14, 0.50, 0.14, 0.86),   // left, upper
    vec4(0.14, 0.14, 0.14, 0.50),   // left, lower
    vec4(0.52, 0.50, 0.52, 0.86),   // right, upper
    vec4(0.52, 0.14, 0.52, 0.50),   // right, lower
    vec4(0.33, 0.14, 0.33, 0.86),   // centre
    vec4(0.14, 0.86, 0.52, 0.50),   // diagonal down
    vec4(0.14, 0.14, 0.52, 0.50)    // diagonal up
);

float glyph(vec2 q, float seed) {
    float d = 1.0;
    for (int i = 0; i < 10; i++) {
        if (hash(vec2(seed, float(i) * 3.7)) < 0.38) {
            d = min(d, seg(q, STROKES[i].xy, STROKES[i].zw));
        }
    }
    return smoothstep(0.075, 0.035, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float col = floor(p.x / CELL.x);
    float row = floor(p.y / CELL.y);
    vec2 f = fract(p / CELL);

    // Each column runs one drop after another; every drop rolls its own dice
    // for whether it shows up at all, so the rain stays sparse and shifting.
    float speed = mix(5.0, 12.0, hash(vec2(col, 1.3)));          // cells per second
    float tail  = floor(mix(7.0, 18.0, hash(vec2(col, 2.9))));   // cells
    float top   = ceil(1.0 / CELL.y) + 1.0;
    float span  = top + tail + 6.0;
    float pos   = iTime * speed + hash(vec2(col, 4.1)) * span;
    float n     = floor(pos / span);
    float head  = top - floor(mod(pos, span));                   // falls: row decreases
    float on    = step(hash(vec2(col, n + 7.0)), DENSITY);

    float d = row - head;                                        // cells above the head
    float light = 0.0;
    vec3 color = COLOR;
    if (on > 0.0 && d >= 0.0 && d <= tail) {
        // Glyphs swap now and then, like a busy display.
        float seed = hash(vec2(col, row)) * 91.0 + floor(iTime * 1.5 + hash(vec2(row, col)) * 7.0);
        float g = glyph(vec2(f.x * CELL.x / CELL.y, f.y), seed);
        float fade = 1.0 - d / tail;
        light = g * fade * fade;
        if (d < 1.0) {                                           // the leading glyph is near-white
            light = g * 1.4;
            color = mix(COLOR, vec3(1.0), 0.7);
        }
    }

    fragColor = vec4(base.rgb + color * light * INTENSITY, base.a);
}
