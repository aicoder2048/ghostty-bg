// fog — soft fog banks drifting slowly across the lower part of the window.
// zh: 雾
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.30;   // overall brightness (0 = off); low so text stays crisp
const float DRIFT     = 0.025;  // sideways speed, in window-heights per second

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
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

    // Two banks at different speeds; the slow one is wide and flat (fog lies low).
    vec2 s = p * vec2(1.6, 3.2);
    float far  = fbm(s + vec2(-iTime * DRIFT * 1.6, 0.0));
    float near = fbm(s * 1.7 + vec2(iTime * DRIFT * 2.6, 3.0) + 0.4 * far);
    float fog = smoothstep(0.30, 0.80, 0.55 * far + 0.55 * near);

    // Thickest along the bottom, gone by the upper third where text sits.
    float height = smoothstep(0.65, 0.0, p.y + 0.12 * (far - 0.5));
    // Slow breathing so the banks thin and thicken.
    float breathe = 0.80 + 0.20 * sin(iTime * 0.13);

    // A thin even haze underneath the banks, so there is always some fog.
    vec3 color = vec3(0.80, 0.84, 0.90) * (0.30 + 0.70 * fog) * height * breathe;
    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
