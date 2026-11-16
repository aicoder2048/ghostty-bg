// portal — a tall oval vortex of violet and cyan light on the right, with a crackling rim and a distant nebula inside.
// zh: 传送门
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float HEIGHT    = 0.38;   // portal height as a fraction of the window height
const float WIDTH     = 0.58;   // width / height of the oval (it stands upright)
const vec2  CENTER    = vec2(-0.30, 0.40); // x measured from the right edge, y from the bottom (screen heights)
const float SPIN      = 0.55;   // swirl speed (radians per second)
const float OPACITY   = 0.55;   // peak strength of the swirl bands; edges fade well below this
const float FLARE_EVERY = 15.0; // seconds between brief bright flares
const int   MOTES     = 14;     // particles drawn into the vortex

const float PI  = 3.14159265;
const float TAU = 6.2831853;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

// Smooth value noise, cheap enough to call a handful of times per pixel.
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    // Opening: a ring of light grows out of a point over the first ~2 s.
    float open = smoothstep(0.0, 2.2, t);
    open = 1.0 - pow(1.0 - open, 3.0);                   // ease-out
    float birth = exp(-max(t - 0.6, 0.0) * 1.3) * smoothstep(0.0, 0.4, t); // extra glow while it opens

    // Slow breathing plus a brief flare every FLARE_EVERY seconds (first one at ~6 s).
    float ph = mod(t - 6.0 + FLARE_EVERY, FLARE_EVERY);
    float flare = smoothstep(0.0, 0.35, ph) * exp(-ph * 1.4);
    float pulse = 1.0 + 0.08 * sin(t * 1.6) + 0.6 * flare + 0.8 * birth;

    // Oval space: x == 1 on the rim.
    vec2 c = vec2(aspect + CENTER.x, CENTER.y);
    float ry = 0.5 * HEIGHT * mix(0.06, 1.0, open);
    vec2 R = vec2(ry * WIDTH, ry);
    vec2 q = (p - c) / R;
    float x = length(q);

    vec3 violet = vec3(0.62, 0.42, 1.00);
    vec3 cyan   = vec3(0.38, 0.86, 1.00);
    vec3 pale   = vec3(0.90, 0.92, 1.00);

    // Soft light spilling onto the surroundings (also the only cost far away).
    float spill = 0.10 / (1.0 + pow(max(x - 1.0, 0.0) * 1.6, 2.0)) * smoothstep(5.0, 1.0, x);
    vec3 glow = mix(violet, cyan, 0.35) * spill * pulse;
    float dim = 0.0;                                     // how much to deepen the backdrop inside

    if (x < 2.8) {
        float a = atan(q.y, q.x);
        float lx = log(max(x, 0.02));

        // Twisted coordinates: rotating with a log twist reads as light spiralling inward.
        vec2 tw = rot(t * SPIN + 2.6 * lx) * q;
        float n1 = noise(tw * 2.6 + vec2(0.0, -t * 0.4));
        float n2 = noise(rot(t * SPIN * 1.7 + 4.0 * lx) * q * 6.0 + 3.7);
        float turb = n1 * 0.65 + n2 * 0.35;

        // Inside the oval: spiral bands, fine streaks, turbulence.
        float inside = smoothstep(1.04, 0.92, x);
        float bands = 0.5 + 0.5 * sin(3.0 * a + 6.0 * lx - t * 2.0 + turb * 3.0);
        bands = pow(bands, 2.5);
        float streaks = 0.5 + 0.5 * sin(23.0 * a + 14.0 * lx - t * 4.5 + n2 * 4.0);
        streaks = pow(streaks, 6.0) * smoothstep(0.2, 0.7, x);
        float swirl = (bands * (0.45 + 0.75 * turb) + streaks * 0.35) * smoothstep(0.08, 0.55, x);
        vec3 swirlCol = mix(cyan, violet, smoothstep(0.35, 0.95, x) + 0.3 * (n1 - 0.5));
        glow += swirlCol * swirl * inside * OPACITY * pulse;

        // Deep core: a dim far-away nebula with a scatter of stars, slowly turning.
        float core = smoothstep(0.75, 0.0, x);
        vec2 cq = rot(t * 0.05) * q;
        float neb = noise(cq * 2.0 + 11.0) * 0.6 + noise(cq * 4.5 - 5.0) * 0.4;
        vec3 nebCol = mix(vec3(0.10, 0.12, 0.35), vec3(0.55, 0.20, 0.55), neb);
        nebCol = mix(nebCol, vec3(0.20, 0.55, 0.70), smoothstep(0.55, 0.85, neb) * 0.5);
        glow += nebCol * core * 0.55;
        vec2 sg = cq * 9.0;
        vec2 cell = floor(sg);
        float sh = hash2(cell);
        vec2 sp = cell + 0.2 + 0.6 * vec2(hash2(cell + 7.1), hash2(cell + 3.3));
        float star = step(0.72, sh) * 0.006 / (dot(sg - sp, sg - sp) * 1.0 + 0.006);
        star *= 0.6 + 0.4 * sin(t * (1.0 + 2.0 * sh) + sh * 30.0);
        glow += pale * star * core * 0.6;
        glow += cyan * exp(-x * x * 18.0) * 0.35 * pulse;  // luminous heart
        dim = core * 0.35 * open;

        // The rim: a thin bright band wobbling with the turbulence, with a soft halo.
        float rd = x - 1.0 - 0.035 * (n1 - 0.5);
        float rim = exp(-rd * rd * 600.0);
        float halo = 0.006 / (rd * rd + 0.006);
        float run = 0.75 + 0.25 * sin(5.0 * a - t * 3.0);
        glow += mix(violet, pale, rim) * (rim * 0.6 * run + halo * 0.28) * pulse;

        // Crackling arcs: short jagged filaments flickering just outside the rim.
        float sector = floor((a + PI) / TAU * 9.0);
        float ct = t * 3.0 + hash1(sector) * 5.0;
        float cell_t = floor(ct);
        float on = step(0.55, hash1(sector * 13.0 + cell_t)) * sin(PI * fract(ct));
        vec2 ang = vec2(cos(a), sin(a));
        float jag = noise(ang * 7.0 + cell_t * 1.7) - 0.5 + 0.5 * (noise(ang * 19.0 + cell_t * 3.1) - 0.5);
        float ad = abs(x - 1.06 - 0.10 * jag);
        float arc = 0.00012 / (ad * ad + 0.00012) * on * smoothstep(1.0, 1.04, x);
        glow += mix(cyan, pale, 0.5) * arc * 0.5 * (1.0 + flare);

        // Motes: particles spiralling inward along the oval, fading as they cross the rim.
        for (int i = 0; i < MOTES; i++) {
            float fi = float(i);
            float life = fract(t * (0.14 + 0.08 * hash1(fi * 3.3)) + hash1(fi * 7.7));
            float r = mix(2.5, 0.85, life * life);
            float an = hash1(fi * 5.1) * TAU + life * 3.2;   // counter-clockwise, matching the swirl
            vec2 mq = r * vec2(cos(an), sin(an));
            vec2 md = (q - mq) * R;                          // back to round screen units
            float br = smoothstep(0.0, 0.25, life) * smoothstep(1.0, 0.8, life);
            glow += mix(pale, cyan, hash1(fi)) * (0.000012 / (dot(md, md) + 0.000008)) * br * 0.8 * open;
        }
    }

    // Edge semi-transparency comes from the soft falloffs; clamp so highlights stay tasteful.
    glow *= INTENSITY;
    vec3 col = base.rgb * (1.0 - dim * INTENSITY) + min(glow, vec3(1.0));
    fragColor = vec4(col, base.a);
}
