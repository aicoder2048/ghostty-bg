// wind — every few seconds a bold gust of bright streamlines whips across, curling into an eddy and tumbling bits along.
// zh: 风
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.80;   // overall brightness (0 = off)
const float PERIOD    = 2.5;    // seconds between gusts (each lands 0-0.9 s late)
const float CROSS     = 1.2;    // seconds for a gust's front to cross the window
const float START     = 0.15;   // first gust starts this many seconds after switching on
const int   LINES     = 5;      // streamlines in one gust
const int   BITS      = 4;      // small objects tumbling along with each gust
const int   WISPS     = 3;      // faint drifting wisps between gusts
const float WISP_GLOW = 0.40;   // brightness of the in-between wisps

const float TAU = 6.2831853;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Centre path of a gust: a long wave. Returns (y, dy/dx).
vec2 gustPath(float x, float seed) {
    float y0 = 0.11 + 0.36 * pow(hash1(seed + 1.0), 1.6);   // mostly middle / lower
    float amp = 0.05 + 0.06 * hash1(seed + 2.0);
    float k = 2.2 + 1.8 * hash1(seed + 3.0);
    float ph = TAU * hash1(seed + 4.0);
    float tilt = (hash1(seed + 5.0) - 0.5) * 0.18;           // some gusts rise, some dip
    float a = k * x + ph;
    float y = y0 + tilt * x + amp * sin(a) + 0.4 * amp * sin(2.1 * a + 1.3);
    float dy = tilt + amp * k * (cos(a) + 0.84 * cos(2.1 * a + 1.3));
    return vec2(y, dy);
}

// A soft line: bright core of half-width w plus a wide glow around it.
float strand(float d, float w, float px, float glow) {
    float core = smoothstep(w + 1.5 * px, w * 0.3, d);
    float halo = glow * exp(-d / (0.010 + 3.0 * w));
    return core + halo;
}

// One gust (index g), started at time t0, seen at point p.
vec3 gust(vec2 p, float g, float t0, float aspect, float px) {
    float dt = iTime - t0;
    if (dt < 0.0) return vec3(0.0);
    float seed = g * 13.7 + 2.0;
    float speed = (aspect + 0.5) / CROSS;
    float head = -0.25 + dt * speed;                 // front of the bundle
    if (p.x > head + 0.05 || p.x < head - 1.6) return vec3(0.0);

    vec2 path = gustPath(p.x, seed);
    float spread = 0.030 + 0.020 * hash1(seed + 6.0);
    // Cheap reject: far above or below the whole bundle (and its eddy).
    if (abs(p.y - path.x) > spread * 3.0 + 0.25) return vec3(0.0);

    float slope = sqrt(1.0 + path.y * path.y);
    float light = 0.0;

    for (int j = 0; j < LINES; j++) {
        float fj = float(j);
        float h = hash1(seed + fj * 7.1);
        float off = (fj - 2.0) * spread * (0.8 + 0.4 * h)
                  * (1.0 + 0.35 * sin(p.x * 1.7 + fj + seed));      // lines breathe apart and together
        float wig = 0.012 * sin(p.x * 9.0 + fj * 2.3 + seed - iTime * 3.0);
        float yl = path.x + off + wig;

        float lead = 0.18 * hash1(seed + fj * 3.3);
        float hj = head - lead;
        float len = 0.80 + 0.50 * hash1(seed + fj * 5.9);
        float along = (hj - p.x) / len;               // 0 at the front, 1 at the tail
        float d = abs(p.y - yl) / slope;

        float thick = (j == 1 || j == 3) ? 0.0042 : 0.0020;
        thick *= 0.7 + 0.6 * hash1(seed + fj * 2.7);
        float shape = smoothstep(0.0, 0.04, along) * pow(max(1.0 - along, 0.0), 1.3);
        if (along > 0.0 && along < 1.0) {
            float w = thick * (0.35 + 0.65 * (1.0 - along));
            light += strand(d, w, px, thick > 0.003 ? 0.45 : 0.20) * shape;
        }

        // One or two of the lines throw off a curl that rides with the gust.
        bool curls = (j == 1) || (j == 3 && hash1(seed + 9.0) > 0.45);
        if (curls) {
            float r = 0.055 + 0.035 * hash1(seed + fj * 4.4);
            float cx = hj - len * (0.25 + 0.2 * hash1(seed + fj * 8.8));
            vec2 cp = gustPath(cx, seed);
            float side = (j == 1) ? 1.0 : -1.0;                     // above or below its line
            float cyl = cp.x + (fj - 2.0) * spread + side * r;
            vec2 q = p - vec2(cx, cyl);
            // Angle measured from the point where the curl leaves the line.
            float th = mod(side * atan(q.y, q.x) + 1.5708, TAU);
            float rr = r * (1.0 - 0.50 * th / TAU);                  // spirals inward
            float dl = abs(length(q) - rr);
            float ca = (cx > hj) ? 0.0 : 1.0;
            float cAlong = clamp((hj - cx) / len, 0.0, 1.0);
            // Fade both ends of the spiral so its seam leaves no hard edge in the glow.
            float fade = smoothstep(0.0, 0.35, th) * pow(1.0 - th / TAU, 1.6)
                       * (1.0 - cAlong) * ca;
            light += strand(dl, thick * 1.1, px, 0.35) * fade * 1.4;
        }
    }

    vec3 col = vec3(0.86, 0.94, 1.0) * light;

    // Small bits caught in the gust, spinning as they go.
    for (int b = 0; b < BITS; b++) {
        float fb = float(b);
        float hb = hash1(seed + fb * 17.3);
        float bx = head - 0.08 - 0.75 * hb;
        float by = gustPath(bx, seed).x + (hash1(seed + fb * 6.1) - 0.5) * 0.16
                 + 0.035 * sin(iTime * 6.0 + fb * 2.0);
        vec2 q = p - vec2(bx, by);
        if (dot(q, q) > 0.006) continue;
        float ang = iTime * (7.0 + 6.0 * hash1(seed + fb * 2.9)) * (hb > 0.5 ? 1.0 : -1.0);
        float c = cos(ang), s = sin(ang);
        q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
        float size = 0.028 + 0.016 * hash1(seed + fb * 3.7);
        float flip = 0.25 + 0.75 * abs(sin(iTime * 9.0 + fb * 1.7));  // tumbling in 3D
        float kind = hash1(seed + fb * 5.3);
        float m;
        vec3 bc;
        if (kind < 0.4) {
            // Leaf: pointed oval.
            float al = q.x / size;
            float edge = size * 0.42 * flip * (1.0 - al * al);
            m = step(abs(al), 1.0) * smoothstep(1.5 * px, 0.0, abs(q.y) - edge);
            bc = vec3(0.75, 0.95, 0.35);
        } else if (kind < 0.7) {
            // Petal: round blob, a bit squashed.
            vec2 e = q / vec2(size * 0.75, size * 0.55 * flip);
            m = smoothstep(1.0, 0.75, length(e));
            bc = vec3(1.0, 0.62, 0.78);
        } else {
            // Scrap of paper: a little rectangle.
            vec2 e = abs(q) - vec2(size * 0.8, size * 0.6 * flip);
            m = smoothstep(1.5 * px, 0.0, max(e.x, e.y));
            bc = vec3(1.0, 0.97, 0.88);
        }
        col += bc * m * 1.1;
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;

    // A gust lasts under ~2 s, so the current and previous one cover everything.
    vec3 color = vec3(0.0);
    float k = floor((iTime - START) / PERIOD);
    for (int i = 0; i < 2; i++) {
        float g = k - float(i);
        if (g < 0.0) continue;
        float t0 = START + g * PERIOD + (g < 0.5 ? 0.0 : 0.9 * hash1(g * 3.7));
        color += gust(p, g, t0, aspect, px);
    }

    // Light wisps drift by all the time so the screen is never empty.
    float wisps = 0.0;
    for (int i = 0; i < WISPS; i++) {
        float fi = float(i);
        float span = aspect + 1.3;
        float speed = 0.30 + 0.12 * hash1(fi * 5.1);
        float lt = (iTime * speed + span * hash1(fi * 9.3 + 1.0)) / span;
        float cyc = floor(lt);
        float head = -0.3 + fract(lt) * span;
        float seed = fi * 31.0 + cyc * 7.7 + 100.0;
        float len = 0.6 + 0.4 * hash1(seed + 8.0);
        float along = (head - p.x) / len;
        if (along < 0.0 || along > 1.0) continue;
        vec2 path = gustPath(p.x, seed);
        float y = path.x + 0.08 * (hash1(seed + 9.0) - 0.3);
        float d = abs(p.y - y) / sqrt(1.0 + path.y * path.y);
        float shape = smoothstep(0.0, 0.1, along) * (1.0 - along);
        wisps += strand(d, 0.0016, px, 0.15) * shape;
    }
    color += vec3(0.80, 0.90, 1.0) * wisps * WISP_GLOW;

    // Keep the top-left (where the shell text usually is) calmer.
    float textMask = 1.0 - 0.6 * smoothstep(0.40, 0.62, p.y)
                         * (1.0 - smoothstep(0.4 * aspect, 0.7 * aspect, p.x));
    color *= textMask;

    fragColor = vec4(base.rgb + min(color, vec3(1.2)) * INTENSITY, base.a);
}
