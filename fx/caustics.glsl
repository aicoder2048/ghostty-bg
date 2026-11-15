// caustics — a soft, moving web of underwater light, with faint sun shafts from above.
// zh: 水光
// group: ocean
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.17;   // overall brightness (0 = off); keep it subtle
const float SCALE     = 5.0;    // how many light cells fit in the window height

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// One layer of the light web: the borders between drifting cells (a moving
// Voronoi pattern). Near a border the two closest cell centres are about
// equally far away, so f2 - f1 is small there and we turn that into a bright line.
float web(vec2 p, float t) {
    vec2 g = floor(p), f = fract(p);
    float f1 = 9.0, f2 = 9.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 o = vec2(float(i), float(j));
        vec2 h = hash2(g + o);
        vec2 c = o + 0.5 + 0.4 * sin(t * (0.6 + 0.5 * h) + 6.2831 * h);   // each centre circles slowly
        float d = length(c - f);
        f2 = min(f2, max(d, f1));
        f1 = min(f1, d);
    }
    return smoothstep(0.13, 0.0, f2 - f1);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // A gentle wobble makes the lines wavy instead of straight. This only bends
    // the light pattern; the terminal itself is still read at uv.
    vec2 w = p * SCALE;
    w += 0.18 * vec2(sin(w.y * 1.3 + iTime * 0.5), sin(w.x * 1.1 - iTime * 0.4));
    // Two layers drifting apart: where their lines cross, the light is brightest.
    float a = web(w, iTime * 0.5);
    float b = web(w * 1.3 + vec2(3.7, 1.9) + iTime * 0.03, iTime * 0.4 + 10.0);
    float light = a * 0.5 + b * 0.35 + a * b * 0.8;
    light *= 0.6 + 0.4 * sin(p.x * 2.1 + p.y * 1.3 + iTime * 0.15);   // brighter and dimmer patches

    // Sun shafts: slanted bands that fade as they go down and sway slowly.
    float xr = p.x + (1.0 - p.y) * 0.35;
    float shafts = pow(0.5 + 0.5 * sin(xr * 6.0 + 0.6 * sin(iTime * 0.13)), 10.0)
                 + 0.7 * pow(0.5 + 0.5 * sin(xr * 10.0 - iTime * 0.09 + 1.3), 14.0);
    shafts *= p.y * p.y;

    vec3 color = vec3(0.55, 0.88, 1.0) * (light * 0.8 + shafts * 0.5) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
