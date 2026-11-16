// crystals — a cluster of translucent amethyst and ice crystals glows in the lower right, with travelling glints, a breathing inner light and rising shards.
// zh: 水晶
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY    = 1.0;    // overall strength (0 = off)
const float OPACITY      = 0.42;   // how solid the gem bodies look (translucent tint over the terminal)
const float HEIGHT       = 0.34;   // tallest crystal as a fraction of the window height
const float CLUSTER_X    = 0.25;   // distance of the cluster root from the right edge (window heights)
const float PULSE_PERIOD = 5.0;    // seconds between waves of inner light running up the crystals
const float LIGHT_SPEED  = 0.22;   // how fast the key light circles (moves the glints across the facets)
const float BLOOM        = 1.0;    // soft halo of light around the gems
const float GROW_TIME    = 1.6;    // seconds for the crystals to grow in when the effect starts
const int   SHARDS       = 12;     // floating crystal motes drifting upward

const vec3 VIOLET = vec3(0.60, 0.40, 1.00);   // amethyst inner glow (base)
const vec3 ICE    = vec3(0.50, 0.85, 1.00);   // ice-blue toward the tips
const vec3 DEEP   = vec3(0.16, 0.10, 0.34);   // shadowed body tint

const int N = 8;
// Hand-placed cluster, listed back to front. Offset from the root (x, in units of
// HEIGHT), lean angle (+ = toward the screen centre), length and half-width
// (fractions of HEIGHT), and a facet rotation that shifts the face lines.
const float CX[N]  = float[N](-0.05,  0.10, -0.34,  0.40, -0.52,  0.20,  -0.16,  0.04);
const float CA[N]  = float[N]( 0.12, -0.34,  0.55, -0.70,  0.95,  -0.20,  0.30, -0.04);
const float CL[N]  = float[N]( 0.62,  0.66,  0.50,  0.42,  0.30,  0.80,   0.74,  1.00);
const float CW[N]  = float[N]( 0.090, 0.110, 0.085, 0.080, 0.065, 0.120,  0.110, 0.150);
const float CR[N]  = float[N]( 0.15, -0.20,  0.25, -0.10,  0.05,  0.20,  -0.25,  0.05);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

vec3 rainbow(float t) {
    return 0.55 + 0.45 * cos(6.2832 * (t + vec3(0.0, 0.33, 0.67)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 root = vec2(aspect - CLUSTER_X, -0.015);
    vec2 rel = p - root;

    // Far from the cluster and its rising shards nothing is drawn: skip all work.
    if (rel.x < -0.55 || rel.x > 0.40 || p.y > 0.75) {
        fragColor = base;
        return;
    }

    float t = iTime;
    float px = 1.0 / iResolution.y;

    // Key light slowly circling in front of the gems; glints follow it.
    float la = t * LIGHT_SPEED;
    vec3 L = normalize(vec3(cos(la) * 0.9, 0.45 + 0.35 * sin(la * 0.73), 0.75));
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));

    vec3 col = base.rgb;      // gem bodies are composited over this
    vec3 light = vec3(0.0);   // additive light (glow, glints, edges, bloom)

    // ---- Crystals ---------------------------------------------------------
    if (rel.y < HEIGHT * 1.25 && rel.x > -0.45 && rel.x < 0.32) {
        for (int i = 0; i < N; i++) {
            float fi = float(i);
            float grow = smoothstep(0.0, 1.0, (t - 0.12 * fi) / GROW_TIME);
            float len = CL[i] * HEIGHT * (0.15 + 0.85 * grow);
            float w = CW[i] * HEIGHT;
            vec2 o = root + vec2(CX[i] * HEIGHT, 0.0);
            vec2 dir = vec2(-sin(CA[i]), cos(CA[i]));
            vec2 perp = vec2(dir.y, -dir.x);

            vec2 d = p - o;
            vec2 q = vec2(dot(d, perp), dot(d, dir));   // x across, y up the crystal
            // Bounding circle (with room for the bloom halo).
            vec2 c = q - vec2(0.0, len * 0.5);
            if (dot(c, c) > pow(len * 0.5 + w + 0.07, 2.0)) continue;

            // Column with a pointed six-sided tip, very slightly tapered.
            float tipLen = w * 2.1;
            float shoulder = len - tipLen;
            float yn = clamp(q.y / len, 0.0, 1.0);
            float colW = w * (1.0 - 0.10 * yn);
            float inTip = step(shoulder, q.y);
            float hw = mix(colW, colW * (len - q.y) / tipLen, inTip);
            float sd = abs(q.x) - hw;
            sd *= mix(1.0, tipLen / length(vec2(tipLen, colW)), inTip);
            sd = max(sd, -q.y);

            // Soft bloom from every gem, brighter low down where the inner light is.
            float pulseY = fract(t / PULSE_PERIOD - fi * 0.015) * 1.5 - 0.25;
            float pulse = exp(-pow((yn - pulseY) * 5.0, 2.0)) * smoothstep(-0.25, 0.05, pulseY);
            vec3 tint = mix(VIOLET, ICE, smoothstep(0.1, 0.95, yn));
            float halo = exp(-max(sd, 0.0) / 0.022) * (0.5 + 0.8 * (1.0 - yn) + 0.9 * pulse);
            light += tint * halo * 0.06 * BLOOM;

            if (sd > 2.0 * px) continue;
            float inside = smoothstep(px, -px, sd);

            // Facets: three visible faces of a hexagonal column. Face lines shift
            // with the crystal's rotation; they converge at the tip automatically.
            float xf = q.x / max(hw, 1e-4);
            float b1 = -0.42 + CR[i], b2 = 0.42 + CR[i];
            vec3 n;
            float fc;
            if (xf < b1)      { n = vec3(-0.82, 0.0, 0.57); fc = (b1 - 1.0) * 0.5; }
            else if (xf < b2) { n = vec3( 0.0, 0.0, 1.0);   fc = (b1 + b2) * 0.5; }
            else              { n = vec3( 0.82, 0.0, 0.57); fc = (b2 + 1.0) * 0.5; }
            n.y += inTip * 0.75;                           // tip faces tilt upward
            // Gentle curvature so the highlight is a spot that slides over the face.
            n.x += (xf - fc) * 0.35;
            n.y += (yn - 0.5) * 0.5;
            n = normalize(n);
            vec2 nxy = n.x * perp + n.y * dir;             // into screen space
            n = vec3(nxy, n.z);

            float diff = 0.25 + 0.75 * max(dot(n, L), 0.0);
            float spec = pow(max(dot(n, H), 0.0), 60.0);

            // Body: translucent, darker where the face turns away from the light.
            float core = 1.0 - 0.5 * xf * xf;
            float inner = exp(-yn * 2.4) * core;           // inner glow, strongest at the base
            vec3 body = mix(DEEP, tint * 0.55, diff * 0.8 + 0.2 * inner);
            float depthFade = 0.75 + 0.25 * fi / float(N - 1);   // back crystals a touch fainter
            float a = inside * OPACITY * (0.55 + 0.45 * diff) * depthFade * INTENSITY;
            col = mix(col, body, a);

            // Inner light + the breathing pulse rising through it.
            light += inside * tint * (inner * 0.22 + pulse * core * 0.45) * depthFade;
            // Specular glint on the face.
            light += inside * vec3(0.95, 0.97, 1.0) * spec * 0.75;

            // Luminous outline and fainter facet lines.
            float edge = smoothstep(1.6 * px, 0.0, abs(sd));
            float fl = min(abs(xf - b1), abs(xf - b2)) * hw;
            float facet = smoothstep(1.2 * px, 0.0, fl) * inside;
            light += mix(tint, vec3(1.0), 0.5) * (edge * (0.28 + 0.6 * spec) + facet * (0.10 + 0.5 * spec + 0.15 * pulse));

            // Prismatic fringe: a thin rainbow just inside the edge, strongest
            // where the light catches, plus little dispersion sparkles that twinkle.
            float fringe = exp(-max(-sd, 0.0) / (3.0 * px)) * inside;
            vec3 prism = rainbow(q.y * 9.0 + xf * 0.4 + la * 0.5);
            light += prism * fringe * (0.06 + 0.5 * spec);
            float cell = floor(q.y / 0.018);
            float tw = pow(0.5 + 0.5 * sin(t * 1.7 + hash1(cell * 7.1 + fi * 13.0) * 40.0), 24.0);
            float along = fract(q.y / 0.018) - 0.5;
            float spark = edge * tw * exp(-along * along * 30.0);
            light += rainbow(hash1(cell + fi * 3.0)) * spark * 0.9;
        }

        // Glow pooled on the ground at the roots.
        vec2 g = (p - root) * vec2(1.0, 3.2);
        light += VIOLET * exp(-length(g) / (HEIGHT * 0.35)) * 0.18 * BLOOM;
    }

    // ---- Floating shards ---------------------------------------------------
    for (int i = 0; i < SHARDS; i++) {
        float fi = float(i);
        float h1 = hash1(fi * 12.9 + 1.3), h2 = hash1(fi * 7.7 + 4.1);
        float h3 = hash1(fi * 3.3 + 9.2), h4 = hash1(fi * 5.1 + 2.7);
        float life = fract(t * (0.045 + 0.04 * h2) + h1);
        vec2 pos = root + vec2((h3 - 0.55) * 0.60 + 0.04 * sin(t * 0.4 + h4 * 6.28),
                               0.02 + life * 0.62);
        vec2 dp = p - pos;
        if (dot(dp, dp) > 0.0025) continue;

        float fade = smoothstep(0.0, 0.15, life) * smoothstep(1.0, 0.55, life);
        float spin = t * (0.3 + 0.4 * h4) + h1 * 6.28;
        vec2 m = mat2(cos(spin), -sin(spin), sin(spin), cos(spin)) * dp;
        float s = 0.0035 + 0.004 * h2;
        float dia = abs(m.x) / s + abs(m.y) / (s * 2.2);
        float shard = smoothstep(1.0, 0.75, dia);
        float twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * (1.2 + h3) + h4 * 30.0), 6.0);
        vec3 sc = mix(VIOLET, ICE, h4);
        // A faint cross flare when a shard catches the light.
        float flare = (exp(-abs(dp.x) / (0.6 * px)) * exp(-abs(dp.y) / 0.010)
                     + exp(-abs(dp.y) / (0.6 * px)) * exp(-abs(dp.x) / 0.010)) * pow(twinkle, 3.0);
        float glow = exp(-length(dp) / (s * 1.6));
        light += fade * (sc * shard * 0.60 * twinkle + sc * glow * 0.18 * twinkle
                         + mix(sc, vec3(1.0), 0.6) * flare * 0.30);
    }

    // Soft tone curve so glints bloom instead of clipping hard.
    light *= INTENSITY;
    light = light / (1.0 + 0.6 * light);
    fragColor = vec4(col + light, base.a);
}
