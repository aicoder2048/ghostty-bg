// sailboat — a small sailboat rides the rolling sea along the bottom, sails full, wake trailing.
// zh: 帆船
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float BOAT      = 0.17;   // boat height, waterline to masthead, in window heights
const float CROSS     = 25.0;   // seconds for one boat to cross the window
const float GAP       = 1.5;    // seconds before the next boat (from the other side)
const float WAKE      = 0.24;   // length of the white wake, in window heights
const float SEA       = 1.0;    // strength of the sea band (0 = boat only)

const float PI = 3.14159265;

const vec3 SAIL      = vec3(0.97, 0.96, 0.93);
const vec3 SAIL_SHADE= vec3(0.66, 0.71, 0.80);
const vec3 HULL      = vec3(0.17, 0.29, 0.48);
const vec3 FOAM      = vec3(0.93, 0.97, 1.00);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// One rolling swell. The -cos(2u) term (a Stokes wave) sharpens the crests
// and flattens the troughs, which is what makes real swells read as waves.
float swell(float x, float t, float k, float w, float a, float ph) {
    float u = x * k - t * w + ph;
    return a * (sin(u) - 0.28 * cos(2.0 * u));
}

// The three layers of sea, back to front: surface height at x.
float sea0(float x, float t) {   // horizon chop
    return 0.172 + swell(x, t, 55.0, 1.2, 0.0030, 0.0) + swell(x, t, 87.0, -1.4, 0.0016, 1.7);
}
float sea1(float x, float t) {   // the swell the boat rides
    return 0.108 + swell(x, t, 21.0, 0.85, 0.0085, 0.3) + swell(x, t, 37.0, 1.25, 0.0035, 2.1)
                 + swell(x, t, 9.0, 0.30, 0.0040, 4.0);
}
float sea2(float x, float t) {   // the near rollers
    return 0.048 + swell(x, t, 15.0, 0.75, 0.0100, 1.1) + swell(x, t, 28.0, 1.05, 0.0045, 0.5);
}

// Paint one wave layer: a translucent body (lighter on the crests, darker in
// the troughs and with depth) under a crisp, light crest line.
vec3 waterLayer(vec3 rgb, float y, float surf, float base, float amp,
                vec3 deep, vec3 top, float alpha, float px) {
    float below = smoothstep(px, -px, y - surf);
    float crest = clamp((surf - base) / amp * 0.5 + 0.5, 0.0, 1.0);   // 0 trough .. 1 crest
    float depth = clamp((surf - y) / 0.045, 0.0, 1.0);
    vec3 c = mix(top, deep, depth);
    c = mix(c * 0.75, c * 1.25 + 0.03, crest * (1.0 - depth));
    rgb = mix(rgb, c, below * alpha * SEA);

    float line = smoothstep(1.6 * px, 0.5 * px, abs(y - surf));
    rgb = mix(rgb, vec3(0.80, 0.92, 0.98), line * mix(0.25, 0.85, crest) * SEA);
    // A second, fainter highlight just under the crest gives each layer an edge.
    float under = smoothstep(1.2 * px, 0.3 * px, abs(y - surf + 4.0 * px));
    rgb = mix(rgb, vec3(0.70, 0.86, 0.95), under * crest * crest * 0.25 * SEA);
    return rgb;
}

// Signed distance (outside > 0) to edge a->b of a counter-clockwise polygon,
// pushed outward by `bulge` in the middle so a sail can belly.
float edge(vec2 q, vec2 a, vec2 b, float bulge) {
    vec2 ba = b - a;
    vec2 n = normalize(vec2(ba.y, -ba.x));
    float s = clamp(dot(q - a, ba) / dot(ba, ba), 0.0, 1.0);
    return dot(q - a, n) - bulge * 4.0 * s * (1.0 - s);
}

// A sail: triangle luff (straight, on a spar or stay) -> head -> clew, with
// a bellied leech and foot. Returns coverage and shading.
vec2 sail(vec2 q, vec2 tack, vec2 head, vec2 clew, float leechB, float footB, float px) {
    float dl = edge(q, tack, head, 0.0);
    float de = edge(q, head, clew, leechB);
    float df = edge(q, clew, tack, footB);
    float d = max(dl, max(de, df));
    float cover = smoothstep(px, -px, d);
    // Chord position 0 at the luff .. 1 at the leech: the cloth curves away
    // near the luff (shaded) and is brightest where the draft is deepest.
    float c = clamp(-dl / max(-dl - de, 1e-4), 0.0, 1.0);
    float light = 0.55 + 0.45 * smoothstep(0.0, 0.45, c) - 0.12 * smoothstep(0.75, 1.0, c);
    // Crosscut seams run square to the leech and sag with the belly.
    vec2 ld = normalize(head - clew);
    float v = dot(q - clew, ld) / 0.105 + 0.25 * sin(PI * c);
    float seam = smoothstep(1.4 * px / 0.105, 0.0, abs(fract(v) - 0.5) - 0.5 + 0.02);
    light -= 0.13 * seam * step(0.04, c);
    return vec2(cover, light);
}

vec3 over(vec3 rgb, vec3 c, float a) { return mix(rgb, c, clamp(a, 0.0, 1.0)); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec3 rgb = base.rgb;
    float px = 1.0 / iResolution.y;
    float t = iTime;

    if (p.y > 0.50) {   // everything lives in the lower half
        fragColor = base;
        return;
    }

    float s0 = sea0(p.x, t), s1 = sea1(p.x, t), s2 = sea2(p.x, t);
    float I = INTENSITY;

    // ---- Seagulls: two gliding "m" ticks drifting left over the right side.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float k = fract(t / 34.0 + 0.30 + fi * 0.5);
        vec2 c = vec2(aspect * (1.02 - 0.50 * k), 0.30 + 0.07 * fi + 0.012 * sin(t * 0.5 + fi * 2.0));
        float g = 0.016 - 0.004 * fi;
        vec2 v = (p - c) / g;
        if (abs(v.x) > 1.3 || abs(v.y) > 1.3) continue;
        v.x = abs(v.x);
        float beat = sin(t * 5.0 + fi * 2.3);
        float f = mix(0.25, beat, smoothstep(-0.3, 0.3, sin(t * 0.6 + fi * 3.0)));  // flap, then glide
        vec2 elbow = vec2(0.45, 0.20 + 0.22 * f);
        vec2 tip = vec2(1.0, 0.05 + 0.55 * f);
        float d = min(segment(v, vec2(0.0), elbow) - 0.085, segment(v, elbow, tip) - 0.05 * (1.2 - v.x));
        d = min(d, length((v - vec2(0.0, -0.02)) * vec2(1.0, 1.6)) - 0.11);
        float a = smoothstep(px / g, -px / g, d) * smoothstep(0.0, 0.08, k) * smoothstep(1.0, 0.9, k);
        rgb = over(rgb, vec3(0.92, 0.93, 0.95), a * 0.65 * I);
    }

    // ---- A distant sail on the horizon, now and then, very slowly.
    {
        float k = fract((t + 6.0) / 46.0);
        float x = aspect * (0.93 - 0.32 * k);
        float h = 0.034;
        vec2 q = (p - vec2(x, 0.170)) / h;
        if (abs(q.x) < 0.8 && q.y > -0.3 && q.y < 1.2 && k < 0.8) {
            float lp = px / h;
            float d = max(max(q.y - 1.0, -q.y + 0.12), max(-q.x, q.x * 1.0 + q.y * 0.42 - 0.42));  // main
            d = min(d, max(max(-q.y + 0.14, q.x - 0.55 + q.y * 0.55), -q.x + 0.06));               // jib
            float hull = max(abs(q.y - 0.05) - 0.06, abs(q.x - 0.05) - 0.42 + (0.05 - q.y) * 1.5);
            float a = smoothstep(lp, -lp, min(d, hull));
            a *= smoothstep(-px, px, p.y - s0) * smoothstep(0.0, 0.06, k) * smoothstep(0.8, 0.7, k);
            rgb = over(rgb, vec3(0.88, 0.88, 0.90), a * 0.55 * I);
        }
    }

    // Back layer of the sea.
    rgb = waterLayer(rgb, p.y, s0, 0.172, 0.004, vec3(0.10, 0.20, 0.30), vec3(0.24, 0.36, 0.46), 0.32 * I, px);

    // ---- The boat: where it is in its crossing, and how it sits on the swell.
    float period = CROSS + GAP;
    float tt = t + 4.5;                                    // already on screen at start
    float n = floor(tt / period);
    float k = fract(tt / period) * period / CROSS;          // 0..1 crossing, >1 = gap
    float dir = mod(n, 2.0) < 0.5 ? 1.0 : -1.0;              // alternate sides
    float M = 0.13;
    float xb = dir > 0.0 ? mix(-M, aspect + M, k) : mix(aspect + M, -M, k);
    xb += 0.006 * sin(t * 0.7);                              // a little surge
    float S = BOAT;

    // Ride the swell: height from a few samples under the hull (smooth bob),
    // pitch from the slope between bow and stern.
    float hl = 0.38 * S;
    float yf = sea1(xb + hl, t), ym = sea1(xb, t), ya = sea1(xb - hl, t);
    float yb = (yf + 2.0 * ym + ya) * 0.25 - 0.004;
    float pitch = atan((yf - ya) / (2.0 * hl)) * 0.85;
    vec2 pos = vec2(xb, yb);
    float showBoat = step(k, 1.0);

    vec2 bv = p - pos;
    if (showBoat > 0.5 && abs(bv.x) < 0.75 * S && bv.y > -0.12 * S && bv.y < 1.12 * S) {
        vec2 q = rot(bv, -pitch) / S;
        q.x *= dir;                                          // mirror for leftward boats
        float lp = 1.2 * px / S;
        vec3 c = rgb;
        float solid = min(1.0, 1.12 * I);                   // the boat itself is opaque

        // Backstay: a hairline from the stern to the masthead.
        float rig = smoothstep(lp * 0.9, 0.0, segment(q, vec2(-0.43, 0.10), vec2(0.03, 0.99)));
        c = over(c, vec3(0.80, 0.82, 0.86), rig * 0.45 * I);

        // Mainsail, hoisted on the mast and sheeted to the boom.
        vec2 ms = sail(q, vec2(0.040, 0.215), vec2(0.040, 0.965), vec2(-0.395, 0.222), 0.050, 0.012, lp);
        c = over(c, mix(SAIL_SHADE, SAIL, ms.y), ms.x * solid);

        // Mast and boom.
        float spar = min(segment(q, vec2(0.03, 0.10), vec2(0.03, 1.0)) - 0.009,
                         segment(q, vec2(0.04, 0.208), vec2(-0.42, 0.214)) - 0.008);
        c = over(c, vec3(0.78, 0.78, 0.80), smoothstep(lp, -lp, spar) * solid);

        // Jib on the forestay, overlapping the main a touch; the main is
        // shaded right behind its leech so the two sails separate cleanly.
        vec2 js = sail(q, vec2(0.467, 0.170), vec2(0.067, 0.866), vec2(-0.02, 0.185), 0.035, 0.020, lp);
        float jshadow = sail(q - vec2(-0.018, 0.0), vec2(0.467, 0.170), vec2(0.067, 0.866), vec2(-0.02, 0.185), 0.035, 0.020, lp).x;
        c = over(c, SAIL_SHADE * 0.75, jshadow * ms.x * (1.0 - js.x) * 0.35 * I);
        c = over(c, mix(SAIL_SHADE, SAIL, js.y * 0.97), js.x * solid);
        float stay = smoothstep(lp * 0.9, 0.0, segment(q, vec2(0.49, 0.13), vec2(0.03, 0.93)));
        c = over(c, vec3(0.85, 0.86, 0.90), stay * 0.5 * I);

        // Pennant at the masthead, streaming aft and fluttering.
        {
            vec2 f = q - vec2(0.03, 0.995);
            float u = -f.x;
            float len = 0.13;
            float wav = 0.014 * sin(u * 48.0 - t * 9.0) * (u / len) + 0.01 * (u / len);
            float hw = 0.017 * (1.0 - u / len);
            float d = max(abs(f.y - wav) - hw, max(-u, u - len));
            c = over(c, vec3(0.95, 0.42, 0.30), smoothstep(lp, -lp, d) * 0.9 * I);
        }

        // Cabin: a low cream deckhouse with three portholes.
        {
            float d = max(max(q.y - 0.150, -q.y + 0.09), max(-0.22 - q.x, q.x + 0.8 * (q.y - 0.10) - 0.07));
            float ports = 1e3;
            for (int i = 0; i < 3; i++) ports = min(ports, length(q - vec2(-0.165 + 0.075 * float(i), 0.124)) - 0.011);
            vec3 cab = mix(vec3(0.84, 0.81, 0.74), vec3(0.95, 0.93, 0.87), smoothstep(0.09, 0.15, q.y));
            cab = mix(cab, HULL * 0.8, smoothstep(lp, -lp, ports));
            c = over(c, cab, smoothstep(lp, -lp, d) * solid);
        }

        // Hull: a sheer line rising to the bow, a curved forefoot and a raked
        // transom; navy topsides with a white stripe and a bright rail.
        {
            float top = 0.095 + 0.035 * smoothstep(-0.10, 0.52, q.x);
            // Keel line: deep amidships, sweeping up to the bow, gently to the stern.
            float r = q.x > 0.08 ? (q.x - 0.08) / 0.44 : max(-q.x - 0.08, 0.0) / 0.36;
            float lift = q.x > 0.08 ? 0.19 : 0.07;
            float bot = -0.06 + lift * r * r;
            float sl = q.x > 0.08 ? 2.0 * 0.19 * r / 0.44 : 0.0;
            float d = max(max(q.y - top, (bot - q.y) / sqrt(1.0 + sl * sl)), -0.44 + 0.06 * q.y - q.x);
            float fromTop = top - q.y;
            vec3 hc = mix(HULL * 0.75, HULL * 1.25, smoothstep(0.0, 0.10, q.y));
            hc = mix(hc, vec3(0.96), smoothstep(lp, -lp, abs(fromTop - 0.030) - 0.007));
            hc = mix(hc, vec3(0.85, 0.88, 0.93), smoothstep(lp, -lp, fromTop - 0.007));
            c = over(c, hc, smoothstep(lp, -lp, d) * solid);
        }

        // Whatever is below the water surface is hidden by the sea.
        float above = smoothstep(-px, px, p.y - s1);
        rgb = mix(rgb, c, above);
    }

    // Middle layer: the swell the boat rides.
    rgb = waterLayer(rgb, p.y, s1, 0.108, 0.012, vec3(0.06, 0.15, 0.25), vec3(0.18, 0.34, 0.46), 0.42 * I, px);

    // ---- Wake and bow wave: broken white foam along the waterline, fixed in
    // the water so it stays behind as the boat moves on, plus a fading
    // diverging wake line.
    if (showBoat > 0.5) {
        float along = (p.x - xb) * dir;                      // + ahead of the boat
        float stern = -0.44 * S;
        float behind = stern - along;                        // distance behind the stern
        if (along < 0.53 * S && behind < WAKE) {
            float fade = behind > 0.0 ? 1.0 - behind / WAKE : 1.0;
            fade *= fade;
            fade *= smoothstep(1.0, 0.94, k);                // fade out as the boat leaves
            float bow = smoothstep(0.28 * S, 0.43 * S, along) * smoothstep(0.54 * S, 0.47 * S, along);
            float hull = smoothstep(0.0, 0.02 * S, -behind);     // alongside the hull
            float thick = 0.0016 + 0.0035 * fade * step(0.0, behind) + 0.0035 * bow;
            float fy = s1 - p.y;                             // depth below the surface
            // Behind the stern the foam breaks up into irregular patches,
            // more and more as it spreads; a pattern fixed in the water.
            float pat = sin(p.x * 150.0 + 2.0 * sin(p.x * 37.0)) + sin(p.x * 83.0 + 1.3) + 0.7 * sin(p.x * 211.0 + 4.0);
            float broken = max(smoothstep(-0.4, 0.4, pat + 2.6 * fade - 1.4), max(bow, hull));
            float foam = smoothstep(-px, px, fy + px) * smoothstep(thick + px, thick - px, fy) * broken;
            rgb = over(rgb, FOAM, foam * mix(0.35, 0.9, max(fade, bow)) * I);

            // The diverging wake line, slanting toward the viewer behind the stern.
            if (behind > 0.0) {
                float yl = s1 - 0.004 - behind * 0.16;
                float l = smoothstep(1.3 * px, 0.3 * px, abs(p.y - yl)) * step(0.0, sin(p.x * 180.0 - t * 0.3));
                rgb = over(rgb, FOAM, l * fade * 0.55 * I);
            }
        }

        // Bow spray: a few droplets thrown forward and up, falling back.
        vec2 bowP = pos + rot(vec2(dir * 0.47 * S, 0.03 * S), pitch);
        if (length(p - bowP) < 0.07) {
            float slam = 0.55 + 0.45 * sin(t * 1.7);
            for (int i = 0; i < 6; i++) {
                float fi = float(i);
                float h = hash1(fi * 7.13 + 1.0);
                float life = 0.9 + 0.3 * h;
                float a = fract(t / life + fi / 6.0) * life;
                vec2 v = vec2(dir * (0.045 + 0.04 * h), 0.10 + 0.06 * hash1(fi * 3.7 + 2.0));
                vec2 d = bowP + v * a + vec2(0.0, -0.32 * a * a);
                float r = 0.0028 * (1.0 - a / life) + 0.0008;
                float drop = smoothstep(px, -px, length(p - d) - r) * step(s1 - 0.002, p.y);
                rgb = over(rgb, FOAM, drop * slam * (1.0 - a / life) * 0.9 * I);
            }
        }
    }

    // Front layer: the near rollers.
    rgb = waterLayer(rgb, p.y, s2, 0.048, 0.014, vec3(0.04, 0.11, 0.20), vec3(0.14, 0.30, 0.42), 0.48 * I, px);

    fragColor = vec4(rgb, base.a);
}
