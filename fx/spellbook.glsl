// spellbook — an old leather-bound spellbook lies open in the lower right; every few seconds a page turns over and small glowing glyphs drift up.
// zh: 魔法书
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SCALE     = 0.235;  // one page width, in window heights (the open book is ~2.1 page widths wide)
const vec2  ANCHOR    = vec2(0.33, 0.20); // book centre: x from the right edge, y from the bottom (window heights)
const float TILT      = 0.07;   // the book lies slightly turned on the table (radians)
const float PERIOD    = 7.0;    // seconds between page turns
const float TURN      = 2.3;    // seconds one page turn takes
const float GLOW      = 0.50;   // warm magic light on the page surface
const int   GLYPHS    = 9;      // glowing glyphs in the air at once
const float LIFE      = 5.0;    // seconds a glyph floats before it fades out
const float GLYPH_SIZE = 0.030; // glyph height, in window heights

const float PI  = 3.14159265;
const float H   = 1.38;         // page height along the spine (page width = 1)
const float M   = 0.09;         // cover margin around the page block
const float ELC = 0.82;         // view from ~55 degrees above the table: depth is
const float ELS = 0.57;         //   squashed by ELC, heights are seen at ELS
const float SH  = 0.20;         // we look from slightly right of centre: raised points shift left
const float KEY = 0.10;         // mild perspective: the far end looks a bit narrower
const float A0  = 0.22;         // slope of a resting page where it leaves the gutter
const float ZG  = -0.03;        // gutter height (pages dip into the binding)
const float ZB  = -0.04;        // top of the cover board, bottom of the page block
const float TC  = 0.045;        // cover board thickness
const vec3  LIGHT = vec3(-0.45, -0.25, 0.86); // main light: above, a little left and in front

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// ---------------------------------------------------------------- camera
// Book space: x across (spine at 0, right page 0..1), y along the spine
// (0 = near edge, H = far edge), z up. "Ortho" space is the flat view:
// X = x, Y = depth squashed + height. A small keystone and a turn then place it
// on screen. Both directions are cheap, so every surface is drawn by inverting.
vec2 center(float aspect) { return vec2(aspect - ANCHOR.x, ANCHOR.y); }

vec2 toOrtho(vec2 p, float aspect) {
    vec2 v = rot(p - center(aspect), -TILT) / SCALE;
    return vec2(v.x / (1.0 - KEY * v.y), v.y);
}

vec2 toScreen(vec3 b, float aspect) {
    float Y = (b.y - 0.5 * H) * ELC + b.z * ELS;
    float X = b.x - SH * b.z;
    return center(aspect) + rot(vec2(X * (1.0 - KEY * Y), Y) * SCALE, TILT);
}

// ---------------------------------------------------------------- pages
// A page is a circular arc of length 1 leaving the gutter at angle a0 and
// ending at angle a0 + k (angles in the x-z plane: 0 = lying right, PI = left).
float arcX(float a0, float k, float s) { return (sin(a0 + k * s) - sin(a0)) / k; }
float arcZ(float a0, float k, float s) { return ZG + (cos(a0) - cos(a0 + k * s)) / k; }

// Height of a resting right page above x (same arc as a turning page at rest).
float restZ(float x) {
    float r = sin(A0) - A0 * x;
    return ZG + (sqrt(max(1.0 - r * r, 0.0)) - cos(A0)) / A0;
}

// Ink and parchment of one page. pg = (u across from the page's left edge,
// y from the near edge), idx picks the content, px = one pixel in page units.
vec3 pageColor(vec2 pg, float idx, float px) {
    float u = pg.x, y = pg.y;

    // Parchment: mottled, fibrous, browner and darker towards the edges.
    float n1 = noise(pg * 5.0 + idx * 7.3);
    float n2 = noise(pg * vec2(40.0, 9.0) + idx * 3.1);
    vec3 col = vec3(0.87, 0.78, 0.59) * (0.94 + 0.07 * n1) * (0.96 + 0.06 * n2);
    float e = min(min(u, 1.0 - u), min(y, H - y));
    float age = smoothstep(0.0, 0.10 + 0.06 * n1, e);
    col = mix(col * vec3(0.72, 0.58, 0.40), col, age);
    float fox = noise(pg * 13.0 + idx * 11.7);
    col *= 1.0 - 0.13 * smoothstep(0.70, 0.84, fox);

    vec3 ink = vec3(0.14, 0.09, 0.06);
    vec3 red = vec3(0.45, 0.13, 0.07);
    float w = max(0.0038, 0.55 * px);       // pen width, at least about one pixel

    // A small diagram on one side, text flowing beside and around it.
    float h0 = hash1(idx * 1.37 + 0.5), h1 = hash1(idx * 2.11 + 1.7), h2 = hash1(idx * 3.07 + 2.3);
    vec2 dc = vec2(h0 < 0.5 ? 0.32 : 0.68, H * mix(0.36, 0.64, h1));
    float R = 0.165;
    vec2 q = pg - dc;
    float lq = length(q);
    float dd = 1e3, dr = 1e3;
    if (lq < R + 0.05) {
        int type = int(mod(idx + floor(h2 * 2.0), 3.0));
        dr = abs(lq - R);
        if (type == 0) {
            // Circle with an inscribed pentagram.
            for (int i = 0; i < 5; i++) {
                float a = float(i) * 2.0 * PI / 5.0, b = float(i + 2) * 2.0 * PI / 5.0;
                dd = min(dd, segment(q, R * vec2(sin(a), cos(a)), R * vec2(sin(b), cos(b))));
            }
            dr = min(dr, abs(lq - 0.08 * R));
        } else if (type == 1) {
            // Astrolabe: two rings with ticks between and a triangle inside.
            dr = min(dr, abs(lq - 0.78 * R));
            float a = atan(q.y, q.x) / (2.0 * PI) * 24.0;
            float tick = abs(fract(a) - 0.5) * 2.0 * PI / 24.0 * lq;
            if (lq > 0.78 * R && lq < R) dd = min(dd, tick);
            for (int i = 0; i < 3; i++) {
                float a1 = float(i) * 2.0 * PI / 3.0, b1 = float(i + 1) * 2.0 * PI / 3.0;
                dd = min(dd, segment(q, 0.7 * R * vec2(sin(a1), cos(a1)), 0.7 * R * vec2(sin(b1), cos(b1))));
            }
        } else {
            // Hexagram in a double circle.
            dr = min(dr, abs(lq - 0.9 * R));
            for (int i = 0; i < 6; i++) {
                float a1 = float(i) * PI / 3.0, b1 = float(i + 2) * PI / 3.0;
                dd = min(dd, segment(q, 0.82 * R * vec2(sin(a1), cos(a1)), 0.82 * R * vec2(sin(b1), cos(b1))));
            }
        }
    }
    float diag = smoothstep(w + px, w, dd);
    float ring = smoothstep(w + px, w, dr);

    // Handwriting: rows of cursive-looking scribble, broken into words.
    const float G = 0.075;                  // line spacing
    float top = H - 0.15;
    float rf = (top - y) / G;
    float row = floor(rf);
    float text = 0.0;
    if (row >= 0.0 && row < floor((H - 0.30) / G)) {
        float rs = row * 3.17 + idx * 17.9;
        float yl = fract(rf);
        float u0 = 0.13, u1 = 0.87;
        float yr = top - (row + 0.5) * G;
        if (abs(yr - dc.y) < R + 0.04) {     // share the band with the diagram
            if (dc.x < 0.5) u0 = dc.x + R + 0.05; else u1 = dc.x - R - 0.05;
        }
        if (hash1(rs) < 0.14) u1 = mix(u0, u1, 0.35 + 0.4 * hash1(rs + 0.7));  // paragraph end
        if (u > u0 && u < u1) {
            float ph = hash1(rs + 1.9) * 40.0;
            float f = u * 230.0 + ph + 1.4 * sin(u * 31.0 + ph);
            float df = 230.0 + 43.4 * cos(u * 31.0 + ph);
            float tall = smoothstep(0.80, 0.97, noise(vec2(u * 60.0 + ph, row)));
            float amp = 0.15 + 0.17 * tall;
            float yc = 0.66 - amp * (0.5 + 0.5 * sin(f));
            float slope = amp * 0.5 * cos(f) * df * G;
            float d = abs(yl - yc) * G / sqrt(1.0 + slope * slope);
            float word = step(0.16, fract(u * 8.0 + hash1(rs + 3.3) * 5.0 + 0.3 * sin(u * 13.0 + ph)));
            word *= smoothstep(u0, u0 + px, u) * smoothstep(u1, u1 - px, u);
            text = smoothstep(w + px, w, d) * word;
        }
    }

    float fade = 0.78 + 0.22 * noise(pg * 22.0 + idx);   // ink soaks in unevenly
    col = mix(col, ink, text * 0.82 * fade);
    col = mix(col, ink, diag * 0.85 * fade);
    col = mix(col, red, ring * 0.85 * fade);
    return col;
}

// Paper brightness from the main light, for a page surface at angle phi.
float pageLight(float phi, float side) {
    vec3 n = side * vec3(-sin(phi), 0.0, cos(phi));   // side = -1 for the back of a page
    return 0.52 + 0.52 * max(dot(n, normalize(LIGHT)), 0.0);
}

// Warm magic light pooled on the open spread (tight, centred on the gutter).
vec3 magicLight(vec3 col, float x, float y, float t) {
    float yy = (y - 0.5 * H) / H;
    float g = exp(-(x * x * 2.2 + yy * yy * 6.0)) * GLOW * (0.85 + 0.15 * sin(t * 1.7));
    return col * (1.0 + g * vec3(0.55, 0.32, 0.08)) + g * vec3(0.10, 0.05, 0.0);
}

// ---------------------------------------------------------------- cover
vec3 leather(vec2 c, float edge) {
    float g1 = noise(c * 55.0), g2 = noise(c * 9.0 + 4.0);
    vec3 col = vec3(0.30, 0.12, 0.07) * (0.80 + 0.30 * g2) * (0.90 + 0.18 * g1);
    // Rubbed, paler leather along the worn outer edge.
    float wear = (1.0 - smoothstep(0.0, 0.035, edge)) * (0.5 + 0.5 * noise(c * 30.0 + 9.0));
    return mix(col, vec3(0.50, 0.33, 0.22), wear * 0.6);
}

vec3 gold(vec2 c, float shade) {
    float b = noise(c * vec2(90.0, 12.0));
    vec3 col = vec3(0.80, 0.60, 0.26) * (0.72 + 0.35 * shade) * (0.88 + 0.2 * b);
    return col;
}

// ---------------------------------------------------------------- glyphs
// Rune-like letters in a unit box, built from a few strokes.
float glyph(vec2 q, int type) {
    float d = 1e3;
    if (type == 0) {
        d = segment(q, vec2(-0.12, -0.5), vec2(-0.12, 0.5));
        d = min(d, segment(q, vec2(-0.12, 0.45), vec2(0.28, 0.15)));
        d = min(d, segment(q, vec2(-0.12, 0.08), vec2(0.28, -0.22)));
    } else if (type == 1) {
        d = segment(q, vec2(-0.3, -0.5), vec2(0.0, 0.5));
        d = min(d, segment(q, vec2(0.0, 0.5), vec2(0.3, -0.5)));
        d = min(d, segment(q, vec2(-0.17, -0.08), vec2(0.17, -0.08)));
    } else if (type == 2) {
        d = abs(length(q * vec2(1.0, 1.25)) - 0.28) * 0.85;
        d = min(d, segment(q, vec2(0.0, -0.5), vec2(0.0, 0.5)));
    } else if (type == 3) {
        d = segment(q, vec2(-0.3, -0.5), vec2(-0.3, 0.5));
        d = min(d, segment(q, vec2(0.3, -0.5), vec2(0.3, 0.5)));
        d = min(d, segment(q, vec2(-0.3, 0.5), vec2(0.3, -0.5)));
        d = min(d, segment(q, vec2(-0.3, -0.5), vec2(0.3, 0.5)));
    } else if (type == 4) {
        d = segment(q, vec2(-0.22, -0.5), vec2(-0.22, 0.5));
        d = min(d, segment(q, vec2(-0.22, 0.42), vec2(0.25, 0.0)));
        d = min(d, segment(q, vec2(0.25, 0.0), vec2(-0.22, -0.42)));
    } else {
        d = segment(q, vec2(-0.2, -0.5), vec2(-0.2, 0.5));
        d = min(d, segment(q, vec2(-0.2, 0.5), vec2(0.25, 0.25)));
        d = min(d, segment(q, vec2(0.25, 0.25), vec2(-0.2, 0.0)));
        d = min(d, segment(q, vec2(-0.2, 0.0), vec2(0.25, -0.5)));
    }
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec3 rgb = base.rgb;
    float t = iTime;
    vec2 C0 = center(aspect);

    // ------------------------------------------------ the book
    if (abs(p.x - C0.x) < 1.25 * SCALE + 0.04 && p.y - C0.y > -0.85 * SCALE && p.y - C0.y < 1.30 * SCALE) {
        vec2 o = toOrtho(p, aspect);
        float X = o.x, Y = o.y;
        float px = 1.0 / (iResolution.y * SCALE);   // one pixel in book units
        vec4 acc = vec4(0.0);
        vec3 L = normalize(LIGHT);

        // Which spread is open, and how far the current turn has got.
        float cyc = (t - 0.8) / PERIOD;
        float n = floor(cyc);
        float tt = clamp(fract(cyc) * PERIOD / TURN, 0.0, 1.0);
        float E = tt * tt * tt * (tt * (tt * 6.0 - 15.0) + 10.0);
        bool turning = tt > 0.0 && tt < 1.0;
        float pg0 = 2.0 * n;                    // left page of the open spread
        // During and after a turn the right page shows the next spread already.
        float leftIdx  = tt >= 1.0 ? pg0 + 2.0 : pg0;
        float rightIdx = tt > 0.0 ? pg0 + 3.0 : pg0 + 1.0;

        // Turning page shape: the root swings from right to left; the free edge
        // first leads (lifted by a finger) then trails (air drag), then lands.
        float a0 = mix(A0, PI - A0, E);
        float a1 = clamp(PI * E + 0.75 * sin(PI * tt) * (1.0 - 1.6 * tt), 0.0, PI);
        float k = a1 - a0;
        if (abs(k) < 0.01) k = k < 0.0 ? -0.01 : 0.01;

        // Soft contact shadow of the whole book on whatever is behind it.
        {
            float yg = (Y - (ZB - TC) * ELS) / ELC + 0.5 * H;
            vec2 dq = vec2(abs(X + SH * (ZB - TC)) - (1.0 + M), abs(yg - 0.5 * H) - (0.5 * H + M));
            float dbox = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0);
            rgb *= 1.0 - 0.45 * INTENSITY * smoothstep(0.10, -0.02, dbox - 0.02);
        }

        // Cover board, top face (the leather turn-ins around the page block).
        {
            float y = (Y - ZB * ELS) / ELC + 0.5 * H;
            float xc = X + SH * ZB;
            float ex = 1.0 + M - abs(xc), ey = min(y + M, H + M - y);
            float edge = min(ex, ey);
            if (edge > -px) {
                vec2 cc = vec2(xc, y);
                vec3 col = leather(cc, edge);
                // Gold tooling: a fine double fillet along the margin.
                float fl = min(abs(edge - 0.030), abs(edge - 0.042));
                col = mix(col, gold(cc, 0.7), smoothstep(0.8 * px + 0.003, 0.003, fl) * 0.85);
                // Gold corner pieces with a scalloped inner edge.
                float ca = ex, cb = ey;
                float sc = ca + cb - (0.20 + 0.012 * sin(atan(cb, ca) * 14.0));
                float corner = smoothstep(px, -px, sc);
                if (corner > 0.0) {
                    float sh = 0.5 + 0.5 * (ca - cb) / 0.2;
                    vec3 gc = gold(cc, 0.75 + 0.25 * sh);
                    gc *= 1.0 - 0.45 * smoothstep(1.2 * px, 0.0, abs(sc + 0.035));  // tooled line
                    gc = mix(gc, vec3(1.0, 0.92, 0.70), smoothstep(0.016, 0.0, abs(sc + 0.012)) * 0.45); // bevel glint
                    col = mix(col, gc, corner);
                }
                // Darker leather in the spine hollow.
                col *= 0.70 + 0.30 * smoothstep(0.0, 0.06, abs(xc));
                col *= 0.80 + 0.25 * smoothstep(0.0, 1.0, (y + M) / (H + 2.0 * M)); // far end catches more light
                over(acc, col, smoothstep(-px, px, edge));
            }
        }
        // Cover board, near face (its thickness).
        {
            float z = (Y - (-M - 0.5 * H) * ELC) / ELS;
            float ex = 1.0 + M - abs(X + SH * z);
            if (z > ZB - TC - px && z < ZB + px && ex > -px) {
                vec3 col = leather(vec2(X, z * 3.0), 1.0) * 0.62;
                col = mix(col, vec3(0.52, 0.34, 0.22), smoothstep(0.012, 0.0, ZB - z) * 0.5); // worn top edge
                if (ex < 0.20 - 0.012) col = gold(vec2(X, z), 0.55 + 0.4 * smoothstep(ZB - TC, ZB, z));
                float cov = smoothstep(-px, px, ex) * smoothstep(-px, px, z - (ZB - TC)) * smoothstep(-px, px, ZB - z);
                over(acc, col, cov);
            }
        }
        // Page block, near face: the stacked page edges.
        {
            float z = (Y + 0.5 * H * ELC) / ELS;
            float ax = abs(X + SH * z);
            if (ax < 0.992 && z > ZB - px) {
                float zt = restZ(ax);
                if (z < zt + px) {
                    float lines = noise(vec2(ax * 3.0, z * 260.0));
                    vec3 col = vec3(0.80, 0.70, 0.52) * (0.78 + 0.18 * lines);
                    col *= 0.72 + 0.28 * smoothstep(ZB, zt, z);            // darker low down
                    col = mix(col * 0.75, col, smoothstep(0.0, 0.08, 0.992 - ax));
                    float cov = smoothstep(-px, px, zt - z) * smoothstep(-px, px, z - ZB);
                    over(acc, col, cov);
                }
            }
        }
        // Page block, right side face (seen because we look from a little right).
        {
            float xm = sin(A0) / A0;
            float z = (xm - X) / SH;
            float zt = restZ(xm);
            if (z > ZB - px && z < zt + px) {
                float y = (Y - z * ELS) / ELC + 0.5 * H;
                if (y > -px && y < H + px) {
                    float lines = noise(vec2(y * 3.0, z * 260.0));
                    vec3 col = vec3(0.74, 0.63, 0.46) * (0.80 + 0.18 * lines);
                    float cov = smoothstep(-px, px, zt - z) * smoothstep(-px, px, z - ZB)
                              * smoothstep(-px, px, y) * smoothstep(-px, px, H - y);
                    over(acc, col, cov);
                }
            }
        }
        // Resting pages (left and right), with the turning page's shadow.
        {
            float xs = X + SH * restZ(abs(X));
            xs = X + SH * restZ(abs(xs));          // two fixed-point steps are plenty
            float ax = abs(xs);
            float r = sin(A0) - A0 * ax;
            if (ax < sin(A0) / A0 + px && r > -1.0) {
                float phi = asin(clamp(r, -1.0, 1.0));
                float s = 1.0 - phi / A0;
                float z = restZ(ax);
                float y = (Y - z * ELS) / ELC + 0.5 * H;
                if (y > -px && y < H + px) {
                    bool right = xs > 0.0;
                    float idx = right ? rightIdx : leftIdx;
                    vec2 pgc = vec2(right ? s : 1.0 - s, y);
                    vec3 col = pageColor(pgc, idx, px);
                    col *= pageLight(right ? phi : PI - phi, right ? 1.0 : -1.0);
                    col *= 0.62 + 0.38 * smoothstep(0.0, 0.16, s);        // gutter shadow
                    // Shadow cast by the lifted page onto the page it is over.
                    if (turning) {
                        float lift = sin(PI * tt);
                        float xr = max(arcX(a0, k, 1.0), arcX(a0, k, clamp((0.5 * PI - a0) / k, 0.0, 1.0)));
                        float xl = min(arcX(a0, k, 1.0), 0.0);
                        float under = right ? smoothstep(xr + 0.12, xr - 0.10, xs) : smoothstep(xl - 0.12, xl + 0.10, xs);
                        col *= 1.0 - 0.38 * under * lift;
                    }
                    col = magicLight(col, xs, y, t);
                    float cov = smoothstep(-px, px, y) * smoothstep(-px, px, H - y)
                              * smoothstep(-px, px, sin(A0) / A0 - ax);
                    over(acc, col, cov);
                }
            }
        }
        // The turning page.
        if (turning) {
            // x - SH*z = X on the arc gives  sin(phi) + SH*cos(phi) = r.
            float R = sqrt(1.0 + SH * SH), dl = atan(SH);
            float r = (k * (X + SH * ZG) + sin(a0) + SH * cos(a0)) / R;
            if (abs(r) <= 1.0) {
                float as = asin(r);
                float lo = min(a0, a0 + k), hi = max(a0, a0 + k);
                float best = -1e3, bs = 0.0, by = 0.0, bphi = 0.0, bx = 0.0;
                for (int j = 0; j < 2; j++) {
                    float phi = j == 0 ? as - dl : PI - as - dl;
                    if (phi < lo - 1e-4 || phi > hi + 1e-4) continue;
                    float s = (phi - a0) / k;
                    float z = ZG + (cos(a0) - cos(phi)) / k;
                    float y = (Y - z * ELS) / ELC + 0.5 * H;
                    if (y < -px || y > H + px) continue;
                    float x = X + SH * z;
                    float depth = (x * SH + z) * ELC - y * ELS;    // larger = nearer the eye
                    if (depth > best) { best = depth; bs = s; by = y; bphi = phi; bx = x; }
                }
                if (best > -1e2) {
                    float cx = cos(bphi) - SH * sin(bphi);  // screen width of the page per unit length
                    bool recto = cx > 0.0;
                    vec2 pgc = vec2(recto ? bs : 1.0 - bs, by);
                    vec3 col = pageColor(pgc, recto ? pg0 + 1.0 : pg0 + 2.0, px);
                    col *= pageLight(bphi, recto ? 1.0 : -1.0);
                    col *= 0.70 + 0.30 * smoothstep(0.0, 0.14, bs);       // near the gutter
                    // Light shining through the thin page when it stands up.
                    col += vec3(0.10, 0.07, 0.03) * smoothstep(0.3, 0.0, abs(cx));
                    col = magicLight(col, bx, by, t);
                    float plen = sqrt(cx * cx + ELS * ELS * sin(bphi) * sin(bphi));
                    float cov = smoothstep(-px, px, by) * smoothstep(-px, px, H - by)
                              * smoothstep(0.0, px, (1.0 - bs) * plen + 0.5 * px);
                    // Thin darker rim on the free edge so the page reads against the page below.
                    col *= 1.0 - 0.25 * smoothstep(2.0 * px, 0.0, (1.0 - bs) * plen);
                    over(acc, col, cov);
                }
            }
        }
        rgb = rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY;
    }

    // ------------------------------------------------ glowing glyphs
    vec3 glow = vec3(0.0);
    float gs = GLYPH_SIZE;
    for (int i = 0; i < GLYPHS; i++) {
        float fi = float(i);
        float u0 = t + fi * LIFE / float(GLYPHS) + 0.4 * hash1(fi * 3.3);
        float cyc = floor(u0 / LIFE);
        float age = u0 - cyc * LIFE;
        float seed = fi * 5.71 + cyc * 13.37;
        float h1 = hash1(seed), h2 = hash1(seed + 1.1), h3 = hash1(seed + 2.3), h4 = hash1(seed + 3.7);
        // Born just above a random spot of the open pages, then rises and sways.
        float bx = (h1 < 0.5 ? -1.0 : 1.0) * mix(0.18, 0.80, h2);
        float by = mix(0.30, 1.10, h3);
        vec2 P0 = toScreen(vec3(bx, by, restZ(abs(bx)) + 0.02), aspect);
        float rise = 0.055 * age + 0.006 * age * age;
        vec2 P = P0 + vec2(0.018 * sin(age * 1.1 + h4 * 6.28) * min(age, 1.0), rise);
        float size = gs * mix(0.85, 1.15, h4) * (0.8 + 0.06 * age);
        vec2 d = p - P;
        if (dot(d, d) > 4.0 * size * size) continue;
        float a = smoothstep(0.0, 0.5, age) * (1.0 - smoothstep(LIFE * 0.45, LIFE, age));
        vec2 q = rot(d, -(h1 - 0.5) * 1.2 - (h2 - 0.5) * 1.4 * age) / size;
        float dg = glyph(q, int(hash1(seed + 5.5) * 6.0));
        float pxg = 1.0 / (iResolution.y * size);
        float core = smoothstep(0.055 + pxg, 0.055, dg);
        float halo = exp(-dg * 9.0) * 0.45;
        glow += a * (core * vec3(1.0, 0.86, 0.55) + halo * vec3(1.0, 0.60, 0.22));
    }
    rgb += glow * INTENSITY;

    fragColor = vec4(rgb, base.a);
}
