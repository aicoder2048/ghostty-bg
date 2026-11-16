// redlanterns — a string of round red New Year lanterns glowing from within, swaying on a cord at the top right.
// zh: 红灯笼
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.85;   // overall strength (0 = off)
const float SIZE       = 1.00;   // lantern size multiplier (1 = largest is ~18% of window height)
const float SWAY       = 1.00;   // how far the lanterns swing in the breeze
const float HALO       = 0.55;   // strength of the warm glow around each lantern
const float PAPER_HIDE = 0.55;   // how much the paper covers what is behind it (max opacity)
const float DRIFT      = 0.70;   // brightness of the drifting sparks and plum petals

const float PI = 3.14159265;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// Three sines at unrelated rates: a soft candle flicker that never repeats.
float flicker(float t, float ph) {
    return 0.90 + 0.05 * sin(t * 6.1 + ph)
                + 0.035 * sin(t * 11.3 + ph * 2.3)
                + 0.02 * sin(t * 19.7 + ph * 1.7);
}

// The cord: enters from the right edge and droops left, leaving through the
// top edge. ax is the window's aspect (its right edge in scene units).
float cordY(float x, float ax) {
    float s = (ax + 0.02 - x) / 0.62;
    return mix(0.985, 1.035, s) - 0.28 * s * (1.0 - s);
}

// Per-lantern setup: x = distance in from the right edge, y = string length,
// z = body half-height, w = phase seed. Index 0 is the biggest, nearest one.
vec4 lanternParams(int i) {
    if (i == 0) return vec4(0.120, 0.095, 0.083, 0.3);
    if (i == 1) return vec4(0.270, 0.190, 0.062, 2.1);
    if (i == 2) return vec4(0.395, 0.060, 0.050, 4.4);
    return              vec4(0.500, 0.150, 0.041, 5.6);
}

// Pendulum swing for a lantern hanging on a string of length len.
float swing(float t, float len, float ph) {
    float w = 1.35 / sqrt(len * 6.0 + 0.4);                 // longer string, slower swing
    float breeze = 0.75 + 0.25 * sin(t * 0.21 + ph);         // the breeze rises and falls
    return SWAY * breeze * (0.075 * sin(t * w + ph) + 0.022 * sin(t * w * 1.73 + ph * 2.1));
}

// One round lantern in lantern units (body is y -1..1, 1.18 wide each side).
// rot turns it around its axis, fl is the candle flicker, glint follows the
// swing, bend sways the tassel. Returns colour (rgb) and coverage (a).
vec4 lantern(vec2 q, float rot, float fl, float glint, float bend, float t, float ph, float aa) {
    vec3 col = vec3(0.0);
    float cover = 0.0;

    // ---- paper globe ----
    const float W = 1.18;
    vec2 e = q / vec2(W, 1.0);
    float r = length(e);
    float body = smoothstep(1.0 + aa, 1.0 - aa, r) * step(abs(q.y), 0.90);
    if (body > 0.0) {
        float halfW = W * sqrt(max(1.0 - q.y * q.y, 0.02));
        float sx = clamp(q.x / halfW, -0.999, 0.999);
        float phi = asin(sx);
        float cphi = sqrt(1.0 - sx * sx);

        // 16 bamboo ribs; they bunch at the sides and slide across as it turns.
        float a = (phi - rot) * 8.0 / PI;
        float dRib = abs(fract(a + 0.5) - 0.5) * (PI / 8.0) * halfW * cphi;
        float rib = smoothstep(0.022 + aa, 0.0, dRib);
        float ab = (PI - phi - rot) * 8.0 / PI;              // back ribs, seen through the paper
        float dRibB = abs(fract(ab + 0.5) - 0.5) * (PI / 8.0) * halfW * cphi;
        float ribB = smoothstep(0.03 + aa, 0.0, dRibB);
        float panel = 0.88 + 0.12 * cos(2.0 * PI * a);        // paper bulges between ribs

        // Lit from inside: hot gold at the centre, red-orange, then deep crimson
        // at the rim where the light passes through more paper.
        float rr = r * r;
        vec3 paper = mix(vec3(1.00, 0.70, 0.34), vec3(0.95, 0.24, 0.07), smoothstep(0.0, 0.55, rr * fl));
        paper = mix(paper, vec3(0.62, 0.07, 0.05), smoothstep(0.45, 1.0, rr));
        paper *= (0.70 + 0.30 * cphi) * panel * (0.92 + 0.12 * fl);
        paper *= 1.0 - 0.45 * rib - 0.12 * ribB;
        // Faint warm rim light where the globe curves away.
        paper += vec3(0.55, 0.12, 0.05) * smoothstep(0.80, 0.99, r) * 0.35;

        col = paper * body;
        cover = body * (0.30 + 0.70 * cphi);
    }

    // ---- gold caps top and bottom ----
    float capW = 0.50 - 0.04 * smoothstep(0.86, 1.0, abs(q.y));
    float capY = abs(q.y);
    float cap = smoothstep(aa, -aa, abs(q.x) - capW)
              * smoothstep(0.84 - aa, 0.84 + aa, capY) * smoothstep(1.02 + aa, 1.02 - aa, capY);
    if (cap > 0.0) {
        float cx = clamp(q.x / capW, -0.999, 0.999);
        float cc = sqrt(1.0 - cx * cx);
        float groove = 0.85 + 0.15 * sin(capY * 90.0);
        vec3 gold = vec3(0.78, 0.52, 0.18) * (0.30 + 0.55 * cc) * groove;
        // A soft metallic glint that slides as the lantern swings.
        gold += vec3(1.0, 0.88, 0.55) * exp(-pow((cx + 0.35 - glint) * 5.0, 2.0)) * 0.55;
        // The edge facing the paper catches the lantern's own light.
        gold += vec3(0.6, 0.25, 0.06) * smoothstep(0.92, 0.84, capY) * 0.5 * fl;
        col = mix(col, gold, cap);
        cover = max(cover, cap * 0.85);
    }

    // Small gold ring on top where the string ties on.
    float ring = smoothstep(0.022 + aa, 0.0, abs(length(q - vec2(0.0, 1.10)) - 0.07));
    col = mix(col, vec3(0.80, 0.58, 0.24), ring);
    cover = max(cover, ring * 0.7);

    // ---- tassel: knot, gold binding, then a sheaf of silk threads ----
    if (q.y < -1.0) {
        float u0 = clamp((-1.0 - q.y) / 1.55, 0.0, 1.0);    // 0 at the cap, 1 at the tips
        vec2 k = q;
        k.x -= bend * u0 * u0 + 0.04 * sin(t * 2.3 + ph + u0 * 4.0) * u0 * u0;

        float knot = smoothstep(0.09 + aa, 0.09 - aa, length(k - vec2(0.0, -1.13)));
        float band = smoothstep(aa, -aa, abs(k.x) - 0.12) * smoothstep(aa, -aa, abs(k.y + 1.30) - 0.06);

        float u = clamp((-1.36 - k.y) / 1.20, 0.0, 1.2);     // along the threads
        float halfT = 0.10 + 0.17 * u;
        float xn = k.x / halfT;                              // -1..1 across the sheaf
        float sid = floor((xn + 1.0) * 7.0);
        float tip = 1.0 - 0.14 * hash(sid + ph * 10.0);       // ragged thread ends
        float threads = smoothstep(aa * 2.0, -aa, abs(xn) - 1.0)
                      * step(-1.36, -k.y) * smoothstep(tip, tip - 0.08, u);
        float strand = 0.78 + 0.22 * sin(xn * 15.0);
        // Silk sheen: lit from the lantern above, fading toward the tips.
        vec3 silk = mix(vec3(0.95, 0.20, 0.08), vec3(0.95, 0.62, 0.25), exp(-xn * xn * 3.0) * 0.45);
        silk *= strand * (1.0 - 0.55 * u) * (0.85 + 0.15 * fl);

        col = mix(col, silk, threads * 0.85);
        cover = max(cover, threads * 0.55);
        vec3 knotC = mix(vec3(0.85, 0.18, 0.08), vec3(1.0, 0.75, 0.35), smoothstep(-1.06, -1.18, k.y) * 0.5);
        col = mix(col, knotC, knot);
        cover = max(cover, knot * 0.75);
        vec3 bandC = vec3(0.82, 0.58, 0.22) * (0.6 + 0.4 * sqrt(max(1.0 - k.x * k.x / 0.0144, 0.0)));
        col = mix(col, bandC, band);
        cover = max(cover, band * 0.8);
    }
    return vec4(col, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float ax = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * ax, 1.0 - uv.y);
    float t = iTime + 3.0;
    float px = 1.0 / iResolution.y;

    vec3 col = vec3(0.0);
    float cover = 0.0;

    // Everything except the drifting bits lives in the right part of the window,
    // so pixels further left skip the lanterns entirely.
    if (p.x > ax - 1.05) {
        // ---- the cord ----
        float cy = cordY(p.x, ax);
        if (abs(p.y - cy) < 0.01 && p.x > ax - 0.64) {
            float slope = (cordY(p.x + 0.01, ax) - cy) / 0.01;
            float d = abs(p.y - cy) / sqrt(1.0 + slope * slope);
            float line = smoothstep(1.6 * px, 0.3 * px, d);
            col += vec3(0.42, 0.14, 0.07) * line;
            cover = max(cover, line * 0.5);
        }

        // ---- lanterns, smallest (farthest) first so the big one sits on top ----
        for (int n = 3; n >= 0; n--) {
            vec4 lp = lanternParams(n);
            float R = lp.z * SIZE;
            float len = lp.y;
            float ph = lp.w;
            vec2 pivot = vec2(ax - lp.x, cordY(ax - lp.x, ax));

            float th = swing(t, len, ph);
            float thLag = swing(t - 0.45, len, ph);
            float c = cos(th), s = sin(th);
            vec2 d = p - pivot;
            vec2 dl = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);   // into the swinging frame

            float drop = len + 1.17 * R;                    // pivot down to the globe's centre
            vec2 q = (dl - vec2(0.0, -drop)) / R;
            float fl = flicker(t, ph * 3.7);

            // Warm halo and wider light spill, centred on the candle.
            float r2 = dot(q / vec2(1.18, 1.0), q / vec2(1.18, 1.0));
            float halo = HALO * (0.55 / (1.0 + r2 * 0.9) + 0.25 / (1.0 + r2 * 0.12))
                       * smoothstep(60.0, 1.0, r2);
            col += vec3(1.0, 0.36, 0.12) * halo * fl * smoothstep(0.45, 1.0, r2);

            // The string from the cord down to the top ring.
            if (abs(dl.x) < 3.0 * px && dl.y < 0.0 && dl.y > -(len + 0.03 * R)) {
                float line = smoothstep(1.3 * px, 0.2 * px, abs(dl.x));
                col += vec3(0.50, 0.20, 0.08) * line;
                cover = max(cover, line * 0.45);
            }

            // Lantern detail only inside its bounding box.
            if (abs(q.x) < 1.6 && q.y < 1.2 && q.y > -2.75) {
                float rot = ph + 0.16 * t * (n == 1 ? -1.0 : 1.0) + 0.35 * sin(t * 0.37 + ph);
                float bend = 7.0 * (thLag - th);
                vec4 l = lantern(q, rot, fl, th * 3.0, bend, t, ph, 1.5 * px / R);
                col = col * (1.0 - l.a) + l.rgb * l.a;
                cover = max(cover, l.a);
            }
        }
    }

    // ---- a few golden sparks and plum petals drifting by, faintly ----
    if (p.x > ax * 0.45) {
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float per = 9.0 + 3.0 * hash(fi + 1.3);
            float k = (t + per * hash(fi + 7.1)) / per;
            float life = fract(k);
            float cyc = floor(k);
            float h = hash(fi * 3.7 + cyc * 1.91);
            float fade = smoothstep(0.0, 0.2, life) * smoothstep(1.0, 0.7, life);
            if (i < 4) {
                // Spark: rises slowly from below the lanterns, wandering.
                vec2 c = vec2(ax - 0.05 - 0.55 * h + 0.04 * sin(t * 0.9 + fi * 2.0),
                              0.40 + life * 0.50);
                vec2 dd = p - c;
                float r2 = dot(dd, dd);
                float tw = 0.7 + 0.3 * sin(t * 5.0 + fi * 4.0);
                float g = 1.2e-5 / (r2 + 1.5e-5) * smoothstep(0.004, 0.0, r2);
                col += vec3(1.0, 0.72, 0.30) * g * fade * tw * DRIFT;
            } else {
                // Plum petal: drifts down and left, turning over as it goes.
                vec2 c = vec2(ax - 0.05 - 0.45 * h - life * 0.30 + 0.03 * sin(t * 1.1 + fi),
                              0.98 - life * 0.75);
                vec2 dd = p - c;
                float a = t * 1.4 + fi * 2.0;
                float ca = cos(a), sa = sin(a);
                dd = vec2(ca * dd.x - sa * dd.y, sa * dd.x + ca * dd.y);
                float flip = 0.45 + 0.55 * abs(sin(t * 1.7 + fi * 3.0));
                vec2 e = dd / vec2(0.011, 0.0075 * flip);
                float petal = smoothstep(1.0, 0.6, dot(e, e));
                col += vec3(0.95, 0.42, 0.50) * petal * fade * 0.55 * DRIFT;
                cover = max(cover, petal * fade * 0.25);
            }
        }
    }

    vec3 rgb = base.rgb * (1.0 - cover * PAPER_HIDE * INTENSITY) + min(col, vec3(1.3)) * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
