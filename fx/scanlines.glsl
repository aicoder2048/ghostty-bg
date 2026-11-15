// scanlines — an old CRT look: faint scanlines, a slow rolling bright band and a soft vignette.
// zh: 扫描线
// group: geek
// Part of ghostty-bg. It only shades or adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float LINE_PX   = 3.0;    // scanline period, in screen pixels
const float ROLL      = 0.07;   // band speed, in window-heights per second

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    float y = 1.0 - uv.y;

    // Scanlines: a gentle darkening every few pixel rows (pixel-based on purpose,
    // so the lines stay crisp whatever the window size).
    float line = 0.5 + 0.5 * cos(fragCoord.y * 6.2831 / LINE_PX);
    float shade = 0.14 * line;

    // Vignette: corners dim a little, like a curved tube.
    vec2 c = (uv - 0.5) * vec2(1.0, 1.15);
    shade += 0.35 * smoothstep(0.35, 0.85, length(c));

    // A wide, soft bright band rolls down from the top, over and over.
    float band = 1.25 - fract(iTime * ROLL) * 1.5;               // y-up, decreasing = rolling down
    float glow = exp(-pow((y - band) / 0.06, 2.0));

    vec3 rgb = base.rgb * (1.0 - shade * INTENSITY);
    rgb += vec3(0.75, 0.95, 1.0) * glow * 0.10 * INTENSITY;

    fragColor = vec4(rgb, base.a);
}
