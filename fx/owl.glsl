// owl — a moonlit owl silhouette on a branch at the right edge blinks glowing amber eyes, turns its head and now and then silently opens its wings.
// zh: 猫头鹰
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float SIZE      = 0.25;   // one owl unit in window heights (feet to ear tufts ~1.1 units)
const float CENTER    = 0.84;   // owl's x position as a fraction of the window width
const float PERCH     = 0.16;   // height of the branch top above the window bottom (window heights)
const float BODY_ALPHA = 0.58;  // how much the dark silhouette covers what is behind it
const float WING_ALPHA = 0.32;  // opacity of the open (translucent) wings
const float RIM       = 0.85;   // strength of the moonlight rim along the lit edges
const float EYE_GLOW  = 1.0;    // strength of the amber eyes and their bloom
const float MOON_GLOW = 0.10;   // faint cool glow behind the owl (0 = off)
const float MIST      = 0.07;   // faint drifting mist around the branch (0 = off)
const float SPREAD_EVERY = 17.0;  // seconds between two wing openings
const float FIRST_SPREAD = 4.0;   // seconds until the first opening
const float BLINK_EVERY  = 5.3;   // seconds between slow blinks

const vec3 SHADOW = vec3(0.025, 0.032, 0.055);  // silhouette colour (deep night blue)
const vec3 MOON   = vec3(0.70, 0.80, 1.00);     // cool moonlight
const vec3 IRIS_IN  = vec3(1.00, 0.42, 0.06);   // deep amber near the pupil
const vec3 IRIS_OUT = vec3(1.00, 0.72, 0.26);   // pale amber at the rim
const vec2 LIGHT  = vec2(-0.42, 0.91);          // moon direction (up and a little left)

const float PI = 3.14159265;

// Animation state, set once per pixel in mainImage.
float gT, gYaw, gTilt, gClose, gExt, gFlap, gLift;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Approximate signed distance to an ellipse (good enough for soft edges).
float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Tapered capsule from a (radius r0) to b (radius r1).
float limb(vec2 p, vec2 a, vec2 b, float r0, float r1) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(r0, r1, h);
}

// A value that holds still, then glides (eased) to a new random target each period.
// The end of one segment is the start of the next, so there are no jumps.
float holdSeq(float t, float period, float ramp, float seed) {
    float k = floor(t / period);
    float a = hash1(k * 7.31 + seed) * 2.0 - 1.0;
    float b = hash1((k + 1.0) * 7.31 + seed) * 2.0 - 1.0;
    return mix(a, b, smoothstep(0.0, ramp, t - k * period));
}

// ---------------------------------------------------------------- shapes
// Head-local coordinates: rotate about the neck by the tilt, origin at the head centre.
vec2 headLocal(vec2 oq) {
    return rot(oq - vec2(0.0, 0.60), -gTilt) + vec2(0.0, 0.60) - vec2(0.0, 0.775);
}

// Body, head, ear tufts, tail and feet as one silhouette.
float owlBody(vec2 q) {
    vec2 oq = q - vec2(0.0, gLift);
    float breathe = 1.0 + 0.012 * sin(gT * 1.6);
    vec2 bq = vec2(oq.x / breathe, oq.y);
    float d = ellipse(bq, vec2(0.0, 0.35), vec2(0.250, 0.345));
    d = smin(d, ellipse(bq, vec2(0.0, 0.53), vec2(0.270, 0.160)), 0.08);
    // Tail hanging behind the branch, feet gripping it.
    vec2 tq = oq - vec2(0.0, -0.02);
    float dt = max(abs(tq.x) - 0.045 - 0.09 * max(-tq.y, 0.0), max(tq.y - 0.06, -0.14 - tq.y));
    d = min(d, dt);
    d = smin(d, min(ellipse(oq, vec2(-0.075, 0.012), vec2(0.06, 0.035)),
                    ellipse(oq, vec2(0.075, 0.012), vec2(0.06, 0.035))), 0.03);

    // Head with ear tufts that shift as it turns.
    vec2 hl = headLocal(oq);
    float dh = ellipse(hl, vec2(0.0), vec2(0.240, 0.200));
    dh = smin(dh, ellipse(hl, vec2(0.0, 0.07), vec2(0.195, 0.135)), 0.05);
    for (int i = 0; i < 2; i++) {
        float s = i == 0 ? -1.0 : 1.0;
        float th = s * 0.60 + gYaw;
        float bx = 0.235 * sin(th) * 0.90;
        vec2 tip = vec2(bx * 1.28 + 0.05 * s * cos(th), 0.32 - 0.03 * abs(sin(th)));
        dh = smin(dh, limb(hl, vec2(bx, 0.12), tip, 0.050, 0.006), 0.03);
    }
    d = smin(d, dh, 0.06);
    // Slightly ragged feathery outline.
    float a = atan(oq.y - 0.45, oq.x);
    return d + 0.0018 * sin(a * 52.0 + 1.5 * sin(a * 7.0));
}

// One open wing seen from the front (side s = -1 left, +1 right). w returns the
// wing's own coordinates, fn the feather index along it.
float owlWing(vec2 q, float s, out vec2 w, out float fn) {
    vec2 oq = q - vec2(0.0, gLift);
    float sc = mix(0.30, 1.0, gExt);                              // grows out as it opens
    w = oq - vec2(s * 0.15, 0.52);
    w.x *= s;
    float ang = mix(-1.0, 0.16, gExt) + gFlap;
    w = rot(w, -ang) / sc;
    float L = 0.92;
    float uc = clamp(w.x / L, 0.0, 1.0);
    float vTop = mix(0.05, 0.02, uc) + 0.10 * sin(PI * uc);
    float vBot = 0.02 - 0.42 * (1.0 - pow(uc, 2.6));
    // Rounded feather tips along the trailing edge, slanted outward on the primaries.
    fn = (w.x / L + 0.45 * uc * (vTop - w.y)) * 10.0;
    float ft = 2.0 * fract(fn) - 1.0;
    vBot -= 0.030 * sqrt(max(1.0 - ft * ft, 0.0)) * (1.0 - 0.2 * uc);
    return max(max(w.y - vTop, vBot - w.y), max(-w.x, w.x - L)) * sc;
}

float wings(vec2 q) {
    if (gExt < 0.002) return 1e3;
    vec2 w; float fn;
    return min(owlWing(q, -1.0, w, fn), owlWing(q, 1.0, w, fn));
}

float scene(vec2 q) { return min(owlBody(q), wings(q)); }

// ---------------------------------------------------------------- branch
float branchD(vec2 q, out float v) {
    float yc = -0.046 - 0.035 * q.x + 0.015 * sin(q.x * 2.0);
    float bh = 0.030 + 0.026 * smoothstep(-0.8, 1.4, q.x);
    float dy = q.y - yc;
    v = clamp(dy / bh, -1.0, 1.0);
    float d = max(abs(dy) - bh, -0.85 - q.x);
    d = min(d, length(vec2(q.x + 0.85, dy)) - bh * 0.8);
    // A thin twig rising to the upper left, with two small leaves.
    d = min(d, limb(q, vec2(-0.45, -0.03), vec2(-0.74, 0.16), 0.013, 0.004));
    float fl = 0.10 * sin(gT * 1.1) + 0.04 * sin(gT * 2.3);
    for (int i = 0; i < 2; i++) {
        vec2 b = i == 0 ? vec2(-0.74, 0.16) : vec2(-0.60, 0.09);
        float ang = i == 0 ? 2.3 + fl : 1.2 - fl;
        vec2 l = rot(q - b, -ang);
        float u = clamp(l.x / 0.15, 0.0, 1.0);
        d = min(d, max(abs(l.y) - 0.036 * pow(sin(PI * u), 0.8), max(-l.x, l.x - 0.15)));
    }
    return d;
}

// ---------------------------------------------------------------- main
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // The branch (with the owl on it) sways very gently about a pivot off the right edge.
    float sway = 0.008 * sin(iTime * 0.45) + 0.004 * sin(iTime * 1.07 + 1.0);
    vec2 pivot = vec2(aspect + 0.10, PERCH);
    vec2 q = (rot(p - pivot, -sway) + pivot - vec2(CENTER * aspect, PERCH)) / SIZE;

    vec3 rgb = base.rgb;
    // Everything (glow included) lives in this box; other pixels cost nothing.
    if (q.y < -0.9 || q.y > 2.3 || q.x < -2.4) { fragColor = base; return; }

    gT = iTime;
    // Wing opening: unfold slowly, one slow deep stroke, hold, fold back.
    float sp = mod(iTime - FIRST_SPREAD, SPREAD_EVERY);
    if (iTime < FIRST_SPREAD) sp = SPREAD_EVERY;
    gExt = smoothstep(0.0, 1.6, sp) * (1.0 - smoothstep(4.4, 6.0, sp));
    float fenv = smoothstep(1.2, 1.8, sp) * (1.0 - smoothstep(3.6, 4.4, sp));
    float fph = 2.0 * PI * (sp - 1.5) / 2.6;
    gFlap = 0.22 * sin(fph) * fenv;
    gLift = 0.025 * fenv * (0.5 - 0.5 * cos(fph));

    // Head: holds, glides to a new look, tilts a little; faces you while the wings are open.
    float calm = 1.0 - smoothstep(0.0, 0.4, gExt);
    gYaw = 0.70 * holdSeq(iTime + 1.3, 3.4, 1.1, 3.0) * calm;
    gTilt = (0.14 * holdSeq(iTime + 0.4, 4.3, 1.3, 11.0) + 0.02 * sin(iTime * 0.7)) * calm;
    float b = mod(iTime + 2.5, BLINK_EVERY);
    gClose = smoothstep(0.0, 0.22, b) * (1.0 - smoothstep(0.32, 0.70, b));

    float px = 1.0 / (iResolution.y * SIZE);                      // one pixel in owl units
    vec3 add = vec3(0.0);                                         // light added on top
    vec3 eyeCol = vec3(0.0);                                      // eyes, painted after the silhouette
    float eyeM = 0.0;

    // ---- moon glow and mist behind everything (very faint, cheap)
    add += MOON * MOON_GLOW * exp(-dot(q - vec2(-0.10, 0.85), q - vec2(-0.10, 0.85)) / 0.9);
    {
        vec2 m = q * vec2(1.2, 3.5) + vec2(gT * 0.06, 0.0);
        float n = 0.65 * vnoise(m) + 0.35 * vnoise(m * 2.1 - vec2(gT * 0.05, 0.0));
        float band = exp(-pow((q.y + 0.05) / 0.28, 2.0)) * smoothstep(-2.4, -0.8, q.x);
        add += MOON * MIST * band * smoothstep(0.35, 0.85, n);
    }

    // ---- branch: dark silhouette with a moonlit top edge
    float alpha = 0.0;
    if (q.y < 0.30 && q.x > -1.0) {
        float v;
        float d = branchD(q, v);
        float m = smoothstep(px, -px, d);
        alpha = m * BODY_ALPHA;
        float e = 0.006;
        vec2 n = normalize(vec2(branchD(q + vec2(e, 0.0), v) - d, branchD(q + vec2(0.0, e), v) - d) + 1e-6);
        float bark = 0.6 + 0.6 * vnoise(vec2(q.x * 14.0, q.y * 40.0));
        float rim = exp(-max(-d, 0.0) / 0.012) * m;
        add += MOON * RIM * 0.6 * rim * smoothstep(0.0, 0.9, dot(n, normalize(LIGHT))) * bark;
    }

    // ---- owl
    float dB = (abs(q.x) < 0.45 && q.y > -0.25 && q.y < 1.25) ? owlBody(q) : 1e3;
    float dW = 1e3;
    vec2 w0, w1; float fn0, fn1;
    if (gExt > 0.002 && q.y > -0.2 && q.y < 1.6) {
        float a0 = owlWing(q, -1.0, w0, fn0), a1 = owlWing(q, 1.0, w1, fn1);
        dW = min(a0, a1);
        if (a1 < a0) { w0 = w1; fn0 = fn1; }
    }
    float d = min(dB, dW);
    if (d < 0.08) {
        // Outward normal from the distance field (one-sided differences).
        float e = 0.014;                                          // wide enough to ignore the ragged outline
        vec2 n = normalize(vec2(scene(q + vec2(e, 0.0)) - d, scene(q + vec2(0.0, e)) - d) + 1e-6);
        float facing = smoothstep(0.0, 0.9, dot(n, normalize(LIGHT)));
        vec2 tg = vec2(-n.y, n.x);
        // Fine feather streaks, running across the edge, only visible in the lit band.
        float fea = 0.78 + 0.22 * sin(dot(q, tg) * 140.0 + 4.0 * vnoise(q * 14.0));
        fea *= 0.8 + 0.4 * vnoise(q * 45.0);

        float mB = smoothstep(px, -px, dB), mW = smoothstep(px, -px, dW) * smoothstep(0.0, 0.25, gExt);
        float cover = max(mB * BODY_ALPHA, mW * WING_ALPHA * (1.0 - mB));
        alpha = 1.0 - (1.0 - alpha) * (1.0 - cover);

        float inside = smoothstep(px, -px, d);
        float rimW = mix(0.018, 0.014, step(dW, dB));
        float rim = exp(-max(-d, 0.0) / rimW) * inside;
        add += MOON * RIM * rim * facing * fea;
        // Soft luminous halo just outside the lit edge.
        add += MOON * RIM * 0.18 * exp(-max(d, 0.0) / 0.02) * (1.0 - inside) * facing;
        // Faint volume: the moon-facing side of the body is a touch less dark.
        add += MOON * 0.035 * mB * smoothstep(-0.3, 0.3, dot(q - vec2(0.0, 0.45), normalize(LIGHT)));

        // Open wings: faint moonlight through the flight feathers.
        if (mW > 0.0 && dW < dB) {
            float sep = min(fract(fn0), 1.0 - fract(fn0));
            float shaft = smoothstep(0.08, 0.0, sep);
            float depth = clamp(-dW / 0.12, 0.0, 1.0);
            add += MOON * 0.10 * mW * (1.0 - mB) * (0.4 * shaft + 0.25 * vnoise(w0 * vec2(40.0, 10.0))) * depth;
        }
    }

    // ---- face: faint facial disc, amber eyes with bloom
    vec2 hl = headLocal(q - vec2(0.0, gLift));
    if (abs(hl.x) < 0.5 && abs(hl.y) < 0.4) {
        float Rw = 0.235;
        float a0 = asin(0.088 / Rw);
        for (int i = 0; i < 2; i++) {
            float s = i == 0 ? -1.0 : 1.0;
            float ph = s * a0 + gYaw;
            float vis = smoothstep(0.10, 0.45, cos(ph)) * smoothstep(1.2, 0.9, abs(ph));
            if (vis <= 0.0) continue;
            vec2 ec = vec2(Rw * sin(ph), 0.005);
            float er = 0.042;
            vec2 e = hl - ec;
            e.x /= mix(0.45, 1.0, cos(ph));                         // foreshortened when turned
            float r = length(e);
            // A thin moonlit arc of the facial disc around each eye.
            float disc = abs(length(e * vec2(1.0, 0.95)) - 0.105);
            add += MOON * 0.10 * smoothstep(0.010, 0.0, disc) * smoothstep(-0.05, 0.08, e.y + s * 0.3 * e.x) * vis;

            // Eyelid closes from the top; the open part of the eye glows.
            float lidY = er * (1.1 - 2.3 * gClose);
            float open = smoothstep(px, -px, e.y - lidY);
            float eye = smoothstep(px, -px, r - er) * open;
            vec3 ic = mix(IRIS_IN, IRIS_OUT, smoothstep(0.35 * er, er, r));
            ic *= 0.85 + 0.15 * sin(atan(e.y, e.x) * 30.0);           // fine iris striations
            ic *= mix(1.0, 0.7, smoothstep(-0.3 * er, er, e.y));      // brow shadow
            float pupil = smoothstep(px, -px, r - 0.45 * er);
            ic = mix(ic, vec3(0.02, 0.01, 0.0), pupil);
            float catchL = smoothstep(px, -px, length(e - er * vec2(-0.30, 0.35)) - 0.14 * er);
            ic = mix(ic, vec3(1.0, 0.95, 0.85), catchL);
            float m = eye * vis * EYE_GLOW;
            eyeCol = mix(eyeCol, ic, m);
            eyeM = max(eyeM, 0.92 * m);
            // Soft bloom; dims while the lid is shut.
            float openAmt = 1.0 - smoothstep(0.4, 0.9, gClose);
            add += IRIS_IN * 0.32 * EYE_GLOW * vis * openAmt * exp(-r * r / (er * er * 5.0));
            add += IRIS_OUT * 0.10 * EYE_GLOW * vis * openAmt * exp(-r * r / (er * er * 18.0));
        }
        // Tiny moonlit tip of the beak between the eyes.
        vec2 bk = hl - vec2(Rw * sin(gYaw), -0.045);
        add += MOON * 0.18 * smoothstep(0.012, 0.0, length(bk * vec2(1.6, 0.8))) * smoothstep(1.0, 0.6, abs(gYaw));
    }

    // Darken by the silhouette, then add the light on top.
    rgb = mix(rgb, SHADOW, clamp(alpha, 0.0, 1.0) * INTENSITY);
    rgb = mix(rgb, eyeCol, eyeM * INTENSITY);
    // Moonlight reads as light on a dark scene; over a bright photo it would only wash it out.
    float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    rgb += add * INTENSITY * (1.0 - 0.7 * smoothstep(0.25, 0.7, lum));
    fragColor = vec4(rgb, base.a);
}
