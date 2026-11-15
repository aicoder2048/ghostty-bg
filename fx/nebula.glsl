// nebula — soft, colourful clouds of gas drift very slowly behind the text.
// zh: 星云
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.22;   // overall brightness (0 = off); keep low so text stays readable
const float DRIFT     = 0.012;  // how fast the clouds drift

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Smooth value noise on a grid.
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Four octaves only: enough for wispy edges, cheap enough for every pixel.
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

    vec2 drift = vec2(iTime * DRIFT, iTime * DRIFT * 0.4);
    float gas = fbm(p * 1.8 + drift);
    float density = smoothstep(0.38, 0.80, gas);
    float hue = noise(p * 0.9 - drift * 0.7 + 5.0);           // slow, large colour patches

    vec3 magenta = vec3(0.85, 0.30, 0.75);
    vec3 teal    = vec3(0.20, 0.65, 0.90);
    vec3 gold    = vec3(0.95, 0.60, 0.35);
    vec3 tint = mix(mix(teal, magenta, smoothstep(0.25, 0.65, hue)), gold, smoothstep(0.70, 0.95, hue));
    float core = smoothstep(0.62, 0.90, gas);                 // brighter knots inside the clouds

    // Fainter in the upper left, where the prompt and most text sit.
    float clear = mix(0.45, 1.0, smoothstep(0.2, 1.1, length(vec2(p.x, 1.0 - p.y))));

    vec3 color = (tint * density + vec3(1.0, 0.9, 0.95) * core * 0.35) * clear * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
