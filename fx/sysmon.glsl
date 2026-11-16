// sysmon — a live system-monitor panel in the lower right, btop style: 8 CPU core meters, a scrolling CPU history graph, memory, network up/down and disk activity.
// zh: 系统监视
// group: geek
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float PANEL_W   = 0.38;   // panel width, as a fraction of the window width
const float PANEL_H   = 0.47;   // panel height, as a fraction of the window height
const float MARGIN    = 0.030;  // gap to the bottom/right edges, in window heights
const float DIM       = 0.42;   // how much the panel darkens the background (contrast for the widgets)
const float SPAN      = 60.0;   // seconds of history shown across the CPU graph
const float NET_SPAN  = 40.0;   // seconds of history across the network / disk rows
const float BUILD_EVERY = 18.0; // a "build" load spike starts once per this many seconds

// Dark-theme palette (One Dark / btop-like).
const vec3 C_GREEN  = vec3(0.40, 0.84, 0.52);
const vec3 C_YELLOW = vec3(0.92, 0.79, 0.38);
const vec3 C_RED    = vec3(0.94, 0.40, 0.40);
const vec3 C_MEM    = vec3(0.56, 0.62, 0.98);
const vec3 C_DOWN   = vec3(0.36, 0.78, 0.92);
const vec3 C_UP     = vec3(0.80, 0.52, 0.90);
const vec3 C_READ   = vec3(0.42, 0.86, 0.72);
const vec3 C_WRITE  = vec3(0.95, 0.66, 0.36);
const vec3 C_FRAME  = vec3(0.62, 0.70, 0.82);

float hash1(float n) { return fract(sin(n * 12.9898 + 4.1414) * 43758.5453); }

// Smooth 1-D value noise (quintic fade, so curves have no kinks).
float vn(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(hash1(i), hash1(i + 1.0), f);
}

// Green -> yellow -> red with load, like htop/btop meters.
vec3 heat(float v) {
    v = clamp(v, 0.0, 1.0);
    return v < 0.5 ? mix(C_GREEN, C_YELLOW, v * 2.0) : mix(C_YELLOW, C_RED, v * 2.0 - 1.0);
}

void over(inout vec3 col, vec3 c, float a) { col = mix(col, c, clamp(a, 0.0, 1.0)); }

// ------------------------------------------------------------ fake telemetry
// A "build": load ramps up in ~1.4 s, holds a few seconds, then settles.
// Each period has exactly one, fully inside it, so no neighbour lookups.
float build(float t) {
    float e = floor(t / BUILD_EVERY);
    float off = (e == 0.0) ? 2.5 : 1.0 + hash1(e * 7.3 + 1.0) * 5.0;
    float dt = t - e * BUILD_EVERY - off;
    float hold = 3.5 + hash1(e * 3.1 + 2.0) * 3.5;
    // Builds differ: some are small incremental ones, about one period in four is quiet.
    float amp = (e == 0.0) ? 0.95 : mix(0.35, 1.0, hash1(e + 9.0)) * step(0.25, hash1(e * 1.9 + 4.0));
    float env = smoothstep(0.0, 1.4, dt) * (1.0 - smoothstep(hold, hold + 4.5, dt));
    // Inside a build the load wobbles as compile jobs start and finish, with a
    // short dip before the (lighter) link step at the end.
    float wob = 0.86 + 0.14 * vn(t * 2.3 + e * 11.0) - 0.22 * exp(-pow((dt - hold + 0.6) * 2.2, 2.0));
    return amp * env * wob;
}

float idleLoad(float t) {
    return 0.07 + 0.20 * vn(t * 0.30) + 0.08 * vn(t * 1.7 + 3.0) + 0.05 * vn(t * 4.3 + 9.0);
}

float cpuTotal(float t) {
    float base = idleLoad(t);
    float b = build(t);
    return clamp(base + b * (0.86 - base) * (0.88 + 0.12 * vn(t * 3.3)), 0.0, 1.0);
}

float coreLoad(float i, float t) {
    float base = idleLoad(t) * (0.45 + 1.1 * hash1(i * 5.7));
    base += 0.16 * (vn(t * 0.8 + i * 13.7) - 0.4) + 0.07 * (vn(t * 3.1 + i * 5.3) - 0.5);
    // Now and then one core pegs alone (a single-threaded job).
    base += 0.65 * smoothstep(0.80, 0.95, vn(t * 0.13 + i * 31.0));
    base = clamp(base, 0.02, 1.0);
    float b = build(t);
    return clamp(base + b * (0.96 - base) * (0.82 + 0.18 * vn(t * 2.7 + i * 7.1)), 0.0, 1.0);
}

float memUsed(float t)  { return 0.40 + 0.05 * vn(t * 0.05) + 0.17 * build(t - 1.5); }
float memCache(float t) { return 0.20 + 0.04 * vn(t * 0.03 + 5.0); }

float netDown(float t) {
    float d = 0.05 + 0.12 * vn(t * 0.9 + 20.0) + 0.75 * pow(vn(t * 0.37 + 40.0), 4.0);
    d += 0.65 * max(build(t + 0.8) - build(t - 2.5), 0.0);   // fetching deps as a build starts
    return clamp(d, 0.0, 1.0);
}
float netUp(float t) {
    return clamp(0.06 + 0.12 * vn(t * 1.1 + 60.0) + 0.6 * pow(vn(t * 0.23 + 80.0), 3.0), 0.0, 1.0);
}

// ------------------------------------------------------------ drawing helpers
float inRect(vec2 q, vec2 a, vec2 b) {   // a = min corner, b = max corner (pixel units)
    return step(a.x, q.x) * step(q.x, b.x) * step(a.y, q.y) * step(q.y, b.y);
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdRoundBox(vec2 p, vec2 h, float r) {
    vec2 q = abs(p) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// A section divider: faint full-width hairline with a short coloured tab at the
// left (where a label would sit) and a tiny live mini-meter at the right.
void divider(inout vec3 col, vec2 L, float x0, float iw, float y, vec3 c, float v) {
    if (abs(L.y - y) > 0.5) return;
    over(col, C_FRAME, 0.07);
    float tab = floor(iw * 0.05);
    if (L.x >= x0 && L.x <= x0 + tab) over(col, c, 0.75);
    float mw = floor(iw * 0.12);
    float mx = x0 + iw - mw;
    if (L.x >= mx && L.x <= x0 + iw) {
        float lit = step(L.x, mx + v * mw);
        over(col, c, 0.18 + 0.62 * lit);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float t = iTime;

    // Work in whole pixels with y up so every edge lands exactly on the pixel grid.
    vec2 P = vec2(fragCoord.x, iResolution.y - fragCoord.y);
    float W = floor(iResolution.x * PANEL_W);
    float H = floor(min(iResolution.y * PANEL_H, W * 0.95));
    float m = floor(iResolution.y * MARGIN);
    vec2 O = vec2(iResolution.x - m - W, m);
    vec2 L = P - O;

    // Pixels outside the panel cost nothing.
    if (INTENSITY <= 0.0 || L.x < -2.0 || L.y < -2.0 || L.x > W + 2.0 || L.y > H + 2.0) {
        fragColor = base;
        return;
    }

    float boot = smoothstep(0.0, 0.6, t);

    // --- Panel: darkened translucent glass, 1-px border, rounded corners.
    float rad = max(4.0, floor(H * 0.025));
    float d = sdRoundBox(L - vec2(W, H) * 0.5, vec2(W, H) * 0.5, rad);
    float inside = clamp(0.5 - d, 0.0, 1.0);
    vec3 col = base.rgb;
    col = mix(col, col * (1.0 - DIM) + vec3(0.012, 0.018, 0.028), inside);
    over(col, C_FRAME, clamp(1.0 - abs(d + 0.5), 0.0, 1.0) * 0.26);

    // --- Layout (top to bottom), all in whole pixels.
    float pad = floor(H * 0.04);
    float gap = floor(H * 0.04);
    float x0 = pad;
    float iw = W - 2.0 * pad;
    float x1 = x0 + iw;
    float hCore = floor(H * 0.21);
    float hHist = floor(H * 0.24);
    float hMem  = max(floor(H * 0.055), 8.0);
    float hNet  = floor(H * 0.20);
    float hDisk = max(floor(H * 0.08), 10.0);

    float yCoreT = H - pad - floor(gap * 0.5);  float yCoreB = yCoreT - hCore;
    float yHistT = yCoreB - gap;         float yHistB = yHistT - hHist;
    float yMemT  = yHistB - gap;         float yMemB  = yMemT - hMem;
    float yNetT  = yMemB - gap;          float yNetB  = yNetT - hNet;
    float yDiskT = yNetB - gap;          float yDiskB = yDiskT - hDisk;

    float total = cpuTotal(t);

    // Section dividers sit in the gaps above each widget.
    divider(col, L, x0, iw, floor(yCoreT + gap * 0.5) + 0.5, C_GREEN, total);
    divider(col, L, x0, iw, floor(yHistT + gap * 0.5) + 0.5, heat(total), total);
    divider(col, L, x0, iw, floor(yMemT + gap * 0.5) + 0.5, C_MEM, memUsed(t));
    divider(col, L, x0, iw, floor(yNetT + gap * 0.5) + 0.5, C_DOWN, netDown(t));
    divider(col, L, x0, iw, floor(yDiskT + gap * 0.5) + 0.5, C_READ, 0.3 + 0.5 * build(t));

    // --- CPU cores: 8 segmented LED meters with a peak-hold marker.
    if (L.y > yCoreB && L.y < yCoreT && L.x > x0 && L.x < x1) {
        float cg = max(3.0, floor(iw * 0.022));
        float cw = floor((iw - 7.0 * cg) / 8.0);
        float rel = L.x - x0;
        float i = floor(rel / (cw + cg));
        float wx = rel - i * (cw + cg);
        float tickH = max(3.0, floor(hCore * 0.07));
        float barB = yCoreB + tickH + 2.0;
        float barH = yCoreT - barB;
        if (i < 8.0 && wx < cw) {
            if (L.y > barB) {
                float segP = max(3.0, floor(barH / 20.0));
                float nSeg = floor(barH / segP);
                float yy = L.y - barB;
                float s = floor(yy / segP);
                float onSeg = step(mod(yy, segP), segP - 1.0) * step(s, nSeg - 1.0);
                float lv = coreLoad(i, t) * nSeg;
                float lit = clamp(lv - s, 0.0, 1.0);
                // Peak hold: recent maximum, slowly falling, like a VU meter.
                float pk = 0.0;
                for (int k = 1; k <= 4; k++) {
                    float fk = float(k);
                    pk = max(pk, coreLoad(i, t - fk * 0.45) - fk * 0.035);
                }
                float ps = floor(max(pk * nSeg, lv));
                float peak = step(abs(s - ps), 0.1) * step(lv, s + 0.5) * step(1.0, ps);
                vec3 c = heat((s + 0.5) / nSeg);
                over(col, c, onSeg * (0.08 + 0.80 * lit + 0.55 * peak));
            } else if (L.y < yCoreB + tickH) {
                // Index ticks under each core: a short centred mark.
                float cx = abs(wx + 0.5 - cw * 0.5);
                over(col, C_FRAME, step(cx, 1.0) * 0.45);
            } else if (L.y < yCoreB + tickH + 1.0) {
                over(col, C_FRAME, 0.12);   // baseline
            }
        }
    }

    // --- CPU history: scrolling polyline (one sample per DT) with a filled area.
    if (L.y > yHistB - 4.0 && L.y < yHistT + 1.0 && L.x > x0 - 1.0 && L.x < x1 + 5.0) {
        float pxs = iw / SPAN;                       // pixels per second
        bool inG = L.x >= x0 && L.x <= x1 && L.y >= yHistB && L.y <= yHistT;
        // Frame and right-side ticks at 0/25/50/75/100 %.
        float onFrame = (abs(L.x - x0) < 0.5 || abs(L.x - x1) < 0.5) && L.y >= yHistB && L.y <= yHistT ? 1.0 : 0.0;
        onFrame = max(onFrame, (abs(L.y - yHistB) < 0.5 || abs(L.y - yHistT) < 0.5) && L.x >= x0 && L.x <= x1 ? 1.0 : 0.0);
        over(col, C_FRAME, onFrame * 0.20);
        float qy = (L.y - yHistB) / hHist * 4.0;
        float qd = abs(qy - floor(qy + 0.5)) * hHist * 0.25;
        if (L.x > x1 + 1.0 && L.x < x1 + 4.0) over(col, C_FRAME, step(qd, 0.5) * 0.45);
        if (L.x > x0 - 0.5 && L.x < x0 + 3.0) over(col, C_FRAME, step(qd, 0.5) * 0.30 * step(L.y, yHistT - 1.0));
        if (inG) {
            // Dotted gridlines: horizontal at quarters, vertical every 10 s (they scroll).
            float hg = step(qd, 0.5) * step(mod(floor(L.x), 3.0), 0.5);
            float tx = t - (x1 - L.x) / pxs;
            float vd = abs(tx - floor(tx / 10.0 + 0.5) * 10.0) * pxs;
            float vg = clamp(1.0 - vd, 0.0, 1.0) * step(mod(floor(L.y), 3.0), 0.5);
            over(col, C_FRAME, max(hg, vg) * 0.10);

            const float DT = 0.75;
            float k = floor(tx / DT);
            vec2 pts[4];
            for (int j = 0; j < 4; j++) {
                float tk = min((k + float(j) - 1.0) * DT, t);
                pts[j] = vec2(x1 - (t - tk) * pxs, yHistB + 1.5 + cpuTotal(tk) * (hHist - 3.0));
            }
            // Height of the line at this x (on the segment containing it).
            float f = clamp((L.x - pts[1].x) / max(pts[2].x - pts[1].x, 1e-3), 0.0, 1.0);
            float yl = mix(pts[1].y, pts[2].y, f);
            float hNorm = (L.y - yHistB) / hHist;
            if (L.y < yl) {
                float g = (L.y - yHistB) / max(yl - yHistB, 1.0);
                over(col, heat(hNorm), 0.08 + 0.26 * g * g);
            }
            float ld = min(segDist(L, pts[0], pts[1]), min(segDist(L, pts[1], pts[2]), segDist(L, pts[2], pts[3])));
            over(col, heat(hNorm), clamp(1.3 - ld, 0.0, 1.0) * 0.95);
        }
        // Live head: a small dot where the newest sample is drawn.
        vec2 head = vec2(x1, yHistB + 1.5 + total * (hHist - 3.0));
        float hd = length(L - head);
        over(col, heat(total), clamp(2.6 - hd, 0.0, 1.0));
    }

    // --- Memory: segmented bar (used / cached / free) with eighth ticks below.
    if (L.y > yMemB && L.y < yMemT && L.x > x0 && L.x < x1) {
        float tickH = 3.0;
        float barB = yMemB + tickH + 1.0;
        float rx = L.x - x0;
        if (L.y > barB) {
            float sp = max(3.0, floor(iw / 80.0));
            float onSeg = step(mod(rx, sp), sp - 1.0);
            float fx = rx / iw;
            float used = memUsed(t), cache = memCache(t);
            float a = fx < used ? 0.80 : (fx < used + cache ? 0.32 : 0.07);
            over(col, C_MEM, onSeg * a);
        } else {
            float e = rx / iw * 8.0;
            float ed = abs(e - floor(e + 0.5)) * iw / 8.0;
            float major = step(abs(mod(floor(e + 0.5), 2.0)), 0.5);
            float len = major > 0.5 ? tickH : tickH - 1.0;
            over(col, C_FRAME, step(ed, 0.5) * step(barB - L.y, len) * 0.40);
        }
    }

    // --- Network: mirrored column sparkline, download up (cyan), upload down (violet).
    if (L.y > yNetB && L.y < yNetT && L.x > x0 && L.x < x1) {
        float mid = floor(yNetB + hNet * 0.5) + 0.5;
        float halfH = hNet * 0.5 - 1.0;
        if (abs(L.y - mid) < 0.5) {
            over(col, C_FRAME, 0.22);
        } else {
            float sp = iw / NET_SPAN;
            float cp = max(3.0, floor(iw / 120.0));
            float sc = floor(t * sp);   // whole-pixel scroll keeps columns crisp
            float u = L.x - x0 + mod(sc, cp);
            float c = floor(u / cp) + floor(sc / cp);
            float onCol = step(mod(u, cp), cp - 1.0);
            float tc = (c * cp - iw) / sp;
            float jit = 0.8 + 0.4 * hash1(c * 1.37);
            float up = L.y > mid ? 1.0 : 0.0;
            float v = up > 0.5 ? netDown(tc) * jit : netUp(tc) * (0.8 + 0.4 * hash1(c * 2.11 + 5.0));
            float h = max(1.0, floor(v * halfH));
            float dy = abs(L.y - mid) - 0.5;
            vec3 cc = up > 0.5 ? C_DOWN : C_UP;
            if (dy < h) {
                float tip = step(h - 1.0, dy);
                over(col, cc, onCol * (0.30 + 0.35 * dy / max(h, 1.0) + 0.30 * tip));
            }
        }
        // Faint quarter gridlines for scale.
        float gq = abs(abs(L.y - mid) - floor(halfH * 0.5));
        over(col, C_FRAME, step(gq, 0.5) * step(mod(floor(L.x), 3.0), 0.5) * 0.08);
    }

    // --- Disk: two rows of activity cells (read / write) blipping as they scroll.
    if (L.y > yDiskB && L.y < yDiskT && L.x > x0 && L.x < x1) {
        float sp = iw / NET_SPAN;
        float cp = max(5.0, floor(iw / 48.0));
        float rowH = floor((hDisk - 2.0) * 0.5);
        float sc = floor(t * sp);   // whole-pixel scroll keeps columns crisp
        float u = L.x - x0 + mod(sc, cp);
        float c = floor(u / cp) + floor(sc / cp);
        float tc = (c * cp - iw) / sp;
        float inCell = step(mod(u, cp), cp - 2.0);
        float row = L.y > yDiskB + rowH + 1.0 ? 0.0 : 1.0;   // 0 = read (top), 1 = write
        float yr = row < 0.5 ? L.y - (yDiskB + rowH + 2.0) : L.y - yDiskB;
        inCell *= step(0.0, yr) * step(yr, rowH);
        float b = build(tc);
        float r = hash1(c * 1.71 + row * 31.0);
        float thr = (row < 0.5 ? 0.74 : 0.82) - 0.42 * b;
        float on = step(thr, r);
        float lvl = 0.35 + 0.6 * hash1(c * 2.37 + row * 17.0);
        vec3 cc = row < 0.5 ? C_READ : C_WRITE;
        // The newest cell flashes briefly when it first appears.
        float age = t - tc;
        float fresh = exp(-age * 4.0);
        over(col, cc, inCell * (0.07 + on * (lvl * 0.75 + fresh * 0.3)));
    }

    // Fade the whole panel in at start; strength scales everything.
    col = mix(base.rgb, col, boot * INTENSITY);
    fragColor = vec4(col, base.a);
}
