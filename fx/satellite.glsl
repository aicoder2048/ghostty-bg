// satellite — a gold-foil satellite tumbles slowly above a planet's glowing limb, its solar panels catching the sun, now and then slipping into the planet's shadow.
// zh: 卫星
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.90;   // overall strength (0 = off)
const float OPACITY    = 0.55;   // how much the satellite body hides what is behind it
const float SAT_SIZE   = 0.037;  // one satellite unit in screen heights (panel tip to tip = 11.8 units)
const float ECLIPSE    = 30.0;   // seconds between passes through the planet's shadow
const float PLANET     = 0.85;   // brightness of the planet's limb, atmosphere and day side
const float STARS      = 0.40;   // faint background stars

// ---- Helpers ------------------------------------------------------------

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float sdBox(vec2 q, vec2 b) {
    vec2 d = abs(q) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float fill(float d, float aa) { return smoothstep(aa, -aa, d); }

// ---- Satellite ------------------------------------------------------------
// q: satellite units (bus is ~2 tall). Ls: sun direction, Pl: direction to the
// planet (both in satellite space). sun: colour/amount of sunlight reaching this
// pixel (dims and reddens in eclipse). Returns colour and coverage.
vec4 drawSatellite(vec2 q, vec2 Ls, vec2 Pl, float roll, vec3 sun, float aa) {
    vec3 L3 = normalize(vec3(Ls, 0.6));
    vec3 H  = normalize(L3 + vec3(0.0, 0.0, 1.0));
    vec3 cool = vec3(0.40, 0.62, 1.00);     // light bounced up from the planet
    vec3 col = vec3(0.0);
    float cov = 0.0;

    // Solar wings. Rolling about the boom foreshortens them and slides the
    // sun's reflection across the cells.
    float fs = cos(roll);
    vec2 wq = vec2(abs(q.x) - 3.75, q.y / fs);
    float dW = sdBox(wq, vec2(2.05, 0.95));
    float wing = fill(dW, aa / fs);
    if (wing > 0.0) {
        vec3 n = vec3(0.0, -sin(roll), fs);
        float diff = max(dot(n, L3), 0.0);
        vec2 cc = (wq + vec2(2.05, 0.95)) / vec2(4.1 / 12.0, 1.9 / 5.0);
        vec2 id = floor(cc), f = fract(cc);
        float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
        float grid = 1.0 - smoothstep(0.03, 0.11, e);
        float rnd = hash12(id + step(0.0, q.x) * 37.0);
        // A broad diagonal band of reflected sun; each cell catches it a little
        // differently, so it sparkles cell by cell as it sweeps.
        float band = q.x * 0.42 + wq.y * 0.55 - 6.0 * sin(roll * 1.1);
        float g = exp(-band * band * 2.2);
        float glint = g * (0.55 + 0.45 * rnd) + pow(g, 10.0) * 0.6;
        vec3 cell = vec3(0.08, 0.12, 0.28) * (0.8 + 0.4 * rnd);
        vec3 c = cell * (0.30 + 1.3 * diff) * sun
               + vec3(0.55, 0.60, 0.68) * grid * (0.08 + 0.40 * diff * sun)
               + mix(vec3(0.70, 0.82, 1.0), vec3(1.0, 0.92, 0.78), rnd) * glint * 0.85 * sun
               + cell * cool * 0.5;
        float frame = fill(abs(dW + 0.035) - 0.035, aa);
        c = mix(c, vec3(0.62, 0.64, 0.68) * (0.15 + 0.85 * diff) * sun + cool * 0.08, frame * 0.8);
        float seam = smoothstep(0.03, 0.08, abs(wq.x));   // gap between the two halves
        col = c * mix(0.3, 1.0, seam);
        cov = wing * mix(0.25, 0.85, seam);
    }

    // Booms joining the wings to the bus.
    vec2 tq = vec2(abs(q.x) - 1.2, q.y);
    float truss = fill(sdBox(tq, vec2(0.52, 0.065)), aa);
    if (truss > 0.0) {
        float ny = clamp(q.y / 0.065, -1.0, 1.0);
        vec3 n = vec3(0.0, ny, sqrt(1.0 - ny * ny));
        float diff = max(dot(n, L3), 0.0);
        float rib = 0.75 + 0.25 * step(0.5, fract(tq.x * 5.0));
        vec3 c = vec3(0.55, 0.57, 0.62) * (0.12 + 0.88 * diff) * rib * sun + cool * 0.10;
        col = mix(col, c, truss);
        cov = max(cov, truss * 0.85);
    }

    // Main bus wrapped in crinkled gold foil: the crinkles bend the normal so
    // the specular highlight breaks into soft glints.
    float dB = sdBox(q, vec2(0.64, 0.94)) - 0.08;
    float bus = fill(dB, aa);
    if (bus > 0.0) {
        float nx = clamp(q.x / 0.74, -1.0, 1.0);
        float ny = sign(q.y) * smoothstep(0.75, 1.02, abs(q.y)) * 0.7;
        float cr = vnoise(q * vec2(5.0, 7.0)) * 0.65 + vnoise(q * vec2(13.0, 17.0) + 4.0) * 0.35;
        float cr2 = vnoise(q * 6.0 + 9.0);
        vec3 n = normalize(vec3(nx + (cr - 0.5) * 0.9, ny + (cr2 - 0.5) * 0.9,
                                sqrt(max(1.0 - nx * nx, 0.04))));
        float diff = max(dot(n, L3), 0.0);
        float spec = pow(max(dot(n, H), 0.0), 28.0);
        float tape = 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.04, abs(abs(q.y) - 0.38)));
        vec3 gold = mix(vec3(0.50, 0.30, 0.09), vec3(0.98, 0.76, 0.36), cr);
        vec3 c = gold * (0.05 + 0.95 * diff) * tape * sun
               + vec3(1.0, 0.90, 0.68) * spec * 1.8 * sun;
        // Cool rim on the edge facing the planet, visible even in shadow.
        float edge = smoothstep(-0.28, 0.0, dB);
        c += cool * edge * max(dot(normalize(q * vec2(1.0, 0.75)), Pl), 0.0) * 0.85;
        col = mix(col, c, bus);
        cov = max(cov, bus);
    }

    // Silver instrument module on top.
    vec2 mq = q - vec2(0.0, 1.38);
    float dM = sdBox(mq, vec2(0.40, 0.32)) - 0.06;
    float modl = fill(dM, aa);
    if (modl > 0.0) {
        float nx = clamp(mq.x / 0.46, -1.0, 1.0);
        vec3 n = vec3(nx, 0.0, sqrt(max(1.0 - nx * nx, 0.04)));
        float diff = max(dot(n, L3), 0.0);
        float spec = pow(max(dot(n, H), 0.0), 14.0);
        float ribs = 0.86 + 0.14 * sin(mq.y * 40.0);
        vec3 c = vec3(0.80, 0.82, 0.86) * (0.05 + 0.85 * diff) * ribs * sun
               + vec3(1.0) * spec * 0.5 * sun;
        c += cool * smoothstep(-0.2, 0.0, dM) * max(dot(normalize(mq), Pl), 0.0) * 0.7;
        col = mix(col, c, modl);
        cov = max(cov, modl);
    }

    // Mast and high-gain dish; the dish ellipse opens and closes with the roll.
    float mast = fill(sdBox(q - vec2(0.0, 1.98), vec2(0.035, 0.26)), aa);
    vec2 dq = q - vec2(0.0, 2.40);
    vec2 dr = vec2(0.80, 0.16 + 0.14 * abs(sin(roll + 0.5)));
    float dd = (length(dq / dr) - 1.0) * dr.y;
    float dish = fill(dd, aa);
    if (mast + dish > 0.0) {
        col = mix(col, vec3(0.5, 0.52, 0.56) * 0.6 * sun + cool * 0.08, mast);
        cov = max(cov, mast * 0.8);
        float lit = smoothstep(-1.2, 1.0, dot(dq / dr, Ls));
        vec3 c = vec3(0.85, 0.87, 0.90) * (0.06 + 0.8 * lit) * sun;
        c += vec3(1.0, 0.95, 0.85) * fill(abs(dd) - 0.025, aa) * 0.6 * sun;   // bright lip
        c += cool * max(-dq.y / dr.y, 0.0) * 0.25;
        col = mix(col, c, dish);
        cov = max(cov, dish);
    }

    return vec4(col * 0.8, cov);
}

// ---- Stars --------------------------------------------------------------------

float stars(vec2 p, float t) {
    const float K = 48.0;
    vec2 g = p * K;
    vec2 id = floor(g);
    float h = hash12(id);
    if (h > 0.12) return 0.0;               // most cells are empty
    vec2 off = (vec2(hash12(id + 3.1), hash12(id + 7.7)) - 0.5) * 0.6;
    float d = length(fract(g) - 0.5 - off);
    float px = K / iResolution.y;           // one pixel in cell units
    float core = smoothstep(px * 1.6, 0.0, d);
    float tw = 0.7 + 0.3 * sin(t * (0.6 + 15.0 * h) + h * 70.0);
    return core * tw * (0.25 + 0.75 * hash12(id + 1.9));
}

// ---- Main ----------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    vec3 col = base.rgb;
    vec2 L = normalize(vec2(0.85, 0.45));   // sun: off to the upper right

    // Planet: a huge sphere whose limb curves through the lower-right corner.
    vec2 C = vec2(aspect * 1.05, -1.60);
    float R = 1.90;
    vec2 dp = p - C;
    float r = length(dp);
    vec2 n = dp / r;
    float h = r - R;                        // height above the surface
    float sunF = dot(n, L);
    float facing = smoothstep(-0.35, 0.55, sunF);

    // Faint stars, hidden behind the planet and dimmer over the text corner.
    if (h > 0.0) {
        float textFade = mix(0.35, 1.0, smoothstep(0.2, 0.9, uv.x + uv.y * 0.6));
        float haze = smoothstep(0.0, 0.12, h);      // washed out by the atmosphere
        col += vec3(0.85, 0.9, 1.0) * stars(p, t) * STARS * textFade * haze * INTENSITY;
    }

    if (h < 0.0) {
        float depth = -h;
        // Darken slightly so the planet reads as a solid body against the sky.
        col = mix(col, vec3(0.01, 0.02, 0.04), smoothstep(0.0, 0.01, depth) * 0.30 * INTENSITY);
        if (depth < 0.45) {
            // Sunlit day side near the limb: ocean blue with slow drifting clouds,
            // squeezed toward the edge like a real sphere seen side-on.
            float s = atan(n.y, n.x) * R + t * 0.004;
            vec2 cp = vec2(s * 12.0, sqrt(depth) * 22.0);
            float cl = vnoise(cp) * 0.6 + vnoise(cp * 2.3 + 5.0) * 0.4;
            float clouds = smoothstep(0.45, 0.80, cl);
            vec3 day = mix(vec3(0.05, 0.16, 0.34), vec3(0.75, 0.84, 0.95), clouds);
            float band = exp(-depth / 0.11) * facing;
            col += day * band * 0.38 * PLANET * INTENSITY;
            // Warm glow along the terminator.
            col += vec3(1.0, 0.45, 0.15) * exp(-pow(sunF / 0.12, 2.0)) * exp(-depth / 0.03)
                 * 0.18 * PLANET * INTENSITY;
        }
    }

    // Atmosphere: a thin luminous line hugging the limb plus a softer haze above.
    if (h > -0.03 && h < 0.35) {
        float line = exp(-abs(h - 0.003) / 0.0045);
        float haze = exp(-max(h, 0.0) / 0.045) * smoothstep(-0.012, 0.0, h);
        vec3 atm = mix(vec3(0.20, 0.45, 1.0), vec3(0.62, 0.85, 1.0), facing);
        atm = mix(vec3(1.0, 0.55, 0.30), atm, smoothstep(-0.05, 0.25, sunF));
        col += atm * (line * 0.75 + haze * 0.22) * (0.12 + 0.88 * facing) * PLANET * INTENSITY;
    }

    // Satellite: wanders slowly over the right side, well above the limb.
    float S = SAT_SIZE;
    vec2 pos = vec2(aspect * (0.80 + 0.06 * sin(t * 0.043 + 0.4)),
                    0.53 + 0.06 * sin(t * 0.029 + 1.3) + 0.02 * sin(t * 0.071));
    vec2 rel = p - pos;
    if (length(rel) < 7.5 * S) {
        float ang  = -0.18 + 0.22 * sin(t * 0.051 + 0.7);   // slow in-plane tumble
        float roll = 0.65 * sin(t * 0.083 + 0.2);           // slow roll about the boom
        vec2 q  = rot(rel, -ang) / S;
        vec2 Ls = rot(L, -ang);
        vec2 Pl = rot(normalize(C - pos), -ang);
        float aa = 1.5 / (iResolution.y * S);

        // Eclipse: a shadow front sweeps across the satellite, holds, then a
        // second front sweeps the light back. Sunlight reddens at the edge,
        // as it passes through the planet's atmosphere.
        float c  = mod(t + 4.0, ECLIPSE);                   // first shadow pass at t = 12 s
        float u  = rel.x / (6.0 * S);
        float f1 = mix(-1.4, 1.4, smoothstep(16.0, 18.5, c));
        float f2 = mix(-1.4, 1.4, smoothstep(23.0, 25.5, c));
        float shade = smoothstep(-0.15, 0.15, f1 - u) * smoothstep(-0.15, 0.15, u - f2);
        vec3 sun = mix(vec3(1.0, 0.97, 0.92), vec3(1.0, 0.42, 0.18), smoothstep(0.05, 0.75, shade))
                 * (1.0 - shade);

        vec4 sat = drawSatellite(q, Ls, Pl, roll, sun, aa);
        col = col * (1.0 - sat.a * OPACITY * INTENSITY) + sat.rgb * INTENSITY;

        // Navigation lights at the wing tips and a strobe on the dish: soft
        // gaussian pulses so they swell and fade instead of popping.
        float fr = exp(-pow((fract(t / 2.4) - 0.15) / 0.035, 2.0));
        float fg = exp(-pow((fract(t / 2.4 + 0.5) - 0.15) / 0.035, 2.0));
        float sp = fract(t / 3.2);
        float fw = exp(-pow((sp - 0.10) / 0.02, 2.0)) + exp(-pow((sp - 0.22) / 0.02, 2.0));
        float dr = length(q - vec2(-5.9, 0.0));
        float dg = length(q - vec2(5.9, 0.0));
        float dw = length(q - vec2(0.0, 2.62));
        vec3 lights = vec3(1.0, 0.25, 0.18) * fr * (exp(-dr * dr * 30.0) + 0.22 * exp(-dr * 2.0))
                    + vec3(0.35, 1.0, 0.60) * fg * (exp(-dg * dg * 30.0) + 0.22 * exp(-dg * 2.0))
                    + vec3(0.9, 0.95, 1.0) * fw * (exp(-dw * dw * 40.0) + 0.15 * exp(-dw * 2.2));
        col += lights * INTENSITY;
    }

    fragColor = vec4(col, base.a);
}
