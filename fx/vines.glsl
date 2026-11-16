// vines — realistic climbing ivy creeps in from the right and bottom-right, unfurling glossy lobed leaves.
// zh: 藤蔓
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.88;   // overall strength (0 = off)
const int   VINES     = 4;      // ivy stems alive at once (each on its own staggered clock)
const int   SEGS      = 7;      // straight pieces per stem, one leaf node each: the main per-pixel cost
const float PERIOD    = 20.0;   // seconds per stem life: grow, rest, fade, pause
const float GROW      = 10.0;   // seconds for the tip to reach full length (slow creep)
const float FADE0     = 15.0;   // the stem starts to fade ...
const float FADE1     = 17.5;   // ... and is gone here, then regrows somewhere else
const float LEAF      = 0.070;  // adult leaf size (centre lobe length), in window heights
const float SWAY      = 0.10;   // how much the stems sway (radians at the tip)
const float BERRIES   = 0.5;    // chance a stem carries a small cluster of ivy berries

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float segDist(vec2 p, vec2 a, vec2 b, out float h) {
    vec2 pa = p - a, ba = b - a;
    h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return length(pa - ba * h);
}

float smax(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * k * 0.25;
}

// Paint premultiplied colour c (alpha c.a) over a premultiplied accumulator.
void over(inout vec4 acc, vec4 c) { acc = c + acc * (1.0 - c.a); }

// The five palmate lobes of a Hedera helix leaf: centre, two laterals, two small
// basal lobes beside the heart-shaped notch where the petiole joins.
void lobe(int k, float lobing, out float ang, out float L, out float w) {
    if (k == 0)     { ang = 0.0;                              L = 1.0;                       w = 0.95; }
    else if (k < 3) { ang = (k == 1 ? 1.0 : -1.0) * 0.98;      L = mix(0.80, 0.72, lobing);   w = 0.76; }
    else            { ang = (k == 3 ? 1.0 : -1.0) * 1.92;      L = mix(0.52, 0.45, lobing);   w = 0.62; }
}

// One ivy leaf in leaf units: origin where the veins meet, centre lobe along +x,
// length 1. Returns premultiplied colour. px = one pixel in leaf units.
vec4 ivyLeaf(vec2 q, float px, float young, float lobing, float autumn, float tone, vec2 lightL, float hv) {
    float r = length(q);
    if (r > 1.06) return vec4(0.0);
    float a = atan(q.y, q.x);

    // Outline in polar form: a rounded core (smaller core = deeper lobes) merged
    // with pointed lobes; pow > 1 gives the acute lobe tips.
    float rs = max(mix(0.72, 0.50, lobing) * smoothstep(2.90, 2.25, abs(a)), 0.10);
    float best = 1e3, bAng = 0.0, bL = 1.0, bDA = 0.0;
    float vein = 0.0;
    for (int k = 0; k < 5; k++) {
        float ang, L, w;
        lobe(k, lobing, ang, L, w);
        float dA = a - ang;
        rs = smax(rs, L * pow(max(1.0 - abs(dA) / w, 0.0), 1.2), 0.08);
        float sc = abs(dA) / w;
        if (sc < best) { best = sc; bAng = ang; bL = L; bDA = dA; }
        // Primary vein down the middle of each lobe, tapering toward the tip.
        float al = r * cos(dA), ac = r * sin(dA);
        if (al > 0.0 && al < 0.88 * L) {
            float vw = max(mix(0.020, 0.004, al / L), 0.5 * px);
            vein = max(vein, smoothstep(px, -px, abs(ac) - vw));
        }
    }
    float d = (r - rs) * 0.8;                       // roughly a distance to the margin
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return vec4(0.0);

    // Coordinates inside the nearest lobe.
    float al = r * cos(bDA), ac = r * sin(bDA);
    float side = ac >= 0.0 ? 1.0 : -1.0;
    vec2 pk = vec2(-sin(bAng), cos(bAng)) * side;   // in-plane, away from that lobe's vein

    // Faint secondary veins branching forward from the midrib.
    float sv = abs(fract((al - abs(ac) * 0.9) * 6.5 + hv * 3.0) - 0.5) / 6.5;
    float sec = smoothstep(px, 0.0, sv - 0.003) * smoothstep(0.9, 0.4, al / bL) * step(0.03, abs(ac));

    // Form: veins sit in shallow grooves and the margin curls down, so each half
    // lobe is a gentle ridge; light from one side picks out the ridges.
    float m  = smoothstep(-0.28, -0.02, d);         // 1 near the margin
    float nv = smoothstep(0.12, 0.0, abs(ac));      // 1 near the vein
    vec2 n2 = pk * (0.60 * m - 0.45 * nv * (1.0 - m));
    float lit = dot(lightL, pk);
    float shade = 0.86 + 0.60 * dot(lightL, n2) + 0.10 * (hv - 0.5);

    // Colour: glossy dark-to-mid green; young leaves paler with a bronze edge;
    // a few leaves turning wine-red for autumn.
    vec3 col = mix(vec3(0.11, 0.25, 0.09), vec3(0.24, 0.42, 0.15), tone);
    col = mix(col, vec3(0.42, 0.55, 0.19), young);
    col = mix(col, vec3(0.44, 0.30, 0.13), young * m * 0.55);
    col = mix(col, vec3(0.46, 0.13, 0.10), autumn * (0.65 + 0.35 * m));
    col *= shade * (1.0 - 0.15 * m);

    vec3 vc = mix(vec3(0.68, 0.74, 0.54), vec3(0.74, 0.60, 0.48), autumn);
    col = mix(col, vc * (0.75 + 0.25 * shade), vein * (0.80 - 0.45 * young));
    col = mix(col, vc * 0.8, sec * 0.18);

    // Crisp sheen: a narrow streak on each half-lobe that faces the light (wax gloss).
    vec2 e = vec2(al / bL - 0.46, (abs(ac) - 0.17 * bL) / 0.30) / vec2(0.27, 0.055 / 0.30);
    float es = (length(e) - 1.0) * 0.055 * bL;
    float spec = smoothstep(px, -px, es) * smoothstep(0.05, 0.45, lit);
    col = mix(col, vec3(0.86, 0.92, 0.88), spec * (0.55 - 0.25 * young));

    // A one-pixel paler margin, as on real ivy, so leaves read on dark themes.
    col = mix(col, col * 1.6 + 0.04, smoothstep(-2.5 * px, -0.5 * px, d) * 0.6);
    return vec4(col * cov, cov);
}

// A glossy blue-black ivy berry. Returns premultiplied colour.
vec4 berry(vec2 p, vec2 c, float rad, float aa, vec2 lightW, float ripe) {
    vec2 q = (p - c) / rad;
    float d = (length(q) - 1.0) * rad;
    float cov = smoothstep(aa, -aa, d);
    if (cov <= 0.0) return vec4(0.0);
    float nz = sqrt(max(1.0 - dot(q, q), 0.0));
    vec3 col = mix(vec3(0.30, 0.38, 0.16), vec3(0.10, 0.08, 0.14), ripe);
    col *= 0.45 + 0.75 * max(0.0, 0.5 * nz + 0.7 * dot(q, lightW));
    float hl = smoothstep(aa, -aa, length(p - c - lightW * rad * 0.45) - rad * 0.22);
    col = mix(col, vec3(0.90, 0.92, 0.95), hl * 0.85);
    return vec4(col * cov, cov);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float aa = 1.0 / iResolution.y;

    vec2 lightW = normalize(vec2(-0.55, 0.83));       // one light, from the top left
    vec2 shOff = vec2(0.006, -0.008);                 // so shadows fall down-right on the wall

    vec3 rgb = base.rgb;
    for (int i = 0; i < VINES; i++) {
        float fi = float(i);
        // Staggered clocks: at switch-on stems are already at different stages.
        float clock = iTime + fi * PERIOD / float(VINES) + 3.0;
        float cyc = floor(clock / PERIOD);
        float t = clock - cyc * PERIOD;
        float fade = 1.0 - smoothstep(FADE0, FADE1, t);
        if (fade <= 0.0) continue;

        float seed = fi * 17.13 + cyc * 5.71;
        float h1 = hash1(seed + 1.0), h2 = hash1(seed + 2.0);
        float h3 = hash1(seed + 3.0), h4 = hash1(seed + 4.0);

        // Roots: two on the right edge, one in the bottom-right corner, one on the
        // bottom; all head up and inward like ivy climbing a wall.
        vec2 root; float th0, bend, len;
        if (i == 0) {
            root = vec2(aspect + 0.01, mix(0.30, 0.50, h1));
            th0 = PI - mix(0.10, 0.45, h2);  bend = mix(-0.9, 0.3, h3);  len = mix(0.42, 0.56, h4);
        } else if (i == 1) {
            root = vec2(aspect + 0.01, mix(0.05, 0.24, h1));
            th0 = PI - mix(0.30, 0.70, h2);  bend = mix(-0.7, 0.2, h3);  len = mix(0.44, 0.58, h4);
        } else if (i == 2) {
            root = vec2(aspect - mix(0.10, 0.38, h1), -0.01);
            th0 = 0.5 * PI + mix(0.15, 0.55, h2);  bend = mix(-0.3, 0.7, h3);  len = mix(0.40, 0.54, h4);
        } else {
            root = vec2(aspect - mix(0.55, 0.85, h1), -0.01);
            th0 = 0.5 * PI + mix(-0.10, 0.40, h2);  bend = mix(-0.5, 0.5, h3);  len = mix(0.34, 0.46, h4);
        }

        // Cheap early out: skip pixels nowhere near this stem.
        vec2 mid = root + 0.5 * len * vec2(cos(th0 + 0.5 * bend), sin(th0 + 0.5 * bend));
        if (length(p - mid) > 0.62 * len + 1.5 * LEAF) continue;

        // Growth: the tip creeps at a steady pace and eases in at full length;
        // gx keeps running so leaves near the tip finish unfurling afterwards.
        float gx = t / GROW;
        float g = 1.0 - pow(1.0 - min(gx, 1.0), 1.4);
        float wig = 6.2831 * hash1(seed + 5.0);
        float curl = (h3 > 0.5 ? 1.0 : -1.0) * 0.45;  // young tips hook a little
        float sway = SWAY * sin(iTime * 0.8 + wig) + 0.4 * SWAY * sin(iTime * 1.9 + wig * 1.7);
        float vside = hash1(seed + 6.0) > 0.5 ? 1.0 : -1.0;
        bool hasBerries = hash1(seed + 7.0) < BERRIES;
        float segLen = len / float(SEGS);

        vec4 acc = vec4(0.0);                         // leaves, petioles, berries
        float stemD = 1e3, shD = 1e3, shL = 0.0;
        float sU = 0.0, sV = 0.0, sW = 1.0, sH = 0.0, sAge = 0.0;
        vec2 sN = vec2(0.0, 1.0), tipD = vec2(1.0, 0.0);
        vec2 P = root;
        for (int k = 0; k < SEGS; k++) {
            float s0 = float(k) / float(SEGS);
            if (s0 >= g) break;
            float sm = s0 + 0.5 / float(SEGS);
            // Heading: a slow bend, a gentle wave, the sway (more toward the tip),
            // and a hook just behind the growing tip.
            float tipNear = clamp(1.0 - (g - sm) / 0.25, 0.0, 1.0);
            float th = th0 + bend * sm + 0.16 * sin(sm * 8.0 + wig) + sway * sm + curl * tipNear * tipNear;
            vec2 d = vec2(cos(th), sin(th));
            vec2 n = vec2(-d.y, d.x);
            float frac = clamp((g - s0) * float(SEGS), 0.0, 1.0);
            vec2 E = P + d * segLen * frac;
            tipD = d;

            // Woody stem, tapering toward the root-less green tip.
            float h;
            float dist = segDist(p, P, E, h);
            float sAt = s0 + h * frac / float(SEGS);
            float w = mix(0.0068, 0.0026, sAt) * mix(0.45, 1.0, clamp((g - sAt) / 0.12, 0.0, 1.0));
            if (dist - w < stemD) {
                stemD = dist - w;
                sU = sAt * len;  sW = w;  sH = h;  sAge = g - sAt;  sN = n;
                sV = dot(p - P, n);
            }
            float hs;
            shD = min(shD, segDist(p - shOff, P, E, hs) - w);

            // One leaf per node, alternating sides; it unfurls after the tip passes.
            float sl = float(k + 1) / float(SEGS);
            float unf = smoothstep(sl, sl + 0.24, gx);
            float side = (mod(float(k), 2.0) < 0.5 ? 1.0 : -1.0) * vside;
            if (unf > 0.0) {
                float hk = hash1(seed + float(k) * 3.3 + 11.0);
                float ang = side * (1.10 + 0.30 * hk) * mix(0.35, 1.0, unf);
                vec2 ld = rot(d, ang + 0.07 * sin(iTime * 1.3 + float(k) * 1.7 + wig));
                ld = normalize(ld + vec2(0.0, -0.30) * unf);           // leaves droop under their weight
                float R = LEAF * mix(1.0, 0.62, sl) * (0.85 + 0.30 * hk) * mix(0.22, 1.0, unf);
                float pet = R * 0.50;
                vec2 B = E + ld * pet;
                vec2 lc = B + ld * R * 0.30;
                if (length(p - lc) < R * 1.15 + pet) {
                    // Petiole: thin green-brown stalk from the node to the leaf.
                    float hp;
                    float dp = segDist(p, E, B, hp) - max(0.0016, 0.6 * aa);
                    float pc = smoothstep(aa, -aa, dp);
                    over(acc, vec4(vec3(0.30, 0.32, 0.15) * pc, pc));

                    vec2 nl = vec2(-ld.y, ld.x);
                    vec2 q = vec2(dot(p - B, ld), dot(p - B, nl)) / R;
                    q.y /= mix(0.35, 1.0, unf);                          // emerges folded along the midrib
                    float young = 1.0 - smoothstep(0.3, 1.0, unf) * smoothstep(0.75, 0.45, sl + 0.25 * hk);
                    young = max(young * 0.85, 0.0);
                    float h5 = hash1(seed + float(k) * 7.1 + 3.0);
                    float autumn = h5 > 0.86 ? mix(0.55, 1.0, hash1(h5 * 91.0)) : 0.0;
                    float lobing = hash1(seed + float(k) * 5.9 + 1.0);
                    float tone = hash1(seed + float(k) * 2.3 + 9.0);
                    vec2 lightL = vec2(dot(lightW, ld), dot(lightW, nl));
                    over(acc, ivyLeaf(q, aa / R, young, lobing, autumn, tone, lightL, hk));
                }
                // Soft contact shadow of the leaf on the wall.
                shL = max(shL, smoothstep(R * 0.80, R * 0.45, length(p - shOff * 1.8 - (B + ld * R * 0.35))));
            }

            // A small umbel of ivy berries on the far side of one mature node.
            if (hasBerries && k == 2) {
                float bs = smoothstep(0.95, 1.25, gx);
                if (bs > 0.0) {
                    vec2 cd = normalize(rot(d, -side * 0.9) + vec2(0.0, -0.2));
                    vec2 C = E + cd * 0.030;
                    if (length(p - C) < 0.032) {
                        float hb;
                        float ds = segDist(p, E, C, hb) - 0.0013;
                        float sc = smoothstep(aa, -aa, ds) * bs;
                        over(acc, vec4(vec3(0.30, 0.34, 0.16) * sc, sc));
                        float ripe = smoothstep(1.05, 1.4, gx);
                        for (int b = 0; b < 7; b++) {
                            float fb = float(b);
                            vec2 o = b == 0 ? vec2(0.0) : 0.0115 * vec2(cos(fb * 1.047 + wig), sin(fb * 1.047 + wig));
                            over(acc, berry(p, C + o + cd * 0.004 * (b == 0 ? 1.0 : 0.0), 0.0056 * bs, aa, lightW, ripe));
                        }
                        shL = max(shL, smoothstep(0.024, 0.014, length(p - C - shOff * 1.5)) * bs);
                    }
                }
            }
            P = E;
        }

        // A tiny folded bud at the growing tip.
        if (g < 1.0) {
            float R = 0.016;
            vec2 nl = vec2(-tipD.y, tipD.x);
            vec2 q = vec2(dot(p - P, tipD), dot(p - P, nl)) / R;
            q.y /= 0.35;
            if (dot(q, q) < 1.2) {
                vec2 lightL = vec2(dot(lightW, tipD), dot(lightW, nl));
                over(acc, ivyLeaf(q, aa / R, 0.9, 0.5, 0.0, 0.5, lightL, 0.3));
            }
        }

        // Stem: a lit cylinder, brown and woody near the root, green near the tip,
        // with darker rings at the nodes.
        vec4 stem = vec4(0.0);
        float v = clamp(sV / sW, -1.0, 1.0);
        float nz = sqrt(max(1.0 - v * v, 0.0));
        float lam = max(0.0, 0.55 * nz + 0.75 * dot(lightW, sN) * v);
        vec3 bark = mix(vec3(0.36, 0.46, 0.18), vec3(0.40, 0.30, 0.19), smoothstep(0.05, 0.35, sAge));
        vec3 sc = bark * (0.40 + 0.80 * lam);
        sc *= 1.0 - 0.30 * smoothstep(0.80, 0.97, sH) * smoothstep(0.08, 0.2, sAge);
        float vl = -0.45 * sign(dot(lightW, sN));
        sc = mix(sc, vec3(0.80, 0.76, 0.62), smoothstep(0.22, 0.08, abs(v - vl)) * 0.45);
        float scov = smoothstep(aa, -aa, stemD);

        // Aerial rootlets: short brown hairs on the wall side, in tufts just below each node.
        float rv = -sV * vside - sW;
        if (rv > 0.0 && rv < 0.009 && sAge > 0.15) {
            float x = sU * 220.0 + rv * 140.0;          // slanted, fine strands
            float id = floor(x);
            float keep = step(0.45, hash1(id * 1.37 + seed));    // irregular: skip about half
            float lenR = 0.003 + 0.006 * hash1(id + seed);
            float line = abs(fract(x) - 0.5) / 220.0;
            float tuft = smoothstep(0.55, 0.68, sH) * smoothstep(0.98, 0.86, sH);
            float rc = smoothstep(aa * 0.8, 0.0, line - 0.0003) * smoothstep(lenR, lenR - aa, rv) * tuft * keep;
            over(stem, vec4(vec3(0.30, 0.23, 0.15) * rc * 0.8, rc * 0.8));
        }
        over(stem, vec4(sc * scov, scov));
        over(stem, acc);                                  // leaves lie over the stem

        // Shadows on the background, then the ivy itself.
        float sh = max(shL * 0.55, smoothstep(2.0 * aa, -2.0 * aa, shD));
        float k2 = fade * INTENSITY;
        rgb *= 1.0 - sh * 0.30 * k2 * (1.0 - stem.a);
        rgb = rgb * (1.0 - stem.a * k2) + stem.rgb * k2;
    }

    fragColor = vec4(rgb, base.a);
}
