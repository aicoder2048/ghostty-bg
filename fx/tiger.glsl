// tiger — a big striped tiger prowls along the bottom edge, stops to look at you and roar, then walks on.
// zh: 老虎
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.48;   // overall strength (0 = off)
const float SIZE      = 0.29;   // one tiger unit in window heights (shoulders ~0.9 units)
const float WALK_TIME = 17.0;   // seconds to walk across the window
const float STOP_TIME = 6.0;    // seconds it pauses partway across
const float HALF_STRIDE = 0.20; // half a stride, in tiger units

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// Tapered segment; .x distance, .y how far along (0 at a, 1 at b).
vec2 limbH(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h) - mix(r0, r1, h), h);
}

float limb(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    return limbH(p, a, b, r0, r1).x;
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Paw offset during the walk: 60% planted and sliding back, 40% swinging
// forward and lifted. A slow, heavy prowl.
vec2 paw(float phase) {
    float s = fract(phase);
    const float L = HALF_STRIDE;
    if (s < 0.6) return vec2(mix(L, -L, s / 0.6), 0.0);
    float u = (s - 0.6) / 0.4;
    return vec2(mix(-L, L, smoothstep(0.0, 1.0, u)), sin(3.14159 * u) * 0.08);
}

// One leg. Front legs are nearly straight with a wrist that folds on the
// swing; hind legs have the backward-bent hock of a cat.
float leg(vec2 q, vec2 top, vec2 foot, bool front) {
    float lifted = foot.y;
    if (front) {
        vec2 wrist = foot + vec2(-0.03 - lifted * 0.6, 0.15);
        float d = smin(limb(q, top, wrist, 0.125, 0.07), limb(q, wrist, foot + vec2(0.0, 0.04), 0.065, 0.06), 0.03);
        return smin(d, ellipse(q, foot + vec2(0.05, 0.035), vec2(0.085, 0.04)), 0.03);
    }
    vec2 knee = vec2(top.x + 0.14, 0.40 + lifted * 0.5);
    vec2 hock = foot + vec2(-0.13, 0.21 + lifted * 0.4);
    float d = smin(limb(q, top, knee, 0.17, 0.09), limb(q, knee, hock, 0.08, 0.065), 0.04);
    d = smin(d, limb(q, hock, foot + vec2(0.0, 0.04), 0.06, 0.055), 0.03);
    return smin(d, ellipse(q, foot + vec2(0.05, 0.035), vec2(0.085, 0.04)), 0.03);
}

// Tail joint angles (0 = forward, pi = back): hanging down from the rump and
// curling back up at the end, carried low.
const float TAIL[6] = float[6](3.80, 4.20, 4.00, 3.50, 3.00, 2.60);

// The tiger in profile facing +x on y = 0. Returns
//   .x silhouette distance (near parts)   .y far-side legs distance
//   .z stripe/dark amount (0..1)          .w white amount (0..1)
// phase: gait; stand: blends to a square stance when stopped; look: head
// turned to the viewer; roar: mouth open; t: time for the tail.
vec4 tiger(vec2 q, float phase, float stand, float look, float roar, float t) {
    float roll = 0.025 * sin(phase * 6.2832) * (1.0 - stand);   // shoulders roll with the front legs
    float bob = 0.012 * sin(phase * 6.2832 * 2.0) * (1.0 - stand);
    vec2 sq = q - vec2(0.0, roll);

    // Heavy body: hindquarters, long torso with a slight belly sag, high shoulders.
    float body = ellipse(q, vec2(-0.02, 0.62), vec2(0.60, 0.19));
    body = smin(body, ellipse(q, vec2(0.0, 0.53), vec2(0.42, 0.12)), 0.08);
    body = smin(body, ellipse(q, vec2(-0.46, 0.63), vec2(0.25, 0.22)), 0.08);
    body = smin(body, ellipse(sq, vec2(0.42, 0.66), vec2(0.24, 0.22)), 0.08);

    // Head, carried low and forward on a thick neck.
    vec2 h = vec2(0.86, 0.67 + roll * 0.5 - bob) + vec2(-0.04, 0.03) * look;
    body = smin(body, limb(q, vec2(0.52, 0.68 + roll), h + vec2(-0.05, 0.0), 0.19, 0.15), 0.06);
    float head = ellipse(q, h, mix(vec2(0.20, 0.17), vec2(0.19, 0.18), look));
    head = smin(head, ellipse(q, h + mix(vec2(-0.03, -0.07), vec2(0.0, -0.07), look),
                              mix(vec2(0.17, 0.12), vec2(0.24, 0.12), look)), 0.04);   // cheek ruff
    vec2 mz = h + mix(vec2(0.17, -0.06), vec2(0.0, -0.08), look);
    head = smin(head, ellipse(q, mz, mix(vec2(0.11, 0.085), vec2(0.12, 0.08), look)), 0.04);

    // Round ears: one behind the other in profile, a pair when facing us.
    vec2 e1 = h + mix(vec2(-0.06, 0.16), vec2(-0.14, 0.14), look);
    vec2 e2 = h + mix(vec2(-0.12, 0.13), vec2(0.14, 0.14), look);
    head = min(head, min(length(q - e1) - 0.065, length(q - e2) - 0.06));

    // Lower jaw: swings down about the hinge in profile, drops straight
    // down when facing us. The open mouth between is dark.
    vec2 hinge = h + mix(vec2(0.02, -0.08), vec2(0.0, -0.10), look);
    vec2 jp = rot(q - hinge, mix(0.55, 0.0, look) * roar) + hinge + vec2(0.0, 0.07 * roar * look);
    float jaw = ellipse(jp, h + mix(vec2(0.13, -0.12), vec2(0.0, -0.15), look), mix(vec2(0.12, 0.045), vec2(0.08, 0.04), look));
    head = smin(head, jaw, 0.02);
    vec2 mc = h + mix(vec2(0.16, -0.13 - 0.04 * roar), vec2(0.0, -0.15), look);
    float mouth = ellipse(q, mc, vec2(mix(0.10, 0.06, look), 0.055) * roar + 0.001);
    head = min(head, mouth);
    body = min(body, head);

    // Legs: lateral-sequence walk, near pair over the far pair.
    vec2 shoulder = vec2(0.42, 0.58 + roll), hip = vec2(-0.46, 0.60);
    float nearLegs = 1e3, farLegs = 1e3;
    for (int i = 0; i < 2; i++) {
        float side = float(i) * 0.5;
        vec2 fp = mix(paw(phase + 0.25 + side), vec2(0.06 - 0.12 * float(i), 0.0), stand);
        vec2 bp = mix(paw(phase + side), vec2(-0.06 + 0.12 * float(i), 0.0), stand);
        float d = min(leg(q, shoulder, vec2(0.44, 0.0) + fp, true),
                      leg(q, hip, vec2(-0.42, 0.0) + bp, false));
        if (i == 0) nearLegs = d; else farLegs = d;
    }
    body = smin(body, nearLegs, 0.03);

    // Tail: six segments, a lazy wave while walking, a flick of the tip when
    // stopped. The last stretch is dark; the rest has rings.
    vec2 tp = vec2(-0.68, 0.72);
    float tail = 1e3, ring = 0.0;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float ang = TAIL[i] + mix(0.06, 0.04 + 0.12 * fi, stand) * sin(t * mix(1.6, 3.0, stand) - fi * 0.8);
        vec2 nx = tp + 0.16 * vec2(cos(ang), sin(ang));
        vec2 l = limbH(q, tp, nx, 0.055 - 0.004 * fi, 0.051 - 0.004 * fi);
        if (l.x < tail) {
            tail = l.x;
            float along = fi + l.y;                               // 0..6 from base to tip
            ring = along > 5.2 ? 1.0 : smoothstep(0.55, 0.75, sin(along * 6.0));
        }
        tp = nx;
    }
    float core = body;                                          // everything but the tail
    body = smin(body, tail, 0.02);

    // Stripes: wavy dark bands across the back, wide at the spine and
    // thinning out toward the belly; none on the head and legs below the body.
    float s = sin(q.x * 23.0 + 1.8 * sin(q.y * 8.0 + q.x * 4.0));
    float th = mix(0.97, 0.40, smoothstep(0.44, 0.84, q.y));
    float stripe = smoothstep(th, th + 0.12, s) * step(-0.72, q.x) * step(q.x, 0.64) * step(0.42, q.y);
    stripe = max(stripe, (tail < 0.0 && core > 0.0) ? ring : 0.0);
    // A few marks on the forehead and cheek.
    vec2 hq = q - h;
    float brow = smoothstep(0.75, 0.95, sin(hq.y * 60.0)) * step(0.08, hq.y) * step(abs(hq.x - 0.02 * (1.0 - look)), 0.06);
    float cheek = smoothstep(0.7, 0.95, sin(hq.y * 55.0 + 1.0)) * step(abs(hq.y + 0.05), 0.05)
                * step(0.13, abs(hq.x)) * step(abs(hq.x), 0.22) * look;                          // whisker-side stripes facing us
    stripe = max(stripe, max(brow, cheek));

    // Eyes and nose are dark too.
    float eyes = min(length(q - (h + mix(vec2(0.07, 0.05), vec2(0.075, 0.04), look))) - 0.022,
                     length(q - (h + mix(vec2(0.07, 0.05), vec2(-0.075, 0.04), look))) - 0.022);
    float nose = ellipse(q, h + mix(vec2(0.27, -0.03), vec2(0.0, -0.045), look), vec2(0.04, 0.025));
    stripe = max(stripe, smoothstep(0.01, -0.01, min(min(eyes, nose), mouth)));

    // White: chin and lower muzzle, a belly hint, and round cheek ruffs facing us.
    float white = smoothstep(0.50, 0.44, q.y) * smoothstep(0.02, -0.02, ellipse(q, vec2(0.0, 0.53), vec2(0.42, 0.12)));
    white = max(white, look * smoothstep(0.01, -0.01, min(length(q - (h + vec2(0.07, 0.10))), length(q - (h + vec2(-0.07, 0.10)))) - 0.03));
    white = max(white, smoothstep(0.02, -0.02, jaw));
    white = max(white, smoothstep(0.02, -0.02, ellipse(q, mz + vec2(0.0, -0.03), vec2(0.10, 0.05))));
    white = max(white, look * smoothstep(0.02, -0.02, min(length(q - (h + vec2(0.1, -0.05))), length(q - (h + vec2(-0.1, -0.05)))) - 0.07));
    vec2 fang = vec2(abs(q.x - mc.x) - 0.03 * look - 0.035 * (1.0 - look), q.y - mc.y - 0.025);
    white = max(white, roar * smoothstep(0.012, 0.0, length(fang * vec2(1.6, 0.6)) - 0.015));

    return vec4(body, farLegs, stripe, white);
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

    // One crossing per cycle, alternating direction, with a pause partway
    // where it stops, turns to look at you and roars. The clock is shifted
    // so the tiger is already on screen at start-up.
    float margin = 1.6 * SIZE;                                  // body + tail beyond the edges
    float travel = aspect + 2.0 * margin;
    float v = travel / WALK_TIME;
    float period = WALK_TIME + STOP_TIME + 2.0;                 // 2 s off screen between passes
    float tt = iTime + (margin + 0.3 * aspect) / v;
    float n = floor(tt / period);
    float u = tt - n * period;
    float dir = mod(n, 2.0) < 1.0 ? 1.0 : -1.0;

    float stopAt = (mix(0.50, 0.70, hash1(n * 5.77 + 3.0)) * aspect + margin) / v;
    float go = stopAt + STOP_TIME;
    float walked = min(u, stopAt) + max(u - go, 0.0);
    float stand = smoothstep(stopAt - 0.6, stopAt, u) * (1.0 - smoothstep(go, go + 0.6, u));
    float look  = smoothstep(stopAt + 0.5, stopAt + 1.1, u) * (1.0 - smoothstep(go - 1.0, go - 0.4, u));
    float roar  = smoothstep(stopAt + 1.8, stopAt + 2.4, u) * (1.0 - smoothstep(stopAt + 3.6, stopAt + 4.3, u));

    float x = walked * v - margin;
    if (dir < 0.0) x = aspect - x;

    vec2 q = (p - vec2(x, 0.005)) / SIZE;
    q.x *= dir;                                                 // face the way it walks
    float stride = 2.0 * HALF_STRIDE / 0.6;
    vec4 tg = tiger(q, walked * v / SIZE / stride, stand, look, roar, iTime);

    float px = 1.5 / (iResolution.y * SIZE);
    float nearA = smoothstep(px, -px, tg.x);
    float farA = smoothstep(px, -px, tg.y) * (1.0 - nearA);

    vec3 orange = vec3(1.0, 0.55, 0.15);
    vec3 dark = vec3(0.10, 0.05, 0.02);
    vec3 color = mix(orange, vec3(1.0, 0.95, 0.88), tg.w);
    color = mix(color, dark, tg.z);

    vec3 rgb = blend(base.rgb, orange * 0.6, farA * INTENSITY);  // far legs: dimmer, behind
    rgb = blend(rgb, color, nearA * INTENSITY);
    fragColor = vec4(rgb, base.a);
}
