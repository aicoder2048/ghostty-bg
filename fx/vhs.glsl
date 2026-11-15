// vhs — a played-back tape feel: faint speckle, a tracking band crawling up, and a PLAY tag in the corner.
// zh: 录像带
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const float TRACKING  = 9.0;    // seconds between tracking bands
const float TAG_SIZE  = 0.034;  // height of the PLAY letters, in window-heights

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// "PLAY" as strokes, in letter units (1 = letter height), laid out left to right.
const vec4 LETTERS[13] = vec4[13](
    vec4(1.30, 0.0, 1.30, 1.0), vec4(1.30, 1.0, 1.80, 1.0),      // P
    vec4(1.80, 1.0, 1.80, 0.5), vec4(1.80, 0.5, 1.30, 0.5),
    vec4(2.15, 0.0, 2.15, 1.0), vec4(2.15, 0.0, 2.65, 0.0),      // L
    vec4(2.95, 0.0, 3.22, 1.0), vec4(3.22, 1.0, 3.49, 0.0),      // A
    vec4(3.05, 0.38, 3.39, 0.38),
    vec4(3.80, 1.0, 4.05, 0.5), vec4(4.30, 1.0, 4.05, 0.5),      // Y
    vec4(4.05, 0.5, 4.05, 0.0),
    vec4(0.0, 0.0, 0.0, 0.0)                                     // unused
);

// The tag: a solid play triangle followed by the word.
float playTag(vec2 q) {
    float tri = step(0.0, q.x) * step(abs(q.y - 0.5), 0.5 * (1.0 - q.x / 0.85));
    float d = 1.0;
    for (int i = 0; i < 12; i++) {
        d = min(d, seg(q, LETTERS[i].xy, LETTERS[i].zw));
    }
    return max(tri, smoothstep(0.11, 0.06, d));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 light = vec3(0.0);

    // Speckle: rare white dots that change every frame of "tape".
    float frame = floor(iTime * 24.0);
    vec2 px = floor(fragCoord.xy / 2.0);
    light += vec3(0.9) * step(0.993, hash(px + frame * vec2(17.0, 31.0))) * 0.35;
    light += vec3(0.03) * hash(px.yx + frame * vec2(5.0, 11.0));    // fine grain

    // Tracking band: every so often a strip of noisy streaks crawls up the screen.
    float k = mod(iTime, TRACKING) / 3.0;                          // visible for 3 s
    if (k < 1.0) {
        float bandY = mix(-0.08, 1.08, k);                          // bottom to top
        float inBand = smoothstep(0.05, 0.0, abs(p.y - bandY));
        float lineRow = floor(fragCoord.y / 2.0);
        float streak = step(0.6, hash(vec2(lineRow, frame)))       // some rows flare
                     * hash(vec2(floor(fragCoord.x / 6.0), lineRow + frame));
        light += vec3(0.85, 0.9, 1.0) * inBand * (0.08 + 0.35 * streak);
    }

    // The PLAY tag in the top-right corner, with a slight tape flicker.
    vec2 q = (p - vec2(aspect - 0.06 - 4.3 * TAG_SIZE, 1.0 - 0.06 - TAG_SIZE)) / TAG_SIZE;
    float flicker = 0.85 + 0.15 * hash(vec2(frame, 2.0));
    light += vec3(0.85, 1.0, 0.95) * playTag(q) * 0.8 * flicker;

    fragColor = vec4(base.rgb + min(light, vec3(1.0)) * INTENSITY, base.a);
}
