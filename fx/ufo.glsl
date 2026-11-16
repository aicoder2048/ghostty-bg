// ufo — a sleek chrome saucer drifts in silently, hovers, shines a soft tractor beam down, then streaks away.
// zh: 飞碟
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float OPACITY   = 0.62;   // how solid the metal hull is (glass dome and light stay translucent)
const float PERIOD    = 21.0;   // seconds from one arrival to the next (about 5 s of empty sky between)
const float WIDTH     = 0.17;   // saucer width as a fraction of the window width
const float BEAM      = 0.55;   // tractor beam brightness
const float LIGHTS    = 1.0;    // rotating rim lights
const float STARS     = 0.35;   // faint background stars (right side only, away from the text)
const int   NLIGHTS   = 8;      // lights around the rim

const float PI = 3.14159265;

// Timeline inside one visit (seconds).
const float T_ARRIVE = 3.6;     // drift in and settle
const float T_BEAM0  = 5.5;     // beam starts
const float T_BEAM1  = 11.5;    // beam ends
const float T_ZIP    = 13.5;    // zips away

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise1(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Where the saucer is at time s of visit n. xy = centre (scene units), z = tilt.
vec3 ufoPose(float s, float n, float aspect, float S) {
    vec2 hover = vec2(mix(0.70, 0.82, hash1(n * 4.1 + 1.0)) * aspect,
                      mix(0.56, 0.70, hash1(n * 2.3 + 2.0)));
    // Arrive from the right edge, sometimes sliding down from the upper right.
    float ang = mix(0.05, 0.75, hash1(n * 7.7 + 3.0));
    vec2 inDir = vec2(cos(ang), sin(ang));
    vec2 start = hover + inDir * (0.42 * aspect + 2.0 * S);

    // Ease-out cubic: it is moving when it appears and glides to a gentle stop.
    float x = clamp(s / T_ARRIVE, 0.0, 1.0);
    float e = 1.0 - pow(1.0 - x, 3.0);
    vec2 pos = mix(start, hover, e);
    float tilt = 0.22 * pow(1.0 - x, 2.0);          // banks into the turn, levels out

    // Calm hover: two slow, unrelated sines so it never looks mechanical.
    float t = iTime;
    pos += S * vec2(0.06 * sin(t * 0.71 + n), 0.09 * sin(t * 1.13 + 2.0 * n));
    tilt += 0.045 * sin(t * 0.83 + 1.0) + 0.02 * sin(t * 1.9);

    // Zip: a tiny pull-back, then hard acceleration up and to the right.
    float z = s - T_ZIP;
    if (z > 0.0) {
        float za = mix(0.15, 0.6, hash1(n * 3.3 + 5.0));
        vec2 dir = vec2(cos(za), sin(za));
        float back = 0.10 * S * smoothstep(0.0, 0.35, z) * (1.0 - smoothstep(0.35, 0.5, z));
        float go = max(z - 0.4, 0.0);
        pos += dir * (go * go * 9.0 - back);
        tilt -= 0.25 * smoothstep(0.3, 0.6, z);
    }
    return vec3(pos, tilt);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once to get y-up scene coords.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float S = 0.5 * WIDTH * aspect;                  // half the saucer width, in screen heights
    float n = floor(iTime / PERIOD);
    float s = mod(iTime, PERIOD);

    vec3 add = vec3(0.0);                            // light added on top
    vec3 hullCol = vec3(0.0);                        // opaque-ish metal layer
    float hullA = 0.0;

    // ---- Faint stars (right side only, cheap: one per cell) ----
    {
        vec2 g = p * 22.0;
        vec2 c = floor(g);
        float h = hash21(c);
        if (h > 0.86) {
            vec2 sp = c + 0.2 + 0.6 * vec2(hash21(c + 7.1), hash21(c + 3.7));
            float d = length(g - sp);
            float tw = 0.55 + 0.45 * sin(iTime * (0.6 + 1.5 * h) + h * 40.0);
            float side = smoothstep(0.35, 0.75, uv.x) * smoothstep(0.0, 0.25, p.y);
            add += vec3(0.80, 0.86, 1.0) * exp(-d * d * 30.0) * tw * side * STARS * (h - 0.86) * 7.0;
        }
    }

    vec3 pose = ufoPose(s, n, aspect, S);
    vec2 pos = pose.xy;
    float tilt = pose.z;
    float vis = smoothstep(T_ZIP + 0.95, T_ZIP + 0.55, s);   // fades as it leaves (already off-screen)

    // ---- Beam: switches on by growing downward, flickers softly ----
    float beamOn = smoothstep(T_BEAM0, T_BEAM0 + 0.9, s) * smoothstep(T_BEAM1, T_BEAM1 - 1.0, s);
    float topY = pos.y - 0.09 * S;
    if (beamOn > 0.0 && p.y < topY) {
        float dTop = topY - p.y;
        float reach = topY * smoothstep(T_BEAM0, T_BEAM0 + 1.4, s);   // how far down it has grown
        float hw = S * 0.30 + dTop * 0.38;                            // cone half-width
        float u = (p.x - pos.x) / hw;
        if (abs(u) < 1.3) {
            float prof = pow(max(1.0 - u * u, 0.0), 1.2);
            float wall = exp(-pow((abs(u) - 0.92) / 0.10, 2.0));      // brighter cone edges
            float stria = 0.85 + 0.15 * sin(u * 9.0 + iTime * 0.7) * sin(u * 4.0 - iTime * 0.4);
            float fall = exp(-dTop * 1.1) * 0.75 + 0.25;
            float grow = smoothstep(reach + 0.04, reach - 0.04, dTop);
            float flick = 0.86 + 0.14 * vnoise1(iTime * 7.0) + 0.05 * sin(iTime * 31.0);
            float b = (prof * 0.55 * stria + wall * 0.35) * fall * grow * flick;

            // Motes drifting up inside the cone: one per grid cell, two layers.
            float m = 0.0;
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float cell = 0.045 + 0.02 * fl;
                float cols = 5.0 + 2.0 * fl;
                float cy = (p.y - iTime * (0.07 + 0.04 * fl)) / cell;
                float col = floor((u + 1.0) * 0.5 * cols);
                vec2 id = vec2(col, floor(cy)) + fl * 31.0;
                float h = hash21(id);
                float mu = (col + 0.2 + 0.6 * hash21(id + 5.3)) / cols * 2.0 - 1.0;
                float dx = (u - mu) * hw;
                float dy = (fract(cy) - (0.2 + 0.6 * h)) * cell;
                float r = 0.0035 + 0.003 * hash21(id + 9.1);
                float tw = 0.6 + 0.4 * sin(iTime * 3.0 + h * 30.0);
                m += step(0.45, h) * exp(-(dx * dx + dy * dy) / (r * r)) * tw;
            }
            b += m * 0.9 * step(abs(u), 1.0) * grow;

            add += vec3(0.70, 0.93, 1.0) * b * BEAM * beamOn * vis;
        }
    }
    // Pool of light where the beam meets the bottom edge.
    {
        float hwB = S * 0.30 + topY * 0.38;
        vec2 d = vec2((p.x - pos.x) / (hwB * 1.3), p.y / 0.07);
        float pool = exp(-dot(d, d)) * smoothstep(T_BEAM0 + 0.9, T_BEAM0 + 1.6, s);
        add += vec3(0.70, 0.93, 1.0) * pool * 0.35 * BEAM * beamOn * vis;
    }

    // ---- Light streak while zipping away ----
    if (s > T_ZIP + 0.45 && s < T_ZIP + 1.6) {
        vec2 A = ufoPose(s - 0.22, n, aspect, S).xy;
        vec2 B = pos;
        vec2 ab = B - A;
        float h = clamp(dot(p - A, ab) / max(dot(ab, ab), 1e-5), 0.0, 1.0);
        float d = length(p - A - ab * h);
        float w = S * (0.03 + 0.10 * h);
        float st = (exp(-d * d / (w * w)) + 0.5 * exp(-d * d / (9.0 * w * w))) * h * h;
        float fade = smoothstep(T_ZIP + 1.6, T_ZIP + 0.9, s)
                   * smoothstep(0.2 * S, 1.2 * S, length(ab));   // no flare before it really moves
        add += vec3(0.85, 0.95, 1.0) * st * 0.9 * fade;
    }

    // ---- The saucer itself (only near it) ----
    vec2 q = rot(p - pos, -tilt) / S;                 // local: hull spans x in [-1, 1]
    if (vis > 0.0 && abs(q.x) < 2.2 && q.y > -1.6 && q.y < 1.2) {
        vec3 pre = add;                               // so the saucer's own light can fade with vis
        float px = 1.0 / (iResolution.y * S);         // one pixel in local units

        // Soft haze glow under and around it (as if it lights the air).
        float halo = exp(-dot(q * vec2(0.8, 2.2), q * vec2(0.8, 2.2)) * 1.6);
        vec2 hz = (q - vec2(0.0, -0.45)) * vec2(0.9, 1.6);
        float haze = exp(-dot(hz, hz) * 1.4);
        add += vec3(0.55, 0.75, 0.95) * (halo * 0.10 + haze * (0.10 + 0.12 * beamOn));

        // Hull: a lens, taller on top than below.
        float hTop = 0.19, hBot = 0.11;
        float ey = q.y > 0.0 ? q.y / hTop : q.y / hBot;
        float r = length(vec2(q.x, ey));
        float aaR = px / hBot * 1.2;
        float hull = smoothstep(1.0, 1.0 - aaR, r);

        // Glass dome sitting on top.
        vec2 dq = (q - vec2(0.0, 0.10)) / vec2(0.36, 0.30);
        float dr = length(dq);
        float dome = smoothstep(1.0, 1.0 - px / 0.25 * 1.5, dr) * smoothstep(0.06, 0.10, q.y);

        if (hull > 0.0) {
            vec3 steel = vec3(0.60, 0.66, 0.76);
            vec3 col;
            if (q.y > 0.0) {
                // Top: chrome reflects a dark sky above and a bright horizon band low down.
                float v = clamp(ey, 0.0, 1.0);
                float env = 0.30 + 0.55 * exp(-pow((v - 0.30) / 0.20, 2.0)) - 0.15 * v;
                col = steel * env + vec3(1.0, 0.85, 0.70) * 0.18 * exp(-v * 6.0);
                // Specular sweep: a highlight that slides as the saucer tilts.
                float sw = -0.30 + 3.5 * tilt + 0.25 * sin(iTime * 0.37);
                float spec = exp(-pow((q.x - sw) / 0.14, 2.0)) * exp(-pow((v - 0.45) / 0.30, 2.0));
                col += vec3(1.0, 0.98, 0.94) * spec * 0.9;
            } else {
                // Underside: darker, lit from below by the haze and beam glow.
                float v = clamp(-ey, 0.0, 1.0);
                col = steel * (0.22 + 0.12 * (1.0 - v)) + vec3(0.6, 0.85, 1.0) * 0.10 * (0.4 + beamOn);
                // Glowing emitter ring under the centre.
                float er = length((q - vec2(0.0, -0.06)) * vec2(1.0, 5.0));
                float ring = exp(-pow((er - 0.30) / 0.06, 2.0));
                float core = exp(-er * er * 9.0);
                float pulse = 0.7 + 0.3 * sin(iTime * 2.2);
                add += vec3(0.65, 0.92, 1.0) * (ring * 0.6 * pulse + core * 0.5 * (0.3 + beamOn)) * hull;
            }
            // Bright rim edge catching light, with a thin dark groove just under it.
            float rimW = (1.0 - q.x * q.x);
            col += vec3(0.95, 0.97, 1.0) * exp(-pow(q.y / 0.012, 2.0)) * 0.55 * pow(max(rimW, 0.0), 0.3);
            col *= 1.0 - 0.35 * exp(-pow((q.y + 0.025) / 0.010, 2.0));
            // Silhouette rim light (luminous edge instead of an outline).
            col += vec3(0.75, 0.88, 1.0) * smoothstep(0.80, 1.0, r) * 0.35;

            float a = OPACITY * hull * (1.0 - dome);
            hullCol = col;
            hullA = a;
        }

        // Dome: translucent glass, inner glow, fresnel edge.
        if (dome > 0.0) {
            float fres = smoothstep(0.55, 1.0, dr);
            float inner = exp(-dr * dr * 2.5) * (0.75 + 0.25 * sin(iTime * 1.3));
            vec3 dc = vec3(0.55, 0.88, 1.0) * (inner * 0.45 + fres * 0.35)
                    + vec3(1.0) * exp(-pow(length(dq - vec2(-0.35, 0.45)) / 0.18, 2.0)) * 0.6;   // window glint
            add += dc * dome;
            hullCol = mix(hullCol, vec3(0.20, 0.30, 0.40), dome);
            hullA = max(hullA, 0.30 * dome);
        }
        // Dome glow spilling into the air above it.
        add += vec3(0.55, 0.85, 1.0) * exp(-pow(length((q - vec2(0.0, 0.18)) * vec2(1.2, 1.6)) / 0.40, 2.0)) * 0.10;

        // Rotating rim lights: front ones bright and a bit larger, back ones faint.
        for (int i = 0; i < NLIGHTS; i++) {
            float a = 2.0 * PI * float(i) / float(NLIGHTS) + iTime * 0.9;
            float front = -sin(a);                    // 1 = facing us
            vec2 lp = vec2(0.94 * cos(a), -0.035 + 0.012 * front);
            float sz = 0.028 + 0.012 * max(front, 0.0);
            float d = length((q - lp) * vec2(1.0, 1.4));
            float k = mix(0.12, 1.0, smoothstep(-0.3, 0.4, front));
            vec3 lc = (i % 2 == 0) ? vec3(1.0, 0.82, 0.58) : vec3(0.70, 0.90, 1.0);
            add += lc * k * LIGHTS * (exp(-d * d / (sz * sz)) * 1.1 + exp(-d * d / (sz * sz * 9.0)) * 0.22);
        }

        add = pre + (add - pre) * vis;
        hullA *= vis;
    }

    vec3 outc = mix(base.rgb, hullCol, clamp(hullA * INTENSITY, 0.0, 1.0)) + add * INTENSITY;
    fragColor = vec4(outc, base.a);
}
