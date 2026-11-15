// sparklers — a sparkler traces slow loops, spitting short bright sparks and leaving a brief trail.
// zh: 仙女棒
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.85;   // overall brightness (0 = off)
const int   SPARKS    = 32;     // sparks in flight at once
const int   TRAIL     = 18;     // segments in the lingering trail
const float TRAIL_SEC = 1.1;    // how long the trail lingers

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Where the burning tip is at time t: a big slow circle plus a small fast one
// gives a looping, hand-drawn path. Kept in the lower right, away from text.
vec2 tipAt(float t, float aspect) {
    vec2 centre = vec2(0.72 * aspect, 0.36);
    return centre + 0.14 * vec2(cos(t * 0.55), sin(t * 0.55) * 0.8)
                  + 0.06 * vec2(cos(t * 1.9), sin(t * 1.9));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 tip = tipAt(iTime, aspect);
    vec3 col = vec3(0.0);

    // Everything happens within reach of the path; skip far-away pixels.
    if (length(p - vec2(0.72 * aspect, 0.30)) > 0.52) {
        fragColor = base;
        return;
    }

    // The wire stick, glowing faintly where it has already burnt.
    vec2 s = segment(p, tip, tip + vec2(0.03, -0.20));
    col += vec3(0.55, 0.35, 0.25) * smoothstep(0.0025, 0.0, s.x) * mix(0.7, 0.15, s.y);

    // The trail: the tip's recent path, fading with age.
    vec2 prev = tip;
    for (int i = 1; i <= TRAIL; i++) {
        float k = float(i) / float(TRAIL);
        vec2 q = tipAt(iTime - k * TRAIL_SEC, aspect);
        vec2 d = segment(p, prev, q);
        col += vec3(1.0, 0.75, 0.40) * smoothstep(0.0045, 0.0, d.x) * (1.0 - k) * 0.8;
        prev = q;
    }

    // Sparks: each one is born at the tip, flies out fast, slows and dies quickly.
    for (int i = 0; i < SPARKS; i++) {
        float fi = float(i);
        float life = mix(0.25, 0.45, hash1(fi * 3.1));
        float t = iTime / life + hash1(fi * 7.7);
        float n = floor(t);
        float k = fract(t);                                       // 0 -> 1 over its life
        float seed = n * 17.3 + fi * 5.1;

        vec2 origin = tipAt(iTime - k * life, aspect);            // where the tip was at birth
        float ang = 6.2831 * hash1(seed);
        float reach = mix(0.04, 0.13, hash1(seed + 1.0));
        vec2 dir = vec2(cos(ang), sin(ang)) * reach;
        float out1 = 1.0 - (1.0 - k) * (1.0 - k);
        float out0 = 1.0 - (1.0 - k * 0.6) * (1.0 - k * 0.6);
        vec2 head = origin + dir * out1 - vec2(0.0, 0.02 * k * k);
        vec2 tail = origin + dir * out0;
        vec2 d = segment(p, tail, head);
        float bright = (1.0 - k) * smoothstep(0.0032, 0.0, d.x) * (0.3 + 0.7 * d.y);
        col += mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.65, 0.25), k) * bright;
    }

    // The burning tip: a hot white core with a warm halo.
    vec2 dt = p - tip;
    col += vec3(1.0, 0.92, 0.75) * 0.00012 / (dot(dt, dt) + 0.00010);
    col += vec3(1.0, 0.6, 0.25) * 0.0012 / (dot(dt, dt) + 0.006) * 0.4;

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
