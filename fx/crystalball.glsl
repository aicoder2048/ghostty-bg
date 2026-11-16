// crystalball — a clear crystal ball on an ornate bronze claw stand in the lower right; violet-blue mist churns inside and now and then parts to reveal tiny sparks.
// zh: 水晶球
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.95;   // overall strength (0 = off)
const float SIZE      = 0.115;  // glass sphere radius, in window heights
const float RIGHT     = 0.24;   // sphere centre distance from the right edge (window heights)
const float GROUND    = 0.035;  // where the stand's foot rests, above the bottom edge
const float MIST      = 1.0;    // brightness of the swirling mist inside the glass
const float SWIRL     = 0.22;   // how fast the mist churns round
const float PARTING   = 13.0;   // seconds between the moments the mist parts
const float POOL      = 0.55;   // coloured light the ball throws on its stand and the table
const int   SPARKS    = 7;      // tiny sparkling points inside the mist

const float PI  = 3.14159265;
const float E   = 0.16;    // we look from slightly above: horizontal circles squash to this
const float SB  = -1.60;   // foot bottom, in sphere radii from the sphere centre
const float RIM = -0.64;   // height of the cup rim that holds the ball
const float LIP = 0.03;    // rolled lip on top of the rim
const mat2  M2  = mat2(0.80, 0.60, -0.60, 0.80);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p, int oct) {
    float s = 0.0, a = 0.5, n = 0.0;
    for (int i = 0; i < 4; i++) {
        if (i >= oct) break;
        s += a * vnoise(p); n += a;
        p = M2 * p * 2.03 + 1.7;
        a *= 0.5;
    }
    return s / n;
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Radius of the turned (lathe) bronze stand at height y, in sphere radii:
// rolled foot, bead band, ogee, a knop, a short neck, then a fluted cup.
float prof(float y) {
    float h = y - SB;
    if (h < 0.13) return 0.74 + 0.08 * sin(PI * clamp(h / 0.13, 0.0, 1.0));
    if (h < 0.18) return 0.74 - 0.08 * smoothstep(0.13, 0.18, h);
    if (h < 0.22) return 0.66 + 0.018 * sin(PI * (h - 0.18) / 0.04);
    if (h < 0.38) return 0.66 - 0.44 * smoothstep(0.22, 0.38, h);
    if (h < 0.48) return 0.22 + 0.08 * sin(PI * (h - 0.38) / 0.10);
    if (h < 0.57) return 0.22 + 0.025 * smoothstep(0.48, 0.57, h);
    if (y < RIM)  return sqrt(1.12 - y * y);
    return sqrt(1.12 - RIM * RIM) + 0.03 * sin(PI * clamp((y - RIM) / LIP, 0.0, 1.0));
}

// Polished dark bronze lit by one warm key light (top left), a dim room, and
// the violet glow of the ball from above (`up`).
vec3 bronze(vec3 n, float up) {
    vec3 L = normalize(vec3(-0.55, 0.65, 0.52));
    vec3 alb = vec3(0.36, 0.23, 0.11);
    float dif = max(dot(n, L), 0.0);
    vec3 Rv = vec3(0.0, 0.0, -1.0) + 2.0 * n.z * n;      // reflected view ray
    float rl = max(dot(Rv, L), 0.0);
    vec3 col = alb * (0.07 + 0.80 * dif) + alb * (0.5 + 0.5 * Rv.y) * 0.22;
    col += vec3(1.0, 0.80, 0.52) * (pow(rl, 40.0) * 1.15 + pow(rl, 6.0) * 0.16);
    col += vec3(0.48, 0.36, 1.0) * up * (0.6 * max(n.y, 0.0) + 0.5 * max(Rv.y, 0.0) * max(Rv.y, 0.0));
    return col;
}

// A window reflected in the glass: a patch between two arcs and two radial
// lines (that is how a flat rectangle bends on a sphere), with a mullion.
// Returns coverage of the glass panes.
float window(vec2 s, float phc, float r0, float r1, float halfA, float px) {
    float rr = length(s);
    float ph = atan(s.y, s.x);
    float dph = mod(ph - phc + PI, 2.0 * PI) - PI;
    float rc = 0.5 * (r0 + r1);
    vec2 lw = vec2(dph * rr, rr - rc);
    vec2 hb = vec2(halfA * rc, 0.5 * (r1 - r0));
    vec2 dq = abs(lw) - hb + 0.03;
    float dw = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0) - 0.03;
    float bar = abs(lw.x) - 0.009;               // one upright mullion: two panes
    return smoothstep(px, -px, max(dw, -bar));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float R = SIZE;
    vec2 C = vec2(aspect - RIGHT, GROUND - SB * R);
    vec2 s = (p - C) / R;                     // sphere units, centre at 0
    // Cheap reject: everything lives in this box (ball, stand, light pool).
    if (abs(s.x) > 1.9 || s.y > 1.05 || s.y < SB - 0.45) {
        fragColor = base;
        return;
    }
    float px = 1.0 / (iResolution.y * R);
    float t = iTime;
    vec3 rgb = base.rgb;

    float glow = 0.85 + 0.15 * sin(t * 0.6);
    // Mist parts once per PARTING seconds (closed at t = 0, first opens ~6 s in).
    float part = smoothstep(0.55, 0.95, 0.5 - 0.5 * cos(2.0 * PI * t / PARTING));
    vec3 VIO = vec3(0.50, 0.32, 0.96);

    // ---- table: tight coloured light pool and a contact shadow under the foot.
    {
        float k = length(vec2(s.x / 1.55, (s.y - SB - 0.02) / 0.26));
        float pool = max(1.0 - k, 0.0);
        rgb += VIO * POOL * glow * pool * pool * (1.0 + 0.3 * part);
        float ks = length(vec2(s.x / 0.98, (s.y - SB + 0.01) / 0.08));
        rgb *= 1.0 - 0.6 * smoothstep(1.0, 0.55, ks);
    }

    // ---- two rear claws, seen beside the ball (it hides their inner half).
    {
        vec2 sm = vec2(abs(s.x), s.y);
        float rho = length(sm);
        float ph = atan(sm.y, sm.x);
        float tc = (ph + 0.66) / 0.50;                       // 0 at the rim, 1 at the tip
        if (tc > -0.15 && tc < 1.0) {
            float te = clamp(tc, 0.0, 1.0);
            float rc = mix(1.08, 0.99, smoothstep(0.0, 1.0, te));
            float w = 0.085 * pow(1.0 - te, 0.8) + 0.006;
            w *= 1.0 + 0.18 * exp(-pow((te - 0.42) / 0.09, 2.0));   // knuckle
            float d = abs(rho - rc) - w;
            float cov = smoothstep(px, -px, d) * smoothstep(1.0, 0.96, tc);
            if (cov > 0.0) {
                float u = clamp((rho - rc) / w, -1.0, 1.0);
                vec2 rd = sm / rho;
                vec3 n = normalize(vec3(rd.x * u * sign(s.x), rd.y * u, 0.75 * sqrt(1.0 - u * u)));
                vec3 c = bronze(n, POOL * glow * 0.5) * 0.85;
                rgb = mix(rgb, c, cov);
            }
        }
    }

    // ---- dark inside of the cup (only a sliver shows beside the ball), and the
    //      back half of the rim lip.
    float yl = RIM + LIP;
    float rOut = prof(yl - 0.0001) + 0.03, rIn = rOut - 0.08;
    {
        float dI = (length(vec2(s.x / rIn, (s.y - yl) / (E * rIn))) - 1.0) * E * rIn;
        rgb = mix(rgb, vec3(0.05, 0.035, 0.03) + VIO * 0.06 * glow, smoothstep(px, -px, dI));
        float dO = (length(vec2(s.x / rOut, (s.y - yl) / (E * rOut))) - 1.0) * E * rOut;
        float lip = smoothstep(px, -px, max(dO, -dI)) * step(yl, s.y);
        rgb = mix(rgb, bronze(normalize(vec3(s.x * 0.4, 0.9, 0.2)), POOL * glow), lip);
    }

    // ---- the glass sphere.
    float r = length(s);
    float cover = smoothstep(px, -px, r - 1.0);
    if (cover > 0.0) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        vec3 g = rgb * vec3(0.78, 0.80, 0.90);                // seen through clear glass
        g *= 1.0 - 0.62 * smoothstep(0.80, 0.975, r);          // dark edge band (total internal reflection)
        g *= 1.0 - 0.35 * smoothstep(-0.55, -0.90, s.y);       // shade of the cup below

        // Swirling luminous mist (only computed inside the glass).
        float dens = 0.0;
        if (r < 0.985) {
            // Turns as a whole, with a spiral twist that winds and unwinds (bounded, so
            // it never coils into stripes however long it runs).
            float a = atan(s.y, s.x) + t * SWIRL + (1.0 - r) * (1.4 + 1.1 * sin(t * 0.17));
            vec2 m = r * vec2(cos(a), sin(a)) * 1.45 - vec2(0.0, t * 0.08);  // and slowly rises
            vec2 w = vec2(fbm(m + vec2(0.0, t * 0.07), 3),
                          fbm(m + vec2(5.2, 1.3) - t * 0.05, 3));
            float d = fbm(m + 2.2 * w - 1.1 + t * 0.03, 4);
            float thr = 0.36 + 0.10 * part;
            dens = smoothstep(thr - 0.06, thr + 0.30, d);
            vec2 hc = 0.38 * vec2(cos(t * 0.31), sin(t * 0.43));  // the parting drifts
            dens *= 1.0 - 0.85 * part * smoothstep(0.70, 0.10, length(s - hc));
            dens *= (0.35 + 0.65 * z) * smoothstep(0.985, 0.93, r);
            // Bright curling edges where the mist folds over itself.
            float fold = pow(clamp(1.0 - abs(d - thr - 0.09) * 9.0, 0.0, 1.0), 3.0);
            vec3 c = mix(VIO, vec3(0.26, 0.42, 1.0), smoothstep(0.35, 0.65, w.x));
            c = mix(c, vec3(0.16, 0.80, 0.78), 0.7 * smoothstep(0.58, 0.76, w.y));
            float em = MIST * glow;
            g = g * (1.0 - 0.55 * dens) + c * (0.25 + 0.95 * d) * dens * 0.85 * em;
            g += mix(c, vec3(0.85, 0.82, 1.0), 0.5) * fold * dens * 0.55 * em;
            g += VIO * 0.10 * z * z * em;                      // faint inner light
        }

        // Tiny sparkling points, mostly seen when the mist thins.
        for (int i = 0; i < SPARKS; i++) {
            float fi = float(i);
            float h1 = hash1(fi * 3.17 + 1.0), h2 = hash1(fi * 5.31 + 2.0), h3 = hash1(fi * 7.77 + 3.0);
            float ang = h1 * 2.0 * PI + t * (0.10 + 0.12 * h2) * (h3 < 0.5 ? 1.0 : -1.0);
            vec2 sp = (0.12 + 0.55 * h2) * vec2(cos(ang), 0.8 * sin(ang)) + vec2(0.0, 0.05 * sin(t * 0.5 + fi));
            vec2 dv = abs(s - sp);
            if (dv.x > 0.08 || dv.y > 0.08) continue;
            float tw = pow(0.5 + 0.5 * sin(t * (1.6 + 2.2 * h3) + fi * 2.1), 3.0);
            float vis = tw * (0.30 + 0.70 * part) * (1.0 - 0.7 * dens);
            float core = smoothstep(px, -px, length(dv) - 0.014);
            float arms = smoothstep(px, 0.0, min(dv.x, dv.y)) * smoothstep(0.075, 0.0, max(dv.x, dv.y));
            g += vec3(0.85, 0.95, 1.0) * max(core, arms * 0.8) * vis;
        }

        // Inverted, darker image of the window, low on the opposite side.
        float inv = window(-s, 2.15, 0.44, 0.58, 0.12, px);
        g = mix(g, vec3(0.62, 0.60, 0.66), inv * 0.16);

        // Fresnel: the glass reflects more of the dim room towards its edge.
        float F = pow(1.0 - z, 3.0);
        vec3 env = mix(vec3(0.04, 0.04, 0.06), vec3(0.36, 0.39, 0.50), smoothstep(-0.6, 0.9, s.y));
        g += env * F * 0.75;

        // Crisp specular window highlight, upper left.
        float win = window(s, 2.15, 0.52, 0.82, 0.15, px);
        float wg = 0.70 + 0.30 * smoothstep(0.52, 0.82, r);
        g = mix(g, vec3(0.96, 0.97, 1.0), win * 0.88 * wg);

        // Thin bright rim, strongest towards the light, with a violet kiss below.
        float line = smoothstep(px, -px, abs(r - 0.986) - 0.010);
        float lit = max(dot(s / max(r, 1e-4), normalize(vec2(-0.6, 0.8))), 0.0);
        g += line * (vec3(0.80, 0.84, 0.92) * (0.18 + 0.70 * lit) + VIO * 0.35 * smoothstep(-0.3, -0.9, s.y));

        rgb = mix(rgb, g, cover);
    }

    // ---- the turned bronze stand, in front of the ball's lower part.
    {
        // Each screen pixel sees the front of a horizontal circle that has been
        // squashed by E; find which height on the stand that is.
        float yp = s.y;
        for (int i = 0; i < 4; i++) {
            float rr = prof(clamp(yp, SB, yl));
            float cx = clamp(s.x / rr, -1.0, 1.0);
            yp = s.y + E * rr * sqrt(1.0 - cx * cx);
        }
        float rr = prof(clamp(yp, SB, yl));
        float d = max(abs(s.x) - rr, max(SB - yp, yp - yl) * 0.5);
        float cov = smoothstep(px, -px, d);
        if (cov > 0.0) {
            float dr = (prof(clamp(yp + 0.004, SB, yl)) - prof(clamp(yp - 0.004, SB, yl))) / 0.008;
            float cx = clamp(s.x / rr, -0.999, 0.999);
            vec3 n = vec3(cx, -dr, sqrt(1.0 - cx * cx));
            // Fluted (gadrooned) bowl and a beaded knop: ripple the normal sideways.
            float az = asin(cx);
            float h = yp - SB;
            float cup = smoothstep(0.60, 0.70, h) * step(yp, RIM);
            n.x += cup * 0.35 * sin(az * 14.0);
            float knop = step(0.38, h) * step(h, 0.48);
            n.x += knop * 0.25 * sin(az * 10.0);
            n = normalize(n);
            float up = POOL * glow * (0.35 + 0.65 * smoothstep(0.3, 0.9, h));
            vec3 c = bronze(n, up);
            // Darker in the crevices where the profile turns in.
            c *= 1.0 - 0.35 * smoothstep(0.5, 2.5, abs(dr)) * step(0.0, -dr);
            rgb = mix(rgb, c, cov);
        }
    }

    // ---- front half of the rim lip: a thin bright edge catching the light.
    {
        float dO = (length(vec2(s.x / rOut, (s.y - yl) / (E * rOut))) - 1.0) * E * rOut;
        float dI = (length(vec2(s.x / rIn, (s.y - yl) / (E * rIn))) - 1.0) * E * rIn;
        float lip = smoothstep(px, -px, max(dO, -dI)) * step(s.y, yl);
        vec3 n = normalize(vec3(s.x * 0.5, 0.75, 0.45));
        rgb = mix(rgb, bronze(n, POOL * glow), lip);
    }

    rgb = mix(base.rgb, rgb, INTENSITY);
    fragColor = vec4(rgb, base.a);
}
