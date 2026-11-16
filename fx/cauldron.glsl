// cauldron — a black iron cauldron bubbles over a crackling fire in the lower right; every ~11 s an ingredient drops in with a splash, the potion swirls into a new colour, boils up and goes off in a puff of coloured smoke with sparkles and runes.
// zh: 魔药锅
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SCALE     = 0.14;   // pot belly half-width, in window heights (feet to rim is ~2.1 of these)
const vec2  ANCHOR    = vec2(0.27, 0.03); // pot centre from the right edge; feet from the bottom (window heights)
const float CYCLE     = 11.0;   // seconds per brew: drop -> splash -> swirl -> boil -> poof -> settle
const float FIRE      = 1.0;    // fire brightness and firelight on the pot
const int   BUBBLES   = 9;      // bubble slots on the potion surface
const float SMOKE     = 0.72;   // opacity of the smoke puff

const float PI = 3.14159265;
const float TD = 1.3;           // the ingredient hits the potion
const float TP = 6.6;           // the poof

// Pot geometry in units of SCALE, origin at the belly centre. The view is from
// slightly above, so horizontal circles show up as ellipses squashed to ~0.22.
const vec2  BODY = vec2(1.0, 0.80);
const float RY   = 0.60;               // rim height
const vec2  RO   = vec2(0.86, 0.19);   // rim, outer edge
const vec2  RI   = RO * 0.86;          // rim, inner edge (the opening)
const float LT   = 0.09;               // thickness of the rolled lip seen from the front
const float SY   = 0.555;              // potion surface
const vec2  SR   = vec2(0.72, 0.155);
const float GROUND = -1.20;            // the fire bed
const vec3  LIGHT = vec3(-0.50, 0.55, 0.67);   // main light: upper left, in front (normalised below)
const vec3  VIEW  = vec3(0.0, 0.22, 0.975);

float PX;   // one screen pixel in pot units

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

float cover(float d) { return clamp(0.5 - d / PX, 0.0, 1.0); }   // ~1 px anti-aliasing

// Signed distance to an ellipse, divided by the gradient so edges stay ~1 px
// sharp even where a flat ellipse is steep.
float ellD(vec2 p, vec2 c, vec2 r) {
    vec2 d = (p - c) / r;
    float L = length(d);
    return (L - 1.0) * L / max(length(d / r), 1e-4);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// Potion colours, one per brew: green -> violet -> amber -> teal.
vec3 potion(float k) {
    k = mod(k, 4.0);
    if (k < 0.5) return vec3(0.40, 0.86, 0.36);
    if (k < 1.5) return vec3(0.66, 0.46, 0.98);
    if (k < 2.5) return vec3(1.00, 0.68, 0.24);
    return vec3(0.24, 0.84, 0.80);
}

// How hard the potion is boiling at cycle time t.
float boilAt(float t) {
    return smoothstep(3.6, 6.0, t) * (1.0 - smoothstep(7.4, 9.6, t));
}

// Cast iron: dark, a sharp sheen from the main light, warm firelight from below
// and a thin cool rim so the black pot still reads on a dark background.
vec3 iron(vec3 N, float fl) {
    vec3 L = normalize(LIGHT);
    float dif = max(dot(N, L), 0.0);
    vec3 R = reflect(-L, N);
    float rv = max(dot(R, VIEW), 0.0);
    vec3 c = vec3(0.075, 0.075, 0.085) * (0.35 + 1.1 * dif);
    c += vec3(0.70, 0.73, 0.80) * (0.10 * pow(rv, 6.0) + 0.55 * pow(rv, 40.0));
    c += vec3(1.0, 0.48, 0.16) * pow(max(-N.y, 0.0), 1.5) * 0.45 * fl * FIRE;
    c += vec3(0.30, 0.32, 0.38) * pow(1.0 - max(N.z, 0.0), 4.0) * 0.35;
    return c;
}

void rivet(vec2 q, vec2 c, vec2 r, float fl, inout vec4 acc) {
    vec2 l = (q - c) / r;
    float d = (length(l) - 1.0) * min(r.x, r.y);
    if (d > 3.0 * PX + 0.3 * r.y) return;
    // small contact shadow below right, then the dome
    float ds = (length((q - c - vec2(0.25, -0.30) * r.y) / r) - 1.05) * min(r.x, r.y);
    over(acc, vec3(0.015), cover(ds) * 0.6);
    vec3 N = normalize(vec3(l, sqrt(max(1.0 - dot(l, l), 0.0))));
    over(acc, iron(N, fl) * 1.15, cover(d));
}

// -------------------------------------------------------------- ingredients
// Each is drawn in its own frame g (pot units, ~0.28 tall, centred).
vec4 mushroom(vec2 g) {
    vec4 a = vec4(0.0);
    // stem with a bulbous foot
    float ds = min(segment(g, vec2(0.0, -0.02), vec2(0.0, -0.11)) - 0.030 - 0.08 * max(-g.y - 0.02, 0.0),
                   length(g - vec2(0.0, -0.12)) - 0.042);
    float sx = clamp(g.x / 0.045, -1.0, 1.0);
    over(a, vec3(0.88, 0.84, 0.74) * (0.80 + 0.25 * (-sx) * 0.6 + 0.1), cover(ds));
    // gills under the cap
    float dg = ellD(g, vec2(0.0, -0.005), vec2(0.13, 0.028));
    over(a, vec3(0.80, 0.74, 0.62), cover(dg));
    // fly-agaric cap with white warts
    float dc = max(ellD(g, vec2(0.0, 0.0), vec2(0.14, 0.095)), -g.y);
    vec2 cl = g / vec2(0.14, 0.095);
    float lit = 0.70 + 0.45 * clamp(dot(normalize(vec2(cl.x, cl.y + 0.3)), vec2(-0.6, 0.8)), -1.0, 1.0);
    vec3 cap = vec3(0.74, 0.14, 0.07) * lit;
    cap = mix(cap, vec3(1.0, 0.86, 0.80), smoothstep(0.35, 0.0, length(cl - vec2(-0.35, 0.6))) * 0.35);
    float dw = min(min(length(g - vec2(-0.065, 0.035)) - 0.020, length(g - vec2(0.015, 0.068)) - 0.018),
                   min(length(g - vec2(0.075, 0.030)) - 0.016, length(g - vec2(-0.010, 0.020)) - 0.014));
    cap = mix(cap, vec3(0.95, 0.92, 0.86) * (0.8 + 0.25 * lit), cover(dw));
    over(a, cap, cover(dc));
    return a;
}

vec4 crystal(vec2 g, out float dOut) {
    vec4 a = vec4(0.0);
    vec2 ag = vec2(abs(g.x), g.y);
    float d = abs(g.x) - 0.048;
    d = max(d, dot(ag - vec2(0.0, 0.16), normalize(vec2(0.075, 0.048))));
    d = max(d, dot(ag - vec2(0.0, -0.13), normalize(vec2(0.06, -0.048))));
    dOut = d;
    // three facets on the body, brighter on the light side, plus bright tips
    float face = g.x < -0.016 ? 1.0 : (g.x < 0.016 ? 0.78 : 0.55);
    float tip = (g.y > 0.085 - 0.6 * abs(g.x) || g.y < -0.075 + 0.5 * abs(g.x)) ? 1.15 : 1.0;
    vec3 c = vec3(0.55, 0.84, 1.0) * face * tip;
    c = mix(c, vec3(0.92, 0.98, 1.0), smoothstep(0.03, 0.0, abs(g.x + 0.016)) * 0.5);   // a glinting edge
    c *= 0.85 + 0.25 * smoothstep(0.12, -0.05, g.y);
    over(a, c, cover(d));
    return a;
}

vec4 feather(vec2 g) {
    vec4 a = vec4(0.0);
    float cx = 0.018 * (g.y / 0.15) * (g.y / 0.15);          // a gently curved shaft
    float xl = g.x - cx;
    float v = (g.y - 0.02) / 0.135;
    float w = 0.058 * sqrt(max(1.0 - v * v, 0.0)) * (0.75 + 0.25 * smoothstep(1.0, 0.0, v));
    float d = xl < 0.0 ? -xl - w : xl - 0.68 * w;
    d = max(d, abs(v) - 1.0);
    // barbs run diagonally out from the shaft; a few soft brown bars
    float barb = 0.88 + 0.12 * sin((g.y - abs(xl) * 0.8) * 300.0);
    float bars = smoothstep(0.2, 0.6, sin(g.y * 48.0 + 1.0));
    vec3 c = mix(vec3(0.90, 0.86, 0.78), vec3(0.55, 0.42, 0.30), bars * 0.55) * barb;
    c *= 0.85 + 0.2 * (xl < 0.0 ? 1.0 : 0.7);
    over(a, c, cover(d));
    float dq = min(segment(g, vec2(cx, 0.15), vec2(0.0, -0.13)), segment(g, vec2(0.0, -0.13), vec2(-0.008, -0.20)));
    over(a, vec3(0.95, 0.93, 0.88), cover(dq - 0.005));
    return a;
}

float star5(vec2 p, float r, float rf) {
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

vec4 starShape(vec2 g, out float dOut) {
    vec4 a = vec4(0.0);
    float d = star5(g, 0.13, 0.45);
    dOut = d;
    // bevelled arms: the half of each arm facing the light is brighter
    float ang = atan(g.x, g.y);
    float sector = mod(ang + PI / 5.0, 2.0 * PI / 5.0) - PI / 5.0;
    float side = sector > 0.0 ? 1.0 : 0.72;
    float lit = side * (0.85 + 0.2 * dot(normalize(g + 1e-4), vec2(-0.6, 0.8)));
    vec3 c = vec3(1.0, 0.80, 0.34) * lit;
    c = mix(c, vec3(1.0, 0.97, 0.85), smoothstep(0.045, 0.0, length(g)) * 0.8);
    over(a, c, cover(d));
    return a;
}

// Elder-futhark runes in a unit box (y 0..1): algiz, tiwaz, fehu, raido.
float rune(float k, vec2 g) {
    float d;
    if (k < 0.5) {
        d = segment(g, vec2(0.0, 0.0), vec2(0.0, 1.0));
        d = min(d, min(segment(g, vec2(0.0, 0.55), vec2(-0.35, 0.95)), segment(g, vec2(0.0, 0.55), vec2(0.35, 0.95))));
    } else if (k < 1.5) {
        d = segment(g, vec2(0.0, 0.0), vec2(0.0, 1.0));
        d = min(d, min(segment(g, vec2(0.0, 1.0), vec2(-0.32, 0.68)), segment(g, vec2(0.0, 1.0), vec2(0.32, 0.68))));
    } else if (k < 2.5) {
        g.x += 0.15;
        d = segment(g, vec2(0.0, 0.0), vec2(0.0, 1.0));
        d = min(d, min(segment(g, vec2(0.0, 0.72), vec2(0.38, 0.98)), segment(g, vec2(0.0, 0.42), vec2(0.38, 0.70))));
    } else {
        g.x += 0.15;
        d = segment(g, vec2(0.0, 0.0), vec2(0.0, 1.0));
        d = min(d, segment(g, vec2(0.0, 1.0), vec2(0.32, 0.80)));
        d = min(d, segment(g, vec2(0.32, 0.80), vec2(0.0, 0.58)));
        d = min(d, segment(g, vec2(0.0, 0.58), vec2(0.34, 0.0)));
    }
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec2 O = vec2(aspect - ANCHOR.x, ANCHOR.y + 1.36 * SCALE);
    vec2 q = (p - O) / SCALE;
    PX = 1.0 / (iResolution.y * SCALE);

    // Everything (pot, fire, smoke, runes) lives inside this box.
    if (q.x < -2.0 || q.x > 2.0 || q.y < -1.5 || q.y > 4.6) return;

    float t = mod(iTime, CYCLE);
    float n = floor(iTime / CYCLE);
    vec3 colA = potion(n), colB = potion(n + 1.0);
    float prog = smoothstep(1.7, 4.6, t);          // old colour -> new colour
    vec3 potC = mix(colA, colB, prog);
    float boil = boilAt(t);
    float fl = 0.85 + 0.15 * sin(iTime * 9.1) * sin(iTime * 5.3 + 1.0);   // firelight flicker
    vec3 fireC = vec3(1.0, 0.52, 0.16);
    vec2 ip = vec2(0.12, SY + 0.015);              // where the ingredient lands

    // Potion surface pattern (computed for every pixel so the derivatives are valid).
    vec2 s = vec2(q.x / SR.x, (q.y - SY) / SR.y);
    float sr = length(s);
    float sa = atan(s.y, s.x);
    float spin = 0.35 * iTime + 5.0 * n + 5.0 * smoothstep(1.4, 6.0, t);
    float sw = sin(3.0 * (sa - spin) + 6.5 * sr);
    float swirl = smoothstep(1.4, 2.2, t) * (1.0 - smoothstep(4.8, 6.2, t));
    float th = 0.93 - 0.55 * swirl;
    float fwS = fwidth(sw) + 1e-3;
    float streak = smoothstep(th - fwS, th + fwS, sw);
    float front = prog * 1.45 - (sr + 0.25 * (sw * 0.5 + 0.5));
    float mNew = clamp(0.5 + front / (fwidth(front) + 1e-3), 0.0, 1.0);
    float rsI = length(s - vec2(ip.x / SR.x, (ip.y - SY) / SR.y));
    float fwR = fwidth(rsI) + 1e-3;

    vec4 acc = vec4(0.0);
    vec3 add = vec3(0.0);

    // ---------------------------------------------------------------- fire
    if (q.y < -0.55 && abs(q.x) < 1.3) {
        // warm light pooled on the ground
        vec2 gq = (q - vec2(0.0, GROUND + 0.02)) / vec2(0.85, 0.18);
        add += fireC * 0.16 * fl * FIRE * exp(-2.0 * dot(gq, gq));

        // the third leg, at the back, half hidden by the flames
        float dbl = segment(q, vec2(0.0, -0.70), vec2(0.02, -1.08)) - 0.045;
        over(acc, iron(normalize(vec3(clamp(q.x / 0.05, -1.0, 1.0), -0.3, 0.6)), fl) * 0.8, cover(dbl));

        // two crossed logs, charred with glowing cracks toward the middle
        for (int j = 0; j < 2; j++) {
            float sgn = j == 0 ? -1.0 : 1.0;
            vec2 a = vec2(0.62 * sgn, -1.27), b = vec2(-0.52 * sgn, -1.12);
            vec2 pa = q - a, ba = b - a;
            float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
            vec2 nrm = normalize(vec2(-ba.y, ba.x));
            float across = dot(pa - ba * h, nrm) / 0.065;
            float d = length(pa - ba * h) - 0.065;
            vec3 c = vec3(0.17, 0.11, 0.075) * (0.75 + 0.4 * across);
            float hot = smoothstep(0.45, 0.85, h) * (0.6 + 0.4 * smoothstep(0.55, 0.95, sin(h * 60.0 + across * 2.0 + float(j))));
            c = mix(c, vec3(1.0, 0.42, 0.10) * fl, hot * 0.85 * FIRE);
            c = mix(c, vec3(0.42, 0.38, 0.34), smoothstep(0.08, 0.0, h) * 0.6);   // cut, ashy end
            over(acc, c, cover(d));
        }

        // flame tongues: one "heat" field, three crisp colour zones
        float heat = -10.0;
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float x0 = (fi - 2.0) * 0.17 + 0.03 * sin(fi * 7.1);
            float H = (0.70 - 0.12 * abs(fi - 2.0) - 0.08 * hash1(fi * 2.3))
                    * (0.82 + 0.18 * sin(iTime * (7.0 + fi * 1.3) + fi * 2.1) * sin(iTime * (4.3 + fi * 0.7) + fi));
            float v = (q.y - (GROUND + 0.02)) / H;
            if (v < -0.3 || v > 1.0) continue;
            float sway = 0.07 * sin(iTime * 5.5 + fi * 1.7 - v * 3.5) * v * v;
            float hw = 0.13 * sqrt(clamp((v + 0.22) / 0.35, 0.0, 1.0)) * (1.0 - v);
            heat = max(heat, (hw - abs(q.x - x0 - sway)) / 0.13);
        }
        float k1 = clamp(0.5 + heat * 0.13 / PX, 0.0, 1.0);
        float k2 = clamp(0.5 + (heat - 0.30) * 0.13 / PX, 0.0, 1.0);
        float k3 = clamp(0.5 + (heat - 0.58) * 0.13 / PX, 0.0, 1.0);
        vec3 fc = mix(mix(vec3(0.92, 0.30, 0.07), vec3(1.0, 0.60, 0.16), k2), vec3(1.0, 0.90, 0.55), k3);
        over(acc, fc * FIRE, k1 * 0.92);
        add += fireC * 0.22 * FIRE * exp(-max(-heat, 0.0) * 0.13 / 0.05) * step(-9.0, heat);

        // crackling embers that pop out sideways and drift up
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float life = 1.2 + 0.5 * hash1(fi * 3.1);
            float u = iTime / life + hash1(fi * 7.7);
            float id = floor(u), f = fract(u);
            float h1 = hash1(id * 13.1 + fi), h2 = hash1(id * 5.3 + fi * 2.0);
            float side = h1 < 0.5 ? -1.0 : 1.0;
            vec2 e0 = vec2(side * (0.15 + 0.3 * h2), GROUND + 0.12);
            vec2 ep = e0 + vec2(side * (0.35 + 0.45 * fract(h1 * 7.0)) * f + 0.04 * sin(f * 12.0 + fi), 0.75 * f - 0.15 * f * f);
            float d = length(q - ep) - 0.016 * (1.0 - 0.6 * f);
            over(acc, mix(vec3(1.0, 0.85, 0.45), vec3(1.0, 0.40, 0.10), f), cover(d) * (1.0 - f * f));
        }
    }

    // ---------------------------------------------------------------- pot body
    float dB = max(ellD(q, vec2(0.0), BODY), q.y - 0.56);
    if (dB < PX) {
        vec2 b = q / BODY;
        float nz = sqrt(max(1.0 - dot(b, b), 0.0));
        vec3 N = normalize(vec3(b.x, b.y * 0.85, nz));
        vec3 col = iron(N, fl);
        // a riveted iron band around the belly
        const float HB = 0.16;
        float rB = BODY.x * sqrt(1.0 - (HB / BODY.y) * (HB / BODY.y));
        float cphi = sqrt(max(1.0 - (q.x / rB) * (q.x / rB), 0.0));
        float yb = HB - 0.22 * rB * cphi;
        float dy = q.y - yb;
        float inBand = cover(abs(dy) - 0.042) * step(abs(q.x), rB);
        vec3 bandC = iron(normalize(N + vec3(0.0, dy * 6.0, 0.25)), fl) * 1.15;
        bandC += vec3(0.55, 0.57, 0.62) * cover(abs(dy - 0.034) - 0.007) * 0.35 * max(0.2, cphi);   // top edge catches light
        bandC *= 1.0 - 0.45 * cover(abs(dy + 0.036) - 0.006);                                        // shadowed lower edge
        col = mix(col, bandC, inBand);
        float phi = clamp(floor(asin(clamp(q.x / rB, -1.0, 1.0)) / (PI / 6.0) + 0.5), -2.0, 2.0) * (PI / 6.0);
        vec2 rc = vec2(rB * sin(phi), HB - 0.22 * rB * cos(phi));
        vec4 pc = vec4(col, 1.0);
        rivet(q, rc, vec2(0.030 * max(cos(phi), 0.3), 0.030), fl, pc);
        over(acc, pc.rgb, cover(dB));
    }

    // ---------------------------------------------------------------- rim and opening
    vec2 c0 = vec2(0.0, RY);
    float dT = ellD(q, c0, RO);
    float dRim = min(min(dT, ellD(q, c0 - vec2(0.0, LT), RO)),
                     max(abs(q.x) - RO.x, max(q.y - RY, RY - LT - q.y)));
    if (dRim < PX) {
        vec3 L = normalize(LIGHT);
        // top of the rolled lip: tube angle runs from inward-up to outward-up
        float rho = length((q - c0) / RO);
        float tt = clamp((rho - 0.86) / 0.14, 0.0, 1.0);
        float psi = mix(2.3, 0.5, tt);
        vec3 dir = normalize(vec3(q.x / RO.x, 0.0, -(q.y - RY) / RO.y) + 1e-4);
        vec3 Nt = vec3(0.0, sin(psi), 0.0) + dir * cos(psi);
        vec3 topC = iron(Nt, fl) + vec3(0.9, 0.92, 0.95) * pow(max(dot(reflect(-L, Nt), VIEW), 0.0), 70.0) * 0.9;
        topC += potC * 0.45 * pow(1.0 - tt, 2.0) * (0.8 + 0.4 * boil);     // the glowing potion lights the inner lip
        // front face of the lip
        float fx = clamp(q.x / RO.x, -1.0, 1.0);
        vec3 dirF = vec3(fx, 0.0, sqrt(max(1.0 - fx * fx, 0.0)));
        float yTop = RY - RO.y * dirF.z;
        float ff = clamp((yTop - q.y) / LT, 0.0, 1.0);
        float psiF = 0.5 - 1.9 * ff;
        vec3 Nf = vec3(0.0, sin(psiF), 0.0) + dirF * cos(psiF);
        vec3 faceC = iron(Nf, fl) + vec3(0.9, 0.92, 0.95) * pow(max(dot(reflect(-L, Nf), VIEW), 0.0), 70.0) * 0.9;
        vec3 col = mix(faceC, topC, cover(dT));

        // the opening: back wall, then the potion
        float dI = ellD(q, c0, RI);
        float kI = cover(dI);
        if (kI > 0.0) {
            float ySurf = SY + SR.y * sqrt(max(1.0 - (q.x / SR.x) * (q.x / SR.x), 0.0));
            vec3 wall = vec3(0.03, 0.03, 0.035) + potC * 0.45 * exp(-max(q.y - ySurf, 0.0) / 0.05);
            vec3 pcol = mix(colA, colB, mNew);
            pcol *= 0.62 + 0.45 * (1.0 - sr * sr);
            pcol = mix(pcol, mix(pcol, vec3(1.0), 0.5), streak * 0.8);
            pcol *= 0.72 + 0.28 * smoothstep(1.0, 0.82, sr);              // meniscus darkens at the wall
            // splash rings spreading from the impact
            float ts = t - TD;
            if (ts > 0.0 && ts < 1.4) {
                float rk = clamp(0.5 - (min(abs(rsI - (0.12 + 0.95 * ts)), abs(rsI - 0.55 * ts)) - 0.035) / fwR, 0.0, 1.0);
                pcol = mix(pcol, mix(pcol, vec3(1.0), 0.6), rk * (1.0 - ts / 1.4));
            }
            col = mix(col, mix(wall, pcol, cover(ellD(q, vec2(0.0, SY), SR))), kI);
        }
        over(acc, col, cover(dRim));
    }

    // bubbles: domes that swell and pop into a crisp ring and two tiny droplets
    float maskB = max(cover(ellD(q, c0, RI)), step(RY, q.y));
    if (abs(q.x) < 0.95 && q.y > 0.35 && q.y < 0.95) {
        vec3 L = normalize(LIGHT);
        for (int i = 0; i < BUBBLES; i++) {
            float fi = float(i);
            float per = 1.1 + 0.7 * hash1(fi * 1.7);
            float ph = hash1(fi * 9.3);
            float u = iTime / per + ph;
            float id = floor(u), f = fract(u);
            float hs = fi * 17.0 + id * 3.1;
            float bb = boilAt(mod((id - ph) * per, CYCLE));          // boil level when it was born
            if (hash1(hs) > 0.40 + 0.60 * bb) continue;
            float a = 6.2831 * hash1(hs + 1.0), rr = 0.80 * sqrt(hash1(hs + 2.0));
            vec2 sp = vec2(SR.x * rr * cos(a), SY + SR.y * rr * sin(a));
            float big = (0.045 + 0.045 * hash1(hs + 3.0)) * (1.0 + 0.6 * bb);
            if (length(q - sp) > big * 4.5) continue;
            if (f < 0.78) {
                float g = smoothstep(0.0, 0.7, f);
                float rb = big * (0.25 + 0.75 * g) * (1.0 + 0.15 * smoothstep(0.6, 0.78, f));
                vec2 bc = sp + vec2(0.0, rb * 0.35);
                float cut = sp.y - 0.15 * rb;
                float d = max(length(q - bc) - rb, cut - q.y);
                vec2 l = (q - bc) / rb;
                float edge = smoothstep(0.55, 1.0, length(l));
                vec3 c = mix(potC * 0.95, mix(potC, vec3(1.0), 0.5), edge * 0.8);
                c = mix(c, vec3(1.0, 0.99, 0.96), cover((length(l - vec2(-0.38, 0.42)) - 0.20) * rb) * 0.9);
                c *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.10 * rb, q.y - cut));
                over(acc, c, cover(d) * 0.92 * maskB);
            } else {
                float tb = (f - 0.78) / 0.22;
                float Rr = big * (1.0 + 2.6 * tb);
                float dr = abs(ellD(q, sp, vec2(Rr, Rr * SR.y / SR.x))) - 0.010;
                vec3 rc = mix(potC, vec3(1.0), 0.55);
                over(acc, rc, cover(dr) * (1.0 - tb) * maskB);
                for (int k = 0; k < 2; k++) {
                    float sd = k == 0 ? -1.0 : 1.0;
                    vec2 dp = sp + vec2(sd * (0.10 + 0.08 * hash1(hs + 5.0 + float(k))) * tb, 0.55 * tb - 0.9 * tb * tb + 0.03);
                    over(acc, rc, cover(length(q - dp) - 0.014) * (1.0 - tb));
                }
            }
        }
    }

    // ---------------------------------------------------------------- legs
    for (int j = 0; j < 2; j++) {
        float sg = j == 0 ? -1.0 : 1.0;
        vec2 A = vec2(0.60 * sg, -0.60), F = vec2(0.80 * sg, -1.24);
        if (abs(q.x - 0.7 * sg) > 0.32 || q.y > -0.40 || q.y < -1.40) continue;
        vec2 pa = q - A, ba = F - A;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float r = mix(0.085, 0.050, h);
        vec2 perp = normalize(vec2(-ba.y, ba.x)) * sg;
        float across = clamp(dot(pa - ba * h, perp) / r, -1.0, 1.0);
        float dl = length(pa - ba * h) - r;
        vec3 N = normalize(vec3(perp * across * sg, sqrt(max(1.0 - across * across, 0.0))));
        // claw foot turned outward
        float df = ellD(q, F + vec2(0.05 * sg, -0.035), vec2(0.115, 0.045));
        if (df < dl) N = normalize(vec3((q - F - vec2(0.05 * sg, -0.035)) / vec2(0.115, 0.045) * vec2(0.6, 1.0), 0.6));
        vec3 c = iron(N, fl);
        c += fireC * 0.30 * fl * FIRE * max(dot(N.xy, vec2(-sg, 0.0)), 0.0);   // the side facing the fire
        float dLeg = min(dl, df);
        over(acc, c, cover(dLeg));
        // riveted strap holding the leg to the belly
        vec2 pq = q - (A + vec2(0.0, 0.05));
        float dp = length(max(abs(pq) - vec2(0.10, 0.07), 0.0)) - 0.025;
        vec3 Np = normalize(vec3(A.x * 0.9, -0.5, 0.75) + vec3(0.0, clamp(pq.y / 0.08, -1.0, 1.0) * 0.4, 0.0));
        over(acc, iron(Np, fl) * 1.1, cover(dp));
        rivet(q, A + vec2(-0.055, 0.075), vec2(0.026), fl, acc);
        rivet(q, A + vec2(0.055, 0.075), vec2(0.026), fl, acc);
        rivet(q, A + vec2(0.0, 0.0), vec2(0.026), fl, acc);
    }

    // ---------------------------------------------------------------- the falling ingredient
    if (t < TD + 0.2 && abs(q.x - ip.x) < 0.6 && q.y > SY - 0.1) {
        float kind = mod(n, 4.0);
        float x = clamp(t / TD, 0.0, 1.0);
        float y = t < TD ? ip.y + 2.7 * (1.0 - x * x) : ip.y - 4.2 * (t - TD);
        vec2 pos = vec2(ip.x, y);
        float ang;
        if (kind < 0.5)      ang = 0.35 * sin(t * 2.2) + 0.9 * t;
        else if (kind < 1.5) ang = 2.4 * t + 0.4;
        else if (kind < 2.5) { ang = 0.7 * sin(t * 3.6) + 0.3; pos.x += 0.20 * sin(t * 3.6) * (1.0 - x); }
        else                 ang = 2.8 * t;
        vec2 g = rot(q - pos, -ang) / 1.45;   // ingredients are drawn ~0.4 tall
        float glowD = 10.0;
        vec4 ing;
        if (kind < 0.5)      ing = mushroom(g);
        else if (kind < 1.5) ing = crystal(g, glowD);
        else if (kind < 2.5) ing = feather(g);
        else                 ing = starShape(g, glowD);
        float vis = smoothstep(0.0, 0.3, t) * cover(ip.y - q.y);     // it vanishes below the surface
        acc.rgb = ing.rgb * vis + acc.rgb * (1.0 - ing.a * vis);
        acc.a = ing.a * vis + acc.a * (1.0 - ing.a * vis);
        vec3 gc = kind < 1.5 ? vec3(0.5, 0.8, 1.0) : vec3(1.0, 0.78, 0.35);
        add += gc * 0.45 * exp(-max(glowD, 0.0) * 1.45 / 0.06) * vis * step(glowD, 9.0);
    }

    // ---------------------------------------------------------------- splash: crown droplets and a jet
    float ts = t - TD;
    if (ts > 0.0 && ts < 0.8 && abs(q.x - ip.x) < 1.0 && q.y > SY - 0.1 && q.y < SY + 0.9) {
        vec3 dc = mix(colA, vec3(1.0), 0.25);
        for (int i = 0; i < 8; i++) {
            float fi = float(i);
            float a = fi / 8.0 * 2.0 * PI + 0.3;
            float hh = hash1(fi * 4.3 + n);
            vec2 vel = vec2(cos(a) * (0.9 + 0.5 * hh), 2.1 + 0.5 * hh + 0.25 * sin(a));
            vec2 dp = ip + vel * ts + vec2(0.0, -3.6 * ts * ts);
            vec2 vv = vel + vec2(0.0, -7.2 * ts);
            float d = segment(q, dp, dp - vv * 0.03) - 0.030 * (1.0 - ts / 0.9);
            over(acc, dc, cover(d) * step(SY, dp.y));
        }
        if (ts > 0.12 && ts < 0.7) {
            float hj = 0.42 * sin(PI * (ts - 0.12) / 0.58);
            float d = min(segment(q, ip, ip + vec2(0.0, hj)) - 0.035, length(q - ip - vec2(0.0, hj + 0.05)) - 0.045);
            over(acc, mix(dc, vec3(1.0), 0.15), cover(d));
        }
    }

    // ---------------------------------------------------------------- vapour wisps
    if (abs(q.x) < 0.9 && q.y > SY + 0.1 && q.y < SY + 1.5) {
        vec3 vc = mix(potC, vec3(0.92), 0.5);
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            float yy = q.y - (SY + 0.12);
            float cx = (fj - 1.0) * 0.32 + (0.05 + 0.10 * yy) * sin(3.2 * yy - iTime * 1.3 + fj * 2.1);
            float d = abs(q.x - cx) - (0.012 + 0.03 * yy);
            float seg = smoothstep(0.15, 0.55, sin(6.5 * yy - iTime * 2.2 + fj * 1.9));
            float k = cover(d) * seg * (1.0 - yy / 1.35) * smoothstep(0.0, 0.15, yy);
            over(acc, vc, k * (0.16 + 0.18 * boil));
        }
    }

    // ---------------------------------------------------------------- the poof
    float tp = t - TP;
    if (tp > 0.0 && tp < 4.4) {
        float e1 = 1.0 - pow(1.0 - clamp(tp / 1.0, 0.0, 1.0), 3.0);    // fast burst, then a slow drift
        float grow = 0.35 + 0.65 * e1 + 0.12 * tp;
        vec2 pc = vec2(0.05, SY + 0.40 + 0.85 * e1 + 0.22 * tp);
        float fade = 1.0 - smoothstep(2.6, 4.2, tp);
        vec3 smC = mix(colB, vec3(0.80, 0.79, 0.84), 0.50);
        vec3 Ls = normalize(vec3(-0.45, 0.60, 0.66));
        if (abs(q.x - pc.x) < 1.7 * grow + 0.2 && q.y < pc.y + 1.5 * grow + 0.6) {
            vec4 sm = vec4(0.0);
            float shrink = 1.0 - 0.3 * smoothstep(2.6, 4.2, tp);
            // billows, top to bottom so the lower ones overlap the upper ones;
            // the first two form a short stem that rises out of the pot and thins away
            for (int i = 0; i < 13; i++) {
                float fi = float(i);
                vec2 cc; float rr;
                if (i < 2) {
                    // a short column joining the potion to the puff; it thins and rises away
                    float st = 1.0 - smoothstep(0.4, 1.5, tp);
                    float y0 = SY + 0.05 + 1.2 * smoothstep(0.4, 1.5, tp), y1 = pc.y - 0.3 * grow;
                    if (fi > 0.5 || st <= 0.0 || y1 <= y0) continue;
                    float hc = clamp((q.y - y0) / (y1 - y0), 0.0, 1.0);
                    float wc = mix(0.10, 0.22, hc * hc) * grow * st;
                    float xc = 0.03 + 0.05 * sin(hc * 3.0 + tp * 2.0);
                    float d = max(abs(q.x - xc) - wc, max(y0 - q.y, q.y - y1 - 0.2));
                    over(sm, smC * (0.62 + 0.1 * hc) + colB * 0.25, cover(d));
                    continue;
                } else {
                    float k = (fi - 2.0) / 10.0;
                    float h1 = hash1(fi * 3.7 + n * 1.3), h2 = hash1(fi * 5.9 + n * 2.1);
                    float sx = mod(fi, 2.0) * 2.0 - 1.0;
                    vec2 off = vec2(sx * (0.08 + 0.55 * h1) * (1.0 - 0.45 * abs(k * 2.0 - 1.0)), mix(0.40, -0.35, k) + 0.08 * (h2 - 0.5));
                    cc = pc + off * grow * (1.0 + 0.12 * tp) + vec2(0.0, 0.08 * tp * (1.0 - k));
                    rr = (0.20 + 0.16 * h2) * grow * shrink * (1.0 + 0.25 * (1.0 - k));   // bigger lobes on top
                }
                vec2 l = (q - cc) / rr;
                float d = (length(l) - 1.0) * rr;
                if (d > PX) continue;
                // Soft, broad shading for the whole puff (lighter on top), and on each
                // billow a light upper-left edge and a slightly shaded lower-right side,
                // so the overlapping billows read as crisp-edged lobes, not balls.
                float ll = length(l);
                vec2 ln = l / max(ll, 1e-3);
                float vert = clamp((q.y - pc.y) / (1.6 * grow) + 0.5, 0.0, 1.0);
                float lit = 0.66 + 0.30 * vert;
                lit += 0.22 * smoothstep(0.72, 0.97, ll) * max(dot(ln, vec2(-0.55, 0.83)), 0.0);
                lit -= 0.16 * smoothstep(0.35, 1.0, ll) * max(dot(ln, vec2(0.55, -0.83)), 0.0);
                vec3 c = smC * lit + colB * 0.30 * (1.0 - vert) * smoothstep(0.3, 1.0, ll) * max(-ln.y, 0.0);
                over(sm, c, cover(d));
            }
            sm *= SMOKE * fade;   // fades as a whole so the edges stay crisp
            acc = sm + acc * (1.0 - sm.a);
        }

        // sparkles: four-pointed glints that twinkle around the puff
        vec3 spC = mix(vec3(1.0, 0.97, 0.90), colB, 0.25);
        for (int i = 0; i < 8; i++) {
            float fi = float(i);
            float t0 = 0.15 + 0.32 * fi;
            float tau = tp - t0;
            if (tau < 0.0 || tau > 1.3) continue;
            float env = sin(PI * tau / 1.3);
            float h1 = hash1(fi * 2.9 + n * 1.7), h2 = hash1(fi * 6.1 + n * 0.9), h3 = hash1(fi * 8.3 + n);
            vec2 sp = pc + vec2((h1 * 2.0 - 1.0) * 1.35, (h2 * 2.0 - 1.0) * 0.75 + 0.2) * grow + vec2(0.0, 0.25 * tau);
            vec2 l = abs(rot(q - sp, h3 > 0.5 ? 0.0 : 0.785 * 0.3));
            if (l.x + l.y > 0.25) continue;
            float sz = 0.10 * env * (0.7 + 0.5 * h3);
            float f = sqrt(l.x) + sqrt(l.y) - sqrt(sz);
            float gr = 0.5 * sqrt(1.0 / (l.x + 1e-5) + 1.0 / (l.y + 1e-5));
            over(acc, spC, cover(f / gr) * env);
            add += colB * 0.35 * env * exp(-length(q - sp) / 0.035);
        }

        // runes that rise out of the smoke and fade
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            float tau = tp - (0.35 + 0.45 * fj);
            if (tau < 0.0 || tau > 3.4) continue;
            float env = smoothstep(0.0, 0.4, tau) * (1.0 - smoothstep(2.4, 3.4, tau));
            vec2 rp = pc + vec2((fj - 1.0) * 0.80 * grow, -0.15 + 0.2 * mod(fj, 2.0))
                         + vec2(0.08 * sin(tau * 1.8 + fj), 0.42 * tau);
            vec2 g = (q - rp) / 0.26 + vec2(0.0, 0.5);
            if (abs(g.x) > 0.8 || g.y < -0.3 || g.y > 1.3) continue;
            float d = rune(mod(n + fj, 4.0), g) * 0.26 - 0.013;
            over(acc, mix(colB, vec3(1.0), 0.55), cover(d) * env * 0.95);
            add += colB * 0.45 * env * exp(-max(d, 0.0) / 0.03);
        }
    }

    // a little light spilling over the rim from the glowing potion
    if (q.y > RY - 0.2 && abs(q.x) < 1.2) {
        vec2 gq = (q - vec2(0.0, RY + 0.05)) / vec2(0.75, 0.30);
        add += potC * (0.06 + 0.06 * boil) * exp(-2.0 * dot(gq, gq)) * (1.0 - acc.a);
    }

    vec3 rgb = base.rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY + add * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
