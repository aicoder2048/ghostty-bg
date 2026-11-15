// meteors — now and then a shooting star crosses the sky.
// zh: 流星
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.85;   // overall brightness (0 = off)
const int   TRACKS    = 4;      // independent meteor "slots"
const float FLIGHT    = 0.9;    // seconds a meteor is visible

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float light = 0.0;
    for (int i = 0; i < TRACKS; i++) {
        float fi = float(i);
        float period = 2.6 + fi * 1.9;                 // each slot fires at its own pace
        float t = iTime / period + fi * 0.37;
        float n = floor(t);                            // which meteor of this slot
        float age = fract(t) * period;                 // seconds since it started
        if (age > FLIGHT) continue;

        float k = age / FLIGHT;                        // 0 -> 1 over the flight
        float seed = n * 7.13 + fi * 31.7;
        vec2 start = vec2(mix(0.25, 1.05, hash1(seed)) * aspect, mix(0.55, 1.02, hash1(seed + 1.0)));
        vec2 dir = normalize(vec2(-1.0, -0.45 - 0.35 * hash1(seed + 2.0)));   // down-left
        float reach = 0.45 + 0.35 * hash1(seed + 3.0);

        vec2 head = start + dir * reach * k;
        vec2 tail = head - dir * (0.10 + 0.16 * sin(3.14159 * k));           // tail grows, then shrinks
        vec2 s = segment(p, tail, head);

        float core = smoothstep(0.0045, 0.0, s.x) * s.y * s.y;               // bright toward the head
        float halo = 0.00002 / (dot(p - head, p - head) + 0.00008);          // glow at the head
        light += (core + halo * 0.6) * sin(3.14159 * k);                     // fade in and out
    }

    vec3 color = vec3(0.92, 0.96, 1.0) * min(light, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
