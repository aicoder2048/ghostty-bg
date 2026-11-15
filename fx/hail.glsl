// hail — small ice pellets pelting down and bouncing off the bottom edge.
// zh: 冰雹
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.65;   // overall brightness (0 = off)
const int   COUNT     = 32;     // pellets in the air at once (about)
const float GRAVITY   = 3.0;    // window heights per second squared
const float GROUND    = 0.02;   // where they land (scene y)

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Fall: from above the top, thrown down fast, then gravity. Solve once for
    // when it lands and how fast it is going then (the same for every pellet).
    float y0 = 1.05, v0 = 0.8;
    float tFall = (-v0 + sqrt(v0 * v0 + 2.0 * GRAVITY * (y0 - GROUND))) / GRAVITY;
    float vHit = v0 + GRAVITY * tFall;

    vec3 ice = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float period = 1.3 + 0.6 * hash1(fi * 5.1);
        float lt = iTime / period + hash1(fi * 2.3);  // random phase: some are mid-air at t = 0
        float cycle = floor(lt);
        float t = fract(lt) * period;                // seconds into this pellet's life
        float seed = fi * 13.0 + cycle * 7.7;

        float size = 0.006 + 0.005 * hash1(seed + 1.0);
        float x = aspect * hash1(seed + 2.0);
        float drift = 0.10;                          // slight wind to the right while falling
        vec2 pos;
        float stretch = 1.0;                         // motion blur while falling fast
        float splash = 0.0;

        if (t < tFall) {
            pos = vec2(x + drift * t, y0 - v0 * t - 0.5 * GRAVITY * t * t);
            stretch = 1.0 + 2.0 * (v0 + GRAVITY * t) / vHit;
        } else {
            // Two bounces, each smaller, kicked sideways a little (left or right).
            float kick = (hash1(seed + 3.0) - 0.5) * 0.5;
            float v1 = vHit * (0.22 + 0.10 * hash1(seed + 4.0));
            float v2 = v1 * 0.4;
            float d1 = 2.0 * v1 / GRAVITY, d2 = 2.0 * v2 / GRAVITY;
            float tb = t - tFall;
            float xHit = x + drift * tFall;
            if (tb < d1) {
                pos = vec2(xHit + kick * tb, GROUND + v1 * tb - 0.5 * GRAVITY * tb * tb);
            } else if (tb < d1 + d2) {
                float s = tb - d1;
                pos = vec2(xHit + kick * tb, GROUND + v2 * s - 0.5 * GRAVITY * s * s);
            } else {
                // Comes to rest and melts away quickly.
                pos = vec2(xHit + kick * (d1 + d2), GROUND);
                size *= max(1.0 - (tb - d1 - d2) * 4.0, 0.0);
            }
            // A short bright tick on the ground right at impact.
            float age = tb;
            vec2 sq = p - vec2(xHit, GROUND - 0.004);
            splash = exp(-age * 18.0) * smoothstep(0.004, 0.0, abs(sq.y))
                   * smoothstep(0.035, 0.0, abs(sq.x));
        }

        if (size < 0.0005 && splash < 0.001) continue;   // melted away
        size = max(size, 0.0005);
        vec2 q = p - pos;
        q.y /= stretch;
        float d = length(q);
        float pellet = smoothstep(size, size * 0.4, d) + 0.25 * smoothstep(size * 2.5, 0.0, d);
        ice += vec3(0.85, 0.93, 1.0) * pellet + vec3(0.7, 0.85, 1.0) * splash * 0.8;
    }

    fragColor = vec4(base.rgb + min(ice, vec3(1.0)) * INTENSITY, base.a);
}
