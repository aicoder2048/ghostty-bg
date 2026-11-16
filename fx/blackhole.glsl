// blackhole — a Gargantua-style black hole in the lower right that keeps eating stars: one drifts in, is torn into a glowing stream, the disc flares and jets fire.
// zh: 黑洞
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (nearby stars are lensed by position only).

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float HOLE      = 0.118;  // shadow radius, in window heights (the disc is ~3.4x taller)
const float TILT      = -0.07;  // disc tilt (radians)
const float FLAT      = 0.085;  // how edge-on the near side of the disc is (1 = face-on)
const float RIN       = 1.17;   // inner edge of the disc, in shadow radii
const float ROUT      = 4.1;    // outer edge of the disc
const float SPIN      = 0.035;  // disc rotation, turns per second at the inner edge
const float BEAM      = 0.32;   // Doppler beaming: left side brighter/bluer, right dimmer/redder
const float STARS     = 0.80;   // brightness of the lensed background stars
const float CYCLE     = 14.0;   // seconds per meal: approach, disruption, flare, jets, calm
const float OFFSET    = 2.6;    // start the first cycle part-way so a star shows up at once
const float STAR      = 0.20;   // radius of the infalling star, in shadow radii
const float JETS      = 1.0;    // jet brightness (0 = no jets)

const float PI  = 3.14159265;
const float TAU = 6.2831853;

// Story beats, in seconds from the start of a cycle.
const float TD   = 5.0;         // star reaches the tidal radius and starts to tear
const float JET0 = 8.0;         // jets switch on
const float FL0  = 7.7;         // ring of light flares out

float hash2(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Value noise that wraps every `period` cells in x, so it can run round the disc.
float wnoise(vec2 x, float period) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float x0 = mod(i.x, period), x1 = mod(i.x + 1.0, period);
    float a = hash2(vec2(x0, i.y)),       b = hash2(vec2(x1, i.y));
    float c = hash2(vec2(x0, i.y + 1.0)), d = hash2(vec2(x1, i.y + 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Turbulent gas at disc radius R and angle phi: long thin streaks along the orbit.
// Inner gas orbits faster (Kepler), so the bands slide past each other.
// fw = how much R changes across one pixel; fine octaves fade out before they alias.
float gas(float R, float phi, float fw) {
    float a = phi / TAU + iTime * SPIN * pow(RIN / R, 1.5);
    float n = 0.40 * wnoise(vec2(a * 5.0, R * 12.0), 5.0);
    n += 0.35 * wnoise(vec2(a * 11.0, R * 30.0), 11.0) * smoothstep(0.9, 0.3, 26.0 * fw);
    n += 0.25 * wnoise(vec2(a * 23.0, R * 70.0), 23.0) * smoothstep(0.9, 0.3, 60.0 * fw);
    return smoothstep(0.18, 0.80, n);
}

// Hot gas colour: deep red -> orange -> amber -> pale gold. Stops short of white
// so the bright side stays a colour instead of a blown-out blob.
vec3 heatColor(float T) {
    vec3 c = mix(vec3(0.50, 0.07, 0.01), vec3(1.00, 0.40, 0.07), smoothstep(0.05, 0.50, T));
    c = mix(c, vec3(1.00, 0.70, 0.36), smoothstep(0.45, 0.95, T));
    return mix(c, vec3(1.00, 0.88, 0.70), smoothstep(0.95, 1.50, T));
}

// Light from disc radius R, angle phi (0 = right, PI = left, negative = near side).
vec3 discLight(float R, float phi, float fw) {
    float c = cos(phi);
    // Gas on the left comes toward us: Doppler-boosted, hotter; the right recedes.
    float D = clamp(1.0 - BEAM * c * sqrt(RIN / R), 0.6, 1.35);
    float T = 1.0 * pow(RIN / R, 0.8) * mix(1.0, D, 0.7);
    float prof = pow(RIN / R, 1.5) * smoothstep(ROUT, ROUT * 0.55, R);
    float g = gas(R, phi, fw);
    return heatColor(T) * prof * D * (0.45 + 0.85 * g) * 1.7;
}

// Height above the disc line at which the lensed far side of ring R shows up,
// for horizontal offset x. Hugs the shadow at the top, meets the disc at x = +-R.
float arcH(float R, float x, float g0, float g1) {
    float k = max(1.0 - x * x / (R * R), 0.0);
    float e = mix(0.5, 2.0, clamp((R - RIN) / (ROUT - RIN), 0.0, 1.0));
    return (g0 + g1 * (R - RIN)) * pow(k, e);
}

// Which disc ring the lensed arc at (|x|, y) belongs to (bisection: arcH grows with R).
float arcR(float ax, float y, float g0, float g1) {
    float lo = RIN, hi = ROUT * 1.05;
    for (int i = 0; i < 9; i++) {
        float m = 0.5 * (lo + hi);
        if (arcH(m, ax, g0, g1) < y) lo = m; else hi = m;
    }
    return 0.5 * (lo + hi);
}

// --- the infalling star's track: an inward spiral, counter-clockwise on screen like
// the disc (in from the right, over the top, round the left, across the front).
// The orbit starts fairly open and settles toward the disc plane as it shrinks.
const float TH0 = 0.05;
float trackR(float th)  { return 1.55 + 6.8 * exp(-0.42 * (th - TH0)); }
float trackSq(float R)  { return mix(0.14, 0.58, smoothstep(1.6, 7.5, R)); }
vec2 trackP(float th) {
    float R = trackR(th);
    return R * vec2(cos(th), trackSq(R) * sin(th));
}
vec2 trackT(float th) {                  // tangent (ignores the slow change of squash)
    float R = trackR(th), dR = -0.42 * (R - 1.55), k = trackSq(R);
    return vec2(dR * cos(th) - R * sin(th), k * (dR * sin(th) + R * cos(th)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Everything is in shadow radii around the hole, disc line along x.
    vec2 q = rot(p - vec2(aspect - 0.62, 0.275), -TILT) / HOLE;
    float r = length(q);
    float ax = abs(q.x), ay = abs(q.y);
    // Far from the hole and outside the star's lane and the jets: nothing to draw.
    if (r > 5.0 && ax > 0.8 && (q.x < 0.0 || q.y < -1.0 || q.y > 5.2)) { fragColor = base; return; }
    float px = 1.0 / (iResolution.y * HOLE);           // one pixel, in shadow radii

    // --- where we are in the story
    float s = mod(iTime + OFFSET, CYCLE);
    float x = max(s - TD, 0.0);                        // seconds since the star began to tear
    float thStar = TH0 + 2.2 * pow(clamp(s / TD, 0.0, 1.0), 1.5);   // speeds up as it falls
    float thEnd = TH0 + TAU + 0.5;                     // where the stream merges into the disc
    float thH = min(thStar + 0.75 * x + 0.35 * x * x, thEnd);      // leading end races ahead
    float thT = min(thStar + 0.30 * x + 0.16 * x * x, thEnd);      // trailing end lags
    // Feeding: the disc brightens as the stream arrives, then slowly settles.
    float feed = smoothstep(TD + 2.2, TD + 3.2, s) * (1.0 - smoothstep(TD + 4.5, CYCLE - 0.5, s));
    float discGain = 0.80 + 0.80 * feed;

    vec3 col = vec3(0.0);
    float arcA = 0.0;
    float shadow = 0.0;
    vec3 front = vec3(0.0);
    float opF = 0.0;
    if (r < 5.0) {
        // --- far side of the disc, lensed into an arc over the top (and a thin one under)
        bool up = q.y > 0.0;
        float g0 = up ? 1.09 : 1.05;
        float g1 = up ? 0.26 : 0.12;
        float Ra = arcR(ax, ay, g0, g1);
        float fwA = fwidth(Ra);
        float inA = clamp((ay - arcH(RIN, ax, g0, g1)) / px + 0.5, 0.0, 1.0);   // crisp inner edge
        col = discLight(Ra, acos(clamp(q.x / Ra, -1.0, 1.0)), fwA) * inA * discGain;
        col *= up ? 1.0 : 0.70 * smoothstep(2.6, 1.5, Ra);                       // underside image is fainter
        arcA = clamp(dot(col, vec3(0.33)) * 3.0, 0.0, 1.0) * inA;

        // --- photon ring: light that looped round the hole, a hair outside the shadow
        float pw = max(0.016, 0.8 * px);
        float ring = exp(-pow((r - 1.025) / pw, 2.0)) + 0.25 * exp(-pow((r - 1.025) / (3.0 * pw), 2.0));
        col += vec3(1.0, 0.82, 0.60) * ring * (1.0 - 0.35 * q.x / max(r, 1e-3)) * (0.9 + 1.6 * feed);

        // --- lensed stars: each pixel looks up where its light really came from
        // (point-lens equation), so stars near the hole stretch into short arcs round it.
        vec2 beta = q * (1.0 - 2.4 / max(dot(q, q), 1e-3)) + vec2(iTime * 0.05, 0.0);
        vec2 cell = floor(beta / 0.6);
        float hs = hash2(cell);
        vec2 sp = (cell + 0.2 + 0.6 * vec2(hash2(cell + 7.1), hash2(cell + 3.3))) * 0.6;
        vec2 db = beta - sp;
        float fb = 0.6 * length(fwidth(beta)) + 1e-4;
        float rs = 0.012;
        float star = step(hs, 0.22) * (0.35 + 0.65 * hash2(cell + 1.9))
                   * exp(-dot(db, db) / (rs * rs + fb * fb)) * min(1.0, 2.0 * rs * rs / (rs * rs + fb * fb));
        star *= smoothstep(1.06, 1.25, r) * smoothstep(4.6, 2.8, r) * (1.0 - arcA);
        col += mix(vec3(0.80, 0.86, 1.0), vec3(1.0, 0.90, 0.78), hash2(cell + 5.5)) * star * STARS * 1.6;

        shadow = 1.0 - smoothstep(1.0 - px, 1.0 + px, r);

        // --- near side of the disc: a thin bright band crossing in front of the shadow
        float Rf = length(vec2(q.x, q.y / FLAT));
        float fwF = fwidth(Rf);
        float inF = clamp((Rf - RIN) / max(fwF, 1e-4) + 0.5, 0.0, 1.0) * step(q.y, 0.0);
        front = discLight(Rf, -acos(clamp(q.x / Rf, -1.0, 1.0)), fwF) * inF * discGain;
        opF = clamp(dot(front, vec3(0.33)) * 2.5, 0.0, 0.92) * inF;
    }

    // --- the tidal stream: the torn star as a glowing ribbon along its spiral.
    // Nearest point on the track by a few Newton steps, for the two windings it can have.
    vec3 sCol = vec3(0.0);
    float sA = 0.0;
    bool sFar = false;
    if (x > 0.0 && thT < thEnd - 0.01 && r < 9.0) {
        float bestD = 1e9, bestTh = thT;
        float th0 = atan(q.y / 0.3, q.x);
        th0 = TH0 + mod(th0 - TH0, TAU);
        for (int k = 0; k < 2; k++) {
            float th = clamp(th0 + TAU * float(k), thT, thH);
            for (int i = 0; i < 3; i++) {
                vec2 T = trackT(th);
                th = clamp(th + dot(q - trackP(th), T) / dot(T, T), thT, thH);
            }
            float d = length(q - trackP(th));
            if (d < bestD) { bestD = d; bestTh = th; }
        }
        float u = (bestTh - thT) / max(thH - thT, 1e-3);         // 0 = trailing end, 1 = leading end
        float w = mix(0.045, 0.15, sqrt(u)) * (1.0 - 0.55 * smoothstep(thEnd - 1.6, thEnd, bestTh));
        float cov = clamp((w - bestD) / px + 0.5, 0.0, 1.0);
        // Fine lengthwise filaments that slide along with the flow.
        float fil = 0.78 + 0.22 * sin(bestTh * 37.0 - s * 4.0) * sin(bestTh * 11.0 + 1.3);
        float tube = 1.0 - 0.45 * clamp(bestD / w, 0.0, 1.0);    // round, brighter down the middle
        float fade = smoothstep(thEnd, thEnd - 0.9, bestTh);     // swallowed by the disc
        vec3 hot = mix(vec3(1.0, 0.48, 0.16), vec3(1.0, 0.86, 0.66), u);
        sCol = hot * (cov * tube * fil * 1.25 + 0.18 * exp(-max(bestD - w, 0.0) / 0.06)) * fade;
        sA = cov * fade;
        sFar = sin(bestTh) > 0.0;
    }

    // --- the star itself: a small crisp sphere that stretches along its path as the
    // tide grows, then shrinks into the stream once it has been torn apart.
    float sr = STAR * (1.0 - smoothstep(0.2, 1.8, x));
    if (sr > 0.002) {
        float thC = mix(thT, thH, 0.6);
        vec2 c = trackP(thC);
        vec2 t = normalize(trackT(thC));
        vec2 d = q - c;
        float stretch = 1.0 + 0.9 * smoothstep(TD - 1.6, TD + 0.6, s);
        vec2 e = vec2(dot(d, t) / stretch, dot(d, vec2(-t.y, t.x)));
        float rr = length(e);
        float cov = clamp((sr - rr) / px + 0.5, 0.0, 1.0);
        float mu = sqrt(max(1.0 - rr * rr / (sr * sr), 0.0));  // limb darkening
        vec3 sc = mix(vec3(1.0, 0.70, 0.45), vec3(1.0, 0.96, 0.88), mu);
        vec3 starC = sc * (0.75 + 0.35 * mu) * cov + vec3(1.0, 0.85, 0.65) * 0.30 * exp(-max(rr - sr, 0.0) / 0.07);
        sCol += starC;
        if (cov > sA) { sA = cov; sFar = sin(thC) > 0.0; }
    }

    // Far-side stream and star pass behind the hole; near-side ones cross in front.
    if (sFar) { col = col * (1.0 - sA) + sCol; }
    col *= 1.0 - shadow;
    col = col * (1.0 - opF) + front;
    if (!sFar) { col = col * (1.0 - sA) + sCol; }

    // --- ring of light: a crisp wavefront that rolls outward when the meal lands
    float ft = s - FL0;
    if (ft > 0.0 && ft < 4.0) {
        for (int i = 0; i < 2; i++) {
            float f2 = ft - 0.35 * float(i);
            if (f2 <= 0.0) continue;
            float rf = 1.05 + 2.8 * (1.0 - exp(-0.9 * f2));
            float wf = 0.025 + 0.02 * f2;
            float line = clamp((wf - abs(r - rf)) / px + 0.5, 0.0, 1.0);
            col += vec3(1.0, 0.80, 0.55) * line * exp(-1.1 * f2) * (i == 0 ? 0.9 : 0.5);
        }
    }

    // --- relativistic jets: two thin blue-white needles along the spin axis.
    float jt = s - JET0;
    if (jt > 0.0 && jt < 5.0 && JETS > 0.0 && ax < 0.5) {
        float yF = 1.15 + (q.y > 0.0 ? 3.2 : 6.0) * (1.0 - exp(-1.8 * jt));   // shoots out fast, then holds; the upper one stays short, clear of the text
        float yB = 1.15 + 6.0 * pow(max(jt - 2.4, 0.0), 1.4);    // base lets go: the jet flies off
        if (ay > yB && ay < yF + 0.1) {
            float w = 0.028 + 0.010 * ay;                         // a very slight opening angle
            float cov = clamp((w - ax) / px + 0.5, 0.0, 1.0);
            float core = clamp((0.4 * w - ax) / px + 0.5, 0.0, 1.0);
            float ends = clamp((yF - ay) / px + 0.5, 0.0, 1.0) * smoothstep(yB, yB + 0.6, ay);
            float knots = 0.65 + 0.35 * smoothstep(0.3, 0.9, sin(ay * 3.2 - jt * 14.0));
            float fade = (1.0 - smoothstep(2.8, 4.4, jt)) * (q.y > 0.0 ? 1.0 : 0.8);
            float halo = 0.22 * exp(-max(ax - w, 0.0) / 0.05);
            vec3 jc = vec3(0.55, 0.75, 1.0) * (cov * 0.85 * knots + halo) + vec3(0.85, 0.92, 1.0) * core * 0.6;
            col += jc * ends * fade * JETS;
        }
        // A bright spot where the jets leave the poles.
        float base0 = exp(-length(vec2(ax, ay - 1.15)) / 0.08) * (1.0 - smoothstep(2.4, 3.2, jt));
        col += vec3(0.75, 0.88, 1.0) * base0 * 0.8 * JETS;
    }

    // Tone-map on the brightest channel: colours keep their hue and nothing clips
    // to a white blob, however much the Doppler side or the flare pile up.
    float m = max(col.r, max(col.g, col.b));
    col *= 0.95 * (1.0 - exp(-1.5 * m)) / max(m, 1e-4);
    col *= INTENSITY;

    vec3 rgb = base.rgb * (1.0 - 0.94 * shadow * INTENSITY);
    rgb *= 1.0 - 0.35 * clamp(dot(col, vec3(0.33)), 0.0, 1.0);             // bright gas covers the text a little
    fragColor = vec4(rgb + col, base.a);
}
