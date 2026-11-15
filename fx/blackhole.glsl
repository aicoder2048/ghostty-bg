// blackhole — a small black hole in the lower-right corner: dark centre, swirling glowing disc, photon ring.
// zh: 黑洞
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.65;   // overall brightness (0 = off)
const float HOLE      = 0.050;  // radius of the dark shadow, in screen heights
const float TILT      = -0.20;  // disc tilt (radians)

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Bright, swirling gas at radius r and angle a (disc-plane coordinates).
// Inner gas turns faster, like a real orbit, so the streaks wind into spirals.
float swirl(float r, float a) {
    float spin = a + iTime * 0.9 / (r * sqrt(r));
    float streaks = 0.55 + 0.25 * sin(spin * 3.0 + log(r) * 9.0)
                         + 0.20 * sin(spin * 7.0 - log(r) * 15.0);
    return streaks;
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
    vec2 q = rot(p - vec2(aspect - 0.28, 0.26), -TILT) / HOLE;
    float r = length(q);
    float px = 1.5 / (iResolution.y * HOLE);
    float outside = smoothstep(1.0 - px, 1.0 + px, r);      // nothing shows inside the shadow

    // The disc seen almost edge-on: a flattened annulus.
    vec2 e = vec2(q.x, q.y / 0.22);
    float er = length(e);
    float ring = smoothstep(1.5, 1.9, er) * smoothstep(4.6, 2.4, er);
    float disc = ring * swirl(er, atan(e.y, e.x));
    float beaming = 0.55 + 0.45 * clamp(-q.x / 3.0, -1.0, 1.0);  // the side coming toward us is brighter
    disc *= beaming * 1.8;
    float front = step(q.y, 0.0);                            // the near half crosses in front of the shadow
    disc *= mix(outside, 1.0, front);

    // The far side of the disc, seen arching over (and faintly under) the shadow.
    float arcR = smoothstep(1.15, 1.45, r) * smoothstep(2.6, 1.6, r);
    float over = smoothstep(-0.2, 0.9, q.y / max(r, 0.001));
    float arc = arcR * mix(0.12, 1.0, over) * swirl(r * 1.6, atan(q.y, q.x)) * 1.2;

    // Thin photon ring hugging the shadow.
    float photon = exp(-pow((r - 1.06) / 0.04, 2.0)) * 0.55;

    float heat = clamp(1.0 - (min(er, r * 1.6) - 1.6) / 3.0, 0.0, 1.0);   // hotter inside
    vec3 hot = mix(vec3(1.0, 0.45, 0.15), vec3(1.0, 0.92, 0.75), heat);

    vec3 color = hot * (disc + arc * (1.0 - front * ring)) + vec3(1.0, 0.80, 0.55) * photon * outside
               + vec3(1.0, 0.55, 0.25) * 0.06 * smoothstep(5.0, 1.2, r) * outside;   // faint glow around it
    color = min(color, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
