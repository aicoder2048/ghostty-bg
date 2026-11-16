// tornado — a big banded funnel hangs from a dark spinning cloud, swaying and roaming the right side, kicking up dust and flinging debris.
// zh: 龙卷风
// group: weather
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.90;   // overall strength (0 = off); scales every layer's opacity
const float GROUND    = 0.05;   // where the rope touches down (scene y, 0 = bottom)
const float TOP       = 0.88;   // where the funnel meets the cloud base
const float TOP_WIDTH = 0.40;   // funnel width at the top, as a fraction of window width
const float SPIN      = 1.0;    // spin speed multiplier for the bands
const int   DEBRIS    = 14;     // boards, leaves and specks whirling around the base

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 q) {
    return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 q) {
    vec2 i = floor(q), f = fract(q);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i), b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0)), d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 q) {
    return 0.55 * noise(q) + 0.30 * noise(q * 2.03 + 7.1) + 0.15 * noise(q * 4.1 + 3.3);
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Funnel radius at height h (0 ground .. 1 cloud): a thin rope that flares
// into a wide cone, with a little extra flare where it joins the cloud.
float radiusAt(float h, float rTop) {
    return 0.013 + rTop * pow(h, 1.7) + 0.06 * smoothstep(0.8, 1.0, h);
}

// Centre line of the funnel: the top drifts behind the base, the middle bows
// in a slow sway, and the thin rope near the ground whips a little faster.
float axisAt(float h, float t, float baseX, float topX) {
    return mix(baseX, topX, h)
         + 0.07 * sin(3.1416 * h) * sin(t * 0.55 - h * 2.5)
         + 0.020 * (1.0 - h) * (1.0 - h) * sin(t * 1.7 - h * 12.0);
}

// Plain alpha blend: the funnel has dark and light parts, so it must be able
// to darken as well as brighten what is behind it.
vec3 over(vec3 dst, vec3 col, float a) {
    return mix(dst, col, clamp(a * INTENSITY, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    // The base roams across the right two thirds; the top follows lazily.
    float baseX = aspect * (0.62 + 0.20 * sin(t * 0.10 + 0.3));
    float topX  = aspect * (0.64 + 0.10 * sin(t * 0.10 - 0.5));
    float rTop  = 0.5 * TOP_WIDTH * aspect;
    float span  = TOP - GROUND;

    vec3 rgb = base.rgb;

    // ---- Debris: work out every piece once, split into behind / in front.
    vec4 backD = vec4(0.0), frontD = vec4(0.0);    // rgb, alpha
    float px = 1.0 / iResolution.y;
    for (int i = 0; i < DEBRIS; i++) {
        float fi = float(i);
        float s1 = hash1(fi * 3.7 + 0.5), s2 = hash1(fi * 9.1 + 1.7), s3 = hash1(fi * 5.3 + 2.9);
        float life = fract(t * (0.11 + 0.10 * s1) + s2);
        // Rise up the vortex, then get flung outward and drop back.
        float dh = 0.015 + 0.42 * life * (1.0 - 0.6 * life) * (0.6 + 0.6 * s3);
        float hh = dh / span;
        float R = radiusAt(hh, rTop) + 0.035 + 0.38 * life * life * (0.4 + 0.6 * s1);
        float ang = s2 * 6.2832 + t * (3.0 + 2.5 * s3) * (1.0 - 0.6 * life);
        vec2 pos = vec2(axisAt(hh, t, baseX, topX) + R * cos(ang), GROUND + dh + 0.025 * sin(ang));
        float near = 0.5 + 0.5 * sin(ang);          // 1 = closest to us
        float size = mix(0.75, 1.35, near);
        vec2 q = rot(t * (4.0 + 6.0 * s1) + fi) * (p - pos) / size;

        float sd;
        vec3 col;
        if (s3 < 0.40) {                             // board: a tumbling plank
            vec2 b = abs(q) - vec2(0.021, 0.0045);
            sd = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0);
            col = mix(vec3(0.24, 0.20, 0.16), vec3(0.50, 0.45, 0.40), s2);   // brown to grey
        } else if (s3 < 0.80) {                      // leaf: a pointed oval
            q.x *= 1.0 + 0.6 * abs(sin(t * 7.0 + fi));   // fluttering
            sd = (length(q / vec2(0.012, 0.0055)) - 1.0) * 0.005;
            col = mix(vec3(0.34, 0.42, 0.24), vec3(0.48, 0.38, 0.24), s1);
        } else {                                     // grit
            sd = length(q) - 0.0045;
            col = vec3(0.52, 0.48, 0.44);
        }
        float a = smoothstep(1.5 * px, -0.5 * px, sd);
        a *= smoothstep(0.0, 0.06, life) * (1.0 - smoothstep(0.85, 1.0, life));
        col *= mix(0.7, 1.15, near);
        if (sin(ang) > 0.0) {
            if (a > frontD.a) frontD = vec4(col, a);
        } else {
            if (a > backD.a) backD = vec4(col, a * 0.8);
        }
    }
    rgb = over(rgb, backD.rgb, backD.a);

    // ---- Funnel body.
    float h = (p.y - GROUND) / span;
    if (h > -0.02 && h < 1.05) {
        float hc = clamp(h, 0.0, 1.0);
        float r = radiusAt(hc, rTop);
        float axis = axisAt(hc, t, baseX, topX);
        float u = (p.x - axis) / r;                  // -1..1 across the funnel
        // Ragged, churning edge.
        float edge = abs(u) + 0.16 * (noise(vec2(hc * 26.0 - t * 1.5, t * 0.7 + sign(u) * 5.0)) - 0.5);
        float cover = smoothstep(1.0, 0.80, edge) * smoothstep(-0.02, 0.01, h);

        if (cover > 0.0) {
            float uc = clamp(u, -1.0, 1.0);
            float nz = sqrt(max(1.0 - uc * uc, 0.0));   // thickness of the cylinder here
            float ang = asin(uc);                        // angle around the front face

            // Three layers of streaks, each spinning at its own speed and
            // slanting by a fixed amount with height (so they never wind up).
            float s = SPIN * t;
            float b0 = noise(vec2((ang + s * 2.6) * 1.6 + hc * 6.0, hc * 34.0));
            float b1 = noise(vec2((ang + s * 1.7) * 2.6 - hc * 4.0, hc * 60.0 + 11.0));
            float b2 = noise(vec2((ang + s * 1.0) * 1.1 + hc * 9.0, hc * 14.0 + 23.0));
            float bands = 0.45 * b0 + 0.30 * b1 + 0.25 * b2;
            float stripe = pow(0.5 + 0.5 * sin(3.0 * (ang + s * 2.2) + hc * 40.0), 3.0);
            bands = mix(bands, stripe, 0.35);
            float dens = smoothstep(0.22, 0.78, bands);

            // Shading: dark slate core and shadow side (right), pale dusty rim.
            float rim = pow(abs(uc), 5.0);
            // Light comes from the left: that side and its rim are pale, the
            // right side falls into deep shadow.
            float side = 0.5 - 0.5 * uc;
            float shade = 0.03 + 0.42 * side * side + rim * (uc < 0.0 ? 0.50 : 0.25) + 0.50 * (dens - 0.5);
            vec3 col = mix(vec3(0.11, 0.13, 0.19), vec3(0.80, 0.83, 0.88), clamp(shade, 0.0, 1.0));

            // Fairly solid: the funnel sits right of most text, so it may hide more.
            float a = cover * (0.62 + 0.22 * nz + 0.10 * rim) * mix(0.72, 1.0, dens);
            a *= mix(1.10, 0.95, hc);                    // rope a touch more solid
            rgb = over(rgb, col, a);
        }
    }

    // ---- Cloud base: a dark, slowly rotating shelf centred over the funnel.
    if (p.y > TOP - 0.16) {
        vec2 cq = p - vec2(topX, TOP + 0.08);
        float dist = length(cq * vec2(1.0, 3.0));
        vec2 sq = cq * vec2(1.0, 3.0);                   // squash: a disc seen side-on
        float inner = fbm(rot(t * 0.45) * sq * 3.5 + 4.0);
        float outer = fbm(rot(t * 0.18) * sq * 2.2 + 9.0);
        float n = mix(inner, outer, smoothstep(0.15, 0.6, dist));
        // Lower edge dips down where it feeds the funnel (a wall cloud).
        float dx = cq.x / (0.55 * aspect);
        float lower = TOP - 0.01 - 0.07 * exp(-cq.x * cq.x * 18.0) + 0.06 * (n - 0.5);
        float dens = smoothstep(lower, lower + 0.06, p.y) * exp(-dx * dx * 1.6);
        vec3 col = mix(vec3(0.13, 0.15, 0.21), vec3(0.50, 0.54, 0.63), smoothstep(0.45, 0.85, n));
        rgb = over(rgb, col, dens * (0.55 + 0.35 * n));
    }

    // ---- Front debris.
    rgb = over(rgb, frontD.rgb, frontD.a);

    // ---- Dust cloud churning around the base.
    vec2 dq = p - vec2(axisAt(0.0, t, baseX, topX), GROUND);
    if (abs(dq.x) < 0.50 && dq.y < 0.35) {
        float ua = clamp(dq.x / 0.30, -1.0, 1.0);
        float a2 = asin(ua) + t * 2.4;                  // spin around the base
        float n1 = fbm(vec2(a2 * 1.8, dq.y * 14.0 - t * 0.9));
        float n2 = fbm(dq * 9.0 + vec2(t * 0.4, -t * 0.8));
        float e = length(dq * vec2(1.0 / 0.30, 1.0 / (0.11 + 0.07 * n2)));
        e += 0.45 * (n2 - 0.5);
        float dens = smoothstep(1.05, 0.35, e) * (0.45 + 0.7 * n1);
        vec3 col = mix(vec3(0.36, 0.32, 0.28), vec3(0.74, 0.66, 0.55), smoothstep(0.3, 0.8, n1));
        rgb = over(rgb, col, dens * 0.80);
    }

    fragColor = vec4(rgb, base.a);
}
