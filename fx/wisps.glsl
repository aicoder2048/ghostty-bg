// wisps — pale blue-green will-o'-the-wisps bob and flicker near the bottom, fading in and out.
// zh: 鬼火
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const int   COUNT     = 7;      // number of wisps
const float SIZE      = 0.026;  // flame half-width in screen heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 glow = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        // Drift slowly left and right, bob up and down, low over the "ground".
        vec2 pos = vec2((0.08 + 0.84 * a) * aspect + 0.10 * sin(iTime * (0.05 + 0.04 * c) + fi * 2.0),
                        0.08 + 0.17 * b + 0.025 * sin(iTime * (0.6 + 0.5 * c) + fi * 1.3));
        // They come and go: each one fades in, lingers, then fades out.
        float vis = smoothstep(-0.6, 0.3, sin(iTime * (0.12 + 0.08 * c) + fi * 2.1));
        float flicker = 0.75 + 0.25 * noise(vec2(iTime * 7.0, fi * 10.0));

        vec2 q = (p - pos) / SIZE;
        float halo = 0.6 / (dot(q, q) + 0.6);
        if (dot(q, q) < 16.0) {
            // A teardrop flame: round below, stretched into a swaying tip above.
            float top = max(q.y, 0.0);
            q.x -= 0.20 * top * top * sin(iTime * 3.0 + fi * 2.0);
            q.x += (noise(vec2(q.y * 2.0 - iTime * 5.0, fi)) - 0.5) * 0.4 * top;
            float dd = length(vec2(q.x, q.y * (q.y > 0.0 ? 0.36 : 1.0)));
            float flame = smoothstep(1.0, 0.0, dd);
            float core = exp(-dot(q, q) * 3.0);
            glow += (mix(vec3(0.30, 0.95, 0.80), vec3(0.85, 1.0, 1.0), core) * (flame * 0.9 + core * 0.6)) * vis * flicker;
        }
        glow += vec3(0.30, 0.85, 0.80) * halo * 0.35 * vis * flicker;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
