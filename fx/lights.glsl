// lights — a string of party bulbs sags along the top edge, twinkling in a chase.
// zh: 彩灯
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.80;   // overall brightness (0 = off)
const int   BULBS     = 16;     // bulbs along the string
const float SWAGS     = 4.0;    // how many sagging loops across the width
const float SAG       = 0.018;  // how far each loop droops (keep tiny: text lives below)

// Height of the wire at x: anchored at the very top, drooping between anchors.
float wireY(float x, float aspect) {
    float f = fract(x / aspect * SWAGS);
    return 0.996 - SAG * 4.0 * f * (1.0 - f);
}

vec3 bulbColor(int i) {
    int k = i - (i / 5) * 5;
    if (k == 0) return vec3(1.0, 0.25, 0.25);
    if (k == 1) return vec3(1.0, 0.80, 0.20);
    if (k == 2) return vec3(0.25, 1.0, 0.40);
    if (k == 3) return vec3(0.30, 0.55, 1.0);
    return vec3(1.0, 0.45, 0.90);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Everything lives in a thin band at the top; skip the rest of the screen.
    if (p.y < 0.88) {
        fragColor = base;
        return;
    }

    vec3 col = vec3(0.0);
    // The wire: a faint thin line (vertical distance is fine for such a shallow curve).
    float wire = smoothstep(0.0025, 0.0, abs(p.y - wireY(p.x, aspect)));
    col += vec3(0.55, 0.55, 0.5) * wire * 0.35;

    for (int i = 0; i < BULBS; i++) {
        float fi = float(i);
        float x = (fi + 0.5) / float(BULBS) * aspect;
        vec2 hook = vec2(x, wireY(x, aspect));
        vec2 q = p - hook;

        // Chase: a bright wave runs along the string, plus a little random twinkle.
        float chase = 0.5 + 0.5 * sin(iTime * 3.0 - fi * 2.0944);
        float twinkle = 0.85 + 0.15 * sin(iTime * 11.0 + fi * 7.7);
        float on = mix(0.12, 1.0, chase * chase * chase) * twinkle;

        // Socket just under the wire, bulb hanging below it.
        float socket = smoothstep(0.0025, 0.0, max(abs(q.x) - 0.0035, abs(q.y + 0.004) - 0.004));
        vec2 b = (q - vec2(0.0, -0.017)) / vec2(0.0075, 0.011);
        float bulb = smoothstep(1.0, 0.75, length(b));
        float halo = 0.00006 / (dot(q - vec2(0.0, -0.017), q - vec2(0.0, -0.017)) + 0.00012);

        vec3 c = bulbColor(i);
        col += vec3(0.4) * socket * 0.5;
        col += (c * bulb + mix(c, vec3(1.0), 0.6) * bulb * bulb * 0.5) * on;
        col += c * halo * on * 0.8;
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
