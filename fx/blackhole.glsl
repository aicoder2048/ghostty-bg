// blackhole — a black hole in the lower-right corner: dark centre, hot spinning disc, photon ring, infalling sparks.
// zh: 黑洞
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.85;   // overall brightness (0 = off)
const float HOLE      = 0.062;  // radius of the dark shadow, in screen heights (disc is ~4.6x this)
const float TILT      = -0.18;  // disc tilt (radians)
const float FLAT      = 0.24;   // how edge-on the disc is (1 = face-on)
const int   SPARKS    = 14;     // glowing bits spiralling in

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Bright, swirling gas at radius r and angle a (disc-plane coordinates).
// Inner gas turns faster, like a real orbit, so the streaks wind into spirals.
float swirl(float r, float a) {
    float spin = a + iTime * 1.6 / (r * sqrt(r));
    return 0.50 + 0.30 * sin(spin * 3.0 + log(r) * 9.0)
                + 0.20 * sin(spin * 7.0 - log(r) * 15.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Lower-right corner, away from the prompt. Everything is drawn in hole units
    // (shadow radius 1); the terminal image itself is never bent.
    vec2 q = rot(p - vec2(aspect - 0.34, 0.28), -TILT) / HOLE;   // fixed: no drift
    float r = length(q);
    float px = 1.5 / (iResolution.y * HOLE);
    float outside = smoothstep(1.0 - px, 1.0 + px, r);      // nothing shows inside the shadow
    float front = step(q.y, 0.0);                            // near half crosses in front of the shadow

    // The disc seen almost edge-on: a flattened annulus, hotter toward the inside.
    vec2 e = vec2(q.x, q.y / FLAT);
    float er = length(e);
    float ring = smoothstep(1.45, 1.8, er) * smoothstep(4.8, 2.2, er);
    float beaming = 0.50 + 0.50 * clamp(-q.x / 3.0, -1.0, 1.0);    // the side coming toward us is brighter
    float disc = ring * swirl(er, atan(e.y, e.x)) * beaming * 2.6;
    disc *= mix(outside, 1.0, front);

    // The far side of the disc, seen arching over (and faintly under) the shadow.
    float arcR = smoothstep(1.12, 1.40, r) * smoothstep(2.7, 1.6, r);
    float over = smoothstep(-0.2, 0.9, q.y / max(r, 0.001));
    float arc = arcR * mix(0.15, 1.0, over) * swirl(r * 1.6, atan(q.y, q.x)) * 1.7;

    // Photon ring hugging the shadow, with a little shimmer running round it.
    float photon = exp(-pow((r - 1.06) / 0.05, 2.0)) * (0.85 + 0.15 * sin(atan(q.y, q.x) * 4.0 - iTime * 3.0));

    float heat = clamp(1.0 - (min(er, r * 1.6) - 1.6) / 3.0, 0.0, 1.0);
    vec3 hot = mix(vec3(1.0, 0.40, 0.10), vec3(1.0, 0.95, 0.85), heat * heat);

    vec3 color = hot * (disc + arc * (1.0 - front * ring))
               + vec3(1.0, 0.85, 0.60) * photon * outside
               + vec3(1.0, 0.50, 0.20) * 0.10 * smoothstep(6.0, 1.3, r) * outside;   // warm haze around it

    // Sparks: each spirals inward along the disc, speeding up, and winks out at the horizon.
    for (int i = 0; i < SPARKS; i++) {
        float fi = float(i);
        float life = 2.5 + 2.0 * hash1(fi * 1.7);
        float t = iTime / life + hash1(fi * 3.3);
        float k = fract(t);                                   // 0 = far out, 1 = swallowed
        float seed = floor(t) * 9.1 + fi;
        float sr = mix(5.5, 1.0, k * k);                      // falls in faster and faster
        float sa = hash1(seed) * 6.28318 + k * k * 9.0;       // winds round as it falls
        vec2 se = vec2(cos(sa), sin(sa)) * sr;                // position in the disc plane
        vec2 sq = vec2(se.x, se.y * FLAT);                    // ... and on screen
        float behind = step(0.0, sq.y);                       // on the far side: the shadow covers it
        float d = length(q - sq);
        float fade = smoothstep(0.0, 0.15, k) * smoothstep(1.0, 0.85, k);
        color += vec3(1.0, 0.85, 0.55) * fade * mix(1.0, outside, behind)
               * (smoothstep(0.12, 0.03, d) + 0.006 / (d * d + 0.012)) * 0.6;
    }

    color = min(color, vec3(1.2)) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
