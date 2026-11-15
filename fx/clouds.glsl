// clouds — soft wispy clouds drift slowly across the upper part of the window.
// zh: 浮云
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.30;   // overall brightness (0 = off)
const float WIND      = 0.010;  // drift speed, in window-heights per second

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Four octaves of noise; each octave is shifted and rotated so it looks soft, not blocky.
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = m * p + 7.3;
        a *= 0.5;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Stretched sideways so the clouds come out long and wispy; the shape also
    // changes slowly while it drifts.
    vec2 c = vec2((p.x - iTime * WIND) * 1.3, p.y * 3.2);
    float n = fbm(c * 1.5 + vec2(0.0, iTime * 0.004));
    float cloud = smoothstep(0.48, 0.80, n);

    // Only the upper part of the window, thinning out toward the middle.
    cloud *= smoothstep(0.40, 0.80, p.y);
    // Fainter over the top-left, where the text usually is.
    cloud *= 1.0 - 0.5 * smoothstep(0.6, 0.0, uv.x);

    // A touch brighter on the top edge, like sunlight on cloud tops.
    float top = smoothstep(0.55, 0.85, fbm(c * 1.5 + vec2(0.0, -0.06 + iTime * 0.004)));
    vec3 color = vec3(0.88, 0.90, 0.96) * cloud * (0.8 + 0.3 * top);

    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
