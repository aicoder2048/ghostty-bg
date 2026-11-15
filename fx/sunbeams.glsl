// sunbeams — soft shafts of sunlight slanting in from the top right corner, slowly shifting.
// zh: 阳光
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.28;   // overall brightness (0 = off)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // The sun sits just outside the top right corner.
    vec2 sun = vec2(aspect + 0.15, 1.25);
    vec2 d = p - sun;
    float r = length(d);
    float a = atan(d.y, d.x);

    // Beams are bands in angle; a few incommensurate waves give uneven widths,
    // and each drifts at its own slow pace so the shafts shift and breathe.
    float t = iTime;
    float rays = 0.0;
    rays += 0.5 + 0.5 * sin(a * 23.0 + t * 0.11);
    rays += 0.5 + 0.5 * sin(a * 37.0 - t * 0.08 + 1.3);
    rays += 0.5 + 0.5 * sin(a * 13.0 + t * 0.05 + 2.1);
    rays = pow(rays / 3.0, 3.0);

    // Only the fan that points down-left into the window, fading with distance
    // so the far (top left, where text sits) end is faint.
    float fan = smoothstep(-2.95, -2.6, a) * smoothstep(-1.45, -1.9, a);
    float fall = exp(-r * 0.85);
    float glow = 0.25 * exp(-r * 3.0);               // warm haze right at the corner

    vec3 color = vec3(1.0, 0.86, 0.60) * (rays * fan * fall * 1.6 + glow);
    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
