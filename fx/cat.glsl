// cat — a cat strolls along the bottom edge, tail swishing; it sits, blinks and looks at you, stretches, walks on.
// zh: 猫
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float SIZE      = 0.18;   // one cat unit in window heights (ears reach ~0.9 units)
const float WALK_TIME = 14.0;   // seconds to walk across the window
const float SIT_TIME  = 5.5;    // seconds it sits partway across
const float BOW_TIME  = 1.6;    // seconds for the stretch after getting up

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

// A better ellipse estimate for very flat ones (an eye shutting), where the
// cheap one above would smear into a long line.
float flatEllipse(vec2 p, vec2 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-4);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Where a paw is relative to its hip/shoulder during a walk. Each foot spends
// 60% of the cycle planted (sliding back as the body moves on) and 40% swinging
// forward through the air.
const float HALF_STRIDE = 0.17;
vec2 paw(float phase) {
    float s = fract(phase);
    const float L = HALF_STRIDE;
    if (s < 0.6) return vec2(mix(L, -L, s / 0.6), 0.0);
    float u = (s - 0.6) / 0.4;
    return vec2(mix(-L, L, smoothstep(0.0, 1.0, u)), sin(3.14159 * u) * 0.07);
}

// A short pulse (0 -> 1 -> 0, `len` seconds) once per `every` seconds, at a
// random moment in each slot so it never feels mechanical (ear twitches).
float pulse(float t, float every, float len, float seed) {
    float k = floor(t / every);
    float at = (t - k * every) - hash1(k * 3.7 + seed) * (every - len);
    return smoothstep(0.0, len * 0.3, at) * (1.0 - smoothstep(len * 0.7, len, at));
}

// Eyes shut for 0.18 s every 4 s (at 0.6 s into each slot); every third slot
// it blinks twice. Kept regular on purpose: the random hash above differs
// slightly between GPUs, and a blink should be easy to time.
float blink(float t) {
    float k = floor(t / 4.0);
    float at = t - k * 4.0;
    float second = mod(k, 3.0) < 0.5 ? 1.0 : 0.0;
    float b1 = 1.0 - smoothstep(0.0, 0.09, abs(at - 0.69));
    float b2 = (1.0 - smoothstep(0.0, 0.09, abs(at - 1.04))) * second;
    return max(b1, b2);
}

// Tail joint angles (radians, 0 = forward, pi/2 = up), base to tip. Walking:
// up and curling forward at the tip like a question mark. Sitting: back,
// down and round the haunch to lie along the ground in front of the paws.
const float TAIL_WALK[5] = float[5](2.30, 1.90, 1.60, 1.25, 0.80);
const float TAIL_SIT[5]  = float[5](4.40, 5.80, 6.25, 6.35, 6.70);

// A cat in profile facing +x, standing on y = 0.
//   phase   gait position (one unit per stride)
//   sit     walking (0) to sitting (1)
//   bow     a play-bow stretch after getting up (front low, rump high)
//   look    while sitting, the head turns to face the viewer (0..1)
float cat(vec2 q, float phase, float sit, float bow, float look, float t) {
    float bob = 0.012 * sin(phase * 6.2832 * 2.0) * (1.0 - sit) * (1.0 - bow);
    q.y -= bob;

    // Body: a long torso with a deeper chest and a round haunch. Sitting tips
    // it up; the stretch tips it the other way.
    vec2  bc = mix(vec2(0.0, 0.46), vec2(0.02, 0.40), sit) + vec2(0.03, -0.08) * bow;
    float d  = ellipse(rot(q - bc, -1.05 * sit + 0.50 * bow), vec2(0.0),
                       mix(vec2(0.38, 0.165), vec2(0.27, 0.17), sit));
    vec2 chest = mix(vec2(0.22, 0.45), vec2(0.12, 0.55), sit) + vec2(0.10, -0.26) * bow;
    d = smin(d, ellipse(q, chest, vec2(0.18, 0.18)), 0.06);
    d = smin(d, ellipse(q, mix(vec2(-0.25, 0.47), vec2(-0.12, 0.22), sit) + vec2(0.0, 0.04) * bow,
                        mix(vec2(0.18, 0.18), vec2(0.23, 0.22), sit)), 0.06);

    // Head and neck.
    vec2 h = mix(vec2(0.50, 0.66), vec2(0.20, 0.88), sit) + vec2(0.18, -0.36) * bow
           + vec2(-0.03 * look, -bob * 0.5);
    d = smin(d, limb(q, chest + vec2(0.06, 0.05), h, 0.10, 0.08), 0.05);
    d = smin(d, ellipse(q, h, vec2(0.15, 0.13)), 0.03);
    d = smin(d, ellipse(q, h + mix(vec2(0.11, -0.035), vec2(0.0, -0.05), look),
                        mix(vec2(0.06, 0.05), vec2(0.07, 0.045), look)), 0.03);   // muzzle

    // Ears: offset one behind the other in profile, a symmetric pair when the
    // head turns to the front. Now and then the back/right ear flicks.
    float twitch = pulse(t + 1.3, 2.6, 0.25, 11.0);
    d = min(d, triangle(q, h + mix(vec2(-0.12, 0.05), vec2(-0.15, 0.04), look),
                           h + mix(vec2(-0.07, 0.25), vec2(-0.11, 0.24), look),
                           h + mix(vec2(0.01, 0.11),  vec2(-0.02, 0.12), look)));
    d = min(d, triangle(q, h + mix(vec2(0.00, 0.11),  vec2(0.02, 0.12), look),
                           h + mix(vec2(0.08, 0.25),  vec2(0.11, 0.24), look) + vec2(0.05, -0.07) * twitch,
                           h + mix(vec2(0.13, 0.04),  vec2(0.15, 0.04), look)));

    // Legs. A lateral-sequence walk: near hind, near fore, far hind, far fore.
    vec2 sh = mix(vec2(0.26, 0.40), vec2(0.15, 0.46), sit) + vec2(0.08, -0.28) * bow;  // shoulder
    vec2 hp = mix(vec2(-0.28, 0.42), vec2(-0.10, 0.22), sit) + vec2(0.0, 0.04) * bow;  // hip
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float side = fi * 0.5;                                  // near / far side
        vec2 fp = mix(vec2(0.26, 0.0) + paw(phase + 0.25 + side), vec2(0.17 + 0.05 * fi, 0.0), sit);
        fp = mix(fp, vec2(0.74 + 0.07 * fi, 0.0), bow);         // front legs stretched out
        vec2 bp = mix(vec2(-0.30, 0.0) + paw(phase + side), vec2(0.06 * fi, 0.0), sit);
        vec2 hock = bp + mix(vec2(-0.08, 0.15), vec2(-0.18, 0.06), sit);
        d = smin(d, limb(q, sh, fp, 0.055, 0.035), 0.03);
        d = smin(d, limb(q, hp, hock, 0.075, 0.04), 0.04);
        d = min(d, limb(q, hock, bp, 0.04, 0.035));
    }

    // Tail: a chain of five segments. A wave runs from base to tip, a slow
    // swish while walking; while sitting only the tip flicks, impatiently.
    vec2 tp = mix(vec2(-0.38, 0.52), vec2(-0.33, 0.20), sit);
    float r = 0.05;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float amp = mix(0.10 + 0.04 * fi, fi >= 3.0 ? 0.45 : 0.04, sit);
        float ang = mix(TAIL_WALK[i], TAIL_SIT[i], sit)
                  + amp * sin(t * mix(2.2, 3.3, sit) - fi * 0.9) + 0.25 * bow;
        vec2 nx = tp + 0.12 * vec2(cos(ang), sin(ang));
        d = smin(d, limb(q, tp, nx, r, r - 0.005), i == 0 ? 0.03 : 0.01);
        tp = nx;
        r -= 0.005;
    }

    // Almond eyes cut out of the head: one in profile, two when facing us.
    // A blink squeezes them shut for a moment every few seconds.
    float open = 1.0 - 0.85 * blink(t);
    vec2 er = vec2(0.035, 0.021 * open);
    vec2 e1 = h + mix(vec2(0.06, 0.02), vec2(0.065, 0.02), look);
    vec2 e2 = h + mix(vec2(0.06, 0.02), vec2(-0.065, 0.02), look);
    float eye = min(flatEllipse(rot(q - e1, mix(0.3, 0.25, look)), er),
                    flatEllipse(rot(q - e2, mix(0.3, -0.25, look)), er));
    eye = min(eye, length(q - (h + vec2(0.0, -0.035))) - 0.018 * look);   // nose
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

    // One crossing per cycle, alternating direction: walk in, sit down and
    // look around, get up with a stretch, walk out. The clock is shifted so the
    // cat is already on screen at start-up.
    float travel = aspect + 0.7;                                // edge to edge, cat included
    float v = travel / WALK_TIME;                               // window heights per second
    float period = WALK_TIME + SIT_TIME + BOW_TIME + 1.0;       // 1 s off screen between passes
    float tt = iTime + (0.35 + 0.15 * aspect) / v;
    float n = floor(tt / period);
    float u = tt - n * period;
    float dir = mod(n, 2.0) < 1.0 ? 1.0 : -1.0;

    float stopAt = (mix(0.30, 0.65, hash1(n * 7.13 + 1.0)) * aspect + 0.35) / v;
    float up = stopAt + SIT_TIME;                               // when it gets up
    float walked = min(u, stopAt) + max(u - up - BOW_TIME, 0.0);
    float sit  = smoothstep(stopAt, stopAt + 0.8, u) * (1.0 - smoothstep(up - 0.8, up, u));
    float look = smoothstep(stopAt + 1.0, stopAt + 1.5, u) * (1.0 - smoothstep(up - 1.6, up - 1.1, u));
    float b = clamp((u - up) / BOW_TIME, 0.0, 1.0);
    float bow = smoothstep(0.0, 0.35, b) * (1.0 - smoothstep(0.65, 1.0, b));

    float x = walked * v - 0.35;
    if (dir < 0.0) x = aspect - x;

    vec2 q = (p - vec2(x, 0.01)) / SIZE;
    q.x *= dir;                                                 // face the way it walks
    float stride = 2.0 * HALF_STRIDE / 0.6;                     // body travel per gait cycle
    float d = cat(q, walked * v / SIZE / stride, sit, bow, look, iTime);

    float px = 1.5 / (iResolution.y * SIZE);                    // one pixel in cat units
    float shape = smoothstep(px, -px, d);

    vec3 color = vec3(0.96, 0.90, 0.82);
    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
