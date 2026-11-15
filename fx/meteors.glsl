// meteors — shooting stars streak across the sky every second or two, with a short shower now and then.
// zh: 流星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.95;   // overall brightness (0 = off)
const int   TRACKS    = 5;      // independent meteor "slots" (together: one every ~1.5 s)
const int   SHOWER    = 7;      // meteors in each shower burst
const float SHOWER_EVERY = 15.0;  // seconds between showers

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// One meteor: k runs 0 -> 1 over its flight; size scales width, trail and glow.
float meteor(vec2 p, vec2 start, vec2 dir, float reach, float k, float size) {
    vec2 head = start + dir * reach * k;
    vec2 tail = head - dir * (0.18 + 0.22 * size) * smoothstep(0.0, 0.3, k);   // trail grows fast, then holds
    vec2 s = segment(p, tail, head);
    float w = 0.0025 + 0.0035 * size;
    float core = smoothstep(w, 0.0, s.x) * s.y * s.y;                        // bright toward the head
    float glow = exp(-s.x / (w * 3.0)) * s.y * 0.35;                         // soft glow along the trail
    float halo = 0.00003 * size / (dot(p - head, p - head) + 0.00008);       // glow at the head
    return (core + glow + halo) * sin(3.14159 * k) * (0.6 + 0.6 * size);    // fade in and out
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float light = 0.0;

    // Regular meteors: each slot fires at its own pace. The phase offsets make
    // slot 0 fire right away, so something shows within a second of enabling.
    for (int i = 0; i < TRACKS; i++) {
        float fi = float(i);
        float period = 5.5 + fi * 1.3;
        float flight = 1.0 + 0.5 * hash1(fi * 3.1);
        float t = iTime / period + 0.02 - fi * 0.19;
        float n = floor(t);
        float age = fract(t) * period;
        if (age > flight) continue;

        float seed = n * 7.13 + fi * 31.7;
        vec2 start = vec2(mix(0.45, 1.15, hash1(seed)) * aspect, mix(0.55, 1.05, hash1(seed + 1.0)));
        float ang = mix(-0.25, -1.1, hash1(seed + 2.0));                     // shallow to steep, down-left
        vec2 dir = vec2(-cos(ang), sin(ang));
        float size = max(hash1(seed + 4.0), step(iTime, 2.0) * 0.9);    // the first one is a big one
        light += meteor(p, start, dir, 0.55 + 0.45 * hash1(seed + 3.0), age / flight, size);
    }

    // Shower: every SHOWER_EVERY seconds, a burst fanning out from one radiant
    // off the top-right corner, all within about two seconds.
    float st = mod(iTime - 4.0, SHOWER_EVERY);
    float burst = floor((iTime - 4.0) / SHOWER_EVERY);
    if (st < 3.5) {
        vec2 radiant = vec2(aspect * mix(0.75, 1.0, hash1(burst + 0.5)), 1.15);
        for (int j = 0; j < SHOWER; j++) {
            float fj = float(j);
            float seed = burst * 13.7 + fj * 5.31;
            float age = st - fj * 0.28 - 0.15 * hash1(seed);
            float flight = 0.9 + 0.4 * hash1(seed + 1.0);
            if (age < 0.0 || age > flight) continue;
            vec2 dir = normalize(vec2(-0.3 - 1.2 * hash1(seed + 2.0), -1.0));
            vec2 start = radiant + dir * (0.15 + 0.25 * hash1(seed + 3.0));
            light += meteor(p, start, dir, 0.7, age / flight, 0.4 + 0.6 * hash1(seed + 4.0));
        }
    }

    vec3 color = vec3(0.92, 0.96, 1.0) * min(light, 1.2) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
