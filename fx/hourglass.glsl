// hourglass — an ornate magic hourglass in the lower right: glowing golden sand drains through the neck, a flash when the last grain lands, then it turns over and runs again.
// zh: 魔法沙漏
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SIZE      = 0.165;  // half the hourglass height, in window heights (whole glass ~1/3 window)
const vec2  ANCHOR    = vec2(0.30, 0.225); // centre: x from the right edge, y from the bottom (window heights)
const float CYCLE     = 12.0;   // seconds per run: drain, flash, turn over, rest
const float DRAIN     = 7.6;    // seconds the sand runs
const float FLIPTIME  = 2.2;    // seconds the turn-over takes
const float GLOW      = 1.0;    // brightness of the glowing sand
const int   MOTES     = 7;      // magic motes rising from the stream

const float PI  = 3.14159265;
const float T0  = 0.3;          // sand starts running (cycle time)
const float LAG = 0.30;         // sand reaches the bottom pile this much later
const float TF  = T0 + DRAIN + LAG;   // last grain lands: flash
const float TS  = TF + 0.55;    // turn-over starts
const float GY  = 0.86;         // glass ends / collar starts (local units, half-height = 1)
const float BC  = 0.55;         // bulb centre height
const float WALL = 0.025;       // glass thickness
const float V0  = 0.6;          // grain speed through the neck (units / s)
const float GR  = 6.0;          // grain acceleration below the neck

const vec3 SAND  = vec3(1.00, 0.70, 0.30);
const vec3 SANDD = vec3(0.70, 0.40, 0.14);
const vec3 WOOD  = vec3(0.26, 0.15, 0.085);
const vec3 BRASS = vec3(0.82, 0.62, 0.30);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

float box(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// Outer glass half-width at height y, and its slope: a funnel from the
// narrow neck that rounds out into the bulb, then tucks in towards the collar.
vec2 glassW(float y) {
    float t = min(abs(y) / GY, 1.0);
    float a = min(t / 0.66, 1.0);
    float w = 0.035 + 0.48 * (1.0 - (1.0 - a) * (1.0 - a));
    float dw = 0.48 * 2.0 * (1.0 - a) / 0.66;
    if (t > 0.66) {
        float b = (t - 0.66) / 0.34;
        w = 0.515 - 0.115 * b * b;
        dw = -0.115 * 2.0 * b / 0.34;
    }
    return vec2(w, dw / GY);
}

// Sand level (height above the bulb centre, along "up") for fill f of a bulb
// whose far end points along c (+1 = far end up, -1 = far end down).
float sandLevel(float f, float c) {
    float empty = mix(-0.34, -0.60, 0.5 + 0.5 * c);
    // The neck end is narrow, so a draining top heap drops slowly at first and
    // fast at the end; the wide far end fills more evenly.
    float ex = mix(0.85, 0.45, 0.5 + 0.5 * c);
    float full = mix(0.27, 0.13, 0.5 + 0.5 * c);   // the wide far end needs a higher level for the same sand
    return mix(empty, full, pow(max(f, 0.0), ex));
}

// Twisted, turned wooden post centred at x = xc (local units). Premultiplied.
vec4 post(vec2 q, float xc, float px, vec3 L) {
    float ay = abs(q.y);
    if (ay > GY + 0.01) return vec4(0.0);
    float r = 0.036 + 0.026 * exp(-pow((ay - 0.80) / 0.035, 2.0))
                    + 0.016 * exp(-pow((ay - 0.715) / 0.018, 2.0));
    float dx = q.x - xc;
    float d = abs(dx) - r;
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return vec4(0.0);
    float nx = clamp(dx / r, -1.0, 1.0);
    vec3 n = vec3(nx, 0.0, sqrt(1.0 - nx * nx));
    // Helical ridges in the middle section: bands slant across the cylinder.
    float twist = 1.0 - smoothstep(0.66, 0.69, ay);
    float ph = q.y / 0.075 + asin(nx) * 0.9;
    float band = 0.5 + 0.5 * cos(2.0 * PI * ph);
    n = normalize(n + twist * vec3(0.0, -0.55 * sin(2.0 * PI * ph), 0.0));
    float dif = max(dot(n, L), 0.0);
    vec3 col = WOOD * (0.35 + 0.95 * dif);
    col *= mix(1.0, 0.55 + 0.45 * smoothstep(0.05, 0.45, band), twist);
    float spec = pow(max(dot(n, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 28.0);
    col += vec3(1.0, 0.86, 0.66) * spec * 0.55;
    return vec4(col, 1.0) * cov;
}

// One moulded tier of a base plate: wood with crisp lit / shadowed rims.
void tier(inout vec4 acc, vec2 q, float px, float y0, float y1, float hw, float sgn, float ly, vec3 grain) {
    float ay = abs(q.y);
    float d = box(vec2(q.x, ay - 0.5 * (y0 + y1)), vec2(hw, 0.5 * (y1 - y0)), 0.018);
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return;
    float v = (ay - y0) / (y1 - y0);                 // 0 inner rim .. 1 outer rim
    // Rounded edge: the rim facing the light is bright, the other one dark.
    float outerLit = max(sgn * ly, 0.0), innerLit = max(-sgn * ly, 0.0);
    vec3 col = WOOD * grain * (0.55 + 0.35 * (1.0 - abs(2.0 * v - 1.0)));
    float rimO = smoothstep(0.80, 1.0, v), rimI = smoothstep(0.20, 0.0, v);
    col = mix(col, vec3(0.62, 0.44, 0.30), rimO * outerLit * 0.8 + rimI * innerLit * 0.8);
    col *= 1.0 - 0.45 * (rimO * (1.0 - outerLit) + rimI * (1.0 - innerLit));
    // Darker rounded ends left and right.
    col *= 0.65 + 0.35 * smoothstep(hw, hw - 0.12, abs(q.x));
    over(acc, col, cov);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float t = mod(iTime + 1.5, CYCLE);               // start mid-run: sand already flowing
    float cyc = floor((iTime + 1.5) / CYCLE);

    // Turn-over: eased 0 -> PI with a gentle lift, so it reads as picked up and set down.
    float k = clamp((t - TS) / FLIPTIME, 0.0, 1.0);
    float e = k * k * k * (k * (6.0 * k - 15.0) + 10.0);
    float th = PI * e;
    float lift = 0.045 * sin(PI * smoothstep(0.0, 1.0, k));
    vec2 C0 = vec2(aspect - ANCHOR.x, ANCHOR.y);
    vec2 C = C0 + vec2(0.0, lift);

    float flash = smoothstep(TF - 0.04, TF + 0.06, t) * exp(-max(t - TF, 0.0) * 3.2);
    float flowing = step(t, TS);

    vec3 Lw = normalize(vec3(-0.55, 0.65, 0.55));    // main light: upper left, in front
    vec3 rgb = base.rgb;
    vec3 glow = vec3(0.0);

    float px = 1.0 / (iResolution.y * SIZE);
    vec2 q = rot(p - C, -th) / SIZE;                 // hourglass frame (rotates with it)
    vec3 L = vec3(rot(Lw.xy, -th), Lw.z);

    if (length(q) < 1.40) {
        vec4 acc = vec4(0.0);

        // Back post, seen through the glass: dimmer, slightly cooler.
        vec4 bp = post(q, 0.0, px, L);
        over(acc, bp.rgb / max(bp.a, 1e-4) * 0.55, bp.a * 0.85);

        // ----- glass shape
        float ay = abs(q.y);
        vec2 gw = glassW(q.y);
        float sl = sqrt(1.0 + gw.y * gw.y);
        float dO = max((abs(q.x) - gw.x) / sl, ay - GY);
        float dI = max((abs(q.x) - max(gw.x - WALL, 0.012)) / sl, ay - GY);
        float covO = smoothstep(px, -px, dO);
        float covI = smoothstep(px, -px, dI);
        over(acc, vec3(0.80, 0.86, 0.92), covO * 0.06);

        // ----- sand (heights measured along "up", which turns during the flip;
        // the surface lags the glass a little, like sand at its angle of repose)
        float ths = th - 0.45 * sin(th);
        vec2 U = rot(vec2(0.0, 1.0), -ths);
        float bulb = sign(q.y + 1e-5);               // +1 local top bulb, -1 local bottom
        vec2 cb = vec2(0.0, BC * bulb);
        float hgt = dot(q - cb, U);
        float xh = dot(q - cb, vec2(U.y, -U.x));
        float c = dot(vec2(0.0, bulb), U);           // far end of this bulb up (+1) / down (-1)

        float prog = clamp((t - T0) / DRAIN, 0.0, 1.0);
        float progB = clamp((t - T0 - LAG) / DRAIN, 0.0, 1.0);
        float f, bump;
        if (bulb > 0.0) {
            // Top bulb: drains, with a conical dip above the neck.
            f = t < TS ? 1.0 - prog : 0.0;
            float dip = 0.16 * smoothstep(0.0, 0.12, prog);
            bump = -dip * max(1.0 - abs(xh) / 0.30, 0.0);
        } else {
            // Bottom bulb: a cone grows under the stream; it flattens as it turns over.
            f = t < TS ? progB : 1.0;
            float cone = (0.05 + 0.10 * smoothstep(0.0, 0.5, f)) * smoothstep(0.0, 0.08, f);
            cone *= 1.0 - smoothstep(0.08, 0.40, ths / PI);
            bump = cone * max(1.0 - abs(xh) / 0.38, 0.0) - 0.03 * cone / 0.15;
        }
        float lev = sandLevel(f, c) + bump;
        float dS = lev - hgt;                        // > 0 inside the sand
        float sc = smoothstep(-px, px, dS) * covI * step(0.004, f);
        if (sc > 0.0) {
            vec2 cell = floor(q * 95.0);
            float g = hash2(cell + cyc * 0.0);
            float g2 = hash2(cell + 17.3);
            float depth = clamp(dS / 0.30, 0.0, 1.0);
            vec3 col = mix(SAND, SANDD, depth);
            col *= 0.86 + 0.28 * g;
            col *= 0.72 + 0.28 * (1.0 - pow(abs(q.x) / max(gw.x, 0.05), 3.0));
            col = mix(col, vec3(1.0, 0.95, 0.75), step(0.985, g2) * 0.8);
            // Crisp lit surface line on top of each heap.
            float rim = smoothstep(2.2 * px, 0.6 * px, dS);
            col = mix(col, vec3(1.0, 0.90, 0.62), rim * 0.85);
            col *= GLOW * (1.0 + 0.9 * flash);
            over(acc, min(col, vec3(1.0)), sc * 0.94);
        }

        // ----- the falling stream (only while upright and running)
        if (flowing > 0.5 && abs(q.x) < 0.06 && q.y < 0.04 && q.y > -0.95) {
            // Where the stream lands: top of the bottom pile.
            float fB = progB;
            float cone = (0.05 + 0.10 * smoothstep(0.0, 0.5, fB)) * smoothstep(0.0, 0.08, fB);
            float yEnd = max(-BC + sandLevel(fB, -1.0) + cone * 0.8, -GY);
            if (q.y > yEnd) {
                float dd = max(-q.y, 0.0);
                float tau = (-V0 + sqrt(V0 * V0 + 2.0 * GR * dd)) / GR;   // time since leaving the neck
                float rel = t - tau;                                        // when it left the neck
                float on = step(T0, rel) * step(rel, T0 + DRAIN);
                // Thin continuous thread.
                float wth = 0.006 + 0.004 * smoothstep(0.0, -0.4, q.y);
                float core = smoothstep(px, 0.0, abs(q.x) - wth * 0.5) * min(1.0, wth / px + 0.3);
                over(acc, vec3(1.0, 0.82, 0.45) * GLOW, core * on * 0.55);
                // Individual grains, crisp, drifting apart as they accelerate.
                const float DT = 0.028;
                float n0 = floor(rel / DT);
                for (int j = -1; j <= 1; j++) {
                    float n = n0 + float(j);
                    float tr = n * DT;
                    if (tr < T0 || tr > T0 + DRAIN) continue;
                    float a = t - tr;
                    float gy = -(V0 * a + 0.5 * GR * a * a);
                    if (gy < yEnd) continue;
                    float gx = (hash1(n * 1.7 + cyc) - 0.5) * 0.030 * smoothstep(0.0, -0.5, gy);
                    float gr = 0.008 + 0.004 * hash1(n * 3.1);
                    float dg = length(q - vec2(gx, gy)) - gr;
                    float gc = smoothstep(px, -px, dg);
                    over(acc, mix(SAND, vec3(1.0, 0.94, 0.75), hash1(n * 5.3)) * GLOW, gc);
                }
            }
        }

        // ----- glass: Fresnel rims and a window reflection
        float wallB = covO * (1.0 - covI);
        float lit = 0.5 + 0.5 * sign(q.x) * normalize(L.xy).x;
        over(acc, vec3(0.85, 0.90, 0.96), wallB * (0.18 + 0.12 * lit));
        float fres = covI * smoothstep(0.05, 0.0, -dI) * (1.0 - 0.6 * sc);
        over(acc, vec3(0.80, 0.88, 0.96), fres * 0.16);
        float edge = smoothstep(1.3 * px, 0.0, abs(dO));
        over(acc, vec3(0.92, 0.95, 1.0), edge * (0.40 + 0.35 * lit + 0.4 * flash));
        // Window highlight: a slim streak on the light side, following the bulb.
        float side = clamp(L.x / 0.6, -1.0, 1.0);
        float hx = 0.60 * gw.x * side;
        float ax = abs(abs(q.y) - 0.53);
        float dh = max(abs(q.x - hx) - 0.020 * (1.0 - ax * ax / 0.08), ax - 0.25);
        over(acc, vec3(1.0), smoothstep(px, -px, dh) * covI * 0.42 * abs(side));
        float dh2 = length(vec2((q.x + 0.42 * hx) / 0.6, ax - 0.12)) - 0.012;
        over(acc, vec3(1.0), smoothstep(px, -px, dh2) * covI * 0.35 * abs(side));

        // ----- front posts
        vec4 fp = post(q, -0.66, px, L);
        acc = fp + acc * (1.0 - fp.a);
        fp = post(q, 0.66, px, L);
        acc = fp + acc * (1.0 - fp.a);

        // ----- brass collars where the glass meets the plates
        {
            float d = box(vec2(q.x, ay - 0.835), vec2(0.45, 0.032), 0.015);
            float cov = smoothstep(px, -px, d);
            if (cov > 0.0) {
                float nx = clamp(q.x / 0.45, -1.0, 1.0);
                vec3 n = vec3(nx, 0.0, sqrt(1.0 - nx * nx));
                float dif = max(dot(n, L), 0.0);
                float spec = pow(max(dot(n, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 40.0);
                vec3 col = BRASS * (0.30 + 0.80 * dif) + vec3(1.0, 0.92, 0.75) * spec * 0.7;
                float ring = smoothstep(1.2 * px, 0.0, abs(ay - 0.835) - 0.004);
                col *= 1.0 - 0.35 * ring;               // engraved ring around the middle
                over(acc, col, cov);
            }
        }

        // ----- plates (two moulded tiers) and bun feet
        float sgn = sign(q.y + 1e-5);
        vec3 grain = vec3(0.85 + 0.30 * hash2(floor(vec2(q.x * 7.0, q.y * 260.0))));
        tier(acc, q, px, 0.86, 0.905, 0.70, sgn, L.y, grain);
        tier(acc, q, px, 0.905, 0.985, 0.80, sgn, L.y, grain);
        {
            // Brass inlay line along the main tier.
            float d = max(abs(ay - 0.945) - 0.008, abs(q.x) - 0.77);
            float cov = smoothstep(px, -px, d);
            float lt = 0.5 + 0.5 * sgn * L.y;
            over(acc, BRASS * (0.55 + 0.6 * lt) * (0.75 + 0.25 * smoothstep(0.7, 0.0, abs(q.x))), cov);
        }
        {
            vec2 fq = vec2(abs(q.x) - 0.60, ay - 0.995);
            float d = (length(fq / vec2(0.080, 0.048)) - 1.0) * 0.048;
            d = max(d, 0.985 - ay);
            float cov = smoothstep(px, -px, d);
            if (cov > 0.0) {
                vec2 nn = fq / vec2(0.080, 0.048);
                vec3 n = normalize(vec3(nn.x * sign(q.x), nn.y * sgn, 0.6));
                float dif = max(dot(n, L), 0.0);
                vec3 col = BRASS * (0.25 + 0.80 * dif);
                col += vec3(1.0, 0.9, 0.7) * pow(max(dot(n, normalize(L + vec3(0, 0, 1))), 0.0), 30.0) * 0.6;
                over(acc, col, cov);
            }
        }

        rgb = rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY;
    }

    // ----- flash when the last grain lands: a crisp expanding ring and a star glint
    if (flash > 0.003) {
        float age = max(t - TF, 0.0);
        vec2 pile = C0 + vec2(0.0, (-BC + sandLevel(1.0, -1.0) + 0.12) * SIZE);
        float r = SIZE * (1.0 + 1.8 * age);
        float dr = abs(length(p - C0) - r);
        float lpx = 1.0 / iResolution.y;
        glow += vec3(1.0, 0.80, 0.45) * smoothstep(1.6 * lpx, 0.0, dr) * flash * 0.8;
        glow += vec3(1.0, 0.75, 0.40) * exp(-dr / (4.0 * lpx)) * flash * 0.20;
        vec2 d = abs(p - pile);
        float ray = max(exp(-d.y / (1.2 * lpx)) * smoothstep(0.12, 0.0, d.x),
                        exp(-d.x / (1.2 * lpx)) * smoothstep(0.07, 0.0, d.y));
        glow += vec3(1.0, 0.92, 0.70) * ray * flash * 0.9;
        glow += vec3(1.0, 0.80, 0.45) * exp(-length(p - pile) / (0.012)) * flash * 0.35;
    }

    // ----- magic motes drifting up out of the stream
    float lpx = 1.0 / iResolution.y;
    for (int i = 0; i < MOTES; i++) {
        float fi = float(i);
        float per = 2.8 + 0.5 * hash1(fi * 3.7);
        float u = iTime + 1.5 + fi * per / float(MOTES) * 1.7;
        float n = floor(u / per);
        float age = u - n * per;
        float born = mod(iTime + 1.5 - age, CYCLE);   // cycle time when this mote appeared
        if (born < T0 + 0.2 || born > T0 + DRAIN) continue;
        float s = n * 11.3 + fi * 5.1;
        float side = hash1(s) < 0.5 ? -1.0 : 1.0;
        vec2 start = C0 + SIZE * vec2(0.0, -0.15 - 0.45 * hash1(s + 1.0));
        float x = side * SIZE * (0.15 + 0.55 * hash1(s + 2.0)) * smoothstep(0.0, 1.6, age)
                + 0.02 * sin(age * 2.2 + s);
        vec2 mp = start + vec2(x, SIZE * 0.55 * age + 0.02 * age * age);
        float life = smoothstep(0.0, 0.35, age) * smoothstep(per, per * 0.55, age);
        float tw = 0.65 + 0.35 * sin(iTime * 7.0 + s * 3.0);
        float dm = length(p - mp);
        float core = smoothstep(1.6 * lpx, 0.4 * lpx, dm);
        glow += vec3(1.0, 0.85, 0.50) * (core * 0.85 + exp(-dm / (2.5 * lpx)) * 0.30) * life * tw;
    }

    rgb += glow * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
