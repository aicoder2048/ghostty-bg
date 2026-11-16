// rocket — a sleek rocket climbs from the lower right on a brilliant plume, leaving a long, lingering vapour trail.
// zh: 火箭
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float PERIOD    = 13.0;   // seconds between launches
const float FLIGHT    = 11.0;   // seconds from liftoff until it fades into the distance
const float LENGTH    = 0.11;   // rocket length at liftoff, in window heights
const float SMOKE     = 0.65;   // opacity of the vapour trail where it is thickest
const float SMOKE_LIFE = 12.0;   // seconds for the trail to fade to about a third
const float STARS     = 0.30;   // brightness of the faint background stars
const int   SEGS      = 12;     // trail is drawn as this many segments per launch

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

// ---- Flight path ---------------------------------------------------------
// u runs 0..1 along the climb. The rocket starts just below the bottom edge,
// rises almost vertically, then pitches over toward the upper right (a gentle
// gravity turn). Each launch gets a slightly different start and lean.
vec2 pathStart(float n, float aspect) {
    return vec2((0.70 + 0.08 * hash1(n * 7.31 + 0.5)) * aspect, -0.07);
}
float pathLean(float n, float aspect) {
    return (0.12 + 0.06 * hash1(n * 3.17 + 1.7)) * aspect;
}
vec2 path(float u, vec2 s, float dx) {
    return s + vec2(dx * u * u, 0.90 * (1.5 * u - 0.5 * u * u));
}
vec2 pathDir(float u, float dx) {
    return normalize(vec2(2.0 * dx * u, 0.90 * (1.5 - u)));
}
// Eased progress: slow liftoff, faster climb, then apparent motion slows as it recedes.
float ease(float a) {
    a = clamp(a, 0.0, 1.0);
    return mix(a, a * a * (3.0 - 2.0 * a), 0.6);
}
// Perspective: things shrink as the rocket flies away from us.
float scaleAt(float u) { return mix(1.0, 0.15, pow(u, 0.75)); }

// Where smoke released at time te drifts after `age` seconds: a light breeze
// pushes it up-left and it meanders a little.
vec2 drift(float age, float te, float n) {
    return age * vec2(-0.006 + 0.004 * sin(te * 0.9 + n * 2.3), 0.0035);
}

// Vapour trail of one launch. Returns density in .x, release height u in .y,
// and smoke age in .z for the segment that dominates this pixel.
vec3 trail(vec2 p, float ageNow, float n, float aspect) {
    vec2 s = pathStart(n, aspect);
    float dx = pathLean(n, aspect);
    float tmax = min(ageNow, FLIGHT);
    if (tmax <= 0.0) return vec3(0.0);

    vec3 best = vec3(0.0);
    vec2 a = vec2(0.0); float wa = 0.0, aa = 0.0, ua = 0.0, ga = 0.0;
    for (int i = 0; i <= SEGS; i++) {
        float te = tmax * float(i) / float(SEGS);    // when this bit was released
        float age = ageNow - te;
        float u = ease(te / FLIGHT);
        float sc = scaleAt(u);
        vec2 b = path(u, s, dx) + drift(age, te, n);
        float wb = sc * (0.010 + 0.020 * age) + 0.003 * age;   // widens as it disperses
        float ab = SMOKE * exp(-age / SMOKE_LIFE) * smoothstep(0.0, 0.8, age)
                 * mix(1.0, 0.55, u);                          // thinner air higher up
        if (i > 0) {
            vec2 pa = p - a, ba = b - a;
            float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
            float d = length(pa - ba * h);
            float w = mix(wa, wb, h);
            float dens = mix(aa, ab, h) * exp(-d * d / (w * w));
            if (dens > best.x) best = vec3(dens, mix(ua, u, h), mix(ga, age, h));
        }
        a = b; wa = wb; aa = ab; ua = u; ga = age;
    }
    return best;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;

    // Start a couple of seconds into a flight so something shows immediately.
    float tt = iTime + 2.0;
    float n = floor(tt / PERIOD);
    float age = tt - n * PERIOD;

    vec3 col = base.rgb;

    // ---- Faint stars (one grid cell per pixel, so it costs almost nothing).
    vec2 cell = floor(p * 24.0);
    float hs = hash21(cell);
    if (hs > 0.86) {
        vec2 sp = (cell + vec2(hash21(cell + 3.1), hash21(cell + 7.7)) * 0.8 + 0.1) / 24.0;
        float tw = 0.65 + 0.35 * sin(iTime * (0.8 + 2.0 * hs) + hs * 40.0);
        float br = (hs - 0.86) / 0.14 * tw;
        float textArea = 1.0 - 0.6 * (1.0 - smoothstep(0.35, 0.6, uv.x)) * (1.0 - smoothstep(0.4, 0.65, uv.y));
        col += vec3(0.80, 0.86, 1.0) * br * STARS * textArea * INTENSITY
             * exp(-pow(length(p - sp) / (1.3 * px), 2.0));
    }

    // Current rocket state.
    vec2 s = pathStart(n, aspect);
    float dx = pathLean(n, aspect);
    float u = ease(age / FLIGHT);
    float sc = scaleAt(u);
    float L = LENGTH * sc;
    vec2 pos = path(u, s, dx);                       // nozzle position
    vec2 dir = pathDir(u, dx);
    float alive = 1.0 - smoothstep(FLIGHT - 2.0, FLIGHT, age);
    float flick = 0.94 + 0.04 * sin(iTime * 29.0) + 0.02 * sin(iTime * 53.0 + 1.3);
    float dRocket = length(p - pos);

    // ---- Vapour trails: this launch and the lingering one before it.
    // Skip the left part of the window entirely: the trail never gets there.
    if (p.x > 0.25 * aspect) {
        vec3 t1 = trail(p, age, n, aspect);
        vec3 t0 = trail(p, age + PERIOD, n - 1.0, aspect);
        vec3 t = t1.x > t0.x ? t1 : t0;
        float dens = max(t1.x, t0.x) + 0.35 * min(t1.x, t0.x);
        if (dens > 0.002) {
            // Billowy texture that drifts with the breeze.
            vec2 q = p * 11.0 + vec2(iTime * 0.05, -iTime * 0.03);
            float tex = 0.6 * vnoise(q) + 0.4 * vnoise(q * 2.3 + 4.1);
            dens *= 0.45 + 0.85 * tex;
            // Lighting: warm firelight near the flame and low down, cool moonlit blue higher up.
            float fire = alive * exp(-dRocket / (0.05 + 0.10 * sc)) * flick;
            float warm = clamp(max(fire, 0.45 * (1.0 - t.y) * exp(-t.z * 0.15)), 0.0, 1.0);
            vec3 cool = vec3(0.60, 0.66, 0.80);
            vec3 hot  = vec3(1.00, 0.68, 0.42);
            vec3 smokeCol = mix(cool, hot, warm) * (0.80 + 0.9 * fire);
            col = mix(col, smokeCol, clamp(dens * INTENSITY, 0.0, 0.75));
        }
    }

    // ---- Launch glow: warm light washing up from below the edge at liftoff.
    float lg = exp(-length((p - s) * vec2(0.8, 1.6)) / 0.16) * (1.0 - smoothstep(0.0, 4.5, age));
    col += vec3(1.0, 0.55, 0.25) * lg * 0.45 * INTENSITY;

    if (alive > 0.0) {
        vec2 side = vec2(dir.y, -dir.x);
        vec2 d = p - pos;
        vec2 q = vec2(dot(d, side), dot(d, dir)) / L;   // rocket units: nozzle at 0, nose at +1
        float aaq = 1.2 * px / L;
        float plumeGrow = mix(1.0, 2.4, u);              // plume balloons in thinner air

        // ---- Bloom: a wide soft halo plus a tight hot glow at the nozzle.
        vec2 gq = d + dir * L * 0.25;
        float gr = length(gq);
        vec3 glow = vec3(1.0, 0.62, 0.32) * 0.30 * exp(-gr / (0.09 * sc + 0.018))
                  + vec3(1.0, 0.85, 0.70) * 0.75 * exp(-gr / (0.016 * sc + 0.005));
        vec3 plume = glow * flick;

        // ---- Exhaust plume (only behind the nozzle).
        if (q.y < 0.1 && q.y > -3.5 && abs(q.x) < 1.2) {
            float y = max(-q.y, 0.0);
            float turb = vnoise(vec2(q.x * 7.0, y * 5.0 - iTime * 14.0));
            // Outer flame: orange, widening and fading with distance.
            float lf = 2.2 * plumeGrow * flick;
            float wf = (0.045 + 0.12 * y) * plumeGrow;
            float flame = exp(-q.x * q.x / (wf * wf)) * pow(clamp(1.0 - y / lf, 0.0, 1.0), 1.6)
                        * smoothstep(-0.02, 0.04, y) * (0.75 + 0.5 * turb);
            // Core: white-blue Mach core with a few pinched shock diamonds.
            float ph = y / 0.13;
            float pinch = 0.70 + 0.30 * abs(cos(ph * PI));
            float wc = 0.036 * pinch * (1.0 + 0.6 * y);
            float diamonds = 0.55 + 0.45 * pow(abs(cos(ph * PI)), 3.0);
            float core = exp(-q.x * q.x / (wc * wc)) * diamonds
                       * (1.0 - smoothstep(0.25, 0.85, y)) * smoothstep(-0.02, 0.02, y);
            vec3 flameCol = mix(vec3(1.0, 0.80, 0.50), vec3(1.0, 0.42, 0.14), smoothstep(0.0, lf, y));
            plume += flameCol * flame * 0.85 + vec3(0.88, 0.94, 1.0) * core * 1.3;
        }
        col += plume * alive * INTENSITY;

        // ---- Body: slim cylinder, ogive nose, small swept fins at the tail.
        if (abs(q.x) < 0.2 && q.y > -0.1 && q.y < 1.1) {
            float hw = 0.052;
            float r = hw * (q.y > 0.60 ? 0.90 : 1.0);                       // narrower upper stage
            float tn = clamp((q.y - 0.80) / 0.20, 0.0, 1.0);
            r *= sqrt(max(1.0 - tn * tn, 0.0)) * (q.y > 0.80 ? 0.90 : 1.0); // rounded nose
            float fin = q.y < 0.15 ? hw + 0.055 * clamp(1.0 - q.y / 0.15, 0.0, 1.0) : 0.0;
            float rr = max(r, fin);
            float sd = max(abs(q.x) - rr, max(-q.y, q.y - 1.0));
            float cover = smoothstep(aaq, -aaq, sd);

            if (cover > 0.0) {
                float nx = clamp(q.x / max(r, 1e-4), -1.0, 1.0);
                // Dark gunmetal silhouette, a cool specular stripe from the sky side,
                // a bright rim on both edges, and warm firelight on the tail.
                vec3 metal = vec3(0.16, 0.18, 0.23);
                metal += vec3(0.75, 0.82, 0.95) * 0.75 * exp(-pow((nx + 0.45) / 0.22, 2.0));
                metal += vec3(0.85, 0.90, 1.0) * 0.45 * smoothstep(0.65, 1.0, abs(nx));
                metal += vec3(1.0, 0.55, 0.25) * 0.85 * exp(-max(q.y, 0.0) * 5.0) * flick;
                metal += vec3(0.30) * step(abs(q.y - 0.60), 0.008);          // stage seam
                if (abs(q.x) > r) metal = vec3(0.30, 0.30, 0.34) + vec3(1.0, 0.55, 0.25) * 0.5;  // fins
                col = mix(col, metal, cover * alive * 0.85 * INTENSITY);
            }
        }
    }

    fragColor = vec4(col, base.a);
}
