// magiccircle — a finely engraved gold magic circle lying on the ground at the lower right; its rings turn and a bright pulse runs along the lines.
// zh: 魔法阵
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float WIDTH     = 0.40;   // circle diameter, as a share of the window width
const float TILT      = 0.36;   // how flat it lies (1 = seen straight from above)
const float PERSP     = 0.16;   // far side shrinks by this much (perspective)
const float LINE_PX   = 1.25;   // engraved line width in pixels
const float GLOW      = 0.22;   // tight halo along the lines (keep small)
const float PULSE     = 8.0;    // seconds between energy pulses
const int   SPARKS    = 12;     // small sparks rising from the circle

const float PI  = 3.14159265;
const float TAU = 6.28318531;

const vec3 GOLD  = vec3(0.93, 0.70, 0.36);   // polished gold at rest
const vec3 HOT   = vec3(1.00, 0.93, 0.76);   // pale white-gold of the pulse

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Offset vector from p to the nearest point of segment a-b (z = position along it).
vec3 segV(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec3(pa - ba * h, h);
}

// ---------------------------------------------------------------- perspective
// The circle lives in flat "ground" coordinates g (radius 1). A true
// perspective map keeps straight lines straight and turns circles into ellipses.
// M holds the derivatives dg/dscreen so that any distance measured in g can be
// turned into an exact on-screen pixel distance -> lines stay 1 px everywhere.
vec4 M;          // (dx/dsx, dx/dsy, dy/dsy, pixels per screen unit)

float px(vec2 v) {               // g-space offset -> distance in pixels
    float l = length(v);
    if (l < 1e-6) return 0.0;
    vec2 n = v / l;
    vec2 gs = vec2(M.x * n.x, M.y * n.x + M.z * n.y);
    return l / max(length(gs), 1e-6) * M.w;
}

// Accumulators: crisp line ink (premultiplied), its coverage, and the halo.
vec3 INK; float COV; vec3 HALO;

// Draw one engraved stroke at pixel distance d; e = pulse energy 0..1+.
void stroke(float d, float w, float e) {
    float cov = clamp(w * 0.5 + 0.5 - d, 0.0, 1.0);          // ~1 px box AA
    vec3 c = mix(GOLD, HOT, clamp(e, 0.0, 1.0));
    float lum = 0.62 + 0.75 * e;
    INK += c * cov * lum;
    COV = max(COV, cov);
    HALO += c * exp(-max(d, 0.0) * 0.55) * (GLOW * 0.35 + GLOW * 1.6 * e);
}

// Travelling pulse: s = position along a path (0..1), hp = head position.
// Bright head, short fading tail behind it, nothing ahead of it.
float runner(float s, float hp, float tail) {
    float b = hp - s;
    if (b < -0.01 || hp > 1.0 + 3.0 / tail) return 0.0;
    return exp(-max(b, 0.0) * tail) * smoothstep(-0.01, 0.0, b);   // short soft-edged front
}

// A small sigil in a cell, q in about [-1,1]^2: three strokes picked from a
// fixed set by the cell's hash, plus a ring on every fourth cell.
vec2 sigilV(vec2 q, float id, out float best) {
    vec2 bv = vec2(1e3);
    best = 1e3;
    for (int j = 0; j < 3; j++) {
        int s = int(hash1(id * 3.17 + float(j) * 7.3) * 8.0);
        if (j == 0) s = int(hash1(id) * 3.0);               // a main stem first
        vec4 e = s == 0 ? vec4( 0.0, -0.9,  0.0,  0.9)
               : s == 1 ? vec4(-0.6, -0.9,  0.6,  0.9)
               : s == 2 ? vec4(-0.6,  0.9,  0.0, -0.9)
               : s == 3 ? vec4(-0.6,  0.9,  0.6,  0.9)
               : s == 4 ? vec4(-0.6, -0.9,  0.6, -0.9)
               : s == 5 ? vec4( 0.0,  0.2,  0.6,  0.9)
               : s == 6 ? vec4(-0.6,  0.0,  0.6,  0.0)
               :          vec4( 0.0, -0.2, -0.6, -0.9);
        vec2 v = segV(q, e.xy, e.zw).xy;
        float l = dot(v, v);
        if (l < best) { best = l; bv = v; }
    }
    if (mod(id, 4.0) < 0.5) {
        vec2 c = vec2(0.0, 0.25);
        vec2 r = q - c;
        float lr = length(r);
        vec2 v = lr > 1e-5 ? r / lr * (lr - 0.32) : vec2(0.32, 0.0);
        if (dot(v, v) < best) { best = dot(v, v); bv = v; }
    }
    return bv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float R = WIDTH * 0.5 * aspect;                    // radius in screen units
    vec2 C = vec2(aspect - R - 0.04 * aspect, 0.19);   // lower right, on the floor
    vec2 dp = p - C;
    float t = iTime;

    // Cheap rejection: only the ellipse and the air just above it are drawn,
    // so the top-left text area costs nothing.
    if (abs(dp.x) > R * 1.25 || dp.y < -R * TILT * 1.3 || dp.y > R * TILT * 1.3 + 0.40) {
        fragColor = base;
        return;
    }

    // Inverse perspective: screen -> ground g.
    vec2 u = dp / R;
    float den = max(TILT - PERSP * u.y, 0.05);
    float gy = u.y / den;
    float w = 1.0 + PERSP * gy;
    vec2 g = vec2(u.x * w, gy);
    float dyds = TILT / (den * den);
    M = vec4(w / R, u.x * PERSP * dyds / R, dyds / R, iResolution.y);

    INK = vec3(0.0); COV = 0.0; HALO = vec3(0.0);

    float fade = smoothstep(0.0, 0.8, t);              // quick fade-in at start
    float pt = mod(t - 1.0, PULSE);                    // pulse clock (first at t = 1 s)
    float r = length(g);
    vec2 n = r > 1e-5 ? g / r : vec2(1.0, 0.0);
    float W = LINE_PX;

    if (r < 1.12) {
        // Each layer turns at its own speed, alternating direction.
        float rA = t * 0.030, rB = -t * 0.050, rC = t * 0.075, rD = -t * 0.110, rE = t * 0.160;
        // Angle of this pixel in each layer's frame, 0..1 starting at the front.
        float a0 = atan(g.x, -g.y) / TAU;
        float aA = fract(a0 - rA / TAU);
        float aB = fract(a0 - rB / TAU);
        float aD = fract(a0 - rD / TAU);

        // ---- Outer rim: double ring, tick scale, three floating arcs.
        float eRim = runner(aA, pt / 1.4, 7.0);
        stroke(px(n * (r - 1.000)), W * 1.15, eRim);
        stroke(px(n * (r - 0.965)), W, eRim);
        {
            float N = 96.0;
            float cell = aA * N;
            float id = floor(cell);
            float major = mod(id, 8.0) < 0.5 ? 1.0 : 0.0;
            float tang = (fract(cell) - 0.5) / N * TAU * r;
            float r1 = mix(0.988, 0.999, major);
            float rad = r - clamp(r, 0.966, r1);
            vec2 v = vec2(-n.y, n.x) * tang + n * rad;
            stroke(px(v), W * 0.85, eRim);
        }
        if (r > 1.03) {
            // Arcs with crisp end caps: distance to an arc segment.
            float k = fract(aA * 3.0);                  // three arcs
            float half_ = 0.36;
            float off = abs(k - 0.5);
            float along = max(off - half_, 0.0) / 3.0 * TAU * 1.07;
            vec2 v = n * (r - 1.07) + vec2(-n.y, n.x) * along;
            stroke(px(v), W, eRim * 0.8);
        }

        // ---- Sigil band between two rings; sigils light one after another.
        float eBand = runner(aB, (pt - 0.6) / 1.6, 6.0);
        stroke(px(n * (r - 0.925)), W, eBand);
        stroke(px(n * (r - 0.775)), W, eBand);
        if (r > 0.78 && r < 0.92) {
            float N = 30.0;
            float cell = aB * N;
            float id = floor(cell);
            float ti = 0.7 + id / N * 1.5;              // this sigil's moment
            float eS = pt > ti ? exp(-(pt - ti) * 2.2) * 1.2 : 0.0;
            float S = 0.050;                            // sigil half-size in g
            vec2 q = vec2((fract(cell) - 0.5) / N * TAU * 0.85, 0.85 - r) / S;
            q.x *= -1.0;
            float bd;
            vec2 v = sigilV(q, id, bd) * S;
            vec2 vg = vec2(-n.y, n.x) * -v.x - n * v.y;
            stroke(px(vg), W * 0.95, eS);
        }

        // ---- Heptagram {7/3}: one continuous path, traced edge by edge.
        if (r < 0.79) {
            vec2 gC = rot(g, -rC);
            float hp = (pt - 1.9) / 1.7;
            float bd = 1e3; vec2 bv = vec2(1.0); float bs = 0.0;
            for (int i = 0; i < 7; i++) {
                float a1 = TAU * float(i * 3) / 7.0, a2 = TAU * float(i * 3 + 3) / 7.0;
                vec3 sv = segV(gC, 0.775 * vec2(sin(a1), -cos(a1)), 0.775 * vec2(sin(a2), -cos(a2)));
                float l = dot(sv.xy, sv.xy);
                if (l < bd) { bd = l; bv = sv.xy; bs = (float(i) + sv.z) / 7.0; }
            }
            stroke(px(rot(bv, rC)), W, runner(bs, hp, 9.0));
        }

        // ---- Inner rings with a dotted ring between them.
        float eIn = runner(aD, (pt - 3.0) / 1.0, 5.0);
        stroke(px(n * (r - 0.580)), W, eIn);
        stroke(px(n * (r - 0.500)), W, eIn);
        if (abs(r - 0.54) < 0.03) {
            float N = 48.0;
            float cell = aD * N;
            vec2 v = vec2(-n.y, n.x) * (fract(cell) - 0.5) / N * TAU * r + n * (r - 0.54);
            stroke(px(v) - 1.0, W, eIn);                // tiny round studs
        }

        // ---- Hexagram: two triangles traced together.
        if (r < 0.51) {
            vec2 gD = rot(g, -rD);
            float hp = (pt - 3.4) / 0.9;
            float bd = 1e3; vec2 bv = vec2(1.0); float bs = 0.0;
            for (int i = 0; i < 6; i++) {
                float j = float(i / 3), e = float(i - (i / 3) * 3);
                float a1 = TAU * (e / 3.0 + j / 6.0), a2 = TAU * ((e + 1.0) / 3.0 + j / 6.0);
                vec3 sv = segV(gD, 0.50 * vec2(sin(a1), -cos(a1)), 0.50 * vec2(sin(a2), -cos(a2)));
                float l = dot(sv.xy, sv.xy);
                if (l < bd) { bd = l; bv = sv.xy; bs = (e + sv.z) / 3.0; }
            }
            stroke(px(rot(bv, rD)), W, runner(bs, hp, 6.0));
        }

        // ---- Core: pentagram {5/2} in a ring, and a small central ring.
        if (r < 0.30) {
            vec2 gE = rot(g, -rE);
            float hp = (pt - 4.2) / 0.8;
            float bd = 1e3; vec2 bv = vec2(1.0); float bs = 0.0;
            for (int i = 0; i < 5; i++) {
                float a1 = TAU * float(i * 2) / 5.0, a2 = TAU * float(i * 2 + 2) / 5.0;
                vec3 sv = segV(gE, 0.25 * vec2(sin(a1), -cos(a1)), 0.25 * vec2(sin(a2), -cos(a2)));
                float l = dot(sv.xy, sv.xy);
                if (l < bd) { bd = l; bv = sv.xy; bs = (float(i) + sv.z) / 5.0; }
            }
            float eCore = 0.75 * exp(-pow((pt - 5.1) * 2.2, 2.0));   // brief flash when the pulse arrives
            stroke(px(rot(bv, rE)), W, runner(bs, hp, 6.0) + eCore);
            stroke(px(n * (r - 0.270)), W, eCore + runner(fract(a0), (pt - 4.2) / 0.8, 5.0));
            stroke(px(n * (r - 0.085)), W, eCore);
        }
    }

    // ---- Sparks: tiny crisp points rising from the circle -----------------
    vec3 SP = vec3(0.0); float spA = 0.0;
    if (dp.y > -R * TILT * 1.2) {
        float burst = exp(-pow((pt - 5.3) * 0.9, 2.0));   // more sparks after a pulse
        for (int i = 0; i < SPARKS; i++) {
            float fi = float(i);
            float life = 2.2 + 1.6 * hash1(fi + 0.3);
            float lt = fract(t / life + hash1(fi + 4.1));
            float cyc = floor(t / life + hash1(fi + 4.1));
            float ang = TAU * hash1(fi * 1.7 + cyc * 3.1);
            float rad = mix(0.45, 1.0, hash1(fi * 2.3 + cyc * 1.3));
            vec2 gs = rad * vec2(sin(ang), -cos(ang));
            // forward perspective: ground -> screen
            float ws = 1.0 + PERSP * gs.y;
            vec2 s0 = R * vec2(gs.x / ws, TILT * gs.y / ws);
            float rise = lt * (0.10 + 0.14 * hash1(fi + 6.2));
            vec2 sp = s0 + vec2(0.004 * sin(lt * 6.0 + fi), rise);
            vec2 d = dp - sp;
            // Short streak below the point (motion), crisp round head.
            float dh = length(d) * iResolution.y;
            float ds = length(segV(dp, sp, sp - vec2(0.0, 0.014)).xy) * iResolution.y;
            float life_ = smoothstep(0.0, 0.08, lt) * (1.0 - smoothstep(0.55, 1.0, lt));
            float amt = life_ * (0.55 + 0.6 * burst);
            float head = clamp(1.3 - dh, 0.0, 1.0);
            float streak = clamp(0.9 - ds, 0.0, 1.0) * 0.45 * clamp(1.0 + d.y / 0.014, 0.0, 1.0);
            float k = max(head, streak) * amt;
            SP += mix(HOT, GOLD, hash1(fi + 1.7) * 0.6) * k * 1.2 + GOLD * exp(-dh * 0.5) * 0.15 * amt;
            spA = max(spA, k);
        }
    }

    // Engraved lines are laid over the picture (opaque-ish ink), the halo is added.
    float a = clamp(COV, 0.0, 1.0) * 0.85 * INTENSITY * fade;
    vec3 ink = INK / max(COV, 1e-3);
    vec3 col = base.rgb * (1.0 - a) + min(ink, vec3(1.3)) * a;
    col += HALO * INTENSITY * fade;
    col += SP * INTENSITY * fade;
    fragColor = vec4(col, base.a);
}
