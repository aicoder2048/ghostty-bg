// binary — faint streams of 0s and 1s drift slowly down the window.
// zh: 二进制
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.30;                     // overall brightness (0 = off)
const vec2  CELL      = vec2(0.026, 0.042);       // digit cell, in window-heights
const vec3  COLOR     = vec3(0.35, 0.95, 0.75);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// A 0 or a 1 drawn with a few strokes, in a cell about 0.62 wide and 1 tall.
float digit(vec2 q, float one) {
    float d;
    if (one > 0.5) {
        d = min(seg(q, vec2(0.31, 0.18), vec2(0.31, 0.82)),       // stem
                seg(q, vec2(0.31, 0.82), vec2(0.19, 0.70)));      // flag
    } else {
        vec2 c = q - vec2(0.31, 0.5);
        vec2 e = abs(c) - vec2(0.10, 0.25);                      // a rounded box outline
        d = abs(length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - 0.04);
    }
    return smoothstep(0.065, 0.03, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float col = floor(p.x / CELL.x);
    float colOn = step(hash(vec2(col, 3.3)), 0.22);              // only some columns carry data

    // Each column slides down at its own slow pace (y grows upward, so add time).
    float speed = mix(0.4, 1.3, hash(vec2(col, 5.1)));           // cells per second
    float y = p.y / CELL.y + iTime * speed + hash(vec2(col, 9.7)) * 50.0;
    float row = floor(y);

    // Rows come in runs: a stream of digits, then a gap.
    float run = floor(row / 9.0);
    float inRun = step(hash(vec2(col, run)), 0.45);
    float along = fract(row / 9.0);
    float ends = smoothstep(0.0, 0.25, along) * smoothstep(1.0, 0.75, along);
    float present = step(hash(vec2(row, col * 1.7)), 0.85);

    // Bits flip every so often.
    float one = step(0.5, hash(vec2(row + floor(iTime * 0.6 + hash(vec2(col, row)) * 5.0), col)));
    vec2 f = vec2(fract(p.x / CELL.x), fract(y));
    float g = digit(vec2(f.x * CELL.x / CELL.y, f.y), one);

    float light = g * colOn * inRun * present * (0.25 + 0.75 * ends);
    fragColor = vec4(base.rgb + COLOR * light * INTENSITY, base.a);
}
