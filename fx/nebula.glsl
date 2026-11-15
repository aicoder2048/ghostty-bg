// nebula — colourful clouds of gas billow and drift slowly, with stars twinkling inside.
// zh: 星云
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const float DRIFT     = 0.035;  // how fast the clouds drift
const float CLEAR     = 0.35;   // how much of the cloud is left in the upper left, where text sits

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

    // A cheap sine warp makes the gas billow instead of just sliding.
    vec2 drift = vec2(iTime * DRIFT, iTime * DRIFT * 0.4);
    vec2 w = p + 0.18 * vec2(sin(p.y * 2.3 + iTime * 0.21), cos(p.x * 1.9 - iTime * 0.17));
    float gas = fbm(w * 1.7 + drift);
    float density = smoothstep(0.32, 0.78, gas);
    float core = smoothstep(0.60, 0.85, gas);                 // bright knots inside the clouds

    // Dust: broad, soft darker patches from one low-frequency noise, so the
    // clouds have depth without hard lines cutting through them.
    float dust = smoothstep(0.40, 0.85, noise(w * 0.9 - drift * 0.5 + 11.0));
    density *= 1.0 - 0.45 * dust;

    float hue = noise(p * 0.9 - drift * 0.6 + 5.0);           // large, slowly shifting colour patches
    vec3 magenta = vec3(0.95, 0.25, 0.75);
    vec3 teal    = vec3(0.10, 0.70, 0.95);
    vec3 gold    = vec3(1.00, 0.65, 0.25);
    vec3 tint = mix(mix(teal, magenta, smoothstep(0.25, 0.60, hue)), gold, smoothstep(0.65, 0.90, hue));

    // Fainter in the upper left, where the prompt and most text sit.
    float clear = mix(CLEAR, 1.0, smoothstep(0.35, 1.40, length(vec2(p.x * 0.8, 1.0 - p.y))));

    vec3 color = (tint * density + vec3(1.0, 0.92, 0.95) * core * 0.6) * clear;

    // Stars embedded in the gas: one layer on a grid, each twinkling at its own pace.
    vec2 g = p * 38.0;
    vec2 cell = floor(g);
    float h = hash2(cell);
    vec2 star = cell + 0.2 + 0.6 * vec2(hash2(cell + 7.1), hash2(cell + 3.7));
    float tw = 0.5 + 0.5 * sin(iTime * (1.0 + 2.5 * h) + h * 40.0);
    float s = step(0.86, h) * smoothstep(0.10, 0.0, length(g - star)) * tw;
    color += vec3(0.9, 0.95, 1.0) * s * (0.6 + 0.6 * density) * clear * 1.4;

    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
