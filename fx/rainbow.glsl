// rainbow — a faint rainbow arc that slowly appears and fades away again.
// zh: 彩虹
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.26;   // overall brightness at its fullest (0 = off)
const float CYCLE     = 40.0;   // seconds for one fade in and out

// Rough spectral colour: k = 0 is red (outside), k = 1 is violet (inside).
vec3 spectrum(float k) {
    vec3 c = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) * -1.0 + k * 0.8));
    return c * c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Centre below the window, a little right of middle: we see the top of the
    // arc, and its left foot lands under the text rather than across it.
    vec2 c = vec2(aspect * 0.62, -0.55);
    float r = length(p - c);
    float R = 1.15, W = 0.075;                        // radius and band width

    float k = (R - r) / W;                            // 0 at the red edge, 1 at violet
    float band = smoothstep(0.0, 0.15, k) * smoothstep(1.0, 0.85, k);
    vec3 color = spectrum(clamp(k, 0.0, 1.0)) * band;

    // Faint secondary bow outside, colours reversed.
    float k2 = (r - (R + 0.17)) / (W * 1.3);
    float band2 = smoothstep(0.0, 0.2, k2) * smoothstep(1.0, 0.8, k2);
    color += spectrum(clamp(k2, 0.0, 1.0)) * band2 * 0.25;

    // Feet fade into the bottom; the left end fades too to keep text clear.
    color *= smoothstep(0.0, 0.25, p.y) * smoothstep(0.1, 0.6, p.x / aspect + 0.3 * p.y);

    // Slow fade in, hold, fade out, rest.
    float s = fract(iTime / CYCLE);
    float life = smoothstep(0.05, 0.35, s) * smoothstep(0.85, 0.6, s);

    fragColor = vec4(base.rgb + color * life * INTENSITY, base.a);
}
