// gifts — a big wrapped present shakes, hops, pops its lid and bursts into a fountain of light, while small presents float behind.
// zh: 礼物
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off); opacity of the big present
const float CYCLE     = 10.3;   // seconds per present: sit, shake, open, glow, next present
const float BOXSIZE   = 0.155;  // one box unit in window heights (box + lid is ~1.75 units, ~27%)
const float GLOW      = 1.0;    // strength of the light burst
const float FLOATERS  = 0.50;   // opacity of the small background presents
const int   SPARKS    = 24;     // stars + confetti in the burst

// Timeline inside one cycle (seconds).
const float T_POP  = 5.20;      // lid pops off
const float T_FADE = 8.80;      // present starts to fade away
const float T_GONE = 9.90;      // fully gone; the next one drops in at the cycle start

#define PI 3.14159265

// Box geometry in box units, slight 3/4 view: front face, a side face to the
// right and the lid top receding along DEP. Origin = bottom of the box.
const vec2  DEP = vec2(0.55, 0.32);
const float FX0 = -1.05;
const float FX1 = 0.55;
const float BH  = 1.15;
const float LX0 = -1.12;        // the lid overhangs the box a little
const float LX1 = 0.62;
const float LY0 = 1.08;
const float LY1 = 1.42;
const float XC  = -0.25;        // ribbon centre on the front faces
const vec2  BOWC = vec2(0.025, 1.58);   // centre of the lid top, where the bow sits
const vec2  LIDC = vec2(-0.15, 1.45);   // lid pivot when it spins away

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Parallelogram o + a*e1 + b*e2 with a, b in [0, 1]. Returns (coverage, a, b);
// the edge distance uses the true gaps between opposite edges so AA stays even.
vec3 para(vec2 q, vec2 o, vec2 e1, vec2 e2, float aa) {
    vec2 r = q - o;
    float det = e1.x * e2.y - e1.y * e2.x;
    float a = (r.x * e2.y - r.y * e2.x) / det;
    float b = (e1.x * r.y - e1.y * r.x) / det;
    float d = min(min(a, 1.0 - a) * abs(det) / length(e2),
                  min(b, 1.0 - b) * abs(det) / length(e1));
    return vec3(smoothstep(-aa, aa, d), a, b);
}

// Satin ribbon across its width (w = -1..1): rounded body, a glossy stripe
// toward the light (upper left) and slightly darker edges.
vec3 satin(vec3 rib, float w) {
    float body = 0.70 + 0.30 * (1.0 - w * w);
    float hl = smoothstep(0.35, 0.0, abs(w + 0.35));
    float edge = smoothstep(0.80, 1.0, abs(w));
    return rib * body * (1.0 - 0.25 * edge) + vec3(0.45) * hl;
}

// Staggered polka dots printed on the wrapping paper.
float dots(vec2 uv, float aa) {
    uv.x += 0.5 * mod(floor(uv.y), 2.0);
    return smoothstep(aa, -aa, length(fract(uv) - 0.5) - 0.16);
}

vec3 paperPrint(vec3 paper, vec2 uv, float aa) {
    return mix(paper, min(paper * 1.35 + 0.18, vec3(1.0)), 0.55 * dots(uv * 2.8, aa * 2.8));
}

// Paint c over the premultiplied accumulator with coverage a.
void over(inout vec4 acc, vec3 c, float a) {
    acc.rgb = mix(acc.rgb, c, a);
    acc.a = mix(acc.a, 1.0, a);
}

// One loop of the bow (m is mirrored so x >= 0). Teardrop pinched toward the
// knot, shadowed inside its opening, with a glossy highlight along the top.
vec4 bowLoop(vec2 m, vec2 c, float ang, vec2 r, vec3 rib, float aa) {
    vec2 lp = rot(-ang) * (m - c);
    float taper = mix(0.45, 1.0, smoothstep(-r.x, 0.1 * r.x, lp.x));
    vec2 e = lp / vec2(r.x, r.y * taper);
    float len = length(e);
    float cov = smoothstep(aa, -aa, (len - 1.0) * r.y * taper);
    float shade = 0.62 + 0.38 * clamp(e.y * 0.6 + 0.5, 0.0, 1.0);
    float fold = smoothstep(0.55, 0.20, length((e - vec2(-0.25, -0.15)) * vec2(1.0, 1.6)));
    vec3 col = rib * shade * (1.0 - 0.5 * fold);
    float hl = smoothstep(0.2, 0.0, abs(len - 0.70)) * smoothstep(0.0, 0.6, e.y)
             * smoothstep(-0.6, 0.2, e.x);
    col += vec3(0.55) * hl;
    col *= 0.8 + 0.2 * smoothstep(1.0, 0.85, len);
    return vec4(col, cov);
}

// A hanging ribbon tail from the knot to e, bent sideways, with a V notch.
vec4 bowTail(vec2 bq, vec2 e, float bend, vec3 rib, float aa) {
    float L = length(e);
    vec2 dir = e / L;
    vec2 n = vec2(-dir.y, dir.x);
    float along = dot(bq, dir);
    float h = clamp(along / L, 0.0, 1.0);
    float side = dot(bq, n) - bend * sin(PI * h);
    float hw = mix(0.085, 0.07, h);
    float w = clamp(side / hw, -1.0, 1.0);
    float d = max(abs(side) - hw, along - (L - 0.09 * (1.0 - abs(w))));
    d = max(d, -along);
    vec3 col = satin(rib, w) * (0.95 - 0.30 * h) * (0.85 + 0.15 * cos(h * 5.0));
    return vec4(col, smoothstep(aa, -aa, d));
}

// The whole present. q is in box units. The lid can be offset and spun away
// (lidOff, lidAng) and faded (lidFade); glow lights up the open box from
// inside. full = false skips the small details (back loops, tag) for the
// little background presents. Returns premultiplied colour + coverage.
vec4 drawGift(vec2 q, vec3 paper, vec3 rib, vec2 lidOff, float lidAng, float lidFade,
              float glow, float swing, float aa, bool full) {
    vec4 acc = vec4(0.0);
    float lidNear = lidFade * (1.0 - smoothstep(0.0, 0.35, length(lidOff)));

    // ---- Box body ----
    if (q.x > -1.25 && q.x < 1.25 && q.y > -0.1 && q.y < 1.6) {
        // Side face (in shade), ribbon running down its middle.
        vec3 s = para(q, vec2(FX1, 0.0), DEP, vec2(0.0, BH), aa);
        if (s.x > 0.0) {
            vec3 c = paperPrint(paper, vec2(s.y * 0.64, s.z * BH), aa) * mix(0.58, 0.44, s.y);
            c *= (0.85 + 0.15 * s.z) * (1.0 - 0.35 * lidNear * smoothstep(0.75, 0.95, s.z));
            float off = (s.y - 0.5) * DEP.x;
            float band = smoothstep(aa, -aa, abs(off) - 0.075);
            c = mix(c, satin(rib, off / 0.075) * 0.6, band);
            over(acc, c, s.x);
        }
        // Front face (lit), darker toward the floor and under the lid.
        vec3 f = para(q, vec2(FX0, 0.0), vec2(FX1 - FX0, 0.0), vec2(0.0, BH), aa);
        if (f.x > 0.0) {
            vec3 c = paperPrint(paper, q, aa) * (0.80 + 0.18 * f.z);
            float off = q.x - XC;
            float band = smoothstep(aa, -aa, abs(off) - 0.13);
            c = mix(c, satin(rib, off / 0.13), band);
            c *= 0.80 + 0.20 * smoothstep(0.0, 0.18, q.y);
            c *= 1.0 - 0.40 * lidNear * smoothstep(0.24, 0.0, LY0 - q.y);
            c += vec3(0.10) * smoothstep(0.05, 0.0, FX1 - q.x) * f.x;   // rim light on the corner
            over(acc, c, f.x);
        }
        // Opening at the top: dark inside, lit up by the gift's own light.
        vec3 o = para(q, vec2(FX0, BH), vec2(FX1 - FX0, 0.0), DEP, aa);
        if (o.x > 0.0) {
            vec3 c = mix(paper * 0.10, paper * 0.32, o.z);
            float g = glow * (1.15 - 0.9 * length(vec2(o.y - 0.5, o.z - 0.5)) * 2.0);
            c = mix(c, vec3(1.0, 0.88, 0.55), clamp(g, 0.0, 1.0));
            over(acc, c, o.x);
        }
    }

    // ---- Lid group (lid, bow, tag) ----
    if (lidFade > 0.0) {
        vec2 ql = rot(-lidAng) * (q - lidOff - LIDC) + LIDC;
        if (ql.x > -1.45 && ql.x < 1.3 && ql.y > 0.55 && ql.y < 2.25) {
            vec4 lid = vec4(0.0);
            // Lid side.
            vec3 s = para(ql, vec2(LX1, LY0), DEP, vec2(0.0, LY1 - LY0), aa);
            if (s.x > 0.0) {
                vec3 c = paper * mix(0.56, 0.46, s.y) * (0.9 + 0.1 * s.z);
                float off = (s.y - 0.5) * DEP.x;
                c = mix(c, satin(rib, off / 0.075) * 0.6, smoothstep(aa, -aa, abs(off) - 0.075));
                over(lid, c, s.x);
            }
            // Lid front, with a darker lip along the bottom.
            vec3 f = para(ql, vec2(LX0, LY0), vec2(LX1 - LX0, 0.0), vec2(0.0, LY1 - LY0), aa);
            if (f.x > 0.0) {
                vec3 c = paperPrint(paper, ql, aa) * (0.92 + 0.10 * f.z);
                float off = ql.x - XC;
                c = mix(c, satin(rib, off / 0.13), smoothstep(aa, -aa, abs(off) - 0.13));
                c *= 0.75 + 0.25 * smoothstep(0.0, 0.06, ql.y - LY0);
                over(lid, c, f.x);
            }
            // Lid top (brightest face), ribbons crossing, soft shadow of the bow.
            vec3 t = para(ql, vec2(LX0, LY1), vec2(LX1 - LX0, 0.0), DEP, aa);
            if (t.x > 0.0) {
                vec3 c = paperPrint(paper, vec2(t.y * (LX1 - LX0), t.z * 0.64), aa);
                c *= 1.10 - 0.12 * t.z;
                float offB = (t.z - 0.5) * 0.64;
                c = mix(c, satin(rib, offB / 0.12) * 1.05, smoothstep(aa, -aa, abs(offB) - 0.12));
                float offA = (t.y - 0.5) * (LX1 - LX0);
                c = mix(c, satin(rib, offA / 0.13) * 1.05, smoothstep(aa, -aa, abs(offA) - 0.13));
                vec2 sd = (ql - BOWC - vec2(0.10, -0.04)) / vec2(0.55, 0.22);
                c *= 1.0 - 0.35 * exp(-2.5 * dot(sd, sd));
                over(lid, c, t.x);
            }

            vec2 bq = ql - BOWC;
            // Tag on a string, hanging over the front-left corner.
            if (full && ql.x < -0.3) {
                vec2 P = vec2(-0.72, 1.12);
                float tagAng = 0.28 + swing;
                vec2 hole = P;
                vec2 sg = ql - vec2(-0.08, 1.57);
                vec2 sb = hole - vec2(-0.08, 1.57);
                float hh = clamp(dot(sg, sb) / dot(sb, sb), 0.0, 1.0);
                float str = smoothstep(aa, -aa, length(sg - sb * hh) - 0.012);
                over(lid, rib * 0.85, str);
                vec2 tq = rot(-tagAng) * (ql - P);
                float d = max(sdBox(tq - vec2(0.0, -0.135), vec2(0.12, 0.195)),
                              tq.y + 0.8 * abs(tq.x) - 0.08);
                float tag = smoothstep(aa, -aa, d);
                if (tag > 0.0) {
                    vec3 c = vec3(0.98, 0.93, 0.80) * (0.88 + 0.12 * smoothstep(-0.33, 0.0, tq.y));
                    c *= 1.0 - 0.6 * smoothstep(aa, -aa, abs(length(tq) - 0.028) - 0.012);
                    float ink = smoothstep(aa, -aa, abs(tq.y + 0.17) - 0.012) * step(abs(tq.x), 0.075)
                              + smoothstep(aa, -aa, abs(tq.y + 0.24) - 0.012) * step(abs(tq.x), 0.05);
                    c = mix(c, rib * 0.45 + paper * 0.25, ink * 0.8);
                    c *= 0.85 + 0.15 * smoothstep(aa * 4.0, 0.0, -d);   // thin darker rim
                    over(lid, c, tag);
                }
            }
            // Bow: tails first, then the back loops, the front loops and the knot.
            if (bq.y > -0.75 && bq.y < 0.62 && abs(bq.x) < 0.8) {
                vec4 tl = bowTail(bq, vec2(-0.36, -0.60), -0.06, rib, aa);
                over(lid, tl.rgb, tl.a);
                tl = bowTail(bq, vec2(0.24, -0.66), 0.06, rib, aa);
                over(lid, tl.rgb, tl.a);
                vec2 m = vec2(abs(bq.x), bq.y);
                if (full) {
                    vec4 bl = bowLoop(m, vec2(0.20, 0.27), 1.0, vec2(0.27, 0.15), rib, aa);
                    over(lid, bl.rgb * 0.62, bl.a);
                }
                vec4 lp = bowLoop(m, vec2(0.33, 0.15), 0.38, vec2(0.36, 0.20), rib, aa);
                over(lid, lp.rgb, lp.a);
                vec2 e = (bq - vec2(0.0, 0.03)) / vec2(0.12, 0.10);
                float kc = smoothstep(aa, -aa, (length(e) - 1.0) * 0.10);
                vec3 kcol = rib * (0.72 + 0.28 * clamp(e.y * 0.5 + 0.5, 0.0, 1.0))
                          + vec3(0.5) * smoothstep(0.5, 0.0, length(e - vec2(-0.3, 0.4)));
                over(lid, kcol, kc);
            }
            acc.rgb = acc.rgb * (1.0 - lid.a * lidFade) + lid.rgb * lidFade;
            acc.a = acc.a * (1.0 - lid.a * lidFade) + lid.a * lidFade;
        }
    }
    return acc;
}

// Wrapping paper + ribbon colour schemes; a different one each cycle.
void palette(float i, out vec3 paper, out vec3 rib) {
    int k = int(mod(i, 6.0));
    if (k == 0)      { paper = vec3(0.82, 0.10, 0.14); rib = vec3(1.00, 0.80, 0.32); }   // red / gold
    else if (k == 1) { paper = vec3(0.14, 0.32, 0.82); rib = vec3(0.92, 0.94, 1.00); }   // blue / silver
    else if (k == 2) { paper = vec3(0.08, 0.55, 0.32); rib = vec3(0.95, 0.20, 0.24); }   // green / red
    else if (k == 3) { paper = vec3(0.52, 0.22, 0.78); rib = vec3(1.00, 0.82, 0.36); }   // purple / gold
    else if (k == 4) { paper = vec3(0.06, 0.62, 0.68); rib = vec3(1.00, 0.52, 0.70); }   // teal / pink
    else             { paper = vec3(0.94, 0.90, 0.82); rib = vec3(0.86, 0.12, 0.18); }   // cream / red
}

// Light adds on dark themes; on light themes it tints instead.
vec3 addLight(vec3 rgb, vec3 col, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(rgb, col * 0.6, a * 0.8) : rgb + col * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec3 rgb = base.rgb;

    // Shift the clock so the first present is already sitting there at start.
    float T = iTime + 0.9;
    float cyc = floor(T / CYCLE);
    float t = T - cyc * CYCLE;

    // ---- Small presents floating in the background ----
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec3 f = i == 0 ? vec3(0.50, 0.22, 0.050)
               : i == 1 ? vec3(0.68, 0.57, 0.042)
               : i == 2 ? vec3(0.89, 0.80, 0.036)
               : i == 3 ? vec3(0.27, 0.13, 0.040)
               :          vec3(0.86, 0.50, 0.030);
        vec2 c = vec2(f.x * aspect + 0.025 * sin(iTime * 0.23 + fi * 2.1),
                      f.y + 0.022 * sin(iTime * 0.7 + fi * 1.9));
        vec2 d = p - c;
        if (dot(d, d) > 2.2 * f.z * f.z * 1.6) continue;          // cheap bounding circle
        float ang = 0.38 * sin(iTime * 0.31 + fi * 2.3);
        vec2 q = rot(-ang) * d / f.z + vec2(-0.05, 0.95);
        vec3 paper, rib;
        palette(fi + 2.0, paper, rib);
        vec4 g = drawGift(q, paper, rib, vec2(0.0), 0.0, 1.0, 0.0, 0.0,
                          1.5 / (iResolution.y * f.z), false);
        float k = FLOATERS * INTENSITY;
        rgb = rgb * (1.0 - g.a * k) + g.rgb * k;
    }

    // ---- The big present: motion for this moment of the cycle ----
    float S = BOXSIZE;
    vec2 anchor = vec2(aspect - 0.27, 0.07);
    float alpha = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(T_FADE, T_GONE, t));
    float yoff = 0.0, ang = 0.0, sq = 0.0, lift = 0.0;

    // Drop in at the start, then a jelly-like settle.
    if (t < 0.55) yoff = 0.9 * (1.0 - (t / 0.55) * (t / 0.55));
    else { float u = t - 0.55; sq += 0.12 * sin(u * 2.0 * PI * 1.6) * exp(-5.0 * u); }

    // Anticipation: a nervous wiggle, then three hops getting bigger; the lid
    // lifts a little on each hop and light leaks out underneath.
    float wig = smoothstep(3.0, 3.35, t) * (1.0 - smoothstep(3.55, 3.85, t));
    ang += 0.06 * wig * sin((t - 3.0) * 24.0);
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float st = 3.85 + 0.45 * fk;
        float dur = 0.36 + 0.02 * fk;
        float h = 0.12 + 0.09 * fk;
        float u = (t - st) / dur;
        if (u > 0.0 && u < 1.0) {
            yoff += h * 4.0 * u * (1.0 - u);
            ang += 0.05 * (mod(fk, 2.0) < 0.5 ? 1.0 : -1.0) * sin(PI * u);
            lift += (0.05 + 0.05 * fk) * sin(PI * u) * sin(PI * u);
        }
        float cr = (t - st + 0.04) / 0.06;                         // crouch before take-off
        float ld = (t - st - dur - 0.05) / 0.07;                   // squash after landing
        sq += (h / 0.30) * (0.07 * exp(-cr * cr) + 0.09 * exp(-ld * ld));
    }
    float tau = t - T_POP;
    float pop = (t - T_POP + 0.02) / 0.07;
    sq -= 0.06 * exp(-pop * pop);                                  // recoil stretch as the lid flies

    vec2 lidOff = vec2(0.0, lift);
    float lidAng = 0.0, lidFade = 1.0;
    if (tau > 0.0) {
        lidOff = vec2(-1.1 * tau, 6.2 * tau - 4.8 * tau * tau);    // thrown up and a little to the left
        lidAng = 2.6 * tau;
        lidFade = 1.0 - smoothstep(1.1, 1.9, tau);
    }
    float burst = tau > 0.0 ? smoothstep(0.0, 0.15, tau) * (1.0 - smoothstep(2.6, 3.6, tau)) : 0.0;
    float glow = 0.35 * smoothstep(3.8, 5.1, t) + burst;
    float swing = 0.04 * sin(t * 1.6) - 3.0 * ang + 0.25 * sin(t * 11.0) * smoothstep(3.0, 3.6, t)
                * (1.0 - smoothstep(4.9, 5.2, t));

    if (alpha > 0.0) {
        vec2 q = (p - anchor) / S;
        // Floor shadow, smaller and lighter while the box is in the air.
        vec2 sh = (q - vec2(0.05, 0.0)) / vec2(1.35 * (1.0 - 0.25 * yoff), 0.16);
        rgb *= 1.0 - 0.35 * alpha * INTENSITY * smoothstep(1.0, 0.3, length(sh)) / (1.0 + yoff * 2.0);

        q.y -= yoff;
        q = rot(-ang) * (q - vec2(-0.25, 0.0)) + vec2(-0.25, 0.0);
        q.y /= 1.0 - sq;
        q.x /= 1.0 + 0.5 * sq;

        float aa = 1.5 / (iResolution.y * S);
        vec3 paper, rib;
        palette(cyc, paper, rib);
        vec4 g = drawGift(q, paper, rib, lidOff, lidAng, lidFade, glow, swing, aa, true);

        // A shine sweeps across the present while it sits.
        float sw = (t - 1.4) * 2.4 - 1.6;
        float sb = exp(-pow((q.x + 0.5 * q.y - sw) / 0.18, 2.0)) * step(1.2, t) * step(t, 3.2);
        g.rgb += g.a * vec3(0.22) * sb;

        float k = alpha * INTENSITY;
        rgb = rgb * (1.0 - g.a * k) + g.rgb * k;

        // Light leaking from under the lid while it rattles.
        vec2 lk = (q - vec2(-0.2, LY0 + lift * 0.5)) / vec2(1.1, 0.10 + lift);
        rgb = addLight(rgb, vec3(1.0, 0.82, 0.45), lift * 4.0 * exp(-dot(lk, lk) * 2.0) * alpha);
    }

    // ---- The fountain of light ----
    if (burst > 0.0 || (tau > 0.0 && tau < 4.2)) {
        vec2 O = anchor + S * vec2(0.02, BH + 0.16);
        vec2 rel = p - O;
        float r = length(rel);
        vec3 gold = vec3(1.0, 0.80, 0.40);

        // Golden rays fanning upward, slowly turning, plus a hot core.
        float a = atan(rel.x, rel.y);
        float fan = smoothstep(1.15, 0.45, abs(a + 0.05));
        float beams = pow(0.5 + 0.5 * cos(a * 9.0 + tau * 0.5), 6.0)
                    + 0.6 * pow(0.5 + 0.5 * cos(a * 15.0 - tau * 0.8 + 1.3), 10.0);
        float reach = 0.10 + 0.62 * smoothstep(0.0, 0.7, tau);
        float rays = fan * beams * (1.0 - smoothstep(0.0, reach, r)) * smoothstep(-0.02, 0.03, rel.y);
        float core = 0.9 * exp(-r * r / 0.008) + 0.35 * exp(-r / 0.10);
        rgb = addLight(rgb, gold, (rays * 0.55 + core) * burst * GLOW);

        // Stars and confetti thrown out of the box, floating down with air drag.
        if (rel.x > -1.1 && rel.x < 0.7 && rel.y > -0.45 && rel.y < 0.9) {
            float px = 1.2 / iResolution.y;
            for (int k = 0; k < SPARKS; k++) {
                float fk = float(k);
                float h1 = hash1(fk * 12.9898 + cyc * 7.13);
                float h2 = hash1(fk * 78.233 + cyc * 3.71);
                float h3 = hash1(fk * 39.425 + 5.0);
                float age = tau - h1 * 1.3;
                if (age < 0.0 || age > 2.6) continue;
                vec2 v = vec2(-0.25 + (h2 - 0.5) * 1.4, 1.05 + 0.8 * h3);
                const float KD = 1.6, G = 1.3;
                float e = (1.0 - exp(-KD * age)) / KD;
                vec2 pos = vec2(v.x * e, (v.y + G / KD) * e - G / KD * age);
                pos.x += 0.025 * sin(age * 5.0 + fk) * smoothstep(0.4, 1.4, age);
                vec2 d = rel - pos;
                if (dot(d, d) > 0.0016) continue;
                float fade = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(1.8, 2.6, age));
                if (mod(fk, 3.0) < 1.0) {
                    // Four-point twinkling star.
                    float tw = 0.65 + 0.35 * sin(age * 18.0 + fk * 3.0);
                    vec2 ad = abs(d);
                    float R = 0.034 * tw;
                    float star = smoothstep(0.0045, 0.0, ad.x) * smoothstep(R, 0.0, ad.y)
                               + smoothstep(0.0045, 0.0, ad.y) * smoothstep(R, 0.0, ad.x)
                               + smoothstep(0.013, 0.0, length(d));
                    rgb = addLight(rgb, vec3(1.0, 0.95, 0.75), star * tw * fade * GLOW);
                } else {
                    // Confetti chip: spins in the plane and flips in 3D.
                    vec2 ld = rot(-(age * (4.0 + 4.0 * h2) + fk)) * d;
                    float flip = abs(cos(age * (5.0 + 3.0 * h3) + fk));
                    float dist = sdBox(ld, vec2(0.011 * max(flip, 0.15), 0.0055));
                    float m = mod(fk, 5.0);
                    vec3 col = m < 1.0 ? vec3(1.0, 0.82, 0.30) : m < 2.0 ? vec3(1.0, 0.45, 0.65)
                             : m < 3.0 ? vec3(0.40, 0.85, 1.0) : m < 4.0 ? vec3(0.95, 0.95, 1.0)
                             : vec3(0.55, 1.0, 0.55);
                    col *= 0.7 + 0.3 * flip;
                    rgb = mix(rgb, col, smoothstep(px, -px, dist) * fade * 0.9 * INTENSITY);
                }
            }
        }
    }

    fragColor = vec4(rgb, base.a);
}
