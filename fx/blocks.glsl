// blocks — little square-cell shapes drop, stack up at the bottom, then the full rows flash and clear.
// zh: 方块
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.45;   // overall brightness (0 = off)
const float CELL      = 0.04;   // block cell size, in window-heights
const float LAYER_T   = 7.0;    // seconds to fill one 2-row layer
const float FLASH_T   = 1.4;    // seconds the full rows flash before clearing
const float PAUSE_T   = 1.0;    // empty floor before the next round
const float FALL      = 14.0;   // falling speed, in cells per second
const float DROP      = 12.0;   // cells a piece falls before it lands (it fades in up there)

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 palette(float h) {
    return h < 0.2 ? vec3(0.20, 0.90, 1.00)     // cyan
         : h < 0.4 ? vec3(1.00, 0.30, 0.80)     // magenta
         : h < 0.6 ? vec3(0.40, 1.00, 0.40)     // green
         : h < 0.8 ? vec3(1.00, 0.80, 0.25)     // amber
                   : vec3(0.50, 0.55, 1.00);    // violet
}

// Is chunk-local cell (lx, ly) part of piece k of a chunk this wide?
// Width 2: one 2x2 square.  Width 3: an L (bottom row + top-left), then a
// 2-cell bar on its top-right.  Width 4: a flat bar, then another on top.
bool inPiece(float w, float k, float lx, float ly) {
    if (lx < 0.0 || lx >= w || ly < 0.0 || ly > 1.0) return false;
    if (w < 2.5) return k < 0.5;
    if (w < 3.5) return k < 0.5 ? (ly < 0.5 || lx < 0.5) : (ly > 0.5 && lx > 0.5);
    return k < 0.5 ? ly < 0.5 : ly > 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 cell = floor(p / CELL);
    vec2 f = fract(p / CELL);

    // One round: fill two layers, flash, clear, pause. No state is kept; the
    // whole picture is a function of the round number and the time within it.
    float roundT = 2.0 * LAYER_T + FLASH_T + PAUSE_T;
    float round_ = floor(iTime / roundT);
    float t = mod(iTime, roundT);
    float done = 2.0 * LAYER_T;

    float lit = 0.0;
    vec3 color = vec3(0.0);

    for (int L = 0; L < 2; L++) {
        float layer = float(L);
        float seed = round_ * 3.1 + layer * 17.3;

        // Split the row into chunks of 2, 3 and 4 cells, shuffled per group of 9.
        float group = floor(cell.x / 9.0);
        float lx = mod(cell.x, 9.0);
        float order = floor(hash(vec2(group, seed)) * 6.0);
        vec3 w = order < 1.0 ? vec3(2, 3, 4) : order < 2.0 ? vec3(2, 4, 3)
               : order < 3.0 ? vec3(3, 2, 4) : order < 4.0 ? vec3(3, 4, 2)
               : order < 5.0 ? vec3(4, 2, 3) : vec3(4, 3, 2);
        float start = 0.0, width = w.x;
        if (lx >= w.x) { start = w.x; width = w.y; }
        if (lx >= w.x + w.y) { start = w.x + w.y; width = w.z; }
        vec2 chunk = vec2(group * 9.0 + start, seed);

        // Landing times inside this layer's window; the top piece of a chunk
        // always lands after the bottom one, so the stack is always supported.
        float t0 = layer * LAYER_T + LAYER_T * 0.55 * hash(chunk + 0.3);
        float t1 = t0 + LAYER_T * (0.08 + 0.32 * hash(chunk + 0.7));

        for (int k = 0; k < 2; k++) {
            float fk = float(k);
            float land = k == 0 ? t0 : t1;
            float lift = 0.0;                                     // cells still above its resting place
            if (t < land) {
                lift = ceil((land - t) * FALL);
                if (lift > DROP) continue;                         // not dropped yet
            }
            if (t > done + FLASH_T) continue;                     // cleared
            float ly = cell.y - layer * 2.0 - lift;
            if (inPiece(width, fk, lx - start, ly)) {
                float fadeIn = 1.0 - lift / DROP;
                lit = max(lit, fadeIn);
                color = palette(hash(chunk + fk * 5.3));
            }
        }
    }

    // When the floor is complete, the full rows blink white before they vanish.
    if (t > done && lit > 0.0) {
        float blink = step(0.5, fract((t - done) * 4.0));
        color = mix(color, vec3(1.0), 0.4 + 0.5 * blink);
    }

    // Each cell: a filled square with a small gap and a brighter bevel edge.
    vec2 a = abs(f - 0.5);
    float m = max(a.x, a.y);
    float square = step(m, 0.42) * (0.65 + 0.45 * step(0.32, m));

    fragColor = vec4(base.rgb + color * lit * square * INTENSITY, base.a);
}
