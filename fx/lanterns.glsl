// lanterns — a lantern festival night: glowing paper sky lanterns rise in three depths, swaying and turning.
// zh: 孔明灯
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.90;   // overall strength (0 = off)
const float NEAR_SIZE  = 0.145;  // height of a near lantern, in window heights
const float MID_SIZE   = 0.058;  // height of a middle-distance lantern
const float RISE       = 0.055;  // rise speed of the near layer, window heights / s
const float HALO       = 0.70;   // strength of the warm glow around each lantern
const float PAPER_HIDE = 0.45;   // how much a lantern's paper covers what is behind it
const float TEXT_CALM  = 0.80;   // how much lanterns dim in the top-left text area

const float PI = 3.14159265;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Three sines at unrelated rates: a smooth, never-repeating candle flicker.
float flicker(float t, float ph) {
    return 0.86 + 0.08 * sin(t * 7.3 + ph)
                + 0.05 * sin(t * 12.9 + ph * 2.3)
                + 0.03 * sin(t * 21.7 + ph * 1.7);
}

// Lanterns dim in the top-left so the shell prompt and text stay readable.
float textCalm(vec2 c, float aspect) {
    float tl = (1.0 - smoothstep(0.30, 0.80, c.x / aspect)) * smoothstep(0.40, 0.85, c.y);
    return 1.0 - TEXT_CALM * tl;
}

// One sky lantern in lantern units: y runs -1 (bottom opening) to +1 (top),
// slightly wider at the top. rot turns it around its vertical axis, fl is the
// flame flicker, aa is the edge softness. Returns colour (rgb) and coverage (a).
vec4 lantern(vec2 q, float rot, float fl, float aa, float detail) {
    float s = clamp((q.y + 1.0) * 0.5, 0.0, 1.0);           // 0 bottom .. 1 top
    float halfW = mix(0.44, 0.60, s);

    // Body: tapered sides, a softly domed top, rounded shoulders.
    float dSide = abs(q.x) - halfW;
    float dTop = q.y - (1.0 - 0.10 * q.x * q.x);
    float k = 0.14;                                         // shoulder roundness
    float h = clamp(0.5 + 0.5 * (dTop - dSide) / k, 0.0, 1.0);
    float dBody = mix(dSide, dTop, h) + k * h * (1.0 - h);  // smooth max
    dBody = max(dBody, -1.0 - q.y);
    float body = smoothstep(aa, -aa, dBody);

    // Bottom opening: seen from below as an ellipse into the lit interior.
    vec2 eR = vec2(0.44, 0.11);
    vec2 e = (q - vec2(0.0, -1.0)) / eR;
    float ek = length(e);
    float eD = (ek - 1.0) / max(length(e / eR) / max(ek, 1e-3), 1e-3);  // ~distance
    float opening = smoothstep(aa, -aa, eD);
    float ring = smoothstep(0.045 + aa, 0.045 - aa * 0.5, abs(eD));

    // Cylinder angle under this point, so ribs crowd toward the edges and slide
    // across as the lantern turns.
    float sx = clamp(q.x / halfW, -0.999, 0.999);
    float phi = asin(sx);
    float cphi = sqrt(1.0 - sx * sx);

    float a = (phi - rot) * 5.0 / PI;                       // 10 ribs round the lantern
    float dRib = abs(fract(a + 0.5) - 0.5) * (PI / 5.0) * halfW * cphi;
    float rib = smoothstep(0.025 + aa, 0.0, dRib);
    float panel = 0.90 + 0.10 * cos(2.0 * PI * a);          // folds between ribs
    float ab = (PI - phi - rot) * 5.0 / PI;                 // ribs on the back, seen through
    float dRibB = abs(fract(ab + 0.5) - 0.5) * (PI / 5.0) * halfW * cphi;
    float ribB = smoothstep(0.03 + aa, 0.0, dRibB);

    // Paper fibre: noise that is carried round with the rotation.
    float fibre = 1.0;
    if (detail > 0.5) {
        vec2 fu = vec2((phi - rot) * 2.2, q.y * 1.6);
        fibre = 0.86 + 0.18 * vnoise(fu * vec2(3.0, 7.0))
                     + 0.08 * vnoise(fu * vec2(14.0, 3.0));
    }

    // Lit from inside: brightest low down near the flame, dimmer up top,
    // a hot spot right above the flame, slightly darker at the curved edges.
    float lit = exp(-s * 1.2);
    vec2 hs = vec2(q.x * 1.5, q.y + 0.70);
    float hot = exp(-dot(hs, hs) * 1.8) * fl;
    vec3 paper = mix(vec3(0.80, 0.26, 0.06), vec3(1.0, 0.66, 0.26), lit) * 1.15;
    paper *= mix(0.72, 1.0, cphi) * panel * fibre * fl;
    paper += vec3(1.0, 0.85, 0.50) * hot;
    paper *= 1.0 - 0.28 * rib - 0.12 * ribB;

    // Interior through the opening: bright core where the fuel cake burns.
    vec2 fc = (q - vec2(0.0, -1.0)) / vec2(0.16, 0.06);
    float fuel = exp(-dot(fc, fc) * 0.8);
    vec3 inside = mix(vec3(1.0, 0.55, 0.18), vec3(1.0, 0.95, 0.75), fuel) * (0.9 + 0.3 * fl);
    float wire = smoothstep(0.03 + aa, 0.0, abs(q.y + 1.0 - 0.18 * q.x)) * step(0.16, abs(q.x));
    inside = mix(inside, vec3(0.25, 0.10, 0.03), wire * 0.7);

    vec3 colr = paper * body;
    float cover = body;
    colr = mix(colr, inside, opening);
    cover = max(cover, opening);
    colr = mix(colr, vec3(0.16, 0.07, 0.03), ring);       // dark wire ring at the rim
    cover = max(cover, ring);
    return vec4(colr, cover);
}

// One rising layer of lanterns on a column grid. Each column rises at its own
// speed; we check the pixel's cell and its 8 neighbours (halos spill over).
void lanternLayer(vec2 p, float aspect, float t, float layer, float size,
                  float speed, vec2 cell, float bright, float detail,
                  inout vec3 col, inout float cover) {
    float hsz = size * 0.5;                                  // half height
    float aa = 1.5 / (hsz * iResolution.y);
    float cx = floor(p.x / cell.x);
    for (int i = -1; i <= 1; i++) {
        float ci = cx + float(i);
        float colSeed = hash(vec2(ci, layer * 7.1));
        float spd = speed * mix(0.75, 1.25, colSeed);
        float off = colSeed * 13.0;
        float yy = p.y - t * spd - off;
        float cy = floor(yy / cell.y);
        for (int j = -1; j <= 1; j++) {
            float rj = cy + float(j);
            vec2 id = vec2(ci, rj);
            float h1 = hash(id + layer * 31.7);
            if (h1 > 0.82) continue;                         // some cells stay empty
            float h2 = hash(id * 1.31 + layer * 5.3 + 1.7);
            float h3 = hash(id * 0.77 + layer * 2.9 + 4.1);
            float sc = mix(0.80, 1.15, h3);
            float ph = h2 * 6.2831;

            // Lantern centre on screen: jittered in its cell, swaying gently.
            float sw = sin(t * mix(0.35, 0.6, h3) + ph);
            vec2 c = vec2((ci + 0.5 + (h2 - 0.5) * 0.35) * cell.x + 0.30 * hsz * sw,
                          (rj + 0.5 + (h1 - 0.4) * 0.30) * cell.y + t * spd + off);
            float tilt = 0.07 * cos(t * mix(0.35, 0.6, h3) + ph);
            vec2 d = p - c;
            float ct = cos(tilt), st = sin(tilt);
            vec2 q = vec2(ct * d.x - st * d.y, st * d.x + ct * d.y) / (hsz * sc);

            float fl = flicker(t, ph * 3.0);
            float calm = textCalm(c, aspect) * bright;

            // Wide warm halo, centred a little below the middle (the flame).
            vec2 qh = q - vec2(0.0, -0.35);
            float r2 = dot(qh, qh);
            float halo = HALO / (1.0 + r2 * 0.45) * smoothstep(30.0, 2.0, r2);
            col += vec3(1.0, 0.50, 0.16) * halo * fl * calm;

            // The lantern itself only inside its bounding box.
            if (abs(q.x) < 0.75 && q.y > -1.25 && q.y < 1.1) {
                vec4 l = lantern(q, t * mix(-0.35, 0.35, h1 / 0.82) + ph, fl, aa / sc, detail);
                col = col * (1.0 - l.a * 0.6) + l.rgb * l.a * calm;
                cover = max(cover, l.a * calm);
            }
        }
    }
}

// Very far lanterns: just tiny warm dots, one per cell.
void farLayer(vec2 p, float aspect, float t, float seed, vec2 cell, float speed,
              inout vec3 col) {
    vec2 g = p;
    g.y -= t * speed;
    vec2 id = floor(g / cell);
    float h1 = hash(id + seed);
    if (h1 > 0.45) return;
    float h2 = hash(id * 1.7 + seed + 3.3);
    float h3 = hash(id * 0.9 + seed + 8.1);
    float ph = h2 * 6.2831;
    vec2 c = (id + 0.5 + (vec2(h2, h3) - 0.5) * 0.4) * cell;
    c.x += 0.004 * sin(t * 0.5 + ph);
    vec2 d = (g - c) * vec2(1.0, 0.75);
    float r = mix(0.0016, 0.0034, h3 * h3);
    float dd = dot(d, d);
    float fl = flicker(t, ph * 2.0);
    float glow = r * r * 2.5 / (dd + r * r * 0.5) * smoothstep(0.00016, 0.0, dd);
    vec2 cs = c + vec2(0.0, t * speed);
    col += vec3(1.0, 0.62, 0.25) * glow * fl * mix(0.35, 1.0, h1 / 0.45) * textCalm(cs, aspect);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime + 40.0;   // start mid-flight: the sky is already full

    vec3 col = vec3(0.0);
    float cover = 0.0;

    // A faint warm glow low in the sky, from all the lanterns below the window.
    col += vec3(0.30, 0.10, 0.03) * smoothstep(0.45, 0.0, p.y) * 0.35;

    // Far to near, so nearer lanterns are drawn over the farther ones.
    farLayer(p, aspect, t, 11.0, vec2(0.075, 0.090), RISE * 0.22, col);
    farLayer(p, aspect, t, 57.0, vec2(0.060, 0.075), RISE * 0.16, col);
    lanternLayer(p, aspect, t, 2.0, MID_SIZE, RISE * 0.55, vec2(0.19, 0.27), 0.75, 0.0, col, cover);
    lanternLayer(p, aspect, t, 1.0, NEAR_SIZE, RISE, vec2(0.40, 0.62), 1.0, 1.0, col, cover);

    vec3 rgb = base.rgb * (1.0 - cover * PAPER_HIDE * INTENSITY) + min(col, vec3(1.2)) * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
