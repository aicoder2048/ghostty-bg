// fireworks — rockets climb on a faint trail and burst into falling, fading sparks.
// zh: 烟花
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.90;   // overall brightness (0 = off)
const int   SHELLS    = 4;      // independent rocket "slots"
const int   SPARKS    = 40;     // sparks per burst
const float RISE      = 1.1;    // seconds a rocket climbs
const float BURST     = 2.3;    // seconds the sparks live

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// A bright, fairly saturated colour from a 0..1 hue.
vec3 hue(float h) {
    return 0.55 + 0.45 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 col = vec3(0.0);
    for (int i = 0; i < SHELLS; i++) {
        float fi = float(i);
        float period = 3.5 + fi * 0.7;                 // staggered, never in lockstep
        float t = iTime / period + fi * 0.29;
        float n = floor(t);                            // which rocket of this slot
        float age = fract(t) * period;                 // seconds since launch
        if (age > RISE + BURST) continue;              // idle gap between rockets

        float seed = n * 13.7 + fi * 57.3;
        // Launch from the bottom, mostly right of centre so the text stays clear.
        vec2 launch = vec2(mix(0.35, 0.95, hash1(seed)) * aspect, -0.02);
        vec2 top = vec2(launch.x + (hash1(seed + 1.0) - 0.5) * 0.12, mix(0.55, 0.82, hash1(seed + 2.0)));
        vec3 tint = hue(hash1(seed + 3.0));
        float size = mix(0.20, 0.30, hash1(seed + 4.0));

        if (age < RISE) {
            // Rocket: slows as it nears the top, with a short dim trail behind.
            float k = age / RISE;
            float kt = max(k - 0.2, 0.0);
            vec2 head = mix(launch, top, 1.0 - (1.0 - k) * (1.0 - k));
            vec2 tail = mix(launch, top, 1.0 - (1.0 - kt) * (1.0 - kt));
            vec2 s = segment(p, tail, head);
            float trail = smoothstep(0.003, 0.0, s.x) * s.y * s.y * 0.45;
            float halo = 0.000015 / (dot(p - head, p - head) + 0.00003);
            col += vec3(1.0, 0.82, 0.55) * (trail + halo * 0.5);
            continue;
        }

        float a = age - RISE;                          // seconds since the burst
        float f = a / BURST;
        float fade = smoothstep(1.0, 0.25, f);
        float drop = 0.05 * a * a;                     // gravity pulls the whole cloud down

        // A quick white flash at the moment of the burst.
        vec2 dc = p - top;
        col += vec3(1.0, 0.95, 0.85) * exp(-a * 14.0) * 0.0004 / (dot(dc, dc) + 0.0008);

        // Skip the spark loop for pixels nowhere near this burst.
        if (length(p - top + vec2(0.0, drop)) > size + 0.04) continue;

        float ap = max(a - 0.2, 0.0);                  // a moment ago, for the streak tail
        float spread = 1.0 - exp(-3.0 * a);            // drag: fast out, then hang
        float spreadPrev = 1.0 - exp(-3.0 * ap);
        float glow = 0.0;
        for (int j = 0; j < SPARKS; j++) {
            float fj = float(j);
            float ang = 6.2831 * (fj + 0.6 * hash1(seed + fj * 7.31)) / float(SPARKS);
            // Project a sphere: random z, so many sparks sit near the rim.
            float z = hash1(seed + fj * 3.17) * 2.0 - 1.0;
            float v = size * sqrt(1.0 - z * z);
            vec2 dir = vec2(cos(ang), sin(ang)) * v;

            vec2 pos  = top + dir * spread     - vec2(0.0, drop);
            vec2 prev = top + dir * spreadPrev - vec2(0.0, 0.05 * ap * ap);
            vec2 s = segment(p, prev, pos);
            float g = smoothstep(0.0038, 0.0, s.x) * s.y;
            vec2 dp = p - pos;
            g += 0.000006 / (dot(dp, dp) + 0.000012);

            // Late in the burst the sparks start to crackle.
            float crackle = mix(1.0, 0.5 + 0.5 * sin(iTime * 31.0 + fj * 5.7), smoothstep(0.4, 0.8, f));
            glow += g * crackle;
        }
        col += mix(vec3(1.0, 0.95, 0.85), tint, smoothstep(0.0, 0.35, a)) * glow * fade;
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
