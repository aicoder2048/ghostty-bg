// birds — a small flock crosses the sky in a loose V, wings beating.
// zh: 飞鸟
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const int   COUNT     = 9;      // birds in the flock (odd: one leader)
const float SPEED     = 0.045;  // screen-widths per second

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float segmentDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// A bird seen from the side-front: two wings, each bent once (a flat "M").
// q is in bird units (wingspan about 2); flap runs from -1 to 1.
float bird(vec2 q, float flap) {
    float lift = 0.15 + 0.45 * flap;
    vec2 a = vec2(abs(q.x), q.y);                       // mirror: draw one wing
    vec2 elbow = vec2(0.5, lift * 0.9);
    vec2 tip = vec2(1.0, lift * 0.45);
    float d = min(segmentDist(a, vec2(0.0), elbow), segmentDist(a, elbow, tip));
    return smoothstep(0.17, 0.05, d);
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
    vec2 p = vec2(uv.x * aspect, uv.y);

    // The leader flies left to right, then re-enters from the left.
    float travel = aspect + 1.1;
    vec2 leader = vec2(mod(iTime * SPEED * aspect, travel) - 0.1,
                       0.70 + 0.04 * sin(iTime * 0.21));

    float shape = 0.0;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i) - float(COUNT / 2);         // ... -1, 0, 1 ...
        float row = abs(fi);                            // how far behind the leader
        vec2 pos = leader + vec2(-row * 0.080, fi * 0.044)
                 + vec2(sin(iTime * 0.7 + fi), cos(iTime * 0.9 + fi * 1.3)) * 0.006;
        float size = 0.036 - row * 0.0016;
        float flap = sin(iTime * (5.0 + hash1(fi + 10.0)) + fi * 1.9);
        shape = max(shape, bird((p - pos) / size, flap));
    }

    vec3 color = vec3(0.95, 0.96, 1.0);
    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
