// waveform — a glowing oscilloscope trace travels along the bottom over a faint graticule.
// zh: 示波器
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const float STRIP     = 0.24;   // height of the scope strip at the bottom, in window-heights
const float AMP       = 0.065;  // wave amplitude, in window-heights

const vec3 GREEN = vec3(0.35, 1.00, 0.50);

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float mid = STRIP * 0.5;
    float y = p.y - mid;
    float light = 0.0;

    // Graticule: dotted grid lines inside the strip, the centre axis a bit brighter.
    if (p.y < STRIP) {
        float step_ = STRIP / 4.0;
        float gy = abs(fract(y / step_ + 0.5) - 0.5) * step_;
        float gx = abs(fract(p.x / step_ + 0.5) - 0.5) * step_;
        float dots = step(0.5, fract(p.x * 90.0)) ;
        float dotsV = step(0.5, fract(p.y * 90.0));
        light += smoothstep(0.0015, 0.0, gy) * dots * 0.15;
        light += smoothstep(0.0015, 0.0, gx) * dotsV * 0.15;
        light += smoothstep(0.0015, 0.0, abs(y)) * 0.08;
    }

    // The signal: a few sines travelling at different speeds, so it never quite repeats.
    float t = iTime;
    float x = p.x;
    float w  = 0.60 * sin(x * 9.0  - t * 2.0)
             + 0.30 * sin(x * 23.0 - t * 3.7 + 1.0)
             + 0.12 * sin(x * 51.0 + t * 1.3);
    float dw = 0.60 * 9.0  * cos(x * 9.0  - t * 2.0)
             + 0.30 * 23.0 * cos(x * 23.0 - t * 3.7 + 1.0)
             + 0.12 * 51.0 * cos(x * 51.0 + t * 1.3);
    float amp = AMP * (0.75 + 0.25 * sin(t * 0.5));
    // Distance to the curve, corrected for its slope so steep parts keep their width.
    float dist = abs(y - amp * w) / sqrt(1.0 + amp * amp * dw * dw);

    float ends = smoothstep(0.0, 0.10, x) * smoothstep(aspect, aspect - 0.10, x);
    light += (smoothstep(0.004, 0.0012, dist) + exp(-dist * 70.0) * 0.30) * ends;

    fragColor = vec4(base.rgb + GREEN * min(light, 1.0) * INTENSITY, base.a);
}
