// mushrooms — a cluster of bioluminescent Mycena mushrooms glowing on a mossy forest-floor strip in the lower right, breathing light and shedding tiny spores.
// zh: 发光蘑菇
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SCALE     = 1.00;   // size of the whole cluster (1 = tallest ~20% of window height)
const float BREATH    = 7.5;    // seconds per slow glow "breath" (each mushroom is out of phase)
const float GLOW      = 1.00;   // brightness of the bioluminescence
const float HALO      = 0.22;   // strength of the tight halo around each cap (keep small)
const float SPORE_P   = 7.0;    // seconds a spore takes to drift up and fade out
const float GROUND_A  = 0.88;   // opacity of the moss / leaf-litter strip

const float PI = 3.14159265;
const vec3  EMIT = vec3(0.42, 1.00, 0.74);   // cool green-cyan bioluminescence
const vec3  FLESH = vec3(0.13, 0.17, 0.15);  // translucent cap flesh where it is not glowing

const int NM = 10;   // mushrooms, back to front
// x: distance from the right edge, y: height to cap, z: cap half-width, w: lean (rad, + = right)
const vec4 M[NM] = vec4[](
    vec4(0.330, 0.160, 0.034, -0.16),
    vec4(0.250, 0.190, 0.040,  0.08),
    vec4(0.400, 0.110, 0.027, -0.30),
    vec4(0.175, 0.125, 0.030,  0.22),
    vec4(0.470, 0.070, 0.019, -0.38),
    vec4(0.290, 0.085, 0.022,  0.30),
    vec4(0.115, 0.065, 0.017,  0.34),
    vec4(0.520, 0.040, 0.011, -0.20),
    vec4(0.215, 0.038, 0.010, -0.12),
    vec4(0.075, 0.030, 0.009,  0.15)
);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Smooth value noise (for the moss texture).
float vnoise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Top of the moss strip: low lumps plus fine tufts.
float groundY(float x) {
    return 0.040 * SCALE
         + 0.006 * sin(x * 23.0 + 1.3) + 0.004 * sin(x * 61.0 + 0.4)
         + 0.0025 * pow(abs(sin(x * 210.0)), 3.0);
}

// Slow out-of-phase breathing (0.55..1).
float breath(int i) {
    float f = float(i);
    float ph = hash1(f * 3.7 + 1.0) * 6.2831;
    float sp = 1.0 + 0.35 * hash1(f * 5.1 + 2.0);
    float b = 0.5 + 0.5 * sin(iTime * 2.0 * PI * sp / BREATH + ph);
    return 0.55 + 0.45 * b * b * (3.0 - 2.0 * b);
}

// Geometry of mushroom i: base B, cap centre T, stem bend, cap tilt.
void geom(int i, float aspect, out vec2 B, out vec2 T, out float h, out float w,
          out float lean, out float bend, out float capLean) {
    vec4 m = M[i];
    float bx = aspect - m.x * SCALE;
    h = m.y * SCALE;
    w = m.z * SCALE;
    lean = m.w;
    B = vec2(bx, groundY(bx) - 0.006 * SCALE);
    bend = (hash1(float(i) * 9.3 + 4.0) - 0.5) * 0.5 - 0.25 * lean;
    T = B + rot(vec2(0.0, h), -lean);
    capLean = lean + atan(-bend) * 0.8;
}

// Cap profile, in units of the cap half-width (rim chord at y = 0).
float domeTop(float x, float hc) {
    float a = 1.0 - min(abs(x), 1.0);
    return hc * (0.72 * sqrt(max(1.0 - x * x, 0.0)) + 0.28 * a * a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Everything lives in the lower right: pixels elsewhere cost nothing.
    float x0 = aspect - 0.78 * SCALE;
    if (p.x < x0 - 0.02 || p.y > 0.62 * SCALE) { fragColor = base; return; }

    float px = 1.0 / iResolution.y;
    vec3 rgb = base.rgb;
    float t = iTime;

    // ---------------------------------------------------------- moss strip
    float gy = groundY(p.x);
    // The strip fades out toward its left end so it does not end in a hard wall.
    float fadeL = smoothstep(x0, x0 + 0.20 * SCALE, p.x);
    if (p.y < gy + 0.01 && fadeL > 0.0) {
        // Light pooled on the moss below each glowing cap.
        float light = 0.0;
        for (int i = 0; i < NM; i++) {
            vec2 B, T; float h, w, ln, bd, cl;
            geom(i, aspect, B, T, h, w, ln, bd, cl);
            vec2 d = (p - vec2(T.x * 0.6 + B.x * 0.4, B.y)) / vec2(5.0 * w + 0.03, 2.0 * w + 0.02);
            light += breath(i) * (w / 0.03) * exp(-dot(d, d));
        }
        light = min(light, 1.6) * GLOW;
        float cov = smoothstep(px, -px, p.y - gy) * fadeL;
        // Moss texture: fine speckles of darker and lighter green-brown.
        float n = 0.6 * vnoise(p * 260.0) + 0.4 * vnoise(p * 900.0);
        float depth = clamp((gy - p.y) / 0.04, 0.0, 1.0);   // darker lower down
        vec3 moss = mix(vec3(0.030, 0.045, 0.028), vec3(0.055, 0.075, 0.035), n);
        moss *= 1.0 - 0.55 * depth;
        moss += EMIT * vec3(0.55, 0.80, 0.55) * light * (0.06 + 0.14 * n) * (1.0 - 0.7 * depth);
        rgb = mix(rgb, moss, cov * GROUND_A * INTENSITY);

        // Twigs lying on the moss, with a faint top edge where the glow catches them.
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float tx = aspect - (0.12 + 0.20 * fk + 0.05 * hash1(fk + 7.0)) * SCALE;
            vec2 a = vec2(tx - 0.07 * SCALE, groundY(tx - 0.07 * SCALE) - 0.006);
            vec2 b = vec2(tx + 0.06 * SCALE, groundY(tx + 0.06 * SCALE) - 0.012 + 0.006 * fk);
            float r = (0.0022 + 0.0008 * fk) * SCALE;
            float d = segment(p, a, b) - r;
            float c = smoothstep(px, -px, d) * fadeL;
            float top = smoothstep(-r, 0.0, d) * step(0.0, dot(p - a, vec2(-(b - a).y, (b - a).x)));
            vec3 tw = vec3(0.07, 0.055, 0.045) + EMIT * light * (0.12 + 0.25 * top);
            rgb = mix(rgb, tw, c * 0.92 * INTENSITY);
        }

        // Fallen leaves: pointed ovals with a midrib, many seen almost edge-on.
        for (int k = 0; k < 6; k++) {
            float fk = float(k);
            float h1 = hash1(fk * 4.3 + 11.0), h2 = hash1(fk * 2.9 + 3.0);
            float lx = aspect - (0.04 + 0.125 * fk + 0.04 * h1) * SCALE;
            vec2 c0 = vec2(lx, groundY(lx) - 0.004);
            float L = (0.020 + 0.016 * h2) * SCALE;
            float ang = (h1 - 0.5) * 0.7;
            vec2 q = rot(p - c0, ang) / L;
            q.y /= 0.35 + 0.35 * h2;                         // foreshortened (lying flat)
            if (abs(q.x) > 1.05 || abs(q.y) > 0.6) continue;
            float s = (q.x + 1.0) * 0.5;
            float hw = 0.42 * pow(max(sin(PI * s), 0.0), 0.8) * (1.0 - 0.25 * s);
            float d = (abs(q.y) - hw) * L * (0.35 + 0.35 * h2);
            float cov2 = smoothstep(px, -px, d) * fadeL;
            float rib = smoothstep(1.2 * px, 0.0, abs(q.y) * L * (0.35 + 0.35 * h2)) * step(abs(q.x), 0.9);
            vec3 lc = mix(vec3(0.10, 0.060, 0.035), vec3(0.15, 0.090, 0.045), h1);
            lc *= 0.85 + 0.3 * q.y;                          // lit edge on top side
            lc += vec3(0.04, 0.03, 0.02) * rib;
            lc += EMIT * light * 0.09;
            rgb = mix(rgb, lc, cov2 * 0.95 * INTENSITY);
        }
    }

    // ---------------------------------------------------------- mushrooms
    for (int i = 0; i < NM; i++) {
        vec2 B, T; float h, w, lean, bend, capLean;
        geom(i, aspect, B, T, h, w, lean, bend, capLean);
        // Cheap reject: nowhere near this mushroom or its halo.
        vec2 mid = (B + T) * 0.5 + vec2(0.0, w * 0.5);
        if (abs(p.x - mid.x) > 0.5 * abs(T.x - B.x) + 1.4 * w + 0.01 ||
            abs(p.y - mid.y) > 0.5 * (T.y - B.y) + 2.2 * w + 0.01) continue;

        float br = breath(i) * GLOW;
        float hc = 1.05 + 0.35 * hash1(float(i) * 1.7 + 8.0);   // cap height / half-width
        float e  = 0.13 + 0.08 * hash1(float(i) * 2.3 + 5.0);   // how much underside we see
        float detail = clamp(w * iResolution.y / 30.0 - 0.3, 0.0, 1.0); // fine lines only when big enough
        float pw = px / w;                                        // one pixel in cap units

        // ---- cap (drawn first; the stem passes in front of the gills)
        vec2 c = rot(p - T, capLean) / w;
        float top = domeTop(c.x, hc);
        float ell = sqrt(max(1.0 - c.x * c.x, 0.0));
        float yb = -e * ell;                                      // front rim (silhouette bottom)
        float yk = e * ell;                                       // back rim
        // Slope-corrected edge distances for ~1 px anti-aliasing.
        float sl = abs(domeTop(c.x + 0.01, hc) - domeTop(c.x - 0.01, hc)) * 50.0;
        float dTop = (c.y - top) / sqrt(1.0 + sl * sl);
        float rr = length(vec2(c.x, c.y / e));
        // Ellipse distance divided by its gradient, so the AA stays ~1 px all round.
        float dEll = (rr - 1.0) * rr / max(length(vec2(c.x, c.y / (e * e))), 1e-3);
        float inDome = smoothstep(pw, -pw, max(dTop, abs(c.x) - 1.0)) * step(0.0, c.y);
        float inEll  = smoothstep(pw, -pw, dEll);
        float capCov = max(inDome, inEll);

        // Tight halo around the glowing rim and gills (the brightest parts).
        float dOut = max(length(vec2(max(abs(c.x) - 1.0, 0.0), c.y)) - e * ell, 0.0) * w;
        float halo = HALO * br * exp(-dOut / (0.0035 * SCALE)) * (1.0 - capCov);
        rgb += EMIT * halo * INTENSITY;

        if (capCov > 0.0) {
            vec3 col; float a;
            if (c.y > yk || rr > 1.0) {
                // Outer cap surface: glows most near the rim, dimmer and browner at the apex.
                float v = clamp((c.y - yk) / max(top - yk, 1e-3), 0.0, 1.0);
                float sa = atan(c.x, hc * 1.05 - c.y);            // angle from the apex
                float stri = smoothstep(0.55, 0.95, cos(sa * 18.0)) * detail;  // gills showing through
                float em = mix(1.0, 0.18, pow(v, 0.6)) * (0.80 + 0.45 * stri * (1.0 - v));
                em *= 0.85 + 0.25 * abs(c.x);                     // thicker path at the sides
                vec3 flesh = mix(FLESH, vec3(0.20, 0.17, 0.12), smoothstep(0.6, 1.0, v));
                col = flesh + EMIT * em * br * 0.95;
                a = 0.62 + 0.25 * (1.0 - v);
            } else {
                // Underside: radial gills, luminous, brightest out at the rim.
                float phi = atan(c.y / e, c.x);
                float g = smoothstep(0.2, 0.9, cos(phi * 22.0)) * detail;
                float em = (0.70 + 0.45 * g) * (0.55 + 0.6 * rr);
                em += smoothstep(0.85, 1.0, rr) * 0.5;            // bright rim edge
                col = vec3(0.10, 0.14, 0.12) + EMIT * em * br;
                a = 0.80;
            }
            rgb = mix(rgb, col, capCov * a * INTENSITY);
        }

        // ---- stem: slender, slightly curved, translucent, brighter toward the cap
        vec2 q = rot(p - B, lean);
        float s = q.y / h;
        if (s > -0.02 && s < 1.0) {
            float cx = bend * h * s * (1.0 - s);
            float r = w * mix(0.12, 0.085, s) * (1.0 + 0.5 * exp(-s * 14.0));
            float d = abs(q.x - cx) - r;
            float cov = smoothstep(px, -px, d) * smoothstep(-0.02, 0.01, s);
            // Hide the part of the stem that sits up inside the cap dome.
            cov *= 1.0 - inDome * step(0.0, c.y) * (1.0 - inEll);
            if (cov > 0.0) {
                float across = (q.x - cx) / r;
                float fib = 0.92 + 0.08 * sin(across * 9.0 + s * 3.0);
                float em = (0.12 + 0.55 * s * s) * (0.75 + 0.35 * across * across) * fib;
                vec3 col = vec3(0.14, 0.17, 0.15) * (0.8 + 0.2 * s) + EMIT * em * br;
                rgb = mix(rgb, col, cov * 0.78 * INTENSITY);
            }
        }
    }

    // ---------------------------------------------------------- spores
    // Tiny crisp glowing specks released under the caps of the larger mushrooms,
    // drifting up and sideways on the air.
    for (int j = 0; j < 12; j++) {
        float fj = float(j);
        int k = j - (j / 6) * 6;                              // one of the 6 biggest caps
        float per = SPORE_P * (0.8 + 0.5 * hash1(fj * 1.9 + 3.0));
        float u0 = t / per + hash1(fj * 7.7 + 1.0) + 0.35;
        float cyc = floor(u0);
        float u = u0 - cyc;
        float sd = fj * 3.1 + cyc * 5.3;
        vec2 B, T; float h, w, ln, bd, cl;
        geom(k, aspect, B, T, h, w, ln, bd, cl);
        vec2 start = T + rot(vec2((hash1(sd) - 0.5) * 1.6 * w, -0.1 * w), -cl);
        float side = hash1(sd + 2.0) < 0.6 ? -1.0 : 1.0;      // mostly drift left (away from the edge)
        vec2 pos = start + vec2(side * (0.04 + 0.05 * hash1(sd + 4.0)) * u
                                + 0.008 * sin(u * 9.0 + sd),
                                (0.16 + 0.12 * hash1(sd + 6.0)) * u * (0.6 + 0.4 * u)) * SCALE;
        float a = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.55, 1.0, u));
        float d = length(p - pos);
        float core = smoothstep(1.6 * px, 0.4 * px, d);
        float gl = exp(-d / (2.2 * px)) * 0.35;
        rgb += EMIT * (core * 0.85 + gl) * a * (0.6 + 0.4 * breath(k)) * INTENSITY;
    }

    fragColor = vec4(rgb, base.a);
}
