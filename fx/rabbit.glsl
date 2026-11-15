// rabbit — a rabbit hops along the bottom edge in little arcs, and stops now and then to look around.
// zh: 兔子
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float SIZE      = 0.11;   // one rabbit unit in window heights (ears reach ~1.1 units)
const float HOP_TIME  = 0.75;   // seconds per hop
const float HOP_LEN   = 1.6;    // rabbit units covered by one hop

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Signed distances (negative inside); the ellipse one is approximate.
float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float limb(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(r0, r1, h);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// A rabbit in profile facing +x. q has its origin at the hind feet on the
// ground. stretch blends the round crouch (0) into the long leaping pose (1);
// ear tilts the ears back (0 = up, 1 = laid back), used in flight and to twitch.
float rabbit(vec2 q, float stretch, float ear) {
    // Body: a round rump and a smaller chest; leaping pulls them apart.
    vec2 rump  = mix(vec2(-0.12, 0.30), vec2(-0.30, 0.34), stretch);
    vec2 chest = mix(vec2(0.18, 0.32),  vec2(0.32, 0.36),  stretch);
    float d = ellipse(q, rump, mix(vec2(0.30, 0.28), vec2(0.30, 0.20), stretch));
    d = smin(d, ellipse(q, chest, mix(vec2(0.20, 0.20), vec2(0.24, 0.16), stretch)), 0.12);
    d = smin(d, limb(q, rump, chest, mix(0.24, 0.17, stretch), mix(0.18, 0.14, stretch)), 0.06);   // waist

    // Head and muzzle.
    vec2 h = mix(vec2(0.36, 0.56), vec2(0.62, 0.48), stretch);
    d = smin(d, ellipse(q, h, vec2(0.17, 0.14)), 0.08);
    d = smin(d, ellipse(q, h + vec2(0.13, -0.04), vec2(0.07, 0.06)), 0.04);

    // Two long ears from the top of the head, swept back by `ear`.
    float a = mix(0.25, 1.05, ear);
    vec2 root = h + vec2(-0.06, 0.09);
    vec2 e = rot(q - root, -a);
    d = min(d, ellipse(e, vec2(0.0, 0.26), vec2(0.065, 0.27)));
    e = rot(q - root - vec2(0.05, 0.0), -a + 0.18);
    d = min(d, ellipse(e, vec2(0.0, 0.24), vec2(0.06, 0.25)));

    // Fluffy round tail.
    d = smin(d, length(q - (rump + vec2(-0.29, 0.06))) - 0.09, 0.03);

    // Hind leg: a big foot flat on the ground when crouched, kicked straight
    // back in the leap. Front paws: tucked under the chest, or reaching forward.
    vec2 heel = mix(vec2(-0.20, 0.05), vec2(-0.55, 0.16), stretch);
    vec2 toe  = mix(vec2(0.12, 0.03),  vec2(-0.82, 0.06), stretch);
    d = smin(d, limb(q, rump + vec2(0.0, -0.08), heel, 0.12, 0.06), 0.05);
    d = smin(d, limb(q, heel, toe, 0.055, 0.045), 0.03);
    vec2 fp = mix(vec2(0.30, 0.03), vec2(0.66, 0.04), stretch);
    d = smin(d, limb(q, chest + vec2(0.02, -0.10), fp, 0.06, 0.04), 0.04);

    // An eye cut out so the head reads.
    return max(d, -(length(q - (h + vec2(0.05, 0.03))) - 0.028));
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

    // One crossing per cycle, alternating direction, with a rest partway.
    // The rest starts on a whole number of hops so it begins on the ground.
    float v = HOP_LEN * SIZE / HOP_TIME;                       // window heights per second
    float travel = aspect + 0.5;
    float restFor = 3.5;
    float period = travel / v + restFor + 4.0;
    float n = floor(iTime / period);
    float u = iTime - n * period;
    float dir = mod(n, 2.0) < 1.0 ? 1.0 : -1.0;

    float stopAt = floor((mix(0.3, 0.7, hash1(n * 5.31 + 2.0)) * aspect + 0.25) / v / HOP_TIME) * HOP_TIME;
    float hopped = min(u, stopAt) + max(u - stopAt - restFor, 0.0);
    bool resting = u > stopAt && u < stopAt + restFor;

    // Within a hop: 35% crouched on the ground, then a parabolic leap.
    float k = hopped / HOP_TIME;
    float f = fract(k);
    float air = clamp((f - 0.35) / 0.65, 0.0, 1.0);
    if (resting) air = 0.0;
    float x = (floor(k) + air) * HOP_LEN * SIZE - 0.25;
    float y = 4.0 * air * (1.0 - air) * 0.85 * SIZE;          // arc height
    float stretch = sin(3.14159 * air);
    stretch = stretch * (2.0 - stretch);                       // stay long for most of the flight
    float tilt = 0.45 * cos(3.14159 * air) * stretch;          // nose up on take-off, down on landing

    // While crouched before take-off it squashes a little; at rest the ears twitch.
    float squash = resting ? 0.0 : smoothstep(0.0, 0.35, f) * (1.0 - step(0.35, f)) * 0.08;
    float ear = 0.85 * stretch;
    if (resting) ear = 0.15 * smoothstep(0.6, 1.0, sin(iTime * 2.3)) + 0.1 * smoothstep(0.8, 1.0, sin(iTime * 5.0 + 1.0));

    if (dir < 0.0) x = aspect - x;
    vec2 q = (p - vec2(x, y + 0.01)) / SIZE;
    q.x *= dir;                                                // face the way it hops
    q = rot(q - vec2(-0.1, 0.3), -tilt) + vec2(-0.1, 0.3);    // pitch around the body
    q.y /= (1.0 - squash);
    float d = rabbit(q, stretch, ear);

    float px = 1.5 / (iResolution.y * SIZE);
    float shape = smoothstep(px, -px, d);

    vec3 color = vec3(0.95, 0.92, 0.88);
    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
