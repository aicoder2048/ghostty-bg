// supernova — on the right, a red supergiant swells and flickers, collapses, explodes in a flash and a racing filamentary shock shell, leaves a glowing nebula with a sweeping pulsar, then a new star forms.
// zh: 超新星
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.95;   // overall strength (0 = off)
const float SIZE      = 0.050;  // red supergiant radius at rest, in window heights
const float SHELL     = 0.190;  // final radius of the remnant shell, in window heights
const vec2  POS       = vec2(0.42, 0.40); // centre: distance from the right edge / bottom edge, window heights
const float CYCLE     = 14.0;   // seconds per life cycle of the star
const float START     = 1.5;    // seconds into the cycle at switch-on (explosion ~4 s later)
const float STARS     = 0.60;   // background starfield brightness
const float FLASH     = 1.0;    // strength of the explosion flash

const float PI = 3.14159265;

// Timeline inside one cycle (seconds).
const float T_COL = 4.8;        // the core gives way: the star starts to collapse
const float T_EX  = 5.6;        // core bounce: the explosion
const float T_FADE = 11.0;      // the remnant starts to fade
const float T_END  = 13.2;      // remnant gone
const float T_BORN = 12.0;      // a new star starts to light up in the old place

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Ridged noise: 1 on the noise's mid-level line, so pow() of it gives thin filaments.
float ridge(vec2 p) { return 1.0 - abs(2.0 * vnoise(p) - 1.0); }

float wrapA(float a) { return mod(a + PI, 2.0 * PI) - PI; }

vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Screen-blend light onto the picture after a soft tone map: never clips to a flat blob.
vec3 screenTM(vec3 a, vec3 L) { return 1.0 - (1.0 - a) * exp(-max(L, 0.0)); }

// Gas colours as seen in real remnant photos: oxygen teal, hydrogen red, sulphur gold.
vec3 gasColour(float e) {
    vec3 teal = vec3(0.30, 0.85, 0.80);
    vec3 red  = vec3(0.95, 0.30, 0.28);
    vec3 gold = vec3(1.00, 0.72, 0.36);
    vec3 c = mix(teal, red, smoothstep(0.30, 0.48, e));
    return mix(c, gold, smoothstep(0.58, 0.74, e));
}

// Background stars: one star at most per grid cell, crisp 1-2 px points.
vec3 starfield(vec2 p, vec2 uv, float px) {
    const float S = 0.045;
    vec2 id = floor(p / S);
    float h = hash21(id + 3.1);
    if (h > 0.42) return vec3(0.0);
    vec2 sp = (id + 0.2 + 0.6 * vec2(hash21(id + 7.7), hash21(id + 1.3))) * S;
    float d = length(p - sp) / px;                       // in pixels
    float mag = pow(hash21(id + 9.2), 3.0);
    float rad = 0.7 + 0.9 * mag;
    float tw = 0.85 + 0.15 * sin(iTime * (1.0 + 2.5 * h) + h * 40.0);
    float I = (0.25 + 0.95 * mag) * (smoothstep(rad + 0.6, rad - 0.6, d) + 0.25 * exp(-d / 1.3)) * tw;
    float tmp = hash21(id + 4.4);
    vec3 c = mix(vec3(1.0, 0.82, 0.62), vec3(0.78, 0.86, 1.0), tmp);
    // Keep the top-left text block clear.
    float clear = smoothstep(0.28, 0.62, length((uv - vec2(0.0, 0.0)) * vec2(1.0, 1.3)));
    return c * I * clear;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec3 rgb = base.rgb;
    if (INTENSITY <= 0.0) { fragColor = base; return; }

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once to get y-up scene coords.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;

    float tt = iTime + START;
    float t = mod(tt, CYCLE);
    float cyc = floor(tt / CYCLE);
    float seed = cyc * 17.3;

    vec2 C = vec2(aspect - POS.x, POS.y);
    vec2 q = p - C;
    float r = length(q);

    // Stars sit behind everything; the star disk below hides the ones behind it.
    vec3 L = starfield(p, uv, px) * STARS;

    // Everything else lives within this radius: early-out keeps the rest cheap.
    if (r > SHELL * 1.35) {
        fragColor = vec4(screenTM(rgb, L * INTENSITY), base.a);
        return;
    }
    float th = atan(q.y, q.x);
    vec2 cs = q / max(r, 1e-5);

    // ------------------------------------------------------------ the star
    // Radius, temperature (0 red .. 1 white-blue) and brightness through the cycle.
    float Rs = 0.0, temp = 0.0, sb = 0.0;
    float swell = smoothstep(0.0, T_COL, t);
    float ramp = smoothstep(0.0, 1.5, t);
    float Rgiant = SIZE * (1.0 + 0.20 * swell + 0.035 * ramp * sin(2.0 * PI * t / 1.7));
    if (t < T_COL) {
        Rs = Rgiant;
        // Flicker grows as the star becomes unstable.
        sb = 1.0 + (0.05 + 0.15 * swell * swell) * sin(t * 7.3) * sin(t * 3.1 + 1.0);
    } else if (t < T_EX) {
        float k = (t - T_COL) / (T_EX - T_COL);
        float kk = k * k * k;                            // slow start, then plunges
        float R1 = SIZE * (1.0 + 0.20 + 0.035 * sin(2.0 * PI * T_COL / 1.7));
        Rs = mix(R1, 0.008, kk);
        temp = smoothstep(0.1, 0.9, k);
        sb = 1.0 + 1.6 * kk;
    } else if (t > T_BORN) {
        float k = smoothstep(T_BORN, CYCLE, t);
        Rs = SIZE * k;                                   // ends exactly where the cycle begins
        sb = k;
    }

    vec3 col = vec3(0.0);
    float disk = 0.0;
    if (Rs > 0.0) {
        float rr = r / Rs;
        disk = smoothstep(1.0 + px / Rs, 1.0 - px / Rs, rr);
        if (disk > 0.0) {
            float mu = sqrt(max(1.0 - rr * rr, 0.0));
            // Huge convection cells (a red supergiant has only a few), foreshortened at the limb.
            vec2 sq = (q / Rs) / (0.45 + 0.55 * mu);
            float g = 0.7 * vnoise(sq * 2.6 + vec2(t * 0.12, -t * 0.09) + seed)
                    + 0.3 * vnoise(sq * 6.0 - vec2(t * 0.2, t * 0.15) + seed);
            vec3 cHot  = mix(vec3(1.00, 0.66, 0.34), vec3(0.95, 0.97, 1.00), temp);
            vec3 cMid  = mix(vec3(0.98, 0.36, 0.12), vec3(0.85, 0.90, 1.00), temp);
            vec3 cLimb = mix(vec3(0.55, 0.08, 0.03), vec3(0.70, 0.78, 1.00), temp);
            vec3 sc = mix(cLimb, cMid, smoothstep(0.0, 0.55, mu));
            sc = mix(sc, cHot, smoothstep(0.5, 1.0, mu) * (0.4 + 0.6 * g));
            sc *= (0.35 + 0.65 * mu) * (0.78 + 0.45 * g);
            col += sc * 1.9 * sb * disk;
        }
        // Thin glowing atmosphere just past the limb (tight: real, not haze).
        float h = max(r - Rs, 0.0) / Rs;
        vec3 atm = mix(vec3(1.0, 0.35, 0.12), vec3(0.8, 0.88, 1.0), temp);
        col += atm * 0.45 * sb * exp(-h / 0.10) * (1.0 - disk);
    }

    // ------------------------------------------------------------ explosion + remnant
    float a = t - T_EX;                                  // seconds since the explosion
    if (a > 0.0 && t < T_END) {
        float fade = 1.0 - smoothstep(T_FADE, T_END, t);
        float Rsh = max(SHELL * (1.0 - exp(-a / 1.25)) + 0.003 * a, 0.004);
        float s = r / Rsh;                               // shell-normalised radius
        float pxs = px / Rsh;
        float hot = exp(-a / 0.9);                       // young ejecta glow white-hot

        // Shock shell: ragged outline, limb-brightened like a real thin spherical shell.
        float rim = 1.0 + 0.07 * (vnoise(cs * 4.0 + seed) - 0.5)
                        + 0.035 * (vnoise(cs * 11.0 + seed + 5.0) - 0.5);
        float hh = 0.14;                                 // shell thickness
        float colm = (sqrt(max(rim * rim - s * s, 0.0)) - sqrt(max((rim - hh) * (rim - hh) - s * s, 0.0)))
                   / sqrt(2.0 * hh * rim);
        colm *= smoothstep(rim + pxs, rim - pxs, s);

        // Filaments expand with the shell (homologous), so the pattern grows, not slides.
        vec2 nq = q / Rsh;
        // Domain warp breaks the noise grid so filaments wander like real gas.
        vec2 wq = vec2(vnoise(nq * 2.5 + seed + 13.0), vnoise(nq * 2.5 + seed + 31.0)) - 0.5;
        // Stretch along the radius: ejecta filaments tend to point outward.
        vec2 aq = vec2(dot(nq, cs), dot(nq, vec2(-cs.y, cs.x)) * 1.8);
        float f1 = pow(ridge(nq * 5.0 + wq * 1.6 + seed + 2.0), 9.0);
        float f2 = pow(ridge(mat2(0.8, -0.6, 0.6, 0.8) * aq * 7.0 + wq * 3.0 + seed + 9.0), 11.0);
        float fil = f1 * 0.95 + f2 * 0.4;
        // Rayleigh-Taylor fingers: thin radial streaks reaching in from the shell.
        float fing = pow(ridge(cs * 9.0 + seed + 21.0), 18.0) * smoothstep(0.45, 0.9, s) * smoothstep(rim, rim - 0.08, s);

        float e = vnoise(nq * 2.2 + seed + 40.0);
        vec3 gas = mix(gasColour(e), vec3(1.0, 0.95, 0.88), hot);
        float shellI = smoothstep(0.0, 0.15, a) * (0.80 + 0.8 * hot) * fade;
        // Big bright clumps and dimmer gaps around the ring, as in Cassiopeia A.
        float clump = 0.35 + 1.1 * smoothstep(0.3, 0.75, vnoise(cs * 3.5 + seed + 17.0));
        col += gas * (colm * (0.12 + 1.9 * fil) * (0.35 + 0.65 * colm) * clump + 0.55 * fing) * shellI;

        // Forward shock: a fine pale-blue line just ahead of the ejecta.
        float fs = rim * 1.035;
        col += vec3(0.62, 0.78, 1.0) * smoothstep(1.4 * pxs, 0.0, abs(s - fs)) * (0.14 + 0.8 * hot) * fade
             * (0.6 + 0.4 * vnoise(cs * 20.0 + seed));

        // Clumpy knots and fast debris streaks flung out ahead of the shell.
        if (r < Rsh * 1.25 + 0.01) {
            float kn = 0.0;
            vec3 kc = vec3(0.0);
            for (int i = 0; i < 18; i++) {
                float fi = float(i);
                float sd = seed + fi * 7.13;
                float ang = 2.0 * PI * (fi + 0.8 * hash1(sd)) / 18.0;
                vec2 dir = vec2(cos(ang), sin(ang));
                // Quick reject: pixel far off this knot's ray.
                if (abs(dot(q, vec2(-dir.y, dir.x))) > 0.012) continue;
                bool streak = i < 6;
                float v = streak ? mix(1.05, 1.18, hash1(sd + 1.0)) : mix(0.72, 1.04, hash1(sd + 1.0));
                vec2 head = dir * Rsh * v;
                float tail = streak ? (0.09 * exp(-a / 1.4) + 0.01) : (0.05 * exp(-a / 1.6) + 0.008);
                vec2 sg = segment(q, head - dir * tail, head);
                float w = streak ? 0.0014 : mix(0.0030, 0.0055, hash1(sd + 2.0)) * (0.5 + 0.5 * sg.y);
                float k = smoothstep(w + px, w - px, sg.x) * (0.25 + 0.75 * sg.y * sg.y);
                k *= streak ? exp(-a / 1.6) : 1.0;
                kn += k;
                kc += k * gasColour(hash1(sd + 3.0));
            }
            vec3 kcol = kn > 0.0 ? kc / kn : vec3(0.0);
            col += mix(kcol, vec3(1.0, 0.95, 0.88), hot) * min(kn, 1.5) * 1.1 * shellI;
        }

        // Explosion flash: a tight white core with thin diffraction spikes, tone-mapped below.
        float fl = smoothstep(0.0, 0.05, a) * exp(-a / 0.55) * FLASH;
        if (fl > 0.002) {
            float core = exp(-r * r / (0.016 * 0.016)) * 2.5 + exp(-r / 0.030) * 0.6;
            float spk = exp(-abs(q.y) / (1.2 * px)) * exp(-abs(q.x) / 0.11)
                      + exp(-abs(q.x) / (1.2 * px)) * exp(-abs(q.y) / 0.11);
            col += vec3(0.95, 0.97, 1.0) * (core + 0.8 * spk) * fl;
        }

        // Pulsar: the neutron star left behind, its beams sweeping like a lighthouse.
        float pv = smoothstep(2.6, 4.0, a) * (1.0 - smoothstep(T_FADE + 0.3, T_BORN + 0.4, t));
        if (pv > 0.0) {
            float phi = a * 1.5 + seed;
            float dA = abs(wrapA(2.0 * (th - phi))) * 0.5;    // angle to the nearest of the two beams
            float bw = 0.045;
            float beam = smoothstep(bw + px / max(r, 1e-4), bw - px / max(r, 1e-4), dA)
                       * (1.0 - dA / bw) * exp(-r / 0.10) * smoothstep(0.0, 0.006, r);
            // Beams light up the filaments they cross.
            beam *= 0.6 + 1.2 * fil;
            float blink = pow(abs(cos(phi - 0.6)), 40.0);  // brightest as a beam sweeps past us
            float dot_ = smoothstep(1.8, 0.6, r / px) + 0.5 * exp(-r / 0.004);
            float pwn = 0.10 * exp(-r / 0.03);             // faint synchrotron haze of the inner nebula
            col += vec3(0.68, 0.78, 1.0) * (0.9 * beam + (0.6 + 1.4 * blink) * dot_ + pwn) * pv;
        }
    }

    // ------------------------------------------------------------ new star forming
    float sv = smoothstep(T_FADE + 0.2, T_FADE + 1.0, t) * (1.0 - smoothstep(CYCLE - 1.0, CYCLE - 0.1, t));
    if (sv > 0.0) {
        // A dark-red cloud of leftover gas contracts and slowly swirls onto the new star.
        float k = clamp((t - T_FADE) / (CYCLE - T_FADE), 0.0, 1.0);
        float rOut = mix(0.13, 0.05, k * k);
        float sw = 1.2 * k;                              // slow swirl
        vec2 cq = mat2(cos(sw), -sin(sw), sin(sw), cos(sw)) * (q / rOut);
        vec2 wq = vec2(vnoise(cq * 2.5 + seed + 51.0), vnoise(cq * 2.5 + seed + 77.0)) - 0.5;
        float cl = pow(ridge(cq * 4.5 + wq * 1.5 + seed + 60.0), 10.0);
        float m = smoothstep(1.0, 0.45, r / rOut) * smoothstep(max(Rs, 0.004), max(Rs, 0.004) * 1.5, r);
        col += vec3(0.90, 0.42, 0.22) * (0.10 + 0.9 * cl) * m * 0.6 * sv;
    }

    // The star disk is opaque: dim what is behind it, then add its light.
    rgb *= 1.0 - 0.85 * disk * INTENSITY;
    L *= 1.0 - disk;
    fragColor = vec4(screenTM(rgb, (L + col) * INTENSITY), base.a);
}
