// crab — a small crab scuttles sideways along the bottom, stops, snaps its claws, goes on.
// zh: 螃蟹
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float SIZE      = 0.048;  // half the shell width, as a fraction of the window height
const float WALK      = 3.5;    // seconds of scuttling ...
const float PAUSE     = 2.5;    // ... then seconds of standing still
const float STRIDE    = 0.40;   // distance covered in one walk (window heights)

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

float limb(vec2 p, vec2 a, vec2 b, float r, float aa) {
    return smoothstep(aa, -aa, segment(p, a, b).x - r);
}

// A crab seen from the front, standing on y = 0. The shell is about 2 wide.
// tick drives the legs, moving (0..1) says how much it is walking, snip (0..1)
// opens the claws. Returns (shape, dark details).
vec2 crab(vec2 q, float tick, float moving, float snip, float aa) {
    float side = q.x > 0.0 ? 1.0 : 0.0;
    vec2 m = vec2(abs(q.x), q.y);                                 // mirror: draw one side
    float bob = 0.05 * moving * abs(sin(tick));
    vec2 mb = m - vec2(0.0, bob);                                 // the body bobs, the feet stay down

    // Three walking legs per side: up to a knee, then down to the ground.
    // The two sides step out of phase, so the legs seem to tick.
    float legs = 0.0;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float ph = tick + fk * 2.1 + side * 1.57;
        float lift = moving * 0.18 * max(0.0, sin(ph));
        vec2 root = vec2(0.55 + 0.17 * fk, 0.42 - 0.06 * fk + bob);
        vec2 knee = vec2(1.15 + 0.22 * fk, 0.70 - 0.05 * fk + bob + 0.5 * lift);
        vec2 foot = vec2(1.40 + 0.26 * fk + 0.10 * moving * cos(ph), lift);
        legs = max(legs, max(limb(m, root, knee, 0.075, aa), limb(m, knee, foot, 0.055, aa)));
    }

    // Shell: a wide oval, a little flatter underneath.
    vec2 s = (mb - vec2(0.0, 0.62)) / vec2(1.0, mb.y > 0.62 ? 0.50 : 0.40);
    float shell = smoothstep(aa, -aa, (length(s) - 1.0) * 0.45);

    // Raised arms with big pincers: a palm with a V cut in the top makes two fingers.
    float arms = max(limb(mb, vec2(0.80, 0.70), vec2(1.28, 0.98), 0.085, aa),
                     limb(mb, vec2(1.28, 0.98), vec2(1.22, 1.30), 0.095, aa));
    vec2 c = mb - vec2(1.18, 1.52);
    float palm = smoothstep(aa, -aa, length(c / vec2(0.28, 0.36)) - 1.0);
    float open = 0.22 + 0.30 * snip;                              // half-angle of the gap
    float gap = step(0.0, c.y) * step(abs(atan(c.x, c.y)), open);
    float claws = max(arms, palm * (1.0 - gap));

    // Eyes on stalks.
    float stalks = limb(mb, vec2(0.26, 0.95), vec2(0.34, 1.22), 0.04, aa);
    float eyes = smoothstep(aa, -aa, length(mb - vec2(0.34, 1.26)) - 0.11);
    float pupils = smoothstep(0.06, 0.035, length(mb - vec2(0.34, 1.27)));

    float shape = max(max(legs, shell), max(claws, max(stalks, eyes)));
    float mouth = smoothstep(0.035, 0.0, abs(length((mb - vec2(0.0, 0.75)) / vec2(1.0, 0.7)) - 0.18))
                * step(mb.y, 0.72) * shell;                          // a little smile
    return vec2(shape, max(pupils, mouth * 0.7));
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

    // Walk, stop, walk ... Each walk eases in and out, so it starts and stops softly.
    float period = WALK + PAUSE;
    float n = floor(iTime / period);
    float f = mod(iTime, period);
    float walked = (n + smoothstep(0.0, WALK, f)) * STRIDE;
    float moving = sin(3.14159 * clamp(f / WALK, 0.0, 1.0));      // 0 when stopped, 1 mid-walk

    // Go back and forth between the two sides of the window.
    float margin = 2.0 * SIZE;
    float span = max(aspect - 2.0 * margin, 0.1);
    float u = mod(walked + 0.3 * span, 2.0 * span);
    float x = margin + (u < span ? u : 2.0 * span - u);

    // Legs tick fast while walking; claws snap now and then while standing.
    float tick = iTime * 14.0;
    float snip = (1.0 - moving) * max(0.0, sin(iTime * 9.0));

    vec2 q = (p - vec2(x, 0.012)) / SIZE;
    float aa = 1.5 / (iResolution.y * SIZE);
    vec2 c = crab(q, tick, moving, snip, aa);

    vec3 color = vec3(1.0, 0.50, 0.35);
    fragColor = vec4(blend(base.rgb, color, c.x * (1.0 - 0.8 * c.y) * INTENSITY), base.a);
}
