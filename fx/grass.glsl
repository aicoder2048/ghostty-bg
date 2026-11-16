// grass — a meadow along the bottom bends under gusts of wind that roll across, with seed plumes and small flowers.
// zh: 草浪
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float HEIGHT    = 0.31;   // typical front-blade height, in window-heights
const float GUST      = 1.15;   // how hard the gusts bend the blades
const float GUST_GAP  = 4.6;    // seconds between gusts
const float GUST_SPEED = 0.68;  // how fast a gust rolls across, window-heights per second
const float FLOWERS   = 0.11;   // share of front blades that carry a flower
const float PLUMES    = 0.13;   // share of blades that carry a seed plume

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A gust: a narrow crest of strong wind that travels left to right across the
// meadow, arriving every GUST_GAP seconds. 0 = calm, 1 = peak of the gust.
float gust(float x) {
    float w = 6.2831 / GUST_GAP;
    float s = 0.5 + 0.5 * sin(w * iTime - w / GUST_SPEED * x + 1.15);
    return s * s * s * s * (0.85 + 0.15 * sin(0.31 * iTime));
}

// How far the grass leans at x: a steady lean, constant gentle sway, plus the gust.
float leanAt(float x, float layer) {
    return 0.22
         + 0.10 * sin(2.3 * iTime + 3.1 * x + layer)
         + 0.06 * sin(3.9 * iTime + 7.3 * x + 2.0 * layer)
         + GUST * gust(x);
}

// Taller and shorter patches along the meadow, so the top edge isn't flat.
float patchHeight(float x) {
    return 0.85 + 0.20 * sin(x * 2.7 + 1.3) + 0.10 * sin(x * 6.1 + 0.4);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 rgb = base.rgb;
    if (p.y > 0.62) {                                    // nothing up here
        fragColor = base;
        return;
    }

    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    float shade = lum > 0.5 ? 0.55 : 1.0;                // darker grass on light themes
    float aa = 1.5 / iResolution.y;

    // A soft dark-green ground under the grass, so the meadow reads as solid.
    float ground = smoothstep(0.10 * patchHeight(p.x), 0.0, p.y);
    rgb = mix(rgb, vec3(0.08, 0.20, 0.12) * shade, ground * 0.55 * INTENSITY);

    // Three depth layers, back to front: darker, shorter and denser at the back.
    for (int l = 0; l < 3; l++) {
        float fl = float(l);
        float H       = HEIGHT * (0.55 + 0.225 * fl);    // layer height
        float spacing = 0.014 + 0.007 * fl;
        float width   = 0.0035 + 0.0022 * fl;
        vec3 rootCol  = mix(vec3(0.14, 0.30, 0.22), vec3(0.20, 0.42, 0.18), fl * 0.5);
        vec3 tipCol   = mix(vec3(0.30, 0.48, 0.32), vec3(0.72, 0.88, 0.42), fl * 0.5);
        float alpha   = 0.62 + 0.14 * fl;

        if (p.y > H * 1.45 + 0.05) continue;

        // All blades of a layer bend along the same curve: sideways offset grows
        // with y^2. So we can work back from this pixel to the roots it might
        // belong to, and only test a handful of nearby blades.
        float bend = 0.55 * p.y * p.y / H;
        float xr = p.x - leanAt(p.x, fl) * bend;
        xr = p.x - leanAt(xr, fl) * bend;
        float cell = floor(xr / spacing);

        vec3 layerCol = vec3(0.0);
        float layerA = 0.0;
        for (int k = -2; k <= 2; k++) {
            float id = cell + float(k);
            float seed = id * 1.37 + fl * 31.0;
            float r1 = hash1(seed), r2 = hash1(seed + 2.0), r3 = hash1(seed + 4.0);
            float kind = hash1(seed + 11.0);

            float x0 = (id + 0.15 + 0.7 * r1) * spacing;
            float lean = leanAt(x0, fl) * mix(0.88, 1.12, r2)
                       + 0.06 * sin(iTime * (2.0 + r3) + r1 * 6.28);
            // A strongly bent blade doesn't reach as high.
            float h = H * patchHeight(x0) * mix(0.65, 1.15, r3);
            h *= 1.0 - 0.15 * min(lean * lean, 1.6);

            bool flower = l == 2 && kind < FLOWERS;
            bool plume  = l > 0 && kind >= FLOWERS && kind < FLOWERS + PLUMES;
            if (flower) h *= 0.85;

            // The blade: a tapering curve, measured across its slant.
            float t = p.y / h;
            float cx = x0 + lean * 0.55 * p.y * p.y / H;
            float slope = lean * 1.1 * p.y / H;
            float dx = (p.x - cx) / sqrt(1.0 + slope * slope);
            float w = width * ((flower || plume) ? 0.6 : 1.0);
            float hw = w * pow(max(1.0 - t, 0.0), 0.7);
            float a = step(t, 1.0) * smoothstep(aa, 0.0, abs(dx) - hw);
            vec3 c = mix(rootCol, tipCol, pow(clamp(t, 0.0, 1.0), 1.2));
            // Front blades get a thin bright rim on one edge, so they read on dark themes.
            if (l == 2) {
                float rim = smoothstep(hw * 0.3, hw * 0.9, -dx) * t;
                c = mix(c, vec3(0.88, 1.0, 0.62), rim * 0.75);
            }
            if (a > 0.0) { layerCol = mix(layerCol, c, a); layerA = max(layerA, a); }

            // Where the tip ends up, and which way it points.
            vec2 tip = vec2(x0 + lean * 0.55 * h * h / H, h);
            vec2 dir = normalize(vec2(lean * 1.1 * h / H, 1.0));
            vec2 q = p - tip;

            if (plume) {
                // A wild-grass seed head: a grainy oval continuing past the tip.
                float L = 0.035 + 0.02 * fl;
                float along = dot(q, dir) + 0.004;
                float across = dot(q, vec2(dir.y, -dir.x));
                float u = (along - L * 0.5) / (L * 0.5);
                float wd = (0.0045 + 0.002 * fl) * (0.7 + 0.3 * sin(along * 260.0));
                float e = smoothstep(1.0, 0.75, u * u + (across / wd) * (across / wd));
                vec3 pc = mix(vec3(0.85, 0.75, 0.50), vec3(1.0, 0.92, 0.70), 0.5 + 0.5 * sin(along * 260.0));
                layerCol = mix(layerCol, pc, e);
                layerA = max(layerA, e);
            }
            if (flower) {
                // A small five-petal flower nodding on its stem.
                float R = 0.015 + 0.006 * r1;
                float rot = lean * 0.8 + 0.4 * sin(iTime * 2.4 + r2 * 6.28);
                float r = length(q);
                float ang = atan(q.y, q.x) + rot;
                float edge = R * (0.55 + 0.45 * abs(cos(2.5 * ang)));
                float petals = smoothstep(edge + aa, edge, r);
                float centre = smoothstep(R * 0.32 + aa, R * 0.32, r);
                float hue = hash1(seed + 13.0);
                vec3 fc = hue < 0.34 ? vec3(0.97, 0.96, 0.92)
                        : hue < 0.67 ? vec3(1.00, 0.84, 0.25)
                                     : vec3(0.76, 0.52, 1.00);
                fc = mix(fc, vec3(1.0, 0.62, 0.12), centre);
                layerCol = mix(layerCol, fc, petals);
                layerA = max(layerA, petals);
            }
        }
        rgb = mix(rgb, layerCol * shade, layerA * alpha * INTENSITY);
    }

    // Seeds and pollen blown off the tops while a gust passes.
    vec2 sp = p - vec2(iTime * 0.42, 0.04 * sin(p.x * 3.0 + iTime));
    vec2 sid = floor(sp / 0.06);
    vec2 sf = fract(sp / 0.06) - 0.5;
    if (hash2(sid) > 0.55) {
        vec2 off = vec2(hash2(sid + 3.1), hash2(sid + 7.7)) - 0.5;
        float d = length(sf - off * 0.6) * 0.06;
        float speck = smoothstep(0.0055, 0.0018, d);
        float band = smoothstep(0.08, 0.20, p.y) * smoothstep(0.58, 0.36, p.y);
        float on = smoothstep(0.15, 0.6, gust(p.x - 0.12));
        rgb = mix(rgb, vec3(1.0, 0.95, 0.72) * shade, speck * band * on * 0.85 * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
