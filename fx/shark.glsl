// shark — a sleek shark glides through deep blue water, sunlight dappling its back under slanting rays.
// zh: 鲨鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float PERIOD    = 22.0;   // seconds per crossing; it turns round off-screen and comes back
const float WIDTH     = 0.43;   // shark length (snout to tail tip) as a fraction of the window width
const float DEPTH_Y   = 0.30;   // cruising height of the shark (0 = bottom, 1 = top)
const float BEAT      = 1.55;   // tail sweep speed (radians per second)
const float OPACITY   = 0.72;   // how solid the body is; below 1 so it sits in the water
const float RIM       = 0.80;   // cool rim light along the upper edges
const float DAPPLE    = 0.60;   // sunlight caustics across the back
const float RAYS      = 0.07;   // slanting light rays from the surface
const int   MOTES     = 12;     // drifting particles in the water

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

// Exact signed distance to a triangle (Inigo Quilez).
float sdTri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ---- Body profile -------------------------------------------------------
// The shark faces +x: snout at x = 1, tail root at x = -1. s = 0 at the snout,
// 1 at the tail root. Great-white proportions: a conical snout, deepest about a
// third of the way back, then a long taper to a slim tail stock.
float topY(float s) {
    float nose = pow(clamp(s / 0.36, 0.0, 1.0), 0.52);
    return 0.230 * nose * (1.0 - 0.84 * smoothstep(0.36, 1.0, s)) + 0.012;
}
float botY(float s) {
    float nose = pow(clamp(s / 0.40, 0.0, 1.0), 0.62);
    return -0.195 * nose * (1.0 - 0.84 * smoothstep(0.40, 1.0, s)) + 0.012;
}

// Signed distance (roughly) to the whole silhouette. fs (0.3..1) squashes the
// tail fin along x as it turns edge-on; fin rows the pectoral fin.
float sharkSD(vec2 q, float fs, float fin) {
    float s = clamp((1.0 - q.x) * 0.5, 0.0, 1.0);
    float t = topY(s), b = botY(s);
    // Vertical distance, scaled by the profile slope near the snout so the edge
    // stays crisp where the outline is steep.
    float d = max(q.y - t, b - q.y) * mix(0.55, 1.0, smoothstep(0.0, 0.25, s));
    d = max(d, max(q.x - 1.0, -1.02 - q.x));

    // Fins: triangles whose points are bent back with height, which gives the
    // convex leading edge and hollow trailing edge of real shark fins.
    vec2 w = q;
    float hu = max(q.y - 0.17, 0.0);
    w.x += 0.95 * hu * hu;
    d = smin(d, sdTri(w, vec2(0.30, 0.18), vec2(0.00, 0.14), vec2(0.04, 0.47)) - 0.008, 0.035);  // first dorsal
    d = smin(d, sdTri(q, vec2(-0.60, 0.07), vec2(-0.72, 0.055), vec2(-0.74, 0.135)), 0.015);      // second dorsal
    d = smin(d, sdTri(q, vec2(-0.62, -0.05), vec2(-0.74, -0.04), vec2(-0.76, -0.11)), 0.015);     // anal

    // Long pectoral fin, swept back and down, rowing a little.
    vec2 pr = vec2(0.36, -0.10);
    vec2 pq = q - pr;
    float a = 0.06 * fin;
    pq = mat2(cos(a), -sin(a), sin(a), cos(a)) * pq;
    float hd = max(-pq.y, 0.0);
    pq.x += 0.9 * hd * hd;
    d = smin(d, sdTri(pq, vec2(0.10, 0.05), vec2(-0.15, 0.03), vec2(-0.34, -0.25)) - 0.010, 0.03);
    d = smin(d, sdTri(q, vec2(-0.30, -0.09), vec2(-0.44, -0.075), vec2(-0.47, -0.17)), 0.02);   // pelvic

    // Crescent tail: two swept lobes, the upper a little taller.
    vec2 c = vec2(-1.0 + (q.x + 1.0) / fs, q.y);
    float up = sdTri(c, vec2(-0.86, 0.05), vec2(-1.04, -0.035), vec2(-1.36, 0.42));
    float lo = sdTri(c, vec2(-0.86, -0.04), vec2(-1.05, 0.04), vec2(-1.25, -0.27));
    float tail = smin(up, lo, 0.05) - 0.012;
    return smin(d, tail * fs, 0.03);
}

// Dappled light from the wavy surface, in world coordinates so the pattern
// stays in the water while the shark slides under it.
float caustic(vec2 p, float t) {
    vec2 q = p * 15.0;
    vec2 w = q + 0.8 * vec2(sin(q.y * 1.7 + t * 0.9), sin(q.x * 1.5 - t * 0.7));
    w += 0.4 * vec2(sin(w.y * 2.9 - t * 1.1), sin(w.x * 2.6 + t));
    float a = pow(1.0 - abs(sin(w.x + 0.4 * w.y)), 5.0);
    float b = pow(1.0 - abs(sin(w.y - 0.5 * w.x)), 5.0);
    return clamp(a + b, 0.0, 1.0);
}

// Soft light shafts slanting down from the surface.
float rays(vec2 p, float t) {
    float u = p.x + 0.30 * p.y;
    float r = 0.55 * pow(0.5 + 0.5 * sin(u * 6.1 + 0.5 * sin(t * 0.13)), 6.0)
            + 0.40 * pow(0.5 + 0.5 * sin(u * 11.3 - t * 0.19 + 1.3), 10.0)
            + 0.35 * pow(0.5 + 0.5 * sin(u * 3.7 + t * 0.07 + 4.0), 4.0);
    return r * smoothstep(-0.2, 1.0, p.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    bool dark = lum < 0.5;
    // Keep the shell text (top-left) clear: the water light is weaker there.
    float textMask = smoothstep(0.15, 0.75, length(vec2(uv.x * 1.2, uv.y * 1.6)));

    vec3 rgb = base.rgb;

    // ---- Water: rays from above, a faint blue depth haze near the bottom.
    float depthGlow = exp(-pow((p.y - DEPTH_Y) / 0.30, 2.0));
    if (dark) {
        rgb += vec3(0.42, 0.68, 0.80) * rays(p, iTime) * RAYS * textMask * INTENSITY;
        rgb += vec3(0.010, 0.035, 0.055) * depthGlow * textMask * INTENSITY;
    }

    // ---- Pose: crossing, slow depth changes, tilt following the climb.
    float clock = iTime + 0.32 * PERIOD;                                  // already in view at start
    float size = min(WIDTH * aspect / 2.40, 0.34);                        // half the body length
    float z = sin(clock * 0.19);                                         // -1 near .. 1 farther
    size *= 1.0 - 0.06 * z;
    float tc = fract(clock / PERIOD);
    float dir = mod(floor(clock / PERIOD), 2.0) < 0.5 ? 1.0 : -1.0;       // alternate sides
    tc += 0.07 * sin(2.0 * PI * tc);                                      // linger in view, hurry off-screen
    float margin = 1.45 * size;
    float x = mix(-margin, aspect + margin, tc);
    if (dir < 0.0) x = aspect - x;
    float y = DEPTH_Y + 0.045 * sin(clock * 0.23) + 0.03 * z;
    float tilt = 0.045 * cos(clock * 0.23);                              // nose follows the climb

    vec2 q = (p - vec2(x, y)) / size;
    q.x *= dir;                                                           // face the way it swims
    q = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * q;

    // Bounding box early-out: only pixels near the shark pay for it.
    if (q.x > -1.5 && q.x < 1.1 && q.y > -0.55 && q.y < 0.60) {
        float ph = clock * BEAT;
        // Seen from the side, the side-to-side sweep shows as the tail fin
        // turning edge-on and broad again, with a slight flex of the tail stock.
        float fs = 0.32 + 0.68 * abs(cos(ph));
        float flex = smoothstep(-0.1, -1.4, q.x);
        q.y -= 0.025 * sin(ph - 1.2) * flex * flex;
        float fin = sin(clock * 0.7);
        float aa = 1.2 / (iResolution.y * size);

        float d = sharkSD(q, fs, fin);
        float soft = aa + 0.006;
        float cov = smoothstep(soft, -soft, d);

        float glowOut = exp(-max(d, 0.0) / 0.03);                         // thin halo for the rim light
        if (cov > 0.0 || glowOut > 0.02) {
            // Up-facing edges: the distance grows when stepping upward.
            float e = 0.02;
            float upness = clamp((sharkSD(q + vec2(0.0, e), fs, fin) - d) / e, 0.0, 1.0);

            float s = clamp((1.0 - q.x) * 0.5, 0.0, 1.0);
            float tY = topY(s), bY = botY(s);
            float v = clamp((q.y - bY) / max(tY - bY, 1e-3), 0.0, 1.0);    // 0 belly .. 1 back
            if (q.y > tY || q.x < -1.0) v = 1.0;                          // fins count as back
            bool lowFin = q.y < bY;
            if (lowFin) v = 0.75;                                          // pectoral: darker topside

            // Countershading: dark slate back fading through a wavy line to a pale belly.
            float line = 0.36 + 0.035 * sin(q.x * 11.0) + 0.02 * sin(q.x * 23.0 + 1.0);
            float belly = smoothstep(line + 0.06, line - 0.06, v);
            vec3 back = vec3(0.075, 0.115, 0.16);
            vec3 pale = vec3(0.52, 0.60, 0.66);
            vec3 col = mix(back, pale, belly * 0.85);
            // Rounded flank: a little lighter mid-body, darker near the outline.
            col *= 0.80 + 0.30 * (1.0 - pow(2.0 * v - 1.0, 2.0));

            // Gill slits, eye and mouth line: subtle darker marks.
            float marks = 0.0;
            for (int k = 0; k < 5; k++) {
                float gx = 0.50 - 0.045 * float(k);
                vec2 g = q - vec2(gx, -0.01);
                g.x += 1.2 * g.y * g.y;                                    // slight curve
                float slit = smoothstep(0.010, 0.003, abs(g.x + 0.06 * g.y)) * smoothstep(0.085, 0.05, abs(g.y));
                marks = max(marks, slit * (0.8 - 0.08 * float(k)));
            }
            vec2 ev = q - vec2(0.76, 0.055);
            float eye = smoothstep(0.022, 0.012, length(ev * vec2(1.0, 1.3)));
            float glint = smoothstep(0.008, 0.0, length(ev - vec2(0.006, 0.007)));
            float mouth = smoothstep(0.010, 0.003, abs(q.y + 0.085 + 0.15 * (q.x - 0.75) * (q.x - 0.75)))
                        * smoothstep(0.58, 0.64, q.x) * smoothstep(0.93, 0.86, q.x);
            col *= 1.0 - 0.55 * max(max(marks, eye), mouth * 0.6);

            // Depth haze: farther parts (and the tail) melt into blue water.
            vec3 haze = vec3(0.07, 0.17, 0.25);
            float hz = 0.15 + 0.12 * z + 0.12 * smoothstep(-0.4, -1.4, q.x);
            col = mix(col, haze, clamp(hz, 0.0, 0.8));

            // Tail fin catches a bit more light when it turns broadside.
            float tailLit = q.x < -1.0 ? 0.85 + 0.25 * abs(cos(ph)) : 1.0;
            col *= tailLit;

            // Fade the edges a touch so it reads as in the water, not on it.
            float alpha = cov * OPACITY * (0.75 + 0.25 * smoothstep(0.0, -0.05, d));

            // Light on top: caustic dapples over the upper half, a cool rim
            // along up-facing edges, and a pinpoint eye glint.
            float dap = caustic(p, iTime) * smoothstep(0.45, 0.95, v) * cov * (lowFin ? 0.3 : 1.0);
            float rimIn = exp(min(d, 0.0) / 0.014) * cov;
            float rim = upness * (rimIn + 0.30 * glowOut * (1.0 - cov));
            vec3 light = vec3(0.55, 0.82, 0.95) * dap * DAPPLE * (0.7 - 0.3 * z) * 0.6
                       + vec3(0.62, 0.86, 1.0) * rim * RIM * 0.55
                       + vec3(0.8, 0.9, 1.0) * glint * cov * 0.5;

            if (dark) {
                rgb = mix(rgb, col, alpha * INTENSITY);
                rgb += light * INTENSITY;
            } else {
                // Light theme: a dark, see-through silhouette with gentle light marks.
                rgb = mix(rgb, col * 0.55, alpha * INTENSITY * 0.8);
                rgb = mix(rgb, vec3(0.85, 0.95, 1.0), clamp(dot(light, vec3(0.33)) * INTENSITY * 0.6, 0.0, 1.0));
            }
        }
    }

    // ---- Drifting particles (marine snow): faint, slow, all over the lower water.
    if (dark) {
        float motes = 0.0;
        for (int i = 0; i < MOTES; i++) {
            float fi = float(i);
            float sp = 0.008 + 0.010 * hash1(fi * 3.1);
            vec2 m = vec2(fract(hash1(fi * 7.7) + iTime * sp * 0.4 + 0.02 * sin(iTime * 0.3 + fi)) * (aspect + 0.2) - 0.1,
                          fract(hash1(fi * 1.3) - iTime * sp) * 0.85);
            float r = 0.0025 + 0.002 * hash1(fi * 9.2);
            float tw = 0.6 + 0.4 * sin(iTime * (0.7 + hash1(fi)) + fi * 2.0);
            motes += smoothstep(r * 2.5, 0.0, length(p - m)) * tw;
        }
        rgb += vec3(0.55, 0.75, 0.85) * motes * 0.30 * textMask * INTENSITY;
    }

    fragColor = vec4(rgb, base.a);
}
