// whale — a humpback whale glides slowly out of the blue depth haze, lit by god rays and caustics from above.
// zh: 鲸鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float OPACITY   = 0.62;   // how solid the whale body is at its sunlit top (it fades toward belly and tail)
const float PERIOD    = 34.0;   // seconds from the start of one crossing to the next
const float CROSS     = 34.0;   // seconds one crossing takes (= PERIOD: it turns round off-screen and swims back)
const float WIDTH     = 0.53;   // whale length (snout to fluke tip) as a fraction of the window width
const float DEPTH_Y   = 0.27;   // height of the swim line above the bottom (0..1); keeps it under the text
const float BEAT      = 0.62;   // speed of the slow up-down tail beat (radians per second)
const float RAYS      = 0.07;   // strength of the slanting god rays in the water
const float GLOW      = 1.0;    // luminous edge and the soft halo of scattered light around the whale
const int   BUBBLES   = 10;     // glinting bubbles rising from the blowhole

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

// ---- Body profile -------------------------------------------------------
// The whale faces +x. s runs along the body: 0 at the snout (x = 1.05) and 1 at
// the tail root (x = -1.0). Humpback proportions: slender flat head about a third
// of the length, deep belly behind it, a small hump and fin two thirds back, then
// a long taper to the tail stock. Kept smooth: the light does the detail.
float sOf(float x) { return (1.05 - x) / 2.05; }

float topY(float s) {
    float head = 0.190 * pow(clamp(s / 0.42, 0.0, 1.0), 0.62);
    float t = head * (1.0 - 0.80 * smoothstep(0.42, 1.0, s));
    t += 0.020 * exp(-pow((s - 0.66) / 0.07, 2.0));                     // dorsal hump
    float fin = smoothstep(0.60, 0.665, s) * (1.0 - smoothstep(0.662, 0.69, s));
    return t + 0.036 * fin * fin;                                        // small hooked fin
}

float botY(float s) {
    float b = 0.225 * pow(clamp((s + 0.015) / 0.34, 0.0, 1.0), 0.55);
    return -b * (1.0 - 0.76 * smoothstep(0.40, 1.0, s));
}

// The swimming wave: almost still at the head, growing toward the tail, and
// travelling backwards along the body (the crest moves from head to fluke).
float wave(float s, float ph) {
    float a = 0.008 + 0.105 * pow(smoothstep(0.28, 1.0, s), 1.7);
    return a * sin(ph - 2.4 * s);
}

// Dancing caustic net from the wavy surface (world coordinates, so the light
// pattern stays in the water while the whale slides under it).
float caustic(vec2 p, float t) {
    vec2 q = p * 22.0;
    vec2 w = q + 0.8 * vec2(sin(q.y * 1.7 + t * 0.9), sin(q.x * 1.5 - t * 0.7));
    w += 0.4 * vec2(sin(w.y * 2.9 - t * 1.1), sin(w.x * 2.6 + t));
    float a = pow(1.0 - abs(sin(w.x + 0.4 * w.y)), 5.0);
    float b = pow(1.0 - abs(sin(w.y - 0.5 * w.x)), 5.0);
    return clamp(a + b, 0.0, 1.0);
}

// Soft god rays slanting down from the surface, slowly drifting and breathing.
float rays(vec2 p, float t) {
    float u = p.x + 0.35 * p.y;
    float r = 0.55 * pow(0.5 + 0.5 * sin(u * 6.3 + 0.5 * sin(t * 0.13)), 6.0)
            + 0.40 * pow(0.5 + 0.5 * sin(u * 11.7 - t * 0.21 + 1.3), 10.0)
            + 0.35 * pow(0.5 + 0.5 * sin(u * 3.9 + t * 0.07 + 4.0), 4.0);
    return r * (0.75 + 0.25 * sin(t * 0.31 + u * 2.0));
}

// Signed distance (whale units, negative inside) to a long, curved pectoral fin,
// plus the position along it (0 root .. 1 tip) in .y.
vec2 pecFin(vec2 q, vec2 root, float ang, float curv) {
    vec2 dir = vec2(cos(ang), sin(ang));
    vec2 d = q - root;
    float u = dot(d, dir);
    float v = dot(d, vec2(-dir.y, dir.x)) - curv * u * u;               // curved, flexing fin
    float t = u / 0.66;
    if (t < -0.3 || t > 1.4) return vec2(1.0, 0.0);
    float tc = clamp(t, 0.0, 1.0);
    float w = mix(0.045, 0.075, smoothstep(0.0, 0.3, tc))
            * sqrt(max(1.0 - pow(max(tc - 0.3, 0.0) / 0.7, 2.0), 0.0));   // rounded tip
    float dd = v > 0.0 ? v - w : -v - 0.8 * w;
    dd = max(dd, max(-u, u - 0.66));
    return vec2(dd, tc);
}

// Whale centre and heading at a given clock time.
void pose(float clock, float size, float aspect, out vec2 c, out float dir, out float tilt) {
    float t = clamp(mod(clock, PERIOD) / CROSS, 0.0, 1.0);
    dir = mod(floor(clock / PERIOD), 2.0) < 0.5 ? 1.0 : -1.0;            // alternate sides
    float margin = 1.45 * size;                                           // fluke tip / halo off-screen
    // Hurry through the off-screen ends and linger while in view (smooth, and the
    // same speed where one crossing joins the next).
    t += 0.08 * sin(2.0 * PI * t);
    float x = mix(-margin, aspect + margin, t);
    if (dir < 0.0) x = aspect - x;
    c = vec2(x, DEPTH_Y + 0.035 * sin(clock * 0.21));
    tilt = 0.05 * cos(clock * 0.21);                                     // nose follows the slow rise and fall
}

// "Over" for premultiplied colour.
void over(inout vec3 C, inout float A, vec3 col, float a) {
    C = C * (1.0 - a) + col * a;
    A = A * (1.0 - a) + a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    bool dark = lum < 0.5;
    // Keep the shell text (top-left) clear: the water light is weaker there.
    float textMask = smoothstep(0.15, 0.70, length(vec2(uv.x * 1.2, uv.y * 1.6)));

    float size = min(WIDTH * aspect / 2.45, 0.60);                       // half the body length
    float clock = iTime + 0.30 * CROSS;                                  // already in view at start

    // Water: a faint blue depth haze toward the bottom and soft god rays.
    vec3 rgb = base.rgb;
    float ray = rays(p, iTime);
    float deep = smoothstep(0.75, 0.0, p.y);
    if (dark) {
        rgb += vec3(0.00, 0.035, 0.06) * deep * textMask;
        rgb += vec3(0.40, 0.65, 0.78) * ray * RAYS * textMask * (0.5 + 0.5 * deep);
    } else {
        rgb -= vec3(0.03, 0.015, 0.0) * deep * textMask;
    }

    vec2 c; float dir, tilt;
    pose(clock, size, aspect, c, dir, tilt);

    vec3 C = vec3(0.0);   // premultiplied whale colour
    float A = 0.0;        // whale coverage
    vec3 G = vec3(0.0);   // additive light: rim glow, halo, glints

    vec2 q = (p - c) / size;
    q.x *= dir;                                                          // face the way it swims
    q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;

    vec3 hazeC = vec3(0.10, 0.25, 0.36);   // colour of the deep water the whale fades into
    vec3 rimC  = vec3(0.50, 0.78, 0.92);   // luminous edge / scattered light

    // Bounding box early-out: everything below only runs near the whale.
    if (q.x > -1.85 && q.x < 1.30 && q.y > -0.95 && q.y < 0.60) {
        float ph = clock * BEAT;
        float finPh = clock * 0.38 + 1.0;
        float soft = max(1.5 / (iResolution.y * size), 0.018);            // soft edge width
        float ca = caustic(p, iTime * 0.7);

        // Far pectoral fin, behind the body: dim and lost in the haze.
        float sF = 0.30;
        vec2 rootF = vec2(1.05 - 2.05 * sF, 0.4 * botY(sF) + wave(sF, ph));
        vec2 fF = pecFin(q, rootF, -2.62 + 0.10 * sin(finPh + 0.8), -0.10 + 0.14 * sin(finPh + 0.8));
        float aF = smoothstep(soft, -soft, fF.x);
        if (aF > 0.0) over(C, A, mix(vec3(0.62, 0.78, 0.88), hazeC, 0.5), aF * 0.28);

        // Body.
        float s = sOf(q.x);
        float sc = clamp(s, 0.0, 1.0);
        float y = q.y - wave(sc, ph);
        float top = topY(sc), bot = botY(sc);
        float dB = max(max(bot - y, y - top), max(-s * 2.05, (s - 1.0) * 2.05));
        float v = clamp((y - bot) / max(top - bot, 1e-3), 0.0, 1.0);    // 0 belly .. 1 back

        // Fluke: broad lobes seen slightly from above, pitching with the tail.
        vec2 root = vec2(-1.0, wave(1.0, ph));
        float slope = -(wave(1.0, ph) - wave(0.98, ph)) / 0.02 / 2.05;
        float th = 1.5 * atan(slope);
        vec2 back = vec2(-cos(th), -sin(th));
        vec2 f = q - root;
        float cc = dot(f, back);
        float fs = 0.62 + 0.06 * sin(ph - 2.4);
        float zz = dot(f, vec2(back.y, -back.x)) / fs;
        float az = abs(zz);
        float k = az / 0.40;
        float cle = 0.40 * pow(k, 1.7) - 0.03;
        float cte = 0.20 + 0.22 * pow(k, 0.9) - 0.05 * exp(-az * az / 0.002);
        float dF = max(max(cle - cc, cc - cte), az - 0.40);

        // Body and fluke as one soft silhouette.
        float dW = min(dB, dF);
        float bodyA = smoothstep(soft, -soft * 1.4, dW);
        float isFluke = step(dF, dB);
        float vv = mix(v, 0.55 + 0.25 * (1.0 - k), isFluke);               // fluke reads as mid-lit
        float ss = mix(s, 1.15, isFluke);                                   // and furthest into the haze

        if (bodyA > 0.0) {
            float n = vnoise(q * vec2(7.0, 11.0));
            // Lit from above: a bright slate-teal back fading to a dim, hazy belly.
            vec3 col = mix(vec3(0.09, 0.20, 0.30), vec3(0.46, 0.66, 0.78), pow(vv, 1.1));
            // A faint pale throat (the humpback's white underside, seen through haze).
            float throat = (1.0 - isFluke) * smoothstep(0.38, 0.12, v) * smoothstep(0.55, 0.15, s);
            col = mix(col, vec3(0.45, 0.58, 0.66), throat * (0.35 + 0.2 * n));
            // Ventral pleats: barely-there light lines along the throat.
            float pl = pow(1.0 - abs(sin(v * 40.0)), 8.0) * throat;
            col += vec3(0.25, 0.35, 0.40) * pl * 0.35;
            // Moving caustics and god rays play across the sunlit back.
            float lit = smoothstep(0.35, 1.0, vv);
            col += vec3(0.50, 0.75, 0.85) * ca * lit * 0.30;
            col += vec3(0.30, 0.48, 0.56) * ray * (0.25 + 0.5 * lit);
            col *= 0.92 + 0.16 * n;                                         // gentle mottling
            // Eye: just a soft shadow, no hard dot.
            float ed = length(vec2(q.x - (1.05 - 2.05 * 0.30), y - (bot + 0.43 * (top - bot))));
            col *= 1.0 - 0.45 * smoothstep(0.03, 0.008, ed) * (1.0 - isFluke);
            // Depth: the rear half and the fluke dissolve into the blue haze.
            float depth = smoothstep(0.35, 1.15, ss);
            col = mix(col, hazeC, 0.10 + 0.45 * depth);
            float a = OPACITY * (0.55 + 0.45 * vv) * (1.0 - 0.45 * depth);
            over(C, A, col, bodyA * a);
        }

        // Luminous edge: a soft glow hugging the back (strongest on top, where the
        // sun catches it) and a wide faint halo of scattered light all round.
        float edge = exp(-abs(dW) / 0.022);
        float topSide = smoothstep(0.3, 0.9, vv) * (1.0 - 0.5 * smoothstep(0.6, 1.15, ss));
        G += rimC * edge * topSide * 0.30 * GLOW;
        G += hazeC * 1.6 * exp(-max(dW, 0.0) / 0.10) * 0.10 * GLOW * (1.0 - 0.4 * smoothstep(0.5, 1.2, ss));

        // Near pectoral fin: long, white, softly glowing, rowing gently.
        float sN = 0.33;
        vec2 rootN = vec2(1.05 - 2.05 * sN, 0.5 * botY(sN) + wave(sN, ph));
        vec2 fN = pecFin(q, rootN, -2.45 + 0.10 * sin(finPh), -0.12 + 0.18 * sin(finPh));
        float aN = smoothstep(soft, -soft * 2.0, fN.x);
        if (aN > 0.0) {
            vec3 fc = mix(vec3(0.55, 0.70, 0.80), vec3(0.88, 0.95, 1.0), smoothstep(0.0, 0.5, fN.y));
            fc += vec3(0.4, 0.6, 0.65) * ca * 0.35;
            over(C, A, fc, aN * 0.50);
        }
        G += vec3(0.65, 0.85, 0.98) * exp(-max(fN.x, 0.0) / 0.035) * 0.11 * GLOW * smoothstep(0.0, 0.3, fN.y);
    }

    // Bubbles: puffs leave the blowhole, stay in the water as the whale swims on,
    // and rise wobbling — drawn as small glints of light, fading before the text area.
    for (int i = 0; i < BUBBLES; i++) {
        float fk = float(i);
        float life = 6.0;
        float age = mod(clock - fk * 0.6, life);
        vec2 bc; float bdir, btilt;
        pose(clock - age, size, aspect, bc, bdir, btilt);
        vec2 hole = vec2(0.60, topY(0.22));
        hole = mat2(cos(btilt), sin(btilt), -sin(btilt), cos(btilt)) * hole;
        hole.x *= bdir;
        vec2 h = vec2(hash1(fk * 12.99 + 1.0), hash1(fk * 78.23 + 2.0));
        vec2 pos = bc + hole * size
                 + vec2((h.x - 0.5) * 0.04 + 0.012 * sin(age * 2.2 + fk), 0.035 * age + 0.004 * age * age);
        float r = 0.004 + 0.004 * h.y + 0.0008 * age;
        float d = length(p - pos);
        if (d > r * 4.0) continue;
        float fade = smoothstep(0.0, 0.5, age) * (1.0 - smoothstep(life - 2.0, life, age))
                   * (1.0 - smoothstep(0.36, 0.52, pos.y));
        float tw = 0.65 + 0.35 * sin(iTime * 3.0 + fk * 2.1);           // gentle twinkle
        float core = exp(-d * d / (r * r * 0.35));
        float ring = exp(-pow((d - r) / (r * 0.25), 2.0));
        float halo = exp(-d / (r * 1.2)) * 0.25;
        G += vec3(0.75, 0.92, 1.0) * (core * 0.55 * tw + ring * 0.30 + halo) * fade;
    }

    float op = INTENSITY * mix(0.6, 1.0, textMask);                      // see-through over the text corner
    if (!dark) G *= 0.5;                                                  // light themes: less added glow
    rgb = rgb * (1.0 - A * op) + C * op + G * op;

    fragColor = vec4(rgb, base.a);
}
