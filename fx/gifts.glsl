// gifts — little wrapped presents with ribbons and bows drift slowly down, turning a little.
// zh: 礼物
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 9;      // number of presents

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float size = mix(0.026, 0.040, c);
        float speed = mix(0.030, 0.050, c);
        float y = 1.15 - mod(b * 1.3 + iTime * speed, 1.3);
        float x = (0.06 + 0.88 * a) * aspect + 0.025 * sin(iTime * 0.4 + fi * 2.9);

        // Present units: box about 2 wide, bow on top up to y = 1.25.
        vec2 q = (p - vec2(x, y)) / size;
        if (dot(q, q) > 4.0) continue;
        float ang = 0.35 * sin(iTime * 0.5 + fi * 1.7);           // rock back and forth
        q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * q;

        float px = 1.5 / (iResolution.y * size);                   // one pixel in present units
        float boxD = sdBox(q - vec2(0.0, -0.25), vec2(0.80, 0.65));
        float lidD = sdBox(q - vec2(0.0, 0.52), vec2(0.92, 0.17));
        float box = smoothstep(px, -px, boxD);
        float lid = smoothstep(px, -px, lidD);
        // A thin dark gap between lid and box keeps them apart.
        float gap = smoothstep(px * 2.0, 0.0, abs(q.y - 0.35)) * step(abs(q.x), 0.92);

        // Ribbon: a vertical band over both, a horizontal band round the box.
        float band = max(smoothstep(px, -px, abs(q.x) - 0.13) * max(box, lid),
                         smoothstep(px, -px, abs(q.y + 0.25) - 0.11) * box);

        // Bow: two loops (rings) and a knot, sitting on the lid.
        vec2 m = vec2(abs(q.x), q.y) - vec2(0.27, 0.86);
        m = mat2(0.87, -0.5, 0.5, 0.87) * m;                       // loops lean outward
        float loopD = abs(length(m / vec2(1.0, 0.6)) * 0.6 - 0.12) - 0.06;
        float bow = smoothstep(px, -px, loopD);
        float knot = smoothstep(px, -px, length(q - vec2(0.0, 0.76)) - 0.1);

        vec3 paper = 0.5 + 0.45 * cos(6.2831 * (hash1(fi * 5.3) + vec3(0.0, 0.33, 0.67)));
        vec3 ribbon = hash1(fi * 2.9) > 0.5 ? vec3(1.0, 0.85, 0.35) : vec3(0.95, 0.95, 1.0);

        float shape = max(box, lid) * (1.0 - gap * 0.8);
        rgb = blend(rgb, paper * mix(0.85, 1.0, lid), shape * 0.75 * INTENSITY);
        rgb = blend(rgb, ribbon, max(band * shape, max(bow, knot)) * 0.8 * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
