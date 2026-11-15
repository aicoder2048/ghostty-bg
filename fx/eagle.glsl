// eagle — a big bald eagle soars across the sky in slow arcs, now and then beating its wings.
// zh: 老鹰
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.42;   // overall strength (0 = off)
const float SPAN      = 0.50;   // wingspan as a fraction of the window width
const float CROSS     = 18.0;   // seconds to cross the window
const float AWAY      = 5.0;    // seconds off screen before it comes back

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

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

// A soaring eagle seen from below, wings spread left-right, head up and turned
// in profile toward +x (the way it flies). q is in eagle units: half the
// wingspan is 1. lift swings the wings up (+) or down (-) around the shoulder.
// Returns: .x dark-ish parts (wings, body), .y white parts (head, tail),
// .z the yellow beak.
vec3 eagle(vec2 q, float lift) {
    vec2 a = vec2(abs(q.x), q.y);                          // mirror: one wing

    // Wing, in its own frame rotated about the shoulder by the beat. A wing
    // raised high is seen edge-on from below, so it also looks shorter.
    vec2 sh = vec2(0.06, 0.04);
    vec2 w = rot(a - sh, -lift) + sh;
    w.x = sh.x + (w.x - sh.x) / mix(1.0, 0.75, abs(lift));

    // Inner wing: a long broad band, leading edge slightly raised toward the
    // wrist, trailing edge bulging where the secondaries are.
    float x = w.x;
    float arch = sin(3.14159 * clamp(x / 0.76, 0.0, 1.0));
    float top = 0.10 + 0.04 * x + 0.03 * arch;
    float bottom = -0.17 + 0.10 * x - 0.04 * arch;
    float inner = max(max(w.y - top, bottom - w.y), x - 0.76);
    inner = smin(inner, ellipse(w, vec2(0.74, 0.01), vec2(0.08, 0.12)), 0.04);   // the hand

    // Primary feathers splayed like fingers at the tip, the eagle's signature.
    float fingers = 1e3;
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        vec2 root = vec2(0.72, 0.10 - 0.04 * fk);
        float ang = 0.32 - 0.13 * fk + 0.25 * lift;
        float len = 0.25 - 0.03 * abs(fk - 2.0);
        fingers = min(fingers, limb(w, root, root + len * vec2(cos(ang), sin(ang)), 0.040, 0.016));
    }
    float wing = smin(inner, fingers, 0.02);

    // Body, white fan tail, white head in profile with a hooked yellow beak.
    float body = ellipse(q, vec2(0.0, 0.02), vec2(0.09, 0.24));
    vec2 t = q - vec2(0.0, -0.16);
    float tail = max(length(t) - 0.28, abs(t.x) - 0.04 + t.y * 0.60);       // fan, rounded end
    tail = max(tail, t.y + 0.03);
    float head = ellipse(q, vec2(0.02, 0.24), vec2(0.085, 0.065));
    vec2 b = q - vec2(0.10, 0.235);
    float beak = max(ellipse(b, vec2(0.0), vec2(0.06, 0.03)), -b.x - 0.01);
    beak = min(beak, length(b - vec2(0.055, -0.022)) - 0.014);              // the hook

    float dark = min(wing, body);
    float white = min(head, tail);
    return vec3(dark, white, beak);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

// Draws one eagle onto rgb. size is half the wingspan in window heights;
// shift offsets its clock; fade scales its strength.
vec3 drawEagle(vec3 rgb, vec2 p, float aspect, float size, float shift, float height, float fade) {
    float period = CROSS + AWAY;
    float t = iTime + shift;
    float n = floor(t / period);
    float u = t - n * period;
    float dir = mod(n, 2.0) < 1.0 ? 1.0 : -1.0;            // alternate direction...
    float y0 = height + (mod(n, 2.0) < 1.0 ? 0.0 : -0.08);  // ...and height

    float travel = aspect + 2.4 * size;
    float x = u / CROSS * travel - 1.2 * size;
    if (dir < 0.0) x = aspect - x;

    // Wide slow arcs: rise and sink, banking into each turn.
    float wave = sin(u * 0.45 + n * 2.0);
    float y = y0 + 0.06 * wave + 0.02 * sin(u * 1.1);
    float bank = 0.14 * cos(u * 0.45 + n * 2.0) * dir;

    // Mostly gliding, wings held a touch above level. Every so often a burst
    // of three slow, deep beats.
    float burst = smoothstep(0.0, 0.3, u - 6.0) * (1.0 - smoothstep(2.0, 2.3, u - 6.0))
                + smoothstep(0.0, 0.3, u - 13.0) * (1.0 - smoothstep(2.0, 2.3, u - 13.0));
    float lift = mix(0.07, 0.07 + 0.38 * sin((u - 6.0) * 6.2832 * 1.0), burst);

    vec2 q = rot((p - vec2(x, y)) / size, -bank);
    q.x *= dir;                                             // head looks the way it flies
    q.x *= 1.0 + 0.12 * sign(q.x) * sin(bank * 3.0) * dir; // the lower wing looks longer

    vec3 d = eagle(q, lift);
    float px = 1.5 / (iResolution.y * size);
    float dark = smoothstep(px, -px, d.x);
    float white = smoothstep(px, -px, d.y);
    float beak = smoothstep(px, -px, d.z);

    rgb = blend(rgb, vec3(0.80, 0.70, 0.58), dark * (1.0 - white) * INTENSITY * fade);
    rgb = blend(rgb, vec3(1.0, 0.98, 0.94), white * INTENSITY * 1.25 * fade);
    rgb = blend(rgb, vec3(1.0, 0.78, 0.25), beak * INTENSITY * 1.5 * fade);
    return rgb;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float size = 0.5 * SPAN * aspect;                       // half the wingspan
    vec3 rgb = base.rgb;
    // A small, faint one far off first, so the big one passes in front of it.
    rgb = drawEagle(rgb, p, aspect, size * 0.22, 11.0, 0.86, 0.45);
    // The big one; its clock starts with it already a third of the way across.
    rgb = drawEagle(rgb, p, aspect, size, CROSS * 0.3, 0.62, 1.0);

    fragColor = vec4(rgb, base.a);
}
