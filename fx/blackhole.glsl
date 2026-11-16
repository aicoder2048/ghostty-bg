// blackhole — a Gargantua-style black hole in the lower right: black shadow, thin photon ring, an edge-on disc lensed over and under it.
// zh: 黑洞
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (nearby stars are lensed by position only).

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float HOLE      = 0.092;  // shadow radius, in window heights (the whole thing is ~3.4x taller)
const float TILT      = -0.07;  // disc tilt (radians)
const float FLAT      = 0.085;  // how edge-on the near side of the disc is (1 = face-on)
const float RIN       = 1.17;   // inner edge of the disc, in shadow radii
const float ROUT      = 4.1;    // outer edge of the disc
const float SPIN      = 0.035;  // disc rotation, turns per second at the inner edge
const float BEAM      = 0.45;   // Doppler beaming: left side brighter/bluer, right dimmer/redder
const float STARS     = 0.80;   // brightness of the lensed background stars

const float PI = 3.14159265;

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
    float a = phi / (2.0 * PI) + iTime * SPIN * pow(RIN / R, 1.5);
    float n = 0.40 * wnoise(vec2(a * 5.0, R * 12.0), 5.0);
    n += 0.35 * wnoise(vec2(a * 11.0, R * 30.0), 11.0) * smoothstep(0.9, 0.3, 26.0 * fw);
    n += 0.25 * wnoise(vec2(a * 23.0, R * 70.0), 23.0) * smoothstep(0.9, 0.3, 60.0 * fw);
    return smoothstep(0.18, 0.80, n);
}

// Hot gas colour: deep red -> orange -> yellow-white -> white -> faint blue-white.
vec3 heatColor(float T) {
    vec3 c = mix(vec3(0.50, 0.07, 0.01), vec3(1.00, 0.40, 0.07), smoothstep(0.05, 0.50, T));
    c = mix(c, vec3(1.00, 0.76, 0.42), smoothstep(0.45, 0.90, T));
    c = mix(c, vec3(1.00, 0.95, 0.88), smoothstep(0.85, 1.25, T));
    return mix(c, vec3(0.84, 0.91, 1.00), smoothstep(1.25, 1.75, T));
}

// Light from disc radius R, angle phi (0 = right, PI = left, negative = near side).
vec3 discLight(float R, float phi, float fw) {
    float c = cos(phi);
    // Gas on the left comes toward us: Doppler-boosted, hotter; the right recedes.
    float D = 1.0 - BEAM * c * sqrt(RIN / R);
    float T = 1.05 * pow(RIN / R, 0.8) * mix(1.0, D, 0.7);
    float prof = pow(RIN / R, 1.8) * smoothstep(ROUT, ROUT * 0.55, R);
    float g = gas(R, phi, fw);
    return heatColor(T) * prof * D * D * (0.50 + 0.80 * g) * 2.4;
}

// Height above the disc line at which the lensed far side of ring R shows up,
// for horizontal offset x. Hugs the shadow at the top, meets the disc at x = +-R.
float arcH(float R, float x, float g0, float g1) {
    // Inner rings: a near-circle round the shadow; outer rings: a flatter hump.
    float k = max(1.0 - x * x / (R * R), 0.0);
    float e = mix(0.5, 2.0, clamp((R - RIN) / (ROUT - RIN), 0.0, 1.0));
    return (g0 + g1 * (R - RIN)) * pow(k, e);
}

// Which disc ring the lensed arc at (|x|, y) belongs to (bisection: arcH grows with R).
float arcR(float ax, float y, float g0, float g1) {
    float lo = RIN, hi = ROUT * 1.05;
    for (int i = 0; i < 10; i++) {
        float m = 0.5 * (lo + hi);
        if (arcH(m, ax, g0, g1) < y) lo = m; else hi = m;
    }
    return 0.5 * (lo + hi);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Everything is in shadow radii around the hole, disc line along x.
    vec2 q = rot(p - vec2(aspect - 0.52, 0.205), -TILT) / HOLE;
    float r = length(q);
    if (r > 5.0) { fragColor = base; return; }        // far away: nothing to draw
    float px = 1.0 / (iResolution.y * HOLE);           // one pixel, in shadow radii
    float ax = abs(q.x), ay = abs(q.y);

    // --- far side of the disc, lensed into an arc over the top (and a thin one under)
    bool up = q.y > 0.0;
    float g0 = up ? 1.09 : 1.05;                       // arc height at the top for the inner ring
    float g1 = up ? 0.26 : 0.12;                       // ... and how fast it grows outward
    float Ra = arcR(ax, ay, g0, g1);
    float fwA = fwidth(Ra);
    float inA = clamp((ay - arcH(RIN, ax, g0, g1)) / px + 0.5, 0.0, 1.0);   // crisp inner edge
    vec3 col = discLight(Ra, acos(clamp(q.x / Ra, -1.0, 1.0)), fwA) * inA;
    col *= up ? 1.10 : 0.75 * smoothstep(2.6, 1.5, Ra);                     // underside image is fainter
    float arcA = clamp(dot(col, vec3(0.33)) * 3.0, 0.0, 1.0) * inA;

    // --- photon ring: light that looped round the hole, a hair outside the shadow
    float pw = max(0.016, 0.8 * px);
    float ring = exp(-pow((r - 1.025) / pw, 2.0)) + 0.25 * exp(-pow((r - 1.025) / (3.0 * pw), 2.0));
    col += vec3(1.0, 0.86, 0.66) * ring * (1.0 - 0.45 * q.x / max(r, 1e-3)) * 1.3;

    // --- lensed stars: each pixel looks up where its light really came from
    // (point-lens equation), so stars near the hole stretch into short arcs round it.
    vec2 beta = q * (1.0 - 2.4 / max(dot(q, q), 1e-3)) + vec2(iTime * 0.05, 0.0);
    vec2 cell = floor(beta / 0.6);
    float hs = hash2(cell);
    vec2 sp = (cell + 0.2 + 0.6 * vec2(hash2(cell + 7.1), hash2(cell + 3.3))) * 0.6;
    vec2 db = beta - sp;
    float fb = 0.6 * length(fwidth(beta)) + 1e-4;      // one pixel, measured in source space
    float rs = 0.012;
    float star = step(hs, 0.22) * (0.35 + 0.65 * hash2(cell + 1.9))
               * exp(-dot(db, db) / (rs * rs + fb * fb)) * min(1.0, 2.0 * rs * rs / (rs * rs + fb * fb));
    star *= smoothstep(1.06, 1.25, r) * smoothstep(4.6, 2.8, r) * (1.0 - arcA);
    col += mix(vec3(0.80, 0.86, 1.0), vec3(1.0, 0.90, 0.78), hash2(cell + 5.5)) * star * STARS * 1.6;

    // --- the shadow: nothing comes out of it
    float shadow = 1.0 - smoothstep(1.0 - px, 1.0 + px, r);
    col *= 1.0 - shadow;
    vec3 rgb = base.rgb * (1.0 - 0.94 * shadow * INTENSITY);

    // --- near side of the disc: a thin bright band crossing in front of the shadow
    float Rf = length(vec2(q.x, q.y / FLAT));
    float fwF = fwidth(Rf);
    float inF = clamp((Rf - RIN) / max(fwF, 1e-4) + 0.5, 0.0, 1.0) * step(q.y, 0.0);
    vec3 front = discLight(Rf, -acos(clamp(q.x / Rf, -1.0, 1.0)), fwF) * inF;
    float opF = clamp(dot(front, vec3(0.33)) * 2.5, 0.0, 0.92) * inF;      // dense gas hides what's behind
    col = col * (1.0 - opF) + front;

    col = min(col, vec3(1.25)) * INTENSITY;
    rgb *= 1.0 - 0.35 * clamp(dot(col, vec3(0.33)), 0.0, 1.0);             // bright gas covers the text a little
    fragColor = vec4(rgb + col, base.a);
}
