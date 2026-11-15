// ants — a line of tiny ants marches along the bottom edge, legs ticking, some carrying crumbs.
// zh: 蚂蚁
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.65;   // overall strength (0 = off)
const float SIZE      = 0.034;  // one ant unit in window heights (an ant is ~2 units long)
const float SPACING   = 3.4;    // ant units from one ant to the next
const float SPEED     = 1.2;    // marching speed in ant units per second

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

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// One leg: up from the body to a knee, then down to the foot. In the tripod
// gait each foot slides back while planted and lifts as it swings forward.
float leg(vec2 q, vec2 hip, float reach, float phase) {
    float s = sin(phase), c = cos(phase);
    vec2 foot = vec2(hip.x + reach + 0.25 * s, max(c, 0.0) * 0.12);
    vec2 knee = vec2(mix(hip.x, foot.x, 0.40), 0.62 + 0.04 * c);
    return min(segment(q, hip, knee), segment(q, knee, foot)) - 0.045;
}

// An ant in profile facing +x, standing on y = 0. Returns the distance to the
// ant in .x and to the crumb it may carry in .y.
vec2 ant(vec2 q, float phase, float twitch, bool crumb) {
    float d = ellipse(rot(q - vec2(-0.70, 0.46), 0.35), vec2(0.0), vec2(0.36, 0.23));  // gaster
    d = min(d, length(q - vec2(-0.27, 0.42)) - 0.065);                                // waist
    d = min(d, ellipse(rot(q - vec2(0.03, 0.45), -0.25), vec2(0.0), vec2(0.24, 0.09)));  // thorax
    d = min(d, length(q - vec2(0.44, 0.54)) - 0.15);                                  // head

    // Elbowed antennae that feel ahead.
    vec2 e = vec2(0.70, 0.86 + 0.06 * twitch);
    d = min(d, min(segment(q, vec2(0.50, 0.64), e),
                   segment(q, e, vec2(0.92, 0.78 - 0.08 * twitch))) - 0.04);

    // Six legs: near and far side in opposite phase (two alternating tripods).
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 hip = vec2(-0.08 + 0.12 * fi, 0.42);
        float reach = -0.50 + 0.45 * fi;
        float alt = mod(fi, 2.0) * 3.14159;
        d = min(d, leg(q, hip, reach, phase + alt));
        d = min(d, leg(q, hip + vec2(0.04, 0.0), reach + 0.06, phase + alt + 3.14159));
    }

    // A crumb held up in the jaws: a lumpy blob above the head.
    float c = 1e3;
    if (crumb) {
        vec2 k = q - vec2(0.72, 0.80);
        float lump = 0.03 * sin(atan(k.y, k.x) * 3.0 + 1.3);
        c = length(k) - 0.24 - lump;
    }
    return vec2(d, c);
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
    vec2 a = p / SIZE;                                       // ant units
    if (a.y < 2.4) {                                         // nothing to draw higher up
        // Repetition instead of a loop over every ant: slide the whole line,
        // then only the ant in this cell and its nearest neighbour can cover
        // this pixel.
        float lx = a.x - iTime * SPEED;
        float cell = floor(lx / SPACING);
        float side = fract(lx / SPACING) < 0.5 ? -1.0 : 1.0;
        float ant_ = 0.0, crumb_ = 0.0;
        for (int k = 0; k < 2; k++) {
            float id = cell + float(k) * side;
            float h = hash1(id * 17.31 + 3.0);
            if (h < 0.15) continue;                          // a gap in the line

            // Each ant drifts a little ahead or behind its slot, and the line
            // rises and dips gently, so it doesn't look stamped.
            float drift = 0.45 * sin(iTime * (0.3 + 0.4 * h) + id * 2.1);
            float ground = 0.35 + 0.18 * sin(id * 0.7) + 0.03 * sin(iTime * 9.0 + id);
            vec2 q = vec2(lx - (id + 0.5) * SPACING - drift, a.y - ground);
            q = rot(q, 0.05 * sin(iTime * 2.0 + id * 1.3));  // slight wobble

            float phase = iTime * SPEED * 6.2 + id * 1.7;    // leg beat matches the speed
            float twitch = sin(iTime * 3.0 + id * 4.0);
            vec2 d = ant(q, phase, twitch, fract(h * 7.0) < 0.3);

            float px = 1.2 / (iResolution.y * SIZE);
            ant_   = max(ant_,   smoothstep(px, -px, d.x));
            crumb_ = max(crumb_, smoothstep(px, -px, d.y));
        }
        rgb = blend(rgb, vec3(0.95, 0.70, 0.45), ant_ * INTENSITY);
        rgb = blend(rgb, vec3(1.0, 0.96, 0.82), crumb_ * INTENSITY * (1.0 - ant_));
    }

    fragColor = vec4(rgb, base.a);
}
