// warp — stars stream outward from a vanishing point, like a calm hyperspace fly-through.
// zh: 星河穿梭
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const float SPEED     = 0.75;   // how fast stars fly outward (keep it calm)

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// One layer of stars on a polar grid around the vanishing point: the angle is cut
// into `sectors` thin rays, and each ray is cut into cells along log(radius).
// Moving every cell outward in log space gives perspective for free: stars start
// as dots near the centre and turn into longer, brighter streaks toward the edges.
float layer(vec2 d, float sectors, float speed, float seed) {
    float r = length(d);
    float a = atan(d.y, d.x) / 6.28318 + 0.5;                 // 0..1 around the centre
    float s = floor(a * sectors);
    float h = hash1(s * 1.731 + seed);
    float centre = (s + 0.5 + (h - 0.5) * 0.5) / sectors;     // jitter so rays look random
    float perp = abs(a - centre) * 6.28318 * r;               // distance from the ray

    float u = log(r) * 3.0 - iTime * speed * SPEED + h * 17.0;
    float cell = floor(u);
    float f = fract(u);
    float on = step(0.66, hash1(cell * 13.17 + s * 7.31 + seed));   // not every cell has a star

    float streak = smoothstep(0.55, 0.80, f) * step(f, 0.80);       // tail fades in toward the head
    float width = 0.0016 + 0.0028 * r;
    float line = smoothstep(width, 0.0, perp);

    float near = smoothstep(0.04, 0.45, r);                         // dim near the vanishing point
    return on * streak * line * near * (0.35 + 0.65 * hash1(cell + s + seed * 3.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Vanishing point near the centre, drifting a little so it never feels fixed.
    vec2 c = vec2(aspect * 0.5, 0.5) + 0.04 * vec2(sin(iTime * 0.07), cos(iTime * 0.05));
    vec2 d = p - c;

    // Three layers at different densities and speeds read as depth.
    float light = layer(d, 70.0, 1.00, 0.0)
                + layer(d, 110.0, 0.80, 11.3) * 0.8
                + layer(d, 160.0, 0.60, 23.9) * 0.6;

    vec3 color = vec3(0.85, 0.92, 1.0) * min(light, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
