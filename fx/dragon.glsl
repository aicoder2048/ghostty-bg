// dragon — a long eastern dragon glides across the sky, its serpentine body rippling behind it.
// zh: 龙
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.42;   // overall strength (0 = off)
const int   SEGMENTS  = 18;     // body links from neck to tail tip
const float SPEED     = 0.075;  // screen heights per second
const float BODY      = 0.95;   // body length in screen heights
const float THICK     = 0.022;  // body half-thickness at the chest

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// The flight path, by distance s travelled. Every link of the body follows
// this same curve a little behind the head, so the waves flow from head to
// tail the way a swimming snake moves.
vec2 path(float s, float y0) {
    return vec2(s, y0 + 0.060 * sin(s * 8.5) + 0.030 * sin(s * 3.3 + 1.3));
}

vec2 heading(float s, float y0) {
    return normalize(path(s + 0.01, y0) - path(s - 0.01, y0));
}

// Body thickness along its length (u = 0 at the neck, 1 at the tail tip):
// a slim neck, a full chest, then a long taper.
float radius(float u) {
    return THICK * (0.8 + 0.2 * smoothstep(0.0, 0.12, u)) * mix(1.0, 0.12, pow(u, 1.3));
}

// One leg hanging from the body at distance s; swing paddles it back and forth.
float leg(vec2 p, float s, float y0, float swing) {
    vec2 hip = path(s, y0);
    vec2 f = heading(s, y0);
    vec2 n = vec2(-f.y, f.x);                                  // "up" from the body
    vec2 down = -n * cos(swing) + f * sin(swing);
    vec2 knee = hip + down * THICK * 2.3;
    vec2 foot = knee + (f * 0.8 - n * 0.4) * THICK * 1.4;
    float d = segment(p, hip, knee).x - THICK * 0.38;
    d = min(d, segment(p, knee, foot).x - THICK * 0.26);
    d = min(d, segment(p, foot, foot + (f * 0.9 + n * 0.3) * THICK * 0.8).x - THICK * 0.10);
    d = min(d, segment(p, foot, foot + (f * 0.5 - n * 0.7) * THICK * 0.8).x - THICK * 0.10);
    return d;
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

    // One pass from left to right, a pause, then again at a new height.
    float period = (aspect + BODY + 0.5) / SPEED + 6.0;
    float cyc = floor(iTime / period);
    float sh = mod(iTime, period) * SPEED - 0.2;               // head position along the path
    float y0 = 0.30 + 0.16 * hash1(cyc * 3.7 + 1.0);

    // Outside the dragon's box nothing needs drawing.
    if (p.x < sh - BODY - 0.08 || p.x > sh + 0.12 || abs(p.y - y0) > 0.2) {
        fragColor = base;
        return;
    }

    float px = 1.0 / iResolution.y;

    // Body: a chain of tapered capsules.
    float body = 1e5, bodyU = 0.0, up = 0.0;
    vec2 prev = path(sh, y0);
    for (int k = 1; k <= SEGMENTS; k++) {
        float s = sh - BODY * float(k) / float(SEGMENTS);
        vec2 cur = path(s, y0);
        vec2 sg = segment(p, prev, cur);
        float u = (float(k - 1) + sg.y) / float(SEGMENTS);
        float d = sg.x - radius(u);
        if (d < body) {
            body = d;
            bodyU = u;
            vec2 ba = cur - prev, pa = p - prev;
            up = step(ba.x * pa.y - ba.y * pa.x, 0.0);         // 1 on the back, 0 on the belly
        }
        prev = cur;
    }
    // Saw-tooth fins along the back, swept toward the tail.
    float fin = (1.0 - fract(bodyU * 26.0)) * smoothstep(0.03, 0.08, bodyU) * smoothstep(0.95, 0.75, bodyU);
    float shape = min(body - up * fin * radius(bodyU) * 0.75, 1e5);

    // Tail tuft: three flame-like leaves fanning out from the tip.
    vec2 tip = path(sh - BODY, y0);
    vec2 tf = heading(sh - BODY, y0);
    vec2 tn = vec2(-tf.y, tf.x);
    for (int j = -1; j <= 1; j++) {
        vec2 end = tip - tf * THICK * 2.6 + tn * float(j) * THICK * 1.1;
        vec2 sg = segment(p, tip, end);
        shape = min(shape, sg.x - THICK * 0.35 * (1.0 - sg.y));
    }

    // Four short legs: the front pair reaches forward as the hind pair pushes back.
    float sw = 0.5 * sin(iTime * 1.6);
    shape = min(shape, leg(p, sh - BODY * 0.16, y0, 0.3 + sw));
    shape = min(shape, leg(p, sh - BODY * 0.20, y0, -0.1 - sw));
    shape = min(shape, leg(p, sh - BODY * 0.55, y0, -0.2 + sw));
    shape = min(shape, leg(p, sh - BODY * 0.59, y0, -0.5 - sw));

    // Head, drawn in its own frame: x forward, y up, in head units.
    vec2 f = heading(sh, y0);
    vec2 n = vec2(-f.y, f.x);
    float hs = THICK * 1.6;
    vec2 hp = path(sh, y0) + f * hs * 0.5;
    vec2 q = vec2(dot(p - hp, f), dot(p - hp, n)) / hs;
    float eye = 0.0;
    if (dot(q, q) < 30.0) {
        float h = length((q - vec2(0.0, 0.1)) / vec2(1.0, 0.8)) - 1.0;      // skull
        h = min(h, segment(q, vec2(0.3, 0.1), vec2(1.7, 0.05)).x - 0.34);   // upper jaw / snout
        h = min(h, segment(q, vec2(0.2, -0.35), vec2(1.4, -0.6)).x - 0.15); // open lower jaw
        vec2 hn = segment(q, vec2(-0.2, 0.6), vec2(-1.7, 1.4));             // antler horn
        h = min(h, hn.x - mix(0.16, 0.05, hn.y));
        hn = segment(q, vec2(-0.9, 0.95), vec2(-1.0, 1.65));                // its branch
        h = min(h, hn.x - mix(0.10, 0.04, hn.y));
        // Mane: a few spikes swept back from the jaw.
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            vec2 sg = segment(q, vec2(-0.3, -0.2 + fj * 0.3), vec2(-1.5 - fj * 0.2, -0.7 + fj * 0.35));
            h = min(h, sg.x - 0.16 * (1.0 - sg.y));
        }
        // Two long whiskers flowing back from the snout, waving slowly.
        float back = clamp(1.7 - q.x, 0.0, 5.0);
        float wave = 0.35 * sin(back * 1.3 - iTime * 2.0) * back / 5.0;
        float w1 = abs(q.y - (-0.05 - 0.18 * back + wave)) - 0.06;
        float w2 = abs(q.y - (0.15 + 0.10 * back - wave)) - 0.06;
        float wmask = step(q.x, 1.7) * step(-3.3, q.x);
        h = min(h, mix(1e5, min(w1, w2), wmask));
        shape = min(shape, h * hs);
        eye = smoothstep(0.17, 0.08, length(q - vec2(0.35, 0.42)));
    }

    // Translucent fill, a bit fuller on the belly, with a crisp outline.
    float inside = smoothstep(px * 1.2, -px * 0.6, shape);
    float rim = smoothstep(px * 2.2, 0.0, abs(shape + px * 0.8));
    float a = inside * mix(0.50, 0.32, up) + rim * 0.6 + eye * 0.8;

    vec3 color = vec3(1.0, 0.82, 0.48);
    fragColor = vec4(blend(base.rgb, color, a * INTENSITY), base.a);
}
