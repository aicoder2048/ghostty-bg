// seahorse — a few seahorses bob slowly in place, little dorsal fins fluttering.
// zh: 海马
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 4;      // number of seahorses

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Signed distance to a tapered tube from a (radius ra) to b (radius rb).
float tube(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 s = segment(p, a, b);
    return s.x - mix(ra, rb, s.y);
}

// A seahorse seen from the side, facing +x, upright. It is about 1.7 tall:
// the crown is near y = 1.2 and the curled tail near y = -0.4.
// flutter drives the dorsal fin. Returns (shape, dark details).
vec2 seahorse(vec2 q, float flutter, float aa) {
    // Head, tilted nose-down, with a long tube snout and a small crown.
    vec2 h = q - vec2(0.0, 1.0);
    h = mat2(0.955, 0.296, -0.296, 0.955) * h;                    // rotate about -0.3 rad
    float d = length(h / vec2(0.21, 0.15)) * 0.15 - 0.15;
    d = min(d, tube(q, vec2(0.12, 0.97), vec2(0.48, 0.86), 0.055, 0.045));
    d = min(d, length(q - vec2(0.49, 0.86)) - 0.06);              // snout tip
    d = min(d, tube(q, vec2(-0.04, 1.08), vec2(-0.08, 1.22), 0.07, 0.04));

    // Neck bends back, belly swells forward, the back stays fairly straight.
    d = min(d, tube(q, vec2(-0.04, 0.93), vec2(-0.12, 0.72), 0.11, 0.12));
    vec2 b = q - vec2(0.0, 0.50);
    d = min(d, length(b / vec2(0.22, 0.30)) * 0.22 - 0.22);
    d = min(d, tube(q, vec2(-0.12, 0.75), vec2(-0.12, 0.30), 0.11, 0.12));

    // Tail: tapers down, then curls forward under the belly.
    vec2 t[8];
    t[0] = vec2(-0.08, 0.30);  t[1] = vec2(-0.10, 0.02);
    t[2] = vec2(-0.04, -0.22); t[3] = vec2(0.08, -0.36);
    t[4] = vec2(0.22, -0.35);  t[5] = vec2(0.28, -0.23);
    t[6] = vec2(0.21, -0.13);  t[7] = vec2(0.13, -0.18);
    for (int k = 0; k < 7; k++) {
        float r0 = mix(0.13, 0.025, float(k) / 7.0);
        float r1 = mix(0.13, 0.025, float(k + 1) / 7.0);
        d = min(d, tube(q, t[k], t[k + 1], r0, r1));
    }
    float body = smoothstep(aa, -aa, d);

    // Dorsal fin on the back: a little fan whose rays ripple quickly.
    vec2 f = q - vec2(-0.22, 0.47);
    float fin = smoothstep(aa, -aa, length(f / vec2(0.17 + 0.03 * flutter, 0.14)) - 1.0) * step(f.x, 0.0);
    float rays = 0.75 + 0.25 * sin(atan(f.y, f.x) * 7.0 + flutter * 2.0);
    float shape = max(body, fin * rays * 0.9);

    // Dark details: eye, and rings around the trunk and tail.
    float eye = smoothstep(0.045, 0.025, length(q - vec2(0.03, 1.02)));
    float rings = smoothstep(0.55, 0.95, sin(q.y * 40.0)) * step(q.y, 0.85) * body * 0.35;
    return vec2(shape, max(eye, rings));
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
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float ph = fi * 1.9;

        float size = mix(0.065, 0.095, b);
        float dir = a > 0.5 ? 1.0 : -1.0;

        // Hover in place: a slow bob, a little drift and a gentle rock back and forth.
        float x = ((fi + 0.5) / float(COUNT) + 0.08 * (a - 0.5)) * aspect + 0.04 * sin(iTime * 0.13 + ph);
        float y = mix(0.18, 0.50, hash1(fi * 5.17 + 4.0)) + 0.035 * sin(iTime * 0.7 + ph);
        float rock = 0.08 * sin(iTime * 0.5 + ph * 1.3);

        vec2 q = (p - vec2(x, y)) / size;
        q.x *= dir;                                               // face left or right
        q = mat2(cos(rock), sin(rock), -sin(rock), cos(rock)) * q;

        float flutter = sin(iTime * 12.0 + ph);
        float aa = 1.5 / (iResolution.y * size);
        vec2 s = seahorse(q, flutter, aa);

        vec3 color = mix(vec3(1.0, 0.78, 0.35), vec3(1.0, 0.55, 0.65), b);
        rgb = blend(rgb, color, s.x * (1.0 - 0.75 * s.y) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
