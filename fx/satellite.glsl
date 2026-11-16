// satellite — a rocket upper stage delivers a satellite on the right: the stage separates and tumbles away, the solar wings swing out and unfold, the dish and boom deploy, and the panels catch the sun.
// zh: 卫星
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float OPACITY   = 0.88;   // how much the spacecraft hides what is behind it
const float SIZE      = 1.00;   // scale of the whole craft (1 = wings span ~0.5 window heights)
const float CYCLE     = 14.0;   // seconds per deployment, arrival to departure
const float EARTH     = 0.80;   // brightness of the thin Earth limb at the lower right (0 = off)
const float STARS     = 0.30;   // faint background stars

const float PI = 3.14159265;

// Timeline inside one cycle (seconds).
const float T_ARR   = 3.0;    // stack has drifted into place
const float T_SEP   = 3.2;    // upper stage separates
const float T_SWING = 4.2;    // solar wings swing out from the body
const float T_UNF   = 5.2;    // first outer panel starts to unfold (then one every 0.55 s)
const float T_DISH  = 6.6;    // dish flips up, then opens
const float T_BOOM  = 7.0;    // boom extends
const float T_TURN  = 8.4;    // turns towards the sun
const float T_GLINT = 9.0;    // glint sweeps across the arrays
const float T_TRIM  = 10.3;   // attitude-control puffs
const float T_DEP   = 11.2;   // drifts away

// Craft dimensions (window heights at SIZE 1).
const vec2  BODY = vec2(0.042, 0.052);   // half size of the bus front face
const float DEP  = 0.011;                // apparent depth of the box (top and right faces)
const float PW   = 0.048;                // width of one solar panel
const float PH   = 0.052;                // half height of a panel
const float YOKE = 0.022;                // yoke length between bus and first panel

// ---- Helpers ------------------------------------------------------------

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float sdBox(vec2 q, vec2 b) {
    vec2 d = abs(q) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float segD(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Coverage of a shape with signed distance d (aa = one pixel).
float cover(float d, float aa) { return clamp(0.5 - d / aa, 0.0, 1.0); }

// Exact pixel coverage of a line of half-width w at distance d.
float lineCov(float d, float w, float aa) {
    return max(min(d + 0.5 * aa, w) - max(d - 0.5 * aa, -w), 0.0) / aa;
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

float ease(float x) { x = clamp(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x); }
float easeOut(float x) { x = clamp(x, 0.0, 1.0); return 1.0 - pow(1.0 - x, 3.0); }

// ---- Choreography -----------------------------------------------------------

// Where the satellite is, its in-plane angle, scale (it shrinks as it recedes) and fade.
void satPose(float t, float aspect, out vec2 pos, out float ang, out float sc, out float fade) {
    vec2 C0 = vec2(aspect - 0.34, 0.37);
    float e = easeOut(t / T_ARR);
    pos = mix(C0 + vec2(0.55, -0.10), C0, e) + vec2(-0.003, 0.004) * t;
    ang = mix(0.45, 0.12, e);
    ang = mix(ang, -0.18, ease((t - T_TURN) / 1.4));           // face the sun
    ang += 0.07 * ease((t - T_TRIM) / 1.0);                    // trim after the puffs
    float x = clamp((t - T_DEP) / (CYCLE - T_DEP), 0.0, 1.0);
    float ed = x * x;
    pos += vec2(0.40, 0.14) * ed;
    ang += 0.30 * ed;
    sc = SIZE * mix(1.0, 0.45, ed);
    fade = 1.0 - smoothstep(0.70, 1.0, x);
}

// ---- Solar wing -------------------------------------------------------------
// Four panels per wing. Panel k turns from edge-on (folded) to face-on, so its
// apparent width is PW * sin(angle); the rest of the folded stack is a thin
// strip at the end. Neighbouring panels tilt opposite ways (an accordion), so
// their brightness alternates while they open.
float panelAngle(int k, float t) {
    if (k == 0) return 0.5 * PI * ease((t - T_SWING) / 1.0);
    return 0.5 * PI * ease((t - T_UNF - 0.55 * float(k - 1)) / 0.75);
}

void wing(inout vec4 acc, vec2 q, float s, float t, vec3 Ll, float aa,
          float tiltB, float glintX, float glintA) {
    float edgeX = s > 0.0 ? BODY.x + DEP : BODY.x;
    float th0 = panelAngle(0, t);
    float root = edgeX + YOKE * sin(th0);
    float u = s * q.x;
    float ph = PH * cos(tiltB);

    // Yoke: two struts from the bus side converging on the wing root.
    if (u > edgeX - 0.002 && u < root + 0.002 && abs(q.y) < 0.03) {
        float d = min(segD(vec2(u, q.y), vec2(edgeX, 0.022), vec2(root, 0.0)),
                      segD(vec2(u, q.y), vec2(edgeX, -0.022), vec2(root, 0.0)));
        float dif = 0.35 + 0.65 * max(Ll.z, 0.0);
        over(acc, vec3(0.70, 0.70, 0.68) * dif, lineCov(d, 0.0011, aa));
    }

    u -= root;
    if (u < -0.002 || u > 4.0 * PW + 0.01 || abs(q.y) > ph + 0.003) return;

    float st = 0.0;
    for (int k = 0; k < 4; k++) {
        float th = panelAngle(k, t);
        float w = max(PW * sin(th), 0.0032);
        if (u < st + w + 0.001) {
            float d = sdBox(vec2(u - st - 0.5 * w, q.y), vec2(0.5 * w, ph));
            float kc = cover(d, aa);
            if (kc <= 0.0) return;
            float alt = (k == 1 || k == 3) ? -1.0 : 1.0;
            vec3 n = vec3(s * alt * cos(th), 0.0, sin(th));
            n = vec3(n.x, n.z * sin(tiltB), n.z * cos(tiltB));
            float dif = max(dot(n, Ll), 0.0);
            vec3 c;
            if (w < 0.009) {
                // Folded or nearly edge-on: we see the panel's light substrate edge.
                c = vec3(0.62, 0.62, 0.64) * (0.30 + 0.70 * dif);
            } else {
                float uu = (u - st) / w;
                vec2 g = vec2(uu * 3.0, (q.y + ph) / (2.0 * ph) * 7.0);
                vec2 id = floor(g), f = fract(g);
                float ex = min(f.x, 1.0 - f.x) * w / 3.0;
                float ey = min(f.y, 1.0 - f.y) * 2.0 * ph / 7.0;
                float grid = max(lineCov(ex, 0.0005, aa), lineCov(ey, 0.0005, aa));
                float frame = clamp((0.0018 - (-d)) / aa + 0.5, 0.0, 1.0);
                float hc = hash12(id + vec2(float(k) * 7.0 + s * 13.0, 3.0));
                vec3 cell = vec3(0.05, 0.09, 0.26) * (0.85 + 0.30 * hc) * (0.30 + 1.05 * dif);
                // A soft sheen of reflected sky, stronger when facing the sun.
                cell += vec3(0.10, 0.16, 0.30) * pow(dif, 6.0) * 0.6;
                // The glint lights whole cells, so it stays crisp-edged.
                float xc = s * (root + st + (id.x + 0.5) * w / 3.0);
                float yc = -ph + (id.y + 0.5) * 2.0 * ph / 7.0;
                float gl = exp(-pow((xc * 0.9 + yc * 0.7 - glintX) / 0.030, 2.0))
                         * glintA * (0.55 + 0.45 * hc);
                cell = mix(cell, vec3(1.0, 0.95, 0.84), clamp(gl, 0.0, 0.92));
                vec3 lineC = vec3(0.62, 0.64, 0.68) * (0.30 + 0.70 * dif);
                c = mix(cell, lineC, max(grid * 0.75, frame));
            }
            over(acc, c, kc);
            return;
        }
        st += w + 0.0014;
    }
}

// ---- Bus (gold-foil box) ------------------------------------------------------

vec3 foil(vec2 q, float lit, float ang) {
    float n1 = vnoise(q * 70.0 + 3.0);
    float n2 = vnoise(q * 160.0 + 11.0);
    vec3 c = vec3(0.78, 0.55, 0.18) * (0.62 + 0.45 * n1 + 0.15 * n2);
    // Crinkle facets: different facets catch the sun as the craft turns.
    float th = 0.66 + 0.10 * sin(ang * 9.0 + 1.0);
    float facet = smoothstep(th, th + 0.02, 0.6 * n1 + 0.4 * n2);
    c += vec3(1.0, 0.86, 0.55) * facet * 0.55;
    // Thin crease lines.
    float crease = 1.0 - smoothstep(0.0, 0.035, abs(n2 - 0.5));
    c *= 1.0 - 0.25 * crease;
    return c * lit;
}

void bus(inout vec4 acc, vec2 q, vec3 Ll, float aa, float ang) {
    if (abs(q.x) > BODY.x + DEP + 0.004 || abs(q.y) > BODY.y + DEP + 0.004) return;
    // Right face (sheared up and back), then the top face.
    float sx = q.x - BODY.x;
    if (sx > -0.001) {
        float yy = q.y - sx * (DEP / DEP);
        float d = max(sdBox(vec2(sx - 0.5 * DEP, yy), vec2(0.5 * DEP, BODY.y)), -sx);
        float lit = 0.20 + 0.80 * max(Ll.x, 0.0);
        over(acc, foil(q * 1.3 + 5.0, lit * 0.75, ang), cover(d, aa));
    }
    float ty = q.y - BODY.y;
    if (ty > -0.001) {
        float xx = q.x - ty;
        float d = max(sdBox(vec2(xx, ty - 0.5 * DEP), vec2(BODY.x, 0.5 * DEP)), -ty);
        float lit = 0.20 + 0.80 * max(Ll.y, 0.0);
        over(acc, foil(q * 1.3 + 9.0, lit * 0.95, ang), cover(d, aa));
    }
    // Front face.
    float d = sdBox(q, BODY);
    float k = cover(d, aa);
    if (k <= 0.0) return;
    float lit = 0.25 + 0.85 * max(Ll.z, 0.0);
    vec3 c = foil(q, lit, ang);
    // White radiator panel on the lower part, with fine heat-pipe lines.
    float dr = sdBox(q - vec2(-0.004, -0.026), vec2(0.030, 0.018));
    if (dr < 0.0) {
        float f = fract((q.x + 0.034) / 0.006);
        float ln = lineCov(min(f, 1.0 - f) * 0.006, 0.0004, aa);
        vec3 rc = vec3(0.86, 0.87, 0.88) * lit * (1.0 - 0.18 * ln);
        c = mix(c, rc, cover(dr, aa));
    }
    // Star tracker: a small dark baffle with a bright rim.
    float ds = length(q - vec2(-0.026, 0.032)) - 0.007;
    c = mix(c, vec3(0.05, 0.05, 0.06), cover(ds, aa));
    c = mix(c, vec3(0.80, 0.80, 0.78) * lit, lineCov(abs(ds), 0.0007, aa));
    // Crisp edge highlight around the face.
    c = mix(c, vec3(1.0, 0.86, 0.52) * lit, lineCov(abs(d), 0.0006, aa) * 0.7);
    over(acc, c, k);
}

// ---- Dish antenna -------------------------------------------------------------
// A mast hinged on top of the bus swings from lying flat to upright, then the
// dish opens. The dish is seen from the side, tilted a little towards us.
void dish(inout vec4 acc, vec2 q, float t, vec3 Ll, float aa) {
    float flip = ease((t - T_DISH) / 0.9);
    float open = mix(0.30, 1.0, ease((t - T_DISH - 0.7) / 0.8));
    vec2 hinge = vec2(0.010, BODY.y + DEP);
    float psi = mix(0.5 * PI + 0.08, 0.0, flip);
    vec2 dm = vec2(-sin(psi), cos(psi));
    vec2 tip = hinge + dm * 0.030;
    if (length(q - hinge) > 0.085) return;
    float lit = 0.30 + 0.70 * max(Ll.z, 0.0);

    // Mast.
    over(acc, vec3(0.75, 0.75, 0.73) * lit, lineCov(segD(q, hinge, tip), 0.0011, aa));

    vec2 pr = vec2(dm.y, -dm.x);
    vec2 r = q - tip;
    float a = dot(r, pr), b = dot(r, dm);
    float R = 0.034 * open, D = 0.013 * open;
    // Back of the bowl (half ellipse under the rim).
    float eo = length(vec2(a / R, (b - D) / D)) - 1.0;
    float kb = cover(max(eo * D, b - D), aa);
    if (kb > 0.0) {
        float sh = 0.45 + 0.55 * clamp(0.5 + 0.5 * dot(normalize(vec2(a, -0.5 * R)), rot(Ll.xy, 0.0)), 0.0, 1.0);
        over(acc, vec3(0.88, 0.88, 0.86) * sh * lit, kb);
    }
    // Inside of the bowl, seen through the rim ellipse: shaded opposite to the back.
    float ei = length(vec2(a / R, (b - D) / (0.28 * R))) - 1.0;
    float ki = cover(ei * 0.28 * R, aa);
    if (ki > 0.0) {
        float g = clamp(0.5 - 0.5 * a / R * sign(Ll.x + 1e-3), 0.0, 1.0);
        vec3 c = vec3(0.70, 0.71, 0.72) * (0.45 + 0.55 * g) * lit;
        c = mix(c, vec3(0.95, 0.95, 0.93), lineCov(abs(ei) * 0.28 * R, 0.0006, aa));
        over(acc, c, ki);
    }
    // Feed on a strut at the focus, once the dish is open.
    float fo = smoothstep(0.75, 0.95, open);
    if (fo > 0.0) {
        vec2 feed = tip + dm * (D + 0.75 * R);
        over(acc, vec3(0.80, 0.80, 0.78) * lit, lineCov(segD(q, tip + dm * D, feed), 0.0008, aa) * fo);
        over(acc, vec3(0.82, 0.80, 0.74) * lit, cover(length(q - feed) - 0.0035, aa) * fo);
    }
}

// ---- Boom ---------------------------------------------------------------------
// A lattice boom telescopes out of the bus floor once the stage is gone.
void boom(inout vec4 acc, vec2 q, float t, vec3 Ll, float aa) {
    float L = 0.10 * ease((t - T_BOOM) / 1.2);
    if (L <= 0.0) return;
    float y0 = -BODY.y;
    float y = y0 - q.y;                        // distance down the boom
    if (y < -0.002 || y > L + 0.012 || abs(q.x) > 0.012) return;
    float lit = 0.30 + 0.70 * max(Ll.z, 0.0);
    if (y < L) {
        float hw = 0.0038;
        float rails = lineCov(abs(abs(q.x) - hw), 0.0006, aa);
        float bay = 0.009;
        float f = fract(y / bay);
        float zig = mod(floor(y / bay), 2.0) < 0.5 ? f : 1.0 - f;
        float diag = lineCov(abs(q.x - mix(-hw, hw, zig)) * 0.7, 0.0005, aa) * step(abs(q.x), hw);
        over(acc, vec3(0.78, 0.78, 0.76) * lit, max(rails, diag));
    }
    // Sensor at the tip.
    float ds = sdBox(vec2(q.x, y - L - 0.005), vec2(0.007, 0.005));
    vec3 c = mix(vec3(0.55, 0.56, 0.58), vec3(0.88, 0.88, 0.86), step(0.0, q.x * sign(Ll.x + 1e-3))) * lit;
    over(acc, c, cover(ds, aa));
}

// ---- Upper stage ----------------------------------------------------------------
// Local frame: origin at the separation ring, the stage hangs down along -y.
void stage(inout vec4 acc, vec2 q, vec3 Ll, float aa) {
    if (abs(q.x) > 0.06 || q.y > 0.003 || q.y < -0.262) return;
    float y = -q.y;
    // Payload adapter: a short dark cone.
    if (y < 0.022) {
        float hw = mix(0.026, 0.046, y / 0.022);
        float d = max(abs(q.x) - hw, max(-y, y - 0.022));
        float nx = clamp(q.x / hw, -1.0, 1.0);
        float dif = max(dot(vec3(nx, 0.3, sqrt(1.0 - nx * nx)), Ll), 0.0);
        vec3 c = vec3(0.30, 0.30, 0.32) * (0.25 + 0.9 * dif);
        c = mix(c, vec3(0.75), lineCov(abs(y - 0.004), 0.0006, aa) * 0.6);
        over(acc, c, cover(d, aa));
        return;
    }
    // Propellant tank: white cylinder with ring frames and a dark band.
    if (y < 0.170) {
        float hw = 0.048;
        float d = max(abs(q.x) - hw, max(0.022 - y, y - 0.170));
        float nx = clamp(q.x / hw, -1.0, 1.0);
        vec3 n = vec3(nx, 0.0, sqrt(1.0 - nx * nx));
        float dif = max(dot(n, Ll), 0.0);
        vec3 H = normalize(Ll + vec3(0.0, 0.0, 1.0));
        float spe = pow(max(dot(n, H), 0.0), 40.0);
        vec3 base = vec3(0.84, 0.83, 0.80);
        if (y > 0.030 && y < 0.042) base = vec3(0.16, 0.16, 0.17);    // dark band
        float ring = max(lineCov(abs(y - 0.095), 0.0006, aa), lineCov(abs(y - 0.150), 0.0006, aa));
        float str = lineCov(abs(fract(asin(nx) * 2.5) - 0.5) * 0.02, 0.0004, aa) * 0.35;
        vec3 c = base * (0.10 + 0.95 * dif) * (1.0 - 0.35 * max(ring, str)) + vec3(0.35) * spe;
        over(acc, c, cover(d, aa));
        return;
    }
    // Thrust structure, then the engine bell.
    if (y < 0.185) {
        float hw = mix(0.040, 0.016, (y - 0.170) / 0.015);
        float d = max(abs(q.x) - hw, y - 0.185);
        over(acc, vec3(0.22, 0.21, 0.20) * (0.35 + 0.65 * max(Ll.z, 0.0)), cover(d, aa));
        return;
    }
    float s = (y - 0.185) / 0.070;
    float hw = 0.012 + 0.024 * pow(clamp(s, 0.0, 1.0), 0.65);
    float d = max(abs(q.x) - hw, y - 0.255);
    float nx = clamp(q.x / hw, -1.0, 1.0);
    float dif = max(dot(vec3(nx, -0.35, sqrt(1.0 - nx * nx)), Ll), 0.0);
    vec3 c = vec3(0.30, 0.24, 0.18) * (0.20 + 1.0 * dif);
    c += vec3(0.55, 0.45, 0.35) * pow(dif, 12.0) * 0.6;                 // metallic streak
    c *= 1.0 - 0.25 * lineCov(abs(fract(s * 6.0) - 0.5) * 0.0117, 0.0004, aa) * step(s, 0.5);
    c = mix(c, vec3(0.80, 0.74, 0.66) * (0.4 + 0.6 * dif), lineCov(abs(y - 0.2535), 0.0010, aa));
    over(acc, c, cover(d, aa));
}

// ---- Thruster puffs -------------------------------------------------------------
// A small crisp cloud of gas: pushed out fast, slowing, growing and fading.
void puff(inout vec4 acc, vec2 q, vec2 o, vec2 dir, float age, float size, vec3 Ll, float aa) {
    if (age <= 0.0 || age > 1.6) return;
    float g = 1.0 - exp(-age * 3.0);
    vec2 c = o + dir * size * 2.2 * g;
    float r = size * (0.15 + 0.85 * g);
    float d = min(length(q - c) - r, length(q - c - dir * r * 0.9) - r * 0.65);
    float k = cover(d, aa);
    if (k <= 0.0) return;
    float al = 0.85 * exp(-age * 1.7) * smoothstep(0.0, 0.04, age);
    vec2 nn = (q - c) / max(r, 1e-4);
    float sh = 0.70 + 0.30 * clamp(dot(nn, normalize(Ll.xy + 1e-4)), -1.0, 1.0);
    over(acc, vec3(0.86, 0.89, 0.94) * sh, k * al);
}

// ---- Scene ------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;
    vec3 col = base.rgb;

    // Start a second into the cycle so the stack is already sliding in.
    float tt = iTime + 1.0;
    float t = mod(tt, CYCLE);

    // Sun from the upper right, a little towards the viewer.
    vec3 Lw = normalize(vec3(0.45, 0.40, 0.80));

    // ---- Faint stars, dimmer over the text corner.
    vec2 cell = floor(p * 26.0);
    float hs = hash12(cell);
    if (hs > 0.88) {
        vec2 sp = (cell + vec2(hash12(cell + 3.1), hash12(cell + 7.7)) * 0.8 + 0.1) / 26.0;
        float tw = 0.75 + 0.25 * sin(iTime * (0.8 + 2.0 * hs) + hs * 40.0);
        float textArea = 1.0 - 0.7 * (1.0 - smoothstep(0.35, 0.6, uv.x)) * (1.0 - smoothstep(0.4, 0.65, uv.y));
        col += vec3(0.82, 0.87, 1.0) * (hs - 0.88) / 0.12 * tw * STARS * textArea * INTENSITY
             * exp(-pow(length(p - sp) / (1.1 * px), 2.0));
    }

    // ---- Earth: a thin limb across the lower right corner.
    if (EARTH > 0.0) {
        vec2 C = vec2(aspect + 0.40, -2.02);
        float R = 2.15;
        float h = length(p - C) - R;
        if (h < 0.0) {
            float depth = -h;
            float lit = smoothstep(-0.2, 0.6, (p.x - aspect * 0.55) / aspect);
            vec3 surf = mix(vec3(0.005, 0.01, 0.025), vec3(0.03, 0.07, 0.16), lit * exp(-depth / 0.06));
            col = mix(col, surf, clamp(depth / px, 0.0, 1.0) * 0.75 * EARTH * INTENSITY);
        }
        if (h > -3.0 * px && h < 8.0 * px) {
            float hp = h / px;
            float lit = smoothstep(0.45, 0.95, p.x / aspect);
            vec3 atm = mix(vec3(0.10, 0.28, 0.65), vec3(0.40, 0.70, 1.0), lit);
            col += atm * (lineCov(abs(hp - 0.8), 0.9, 1.0) * 0.9
                          + exp(-max(hp, 0.0) / 2.5) * step(0.0, hp) * 0.25) * EARTH * INTENSITY;
        }
    }

    vec2 pos; float ang, sc, fade;
    satPose(t, aspect, pos, ang, sc, fade);

    // ---- Upper stage: rides along until separation, then backs off and tumbles.
    {
        vec2 sp; float sa, ss, sf;
        float ts = max(t - T_SEP, 0.0);
        satPose(min(t, T_SEP), aspect, sp, sa, ss, sf);
        vec2 axis = rot(vec2(0.0, -1.0), sa);
        vec2 spos = sp + axis * ss * BODY.y
                  + axis * (0.022 * ts + 0.0015 * ts * ts) + vec2(0.006, 0.0) * ts;
        float sang = sa + 0.30 * ts * ts / (1.0 + ts);
        float sscale = ss / (1.0 + 0.05 * ts);
        float sfade = 1.0 - smoothstep(5.5, 7.5, ts);
        if (t >= T_SEP) sfade *= sf; else sfade = fade;
        vec2 rel = p - spos;
        if (sfade > 0.0 && dot(rel, rel) < pow(0.28 * sscale, 2.0)) {
            vec4 acc = vec4(0.0);
            vec3 Ll = vec3(rot(Lw.xy, -sang), Lw.z);
            stage(acc, rot(rel, -sang) / sscale, Ll, px / sscale);
            float k = OPACITY * INTENSITY * sfade;
            col = col * (1.0 - acc.a * k) + acc.rgb * k;
        }
    }

    // ---- Satellite.
    vec2 rel = p - pos;
    if (fade > 0.0 && dot(rel, rel) < pow(0.32 * sc, 2.0)) {
        vec2 q = rot(rel, -ang) / sc;
        float aa = px / sc;
        vec3 Ll = vec3(rot(Lw.xy, -ang), Lw.z);
        vec4 acc = vec4(0.0);

        // Panels tilt about the wing axis to face the sun during the turn.
        float tb = mix(-0.55, atan(Ll.y, Ll.z), ease((t - T_TURN) / 1.4));
        float gx = mix(-0.40, 0.40, clamp((t - T_GLINT) / 1.1, 0.0, 1.0));
        float ga = smoothstep(T_GLINT - 0.1, T_GLINT + 0.15, t) * (1.0 - smoothstep(T_GLINT + 0.9, T_GLINT + 1.2, t));

        wing(acc, q, sign(q.x), t, Ll, aa, tb, gx, ga);
        boom(acc, q, t, Ll, aa);
        bus(acc, q, Ll, aa, ang);
        dish(acc, q, t, Ll, aa);

        // Separation puffs from the springs/thrusters around the interface ring.
        float a0 = t - T_SEP;
        puff(acc, q, vec2(-0.040, -0.056), normalize(vec2(-1.0, -0.20)), a0, 0.026, Ll, aa);
        puff(acc, q, vec2( 0.040, -0.056), normalize(vec2( 1.0, -0.20)), a0 - 0.05, 0.026, Ll, aa);
        puff(acc, q, vec2(-0.022, -0.060), normalize(vec2(-0.5, -1.0)), a0 - 0.10, 0.020, Ll, aa);
        puff(acc, q, vec2( 0.022, -0.060), normalize(vec2( 0.5, -1.0)), a0 - 0.12, 0.020, Ll, aa);
        // Attitude trim: one corner pair starts the turn, the opposite pair stops it.
        float a1 = t - T_TRIM;
        puff(acc, q, vec2(-BODY.x + 0.004, BODY.y + DEP), vec2(0.0, 1.0), a1, 0.018, Ll, aa);
        puff(acc, q, vec2(BODY.x + DEP - 0.004, -BODY.y), vec2(0.0, -1.0), a1, 0.018, Ll, aa);
        puff(acc, q, vec2(BODY.x + 0.004, BODY.y + DEP), vec2(0.0, 1.0), a1 - 0.7, 0.014, Ll, aa);
        puff(acc, q, vec2(-BODY.x + 0.004, -BODY.y), vec2(0.0, -1.0), a1 - 0.7, 0.014, Ll, aa);

        float k = OPACITY * INTENSITY * fade;
        col = col * (1.0 - acc.a * k) + acc.rgb * k;
    }

    fragColor = vec4(col, base.a);
}
