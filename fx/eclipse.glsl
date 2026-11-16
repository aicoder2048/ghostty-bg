// eclipse — a total solar eclipse in the upper right: the moon slides over the sun, Baily's beads and the diamond ring flash, then the pearly corona, pink prominences and a few stars appear.
// zh: 日食
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float RADIUS    = 0.075;  // sun radius, in window heights (disk = 15% of the height)
const vec2  POS       = vec2(0.30, 0.27); // sun centre: distance from the right edge / top edge, window heights
const float CYCLE     = 25.0;   // seconds for one full eclipse
const float START     = 3.0;    // seconds into the cycle at switch-on (already partly covered)
const float SUN       = 0.80;   // brightness of the uncovered sun (kept below glare)
const float CORONA    = 0.90;   // corona brightness during totality
const float PROM      = 0.95;   // prominence brightness
const float STARS     = 0.85;   // stars that come out during totality
const float DIMSKY    = 0.25;   // how much the sky around the sun darkens in totality
const float MOONK     = 1.035;  // moon / sun apparent size (just above 1, so totality is real)

const float PI = 3.14159265;

// Timeline inside one cycle (seconds).
const float T_C2 = 6.0;         // crescent has shrunk to a sliver
const float T_TA = 7.4;         // beads are gone: totality starts
const float T_TB = 17.6;        // totality ends
const float T_C3 = 19.0;        // beads gone again, the crescent is growing

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float wrapA(float a) { return mod(a + PI, 2.0 * PI) - PI; }

// Lunar limb radius (sun radii) in direction cs: mountains and a few deep
// valleys. Sunlight shining through the valleys is what makes Baily's beads.
float moonRadius(vec2 cs) {
    float ripple = vnoise(cs * 9.0 + 3.0) - 0.5;
    float valley = smoothstep(0.55, 0.95, vnoise(cs * 15.0 + 11.0));
    return MOONK + 0.003 * ripple - 0.011 * valley * valley;
}

// Screen-blend light onto the picture: bright light never clips harshly.
vec3 screen(vec3 a, vec3 l) { return 1.0 - (1.0 - a) * (1.0 - clamp(l, 0.0, 1.0)); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec3 rgb = base.rgb;

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once to get y-up scene coords.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 C = vec2(aspect - POS.x, 1.0 - POS.y);
    vec2 q = (p - C) / RADIUS;                       // sun radii, sun at the origin
    float r = length(q);
    if (r > 7.0 || INTENSITY <= 0.0) { fragColor = base; return; }
    float px = 1.0 / (iResolution.y * RADIUS);       // one pixel, in sun radii

    // ---------------------------------------------------------- timeline
    float tt = iTime + START;
    float u = mod(tt, CYCLE);
    float cyc = floor(tt / CYCLE);
    float gap = MOONK - 1.0;
    // e = depth of sunlight left at the limb (sun radii); < 0 means totality.
    // s = moon offset along its path (sun radii).
    float e, s;
    if (u < T_C2) {
        float k = u / T_C2;
        e = 0.012 + 0.95 * pow(1.0 - k, 1.6);      // fast at first, slowing to the sliver
        s = gap + e;
    } else if (u < T_TA) {
        e = mix(0.012, -0.012, smoothstep(T_C2, T_TA, u));
        s = gap + e;
    } else if (u < T_TB) {
        e = -0.012;
        s = mix(gap - 0.012, -(gap - 0.012), (u - T_TA) / (T_TB - T_TA));
    } else if (u < T_C3) {
        e = mix(-0.012, 0.012, smoothstep(T_TB, T_C3, u));
        s = -(gap + e);
    } else {
        float k = (u - T_C3) / (CYCLE - T_C3);
        e = 0.012 + 0.95 * pow(k, 1.6);
        s = -(gap + e);
    }
    float fade = smoothstep(0.0, 1.5, u) * smoothstep(CYCLE, CYCLE - 1.5, u) * INTENSITY;
    vec2 dir = normalize(vec2(0.88, 0.47));          // the moon travels toward -dir
    vec2 mc = dir * s;                               // moon centre

    float cv = smoothstep(0.10, 0.0, e);             // corona shows once the sun is a sliver
    float totality = smoothstep(T_TA - 0.6, T_TA + 1.2, u) * smoothstep(T_TB + 0.6, T_TB - 1.2, u);

    // ---------------------------------------------------------- moon geometry
    vec2 qm = q - mc;
    float rmp = length(qm);
    float moonR = moonRadius(qm / max(rmp, 1e-4));
    float moonIn = smoothstep(moonR + px, moonR - px, rmp);   // 1 inside the moon

    // ---------------------------------------------------------- sky darkens
    rgb *= 1.0 - DIMSKY * cv * fade * exp(-r * r / 12.0);

    // ---------------------------------------------------------- corona
    float th = atan(q.y, q.x);
    vec2 cs = vec2(cos(th), sin(th));
    if (r > 0.98 && cv > 0.0) {
        float eqA = (hash1(cyc * 3.7 + 1.0) - 0.5) * 0.7;      // tilt of the solar equator
        float sd = cyc * 17.0;
        // Fine radial rays: noise of angle only, so every feature is a straight ray.
        float f1 = vnoise(cs * 24.0 + sd);
        float f2 = vnoise(cs * 60.0 + sd + 40.0);
        float rays = mix(f1, f2, 0.45);
        float m = 0.50 + 1.0 * rays * rays;
        // Helmet streamers: broad near the equator, tapering to points outward.
        float a = th - eqA;
        float pole = abs(sin(a));
        float lobes = vnoise(cs * 2.2 + sd + 80.0);
        float env = exp(-pow(pole * r / (0.40 + 0.45 * lobes), 2.0));
        float ir = 1.0 / r;
        float inner = pow(ir, 9.0);
        float outer = pow(ir, 2.0) * (0.05 + 1.0 * env * (0.25 + 0.95 * lobes)) * m;
        outer *= smoothstep(5.5, 1.8, r);
        // Polar plumes: short, fine straight rays near the poles.
        float plume = pow(ir, 5.0) * pow(f2, 2.5) * smoothstep(0.55, 0.95, pole) * 0.9;
        float I = (0.85 * inner * (0.75 + 0.5 * rays) + 0.95 * outer + plume) * CORONA;
        I *= smoothstep(0.98, 1.0, r);
        vec3 tint = mix(vec3(1.0, 0.97, 0.92), vec3(0.84, 0.90, 1.0), smoothstep(1.1, 2.6, r));
        rgb = screen(rgb, tint * I * cv * fade);
    }

    // ---------------------------------------------------------- moon disk
    // Nearly black once the corona is up; only a faint shadow while the sun glares.
    rgb = mix(rgb, vec3(0.006, 0.006, 0.010), moonIn * mix(0.45, 0.96, cv) * fade);

    // ---------------------------------------------------------- prominences + chromosphere
    float h = r - 1.0;
    if (h > -0.02 && h < 0.25 && cv > 0.0) {
        float pk = 0.0;
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float sd = cyc * 11.0 + fi * 5.3;
            float ang = 2.0 * PI * (fi + 0.2 + 0.6 * hash1(sd)) / 4.0;
            float w = mix(0.06, 0.13, hash1(sd + 1.0));     // angular half-width
            float ht = mix(0.10, 0.18, hash1(sd + 2.0));    // height, sun radii
            float d = wrapA(th - ang) / w;
            if (abs(d) > 1.0) continue;
            float k;
            if (hash1(sd + 3.0) < 0.5) {
                // Hedgerow / plume: ragged top, fine vertical filaments.
                float fil = vnoise(vec2(th * 140.0, h * 6.0) + sd);
                float top = ht * (1.0 - d * d) * (0.6 + 0.6 * fil);
                k = smoothstep(top + px, top - px, h);
            } else {
                // Arch: a thin loop of glowing gas anchored at both ends.
                float arc = ht * sqrt(max(1.0 - d * d, 0.0));
                float thick = 0.020 * (1.0 + 0.6 * abs(d));
                k = smoothstep(thick + px, thick - px, abs(h - arc));
            }
            pk = max(pk, k * smoothstep(-0.02, 0.0, h));
        }
        // Chromosphere: a thin pink skin right on the limb.
        float chrom = smoothstep(-px, 0.0, h) * smoothstep(0.018 + px, 0.018 - px, h);
        float lit = max(pk, chrom * 0.9) * (1.0 - moonIn);
        vec3 pink = mix(vec3(1.0, 0.45, 0.55), vec3(0.95, 0.22, 0.35), smoothstep(0.0, 0.08, h));
        rgb = screen(rgb, pink * lit * PROM * cv * fade);
    }

    // ---------------------------------------------------------- photosphere
    float sunIn = smoothstep(1.0 + px, 1.0 - px, r) * (1.0 - moonIn);
    if (sunIn > 0.0) {
        float mu = sqrt(max(1.0 - r * r, 0.0));
        // Limb darkening: hot white centre, warmer and dimmer toward the edge.
        vec3 sc = mix(vec3(1.0, 0.62, 0.32), vec3(1.0, 0.95, 0.84), pow(mu, 0.5));
        sc *= 0.55 + 0.45 * mu;
        rgb = screen(rgb, sc * SUN * 1.15 * sunIn * fade);
    }

    // ---------------------------------------------------------- Baily's beads + diamond ring
    float thin = smoothstep(0.05, 0.008, e) * smoothstep(-0.014, -0.004, e);
    if (thin > 0.0 && abs(r - 1.0) < 0.6) {
        // How far the sun's limb at this angle peeks past the lunar limb.
        vec2 L = cs - mc;
        float gl = length(L) - moonRadius(L / length(L));
        float bead = smoothstep(0.0, 0.006, gl);
        float limb = exp(-abs(r - 1.0) / max(0.02, 2.0 * px));
        rgb = screen(rgb, vec3(1.0, 0.96, 0.88) * bead * limb * thin * fade);

        // The diamond: one tight starburst where the last (or first) light is.
        vec2 P = (u < CYCLE * 0.5) ? -dir : dir;
        vec2 d = q - P * 1.01;
        float dl = length(d);
        float ring = smoothstep(0.03, 0.006, e) * smoothstep(-0.012, -0.002, e);
        vec2 dr = vec2(d.x + d.y, d.x - d.y) * 0.7071;        // 45-degree axes
        float spikes = exp(-abs(d.x) / (1.5 * px)) * exp(-abs(d.y) / 0.45)
                     + exp(-abs(d.y) / (1.5 * px)) * exp(-abs(d.x) / 0.45)
                     + 0.5 * (exp(-abs(dr.x) / (1.5 * px)) * exp(-abs(dr.y) / 0.25)
                            + exp(-abs(dr.y) / (1.5 * px)) * exp(-abs(dr.x) / 0.25));
        float core = exp(-dl * dl / 0.004) + 0.5 * exp(-dl / 0.16);
        rgb = screen(rgb, vec3(1.0, 0.97, 0.92) * (core + 0.3 * spikes) * ring * fade);
    }

    // ---------------------------------------------------------- stars
    float sv = smoothstep(T_TA - 0.5, T_TA + 2.5, u) * smoothstep(T_TB + 0.5, T_TB - 1.5, u);
    if (sv > 0.0) {
        float st = 0.0;
        for (int i = 0; i < 7; i++) {
            float fi = float(i);
            float ang = fi * 2.39996 + 0.7;
            float rad = 2.6 + 3.6 * hash1(fi * 7.1 + 2.0);
            vec2 sp = rad * vec2(cos(ang), sin(ang) * 0.75);
            float mag = (i == 0) ? 1.0 : mix(0.35, 0.8, hash1(fi * 3.3));
            if (i == 0) sp = vec2(-4.4, -1.6);                  // one bright planet
            float d = length(q - sp) / px;                       // in pixels
            st += mag * (smoothstep(1.6, 0.5, d) + 0.25 * exp(-d / 1.8));
        }
        rgb = screen(rgb, vec3(0.92, 0.95, 1.0) * st * STARS * sv * fade * (1.0 - moonIn));
    }

    fragColor = vec4(rgb, base.a);
}
