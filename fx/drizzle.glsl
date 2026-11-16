// drizzle — realistic rain: crisp slanted streaks in three depths, wind gusts, splashes and ripples on a wet surface.
// zh: 细雨
// group: weather
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY   = 0.85;   // overall strength (0 = off)
const float SPEED       = 2.4;    // near-layer fall speed, window heights per second
const float SLANT       = 0.10;   // calm-air slant (sideways per unit fallen)
const float GUST_SLANT  = 0.24;   // extra slant at the peak of a gust
const float GUST_PERIOD = 9.0;    // seconds between gusts
const float GUST_LEN    = 3.6;    // how long one gust lasts, seconds
const float GUST_START  = 1.2;    // first gust starts here (peaks ~3 s in)
const float DENSITY     = 0.28;   // share of cells holding a drop in calm air
const float GUST_DENS   = 0.20;   // extra share during a gust
const float FLOOR       = 0.030;  // near edge of the wet surface (window heights)
const float DEPTH_BAND  = 0.040;  // how far "back" the surface reaches on screen
const float TEXT_CALM   = 0.55;   // how much rain is thinned over the top-left text

const float PI = 3.14159265;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Gust envelope, 0..1: a smooth sin^2 bump of length GUST_LEN every GUST_PERIOD.
float gustPhase(float t) { return mod(t - GUST_START + GUST_PERIOD, GUST_PERIOD); }

float gust(float t) {
    float ph = gustPhase(t);
    return ph < GUST_LEN ? pow(sin(PI * ph / GUST_LEN), 2.0) : 0.0;
}

// Time integral of gust(): how far the extra wind has pushed the rain so far.
// Exact, so drops drift sideways smoothly and never jump back.
float gustIntegral(float t) {
    float done = floor((t - GUST_START + GUST_PERIOD) / GUST_PERIOD) - 1.0;
    float ph = gustPhase(t);
    float part = ph < GUST_LEN
        ? ph * 0.5 - GUST_LEN / (4.0 * PI) * sin(2.0 * PI * ph / GUST_LEN)
        : GUST_LEN * 0.5;
    return done * GUST_LEN * 0.5 + part;
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Soft-union of coverages, so overlapping drops never exceed 1.
void addCov(inout float acc, float k) { acc = acc + k - acc * k; }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; work with y up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;          // one pixel in scene units
    float t = iTime;

    float g = gust(t);
    float G = gustIntegral(t);
    float slant = SLANT + GUST_SLANT * g;

    // Top-left (where the shell text sits): still raining, but sparser and fainter.
    float textMask = (1.0 - smoothstep(0.35, 0.65, uv.x)) * (1.0 - smoothstep(0.35, 0.62, uv.y));
    float calm = 1.0 - TEXT_CALM * textMask;

    // ------------------------------------------------------------ streaks
    // Four depths (near -> very far). Each lives on a slanted grid that moves
    // with the drops, so one cell = at most one drop and no neighbour lookups.
    float rainNear = 0.0;   // near layers, drawn a little brighter
    float rainFar  = 0.0;
    for (int i = 0; i < 4; i++) {
        float z = float(i) / 3.0;                  // 0 = near, 1 = far
        float v     = SPEED * mix(1.0, 0.48, z);
        float cols  = mix(8.0, 30.0, z);           // columns per window height
        float cellH = mix(0.32, 0.11, z);
        float wPx   = mix(1.6, 0.8, z);            // line width in pixels
        float alpha = mix(0.60, 0.26, z);
        float dens  = (DENSITY + GUST_DENS * g) * mix(0.85, 1.25, z) * calm;

        // Grid coordinates: u follows the calm-air slant plus the gust drift,
        // w follows the fall. Both stay constant for a given drop.
        float u = p.x + SLANT * p.y - GUST_SLANT * v * G + float(i) * 0.731;
        float w = p.y + v * t + float(i) * 0.379;
        vec2 cell = floor(vec2(u * cols, w / cellH));
        vec2 f = fract(vec2(u * cols, w / cellH));
        vec2 id = cell + float(i) * 17.0;

        float h = hash(id);
        float present = clamp((dens - h) / 0.04, 0.0, 1.0);   // fades in/out as density changes
        if (present <= 0.0) continue;

        float len = mix(0.11, 0.032, z) * (0.75 + 0.5 * hash(id + 2.7));
        float hx = (0.3 + 0.4 * hash(id + 4.1)) / cols;
        float hy = (0.04 + (0.92 - len / cellH) * hash(id + 8.3)) * cellH;

        // Offset from the drop's head, back in scene units.
        float dy = f.y * cellH - hy;
        float dx = (f.x / cols - hx) - SLANT * dy;
        // Tail points up-wind (drops move right and down).
        vec2 tailDir = normalize(vec2(-slant, 1.0));
        float a = dot(vec2(dx, dy), tailDir);
        float perp = dot(vec2(dx, dy), vec2(tailDir.y, -tailDir.x));

        float across = clamp(0.5 * (wPx + 1.0) - abs(perp) / px, 0.0, 1.0) * min(wPx, 1.0);
        float tt = a / len;
        float along = clamp(a / px + 0.5, 0.0, 1.0)                 // crisp head
                    * (1.0 - smoothstep(0.45, 1.0, tt))           // tail fades out
                    * (0.8 + 0.2 * (1.0 - clamp(tt, 0.0, 1.0)));  // slightly brighter head
        // Stop at the surface (far drops land further back, higher on screen).
        float yEnd = FLOOR + z * DEPTH_BAND;
        float clip = smoothstep(yEnd - 0.003, yEnd + 0.002, p.y);
        float lum = 0.65 + 0.35 * hash(id + 5.9);

        float k = across * along * clip * present * alpha * lum * (0.85 + 0.25 * g);
        if (i < 2) addCov(rainNear, k); else addCov(rainFar, k);
    }
    float rain = rainNear + rainFar - rainNear * rainFar;
    rain *= mix(1.0, 0.6, textMask);

    // ------------------------------------------------------ wet surface
    float splash = 0.0;
    if (p.y < FLOOR + DEPTH_BAND + 0.06) {
        // A faint sheen line where the wet surface meets the view.
        float sheen = clamp(1.0 - abs(p.y - (FLOOR + DEPTH_BAND + 0.004)) / px, 0.0, 1.0) * 0.10;
        addCov(splash, sheen);

        float CW = 0.05;   // splash cell width
        float cx = floor(p.x / CW);
        for (int j = 0; j < 2; j++) {
            for (int k = -1; k <= 1; k++) {
                float c = cx + float(k);
                vec2 sid = vec2(c, float(j) * 31.0);
                float T = 0.55 + 0.55 * hash(sid + 1.3);       // seconds between drops here
                float tc = t / T + hash(sid + 7.7);
                float cyc = floor(tc);
                float age = fract(tc) * T;
                vec2 eid = sid + cyc * vec2(0.37, 1.91);
                if (hash(eid + 3.3) > 0.45 + 0.35 * g) continue;

                float z = hash(eid + 9.1);                    // depth on the surface
                float sc = mix(1.0, 0.45, z);                 // further = smaller
                vec2 ctr = vec2((c + 0.15 + 0.7 * hash(eid + 5.5)) * CW,
                                FLOOR + z * DEPTH_BAND);
                vec2 q = p - ctr;
                if (abs(q.x) > 0.06 || abs(q.y) > 0.03) continue;

                float life = age / T;
                float fade = (1.0 - life) * exp(-life * 2.5);   // rings die out quickly on real water

                // Expanding ripple rings, flattened by perspective (two, staggered).
                for (int r = 0; r < 2; r++) {
                    float ar = age - float(r) * 0.12;
                    if (ar <= 0.0) continue;
                    float rad = 0.045 * sc * (1.0 - exp(-ar * 3.5));
                    vec2 R = vec2(rad, rad * 0.22) + 1e-4;
                    float fr = length(q / R) - 1.0;
                    vec2 grad = (q / (R * R)) / max(length(q / R), 1e-4);
                    float d = abs(fr) / max(length(grad), 1e-4);
                    float ring = clamp(1.0 - d / px, 0.0, 1.0);
                    addCov(splash, ring * fade * (r == 0 ? 0.62 : 0.30) * mix(1.0, 0.6, z) * smoothstep(0.0, 0.03, ar));
                }

                // Crown splash: a brief bright impact and a few droplets
                // thrown up on short ballistic arcs.
                if (age < 0.22) {
                    float flash = clamp(1.0 - (length(q * vec2(0.5, 1.6)) - 1.5 * px * sc) / px, 0.0, 1.0);
                    addCov(splash, flash * (1.0 - smoothstep(0.0, 0.07, age)) * 0.7);
                    for (int m = 0; m < 4; m++) {
                        float fm = float(m);
                        float th = mix(-1.15, 1.15, (fm + 0.2 + 0.6 * hash(eid + fm)) / 4.0);
                        float vs = 0.30 * sc * (0.7 + 0.6 * hash(eid + fm + 11.0));
                        float gr = 3.8 * sc;
                        vec2 vel = vec2(sin(th), cos(th)) * vs;
                        vec2 pos = vel * age - vec2(0.0, 0.5 * gr * age * age);
                        vec2 vnow = vel - vec2(0.0, gr * age);
                        if (pos.y < -0.002) continue;
                        // Short motion streak behind each droplet.
                        float dd = segment(q, pos, pos - vnow * 0.012);
                        float dot_ = clamp(0.5 * (1.4 * sc + 1.0) - dd / px, 0.0, 1.0);
                        addCov(splash, dot_ * 0.75 * (1.0 - smoothstep(0.12, 0.22, age)));
                    }
                }
            }
        }
    }

    // --------------------------------------------------------- colour
    // Drops catch the scene's light: a cool near-white with a hint of the
    // background colour, a little brighter over brighter areas.
    float bl = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tint = mix(vec3(0.80, 0.86, 0.93), base.rgb / max(bl, 0.05) * 0.8, 0.22);
    tint = clamp(tint * (0.85 + 0.5 * bl), 0.0, 1.0);

    float cov = clamp((rain + splash - rain * splash) * INTENSITY, 0.0, 1.0);
    vec3 col = mix(base.rgb, max(tint, base.rgb + 0.10), cov);
    fragColor = vec4(col, base.a);
}
