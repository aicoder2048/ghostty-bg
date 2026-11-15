// birds — two flocks cross the sky in loose V shapes, beating their wings, then gliding.
// zh: 飞鸟
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.62;   // overall strength (0 = off)
const int   NEAR      = 9;      // birds in the near flock (odd: one leader)
const int   FAR       = 7;      // birds in the far flock

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// A bird seen from behind, flying away: a small body and two wings, each bent
// once (the flat "M" you see in the distance). The wings are thick at the
// shoulder and taper to the tip. q is in bird units (wingspan about 2);
// lift is how high the wings are held, from about -0.3 (down) to 0.6 (up).
float bird(vec2 q, float lift) {
    vec2 a = vec2(abs(q.x), q.y);                          // mirror: draw one wing
    vec2 elbow = vec2(0.48, lift * 0.85);
    vec2 tip = vec2(1.0, lift * 0.30);

    vec2 inner = segment(a, vec2(0.0), elbow);             // shoulder to elbow
    vec2 outer = segment(a, elbow, tip);                   // elbow to tip
    float wing = max(smoothstep(mix(0.20, 0.13, inner.y), 0.04, inner.x),
                     smoothstep(mix(0.13, 0.04, outer.y), 0.01, outer.x));

    float body = smoothstep(0.26, 0.12, length((q - vec2(0.0, -0.05)) * vec2(1.0, 0.75)));
    return max(wing, body);
}

// One flock: `count` birds behind a leader, moving left to right.
float flock(vec2 p, float aspect, int count, float size, float height,
            float speed, float spread, float seed) {
    float travel = aspect + spread * float(count) + 0.4;
    vec2 leader = vec2(mod(iTime * speed * aspect + seed * travel, travel) - 0.1,
                       height + 0.035 * sin(iTime * 0.21 + seed * 6.0));

    float shape = 0.0;
    for (int i = 0; i < 9; i++) {
        if (i >= count) break;
        float fi = float(i) - float(count / 2);            // ... -1, 0, 1 ...
        float row = abs(fi);                               // how far behind the leader
        float id = fi + seed * 20.0;

        vec2 pos = leader + vec2(-row * spread, fi * spread * 0.55)
                 + vec2(sin(iTime * 0.7 + id), cos(iTime * 0.9 + id * 1.3)) * size * 0.25;
        float s = size * (1.0 - row * 0.045) * mix(0.85, 1.1, hash1(id + 4.0));

        // A few beats, then a glide with the wings held out, each bird in its own rhythm.
        float beat = sin(iTime * (5.5 + 1.5 * hash1(id + 10.0)) + id * 1.9);
        float flapping = smoothstep(-0.25, 0.25, sin(iTime * 0.55 + id * 2.7));
        float lift = mix(0.18, 0.15 + 0.45 * beat, flapping);

        shape = max(shape, bird((p - pos) / s, lift));
    }
    return shape;
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

    // The far flock is smaller, higher, slower and fainter: that reads as distance.
    float far  = flock(p, aspect, FAR,  0.019, 0.86, 0.030, 0.045, 0.37);
    float near = flock(p, aspect, NEAR, 0.036, 0.68, 0.045, 0.080, 0.0);

    vec3 color = vec3(0.95, 0.96, 1.0);
    fragColor = vec4(blend(base.rgb, color, max(near, far * 0.6) * INTENSITY), base.a);
}
