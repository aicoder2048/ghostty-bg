// fish — a few fish swim across the lower half, tails wagging.
// zh: 鱼群
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.50;   // overall strength (0 = off)
const int   COUNT     = 10;     // number of fish

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// A fish facing +x: an oval body and a triangular tail that swings.
// q is in fish units (the body is about 2 long); wag runs from -1 to 1.
float fish(vec2 q, float wag) {
    q.y += sin(q.x * 2.0 - wag * 1.5) * 0.06;                     // the body bends a little
    float body = smoothstep(1.0, 0.78, length(q * vec2(1.0, 2.4)));

    vec2 t = q - vec2(-0.85, 0.0);                                // tail root
    t.y -= wag * (-t.x) * 0.7;                                    // swing more toward the tip
    float inside = step(t.x, 0.0) * step(-0.8, t.x);
    float tail = inside * smoothstep(0.06, 0.0, abs(t.y) - (-t.x) * 0.75);

    return max(body, tail * 0.85);
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
    float travel = aspect + 0.6;

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float dir = a > 0.5 ? 1.0 : -1.0;                         // swim right or left
        float speed = mix(0.035, 0.075, c) * aspect;
        float x = mod(b * travel + iTime * speed * dir, travel) - 0.3;
        float y = mix(0.10, 0.52, hash1(fi * 5.17 + 4.0)) + 0.012 * sin(iTime * 0.8 + fi * 2.0);
        float size = mix(0.022, 0.040, hash1(fi * 9.31 + 5.0));

        vec2 q = (p - vec2(x, y)) / size;
        q.x *= dir;                                               // face the way it swims
        float wag = sin(iTime * (6.0 + 3.0 * c) + fi * 1.7);

        vec3 color = mix(vec3(1.0, 0.62, 0.30), vec3(0.45, 0.85, 1.0), b);
        rgb = blend(rgb, color, fish(q, wag) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
