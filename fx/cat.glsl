// cat — a cat walks along the bottom edge, tail held high, and now and then sits down for a rest.
// zh: 猫
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float SIZE      = 0.12;   // one cat unit in window heights (ears reach ~0.9 units)
const float SPEED     = 0.85;   // walking speed in cat units per second

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Signed distances (negative inside). The ellipse one is approximate, which is
// fine for soft-edged shapes this small.
float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// A segment whose radius goes from r0 at a to r1 at b (legs, tail, neck).
float limb(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(r0, r1, h);
}

float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0,  v1 = p - p1,  v2 = p - p2;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Where a paw is relative to its hip/shoulder during a walk. Each foot spends
// 60% of the cycle planted (sliding back as the body moves on) and 40% swinging
// forward through the air.
vec2 paw(float phase) {
    float s = fract(phase);
    const float L = 0.15;                                 // half a stride
    if (s < 0.6) return vec2(mix(L, -L, s / 0.6), 0.0);
    float u = (s - 0.6) / 0.4;
    return vec2(mix(-L, L, smoothstep(0.0, 1.0, u)), sin(3.14159 * u) * 0.07);
}

// A cat in profile facing +x, standing on y = 0. phase drives the gait (one
// unit per stride), sit blends from walking (0) to sitting (1), t sways the tail.
float cat(vec2 q, float phase, float sit, float t) {
    float bob = 0.012 * sin(phase * 6.2832 * 2.0) * (1.0 - sit);
    q.y -= bob;

    // Body: a long torso with a deeper chest and a round haunch. Sitting tips it up.
    vec2  bc = mix(vec2(0.0, 0.46), vec2(0.02, 0.40), sit);
    float d  = ellipse(rot(q - bc, -1.05 * sit), vec2(0.0), mix(vec2(0.38, 0.165), vec2(0.27, 0.17), sit));
    d = smin(d, ellipse(q, mix(vec2(0.22, 0.45), vec2(0.12, 0.55), sit), vec2(0.18, 0.18)), 0.06);
    d = smin(d, ellipse(q, mix(vec2(-0.25, 0.47), vec2(-0.12, 0.22), sit),
                        mix(vec2(0.18, 0.18), vec2(0.23, 0.22), sit)), 0.06);

    // Head, neck, muzzle and two pointed ears.
    vec2 h = mix(vec2(0.50, 0.66), vec2(0.22, 0.88), sit) + vec2(0.0, -bob * 0.5);
    d = smin(d, limb(q, mix(vec2(0.28, 0.50), vec2(0.14, 0.62), sit), h, 0.10, 0.08), 0.05);
    d = smin(d, ellipse(q, h, vec2(0.15, 0.13)), 0.03);
    d = smin(d, ellipse(q, h + vec2(0.11, -0.035), vec2(0.06, 0.05)), 0.03);
    d = min(d, triangle(q, h + vec2(-0.12, 0.05), h + vec2(-0.07, 0.25), h + vec2(0.01, 0.11)));
    d = min(d, triangle(q, h + vec2(0.0, 0.11), h + vec2(0.08, 0.25), h + vec2(0.13, 0.04)));

    // Legs. A lateral-sequence walk: near hind, near fore, far hind, far fore.
    vec2 sh = mix(vec2(0.26, 0.40), vec2(0.15, 0.46), sit);    // shoulder
    vec2 hp = mix(vec2(-0.28, 0.42), vec2(-0.10, 0.22), sit);  // hip
    for (int i = 0; i < 2; i++) {
        float side = float(i) * 0.5;                            // near / far side
        vec2 fp = mix(vec2(0.26, 0.0) + paw(phase + 0.25 + side), vec2(0.17 + 0.05 * float(i), 0.0), sit);
        vec2 bp = mix(vec2(-0.30, 0.0) + paw(phase + side), vec2(0.0 + 0.06 * float(i), 0.0), sit);
        vec2 hock = bp + mix(vec2(-0.08, 0.15), vec2(-0.18, 0.06), sit);
        d = smin(d, limb(q, sh, fp, 0.055, 0.035), 0.03);
        d = smin(d, limb(q, hp, hock, 0.075, 0.04), 0.04);
        d = min(d, limb(q, hock, bp, 0.04, 0.035));
    }

    // Tail: held up in a soft question mark while walking, wrapped along the
    // ground while sitting. Three segments through four points.
    float sway = sin(t * 1.7) * 0.05;
    float flick = sin(t * 3.1) * 0.04 * sit;
    vec2 t0 = mix(vec2(-0.38, 0.52), vec2(-0.30, 0.10), sit);
    vec2 t1 = mix(vec2(-0.54, 0.74 + sway * 0.5), vec2(-0.44, 0.04), sit);
    vec2 t2 = mix(vec2(-0.52 + sway, 0.96), vec2(-0.25, 0.03), sit);
    vec2 t3 = mix(vec2(-0.40 + sway * 1.5, 1.02), vec2(0.05, 0.04 + flick), sit);
    d = smin(d, limb(q, t0, t1, 0.045, 0.04), 0.03);
    d = min(d, limb(q, t1, t2, 0.04, 0.035));
    d = min(d, limb(q, t2, t3, 0.035, 0.03));

    // A small almond eye cut out of the head so the face reads.
    float eye = ellipse(rot(q - (h + vec2(0.06, 0.02)), 0.3), vec2(0.0), vec2(0.03, 0.017));
    return max(d, -eye);
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

    // One crossing per cycle, alternating direction. Partway across the cat
    // stops, sits for a few seconds, then gets up and walks on.
    float v = SPEED * SIZE;                                     // window heights per second
    float travel = aspect + 0.5;
    float sitFor = 6.0;
    float period = travel / v + sitFor + 4.0;                   // + a short gap off screen
    float n = floor(iTime / period);
    float u = iTime - n * period;
    float dir = mod(n, 2.0) < 1.0 ? 1.0 : -1.0;

    float stopAt = (mix(0.25, 0.70, hash1(n * 7.13 + 1.0)) * aspect + 0.25) / v;
    float walked = min(u, stopAt) + max(u - stopAt - sitFor, 0.0);
    float sit = smoothstep(stopAt, stopAt + 0.9, u)
              * (1.0 - smoothstep(stopAt + sitFor - 0.9, stopAt + sitFor, u));

    float x = walked * v - 0.25;
    if (dir < 0.0) x = aspect - x;

    vec2 q = (p - vec2(x, 0.01)) / SIZE;
    q.x *= dir;                                                 // face the way it walks
    float stride = 2.0 * 0.15 / 0.6;                            // body travel per gait cycle
    float d = cat(q, walked * SPEED / stride, sit, iTime);

    float px = 1.5 / (iResolution.y * SIZE);                    // one pixel in cat units
    float shape = smoothstep(px, -px, d);

    vec3 color = vec3(0.96, 0.90, 0.82);
    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
