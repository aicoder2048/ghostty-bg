// shark — a big great white cruises across, tail sweeping, small fish scattering ahead of it.
// zh: 鲨鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.38;   // overall strength (0 = off); moderate because the shark is big
const float CROSS     = 15.0;   // seconds one crossing takes
const float GAP       = 5.0;    // seconds of open water before it comes back the other way
const float WIDTH     = 0.65;   // shark length as a fraction of the window width
const int   FISH      = 8;      // small fish that scatter ahead of it

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Signed distance to a tapered tube from a (radius ra) to b (radius rb).
float tube(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 s = segment(p, a, b);
    return s.x - mix(ra, rb, s.y);
}

// A great white seen from the side, facing +x. The body runs from the tail root
// (x = -1) to the snout (x = 1); the tail fin reaches back to about x = -1.45.
// sweep (-1..1) is the tail swinging side to side, which from the side shows as
// the tail fin turning edge-on and wide again, and the tail stock flexing.
// Returns (shape, back/belly mix, dark details).
vec3 shark(vec2 q, float sweep, float fin, float aa) {
    // Slight flex toward the tail.
    float t = clamp((0.2 - q.x) / 1.2, 0.0, 1.4);
    float y = q.y - 0.05 * sweep * t * t;

    // Torpedo body with a pointed snout; the belly is a bit flatter than the back.
    float h;
    if (q.x > 0.2) {
        float k = (q.x - 0.2) / 0.8;
        h = 0.20 * pow(max(1.0 - pow(k, 1.6), 0.0), 0.65);
    } else {
        float k = (0.2 - q.x) / 1.2;
        h = 0.035 + 0.165 * (1.0 - k * k);
    }
    h *= y > 0.0 ? 1.0 : 0.85;
    float d = max(abs(y) - h, max(-1.0 - q.x, q.x - 1.0));

    // Tall triangular first dorsal, small second dorsal and anal fins.
    d = min(d, tube(q, vec2(0.12, 0.15), vec2(-0.22, 0.56), 0.10, 0.012));
    d = min(d, tube(q, vec2(-0.12, 0.15), vec2(-0.22, 0.56), 0.08, 0.010));
    d = min(d, tube(q, vec2(-0.70, 0.07), vec2(-0.80, 0.16), 0.035, 0.008));
    d = min(d, tube(q, vec2(-0.72, -0.06), vec2(-0.82, -0.14), 0.030, 0.008));

    // Long pectoral fin that rows slowly, and a small pelvic fin.
    vec2 pr = vec2(0.28, -0.13);
    float pa = -2.2 + 0.12 * fin;
    d = min(d, tube(q, pr, pr + 0.50 * vec2(cos(pa), sin(pa)), 0.075, 0.015));
    d = min(d, tube(q, vec2(-0.40, -0.11), vec2(-0.56, -0.22), 0.04, 0.01));

    // Crescent tail, upper lobe much taller. Squash it along x as it turns edge-on.
    vec2 r = vec2(-1.0, 0.05 * sweep);
    vec2 c = vec2(r.x + (q.x - r.x) / (0.55 + 0.45 * abs(cos(sweep * 1.2))), q.y);
    float tail = tube(c, r + vec2(0.0, 0.02), r + vec2(-0.45, 0.50), 0.10, 0.015);
    tail = min(tail, tube(c, r - vec2(0.0, 0.02), r + vec2(-0.32, -0.32), 0.08, 0.015));
    tail = min(tail, tube(c, r, r + vec2(-0.14, 0.0), 0.08, 0.06));
    float shape = max(smoothstep(aa, -aa, d), smoothstep(aa, -aa, tail));

    // Countershading: dark back and fins, pale belly, with a wavy border.
    float belly = smoothstep(0.02, -0.04, y - 0.03 * sin(q.x * 9.0) + 0.02) * step(d, 0.01);

    // Dark details: eye, five gill slits, the mouth line under the snout.
    float eye = smoothstep(0.032, 0.016, length(q - vec2(0.72, 0.04)));
    float gills = 0.0;
    for (int k = 0; k < 5; k++) {
        float gx = 0.36 + 0.045 * float(k);
        gills = max(gills, smoothstep(0.012, 0.004, segment(q, vec2(gx, -0.10), vec2(gx + 0.02, 0.07)).x));
    }
    float mouth = smoothstep(0.016, 0.006, segment(q, vec2(0.88, -0.10), vec2(0.62, -0.13)).x);
    return vec3(shape, belly, max(eye, max(gills * 0.8, mouth * 0.8)));
}

// A small fish facing +x (as in fish.glsl): an oval body and a wagging tail.
float fish(vec2 q, float wag) {
    float body = smoothstep(1.0, 0.78, length(q * vec2(1.0, 2.4)));
    vec2 t = q - vec2(-0.85, 0.0);
    t.y -= wag * (-t.x) * 0.7;
    float inside = step(t.x, 0.0) * step(-0.8, t.x);
    float tail = inside * smoothstep(0.06, 0.0, abs(t.y) - (-t.x) * 0.75);
    return max(body, tail * 0.85);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Big things big: a fixed share of the window width, capped for very wide windows.
    float size = min(WIDTH * aspect / 2.45, 0.80);
    float margin = 1.5 * size;

    // Shift the clock so the shark is already coming in when the effect starts.
    float period = CROSS + GAP;
    float clock = iTime + 0.33 * CROSS;
    float cycle = floor(clock / period);
    float ct = mod(clock, period);                               // seconds into this cycle
    float t = ct / CROSS;                                        // 0..1 while crossing
    float dir = mod(cycle, 2.0) < 0.5 ? 1.0 : -1.0;              // alternate sides

    float x = mix(-margin, aspect + margin, t);
    if (dir < 0.0) x = aspect - x;
    // A slow dive or climb over the crossing, different each time; the nose follows it.
    float k = hash1(cycle * 3.7 + 1.0) - 0.5;
    float y = 0.40 + 0.10 * k * sin(t * 3.14159) + 0.015 * sin(clock * 0.7);
    float tilt = -0.10 * k * cos(t * 3.14159);                 // in the shark's own frame

    vec3 rgb = base.rgb;
    if (t < 1.0) {
        vec2 q = (p - vec2(x, y)) / size;
        q.x *= dir;                                              // face the way it swims
        q = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * q;

        float sweep = sin(clock * 2.2);
        float aa = 1.5 / (iResolution.y * size);
        vec3 s = shark(q, sweep, sin(clock * 0.8), aa);

        vec3 color = mix(vec3(0.50, 0.66, 0.82), vec3(0.92, 0.96, 1.0), s.y);
        float a = s.x * mix(0.75, 1.0, s.y) * (1.0 - 0.8 * s.z);
        rgb = blend(rgb, color, a * INTENSITY);
    }

    // Small fish waiting ahead of the shark dart away and fade as it gets close,
    // then gather again at the start of the next crossing.
    float head = x + dir * size;
    for (int i = 0; i < FISH; i++) {
        float fi = float(i);
        float hx = (0.15 + 0.7 * hash1(fi * 12.99 + 3.0)) * aspect;
        float hy = y + (hash1(fi * 78.23 + 5.0) - 0.5) * 0.30;
        float near = (head - hx) * dir;                          // > 0 once the snout has passed
        float flee = smoothstep(-0.45, 0.05, near);
        float up = hash1(fi * 5.1) > 0.5 ? 1.0 : -1.0;
        vec2 pos = vec2(hx, hy) + 0.04 * vec2(sin(iTime * 0.6 + fi), sin(iTime * 0.9 + fi * 2.0))
                 + flee * flee * vec2(dir * 0.35, up * 0.25);
        float fsz = 0.018;
        vec2 q = (p - pos) / fsz;
        q.x *= dir;                                              // they swim the same way, away from it
        float fade = (1.0 - flee) * smoothstep(0.0, 1.5, ct);
        float wag = sin(iTime * (7.0 + 8.0 * flee) + fi * 1.7);
        rgb = blend(rgb, vec3(1.0, 0.80, 0.45), fish(q, wag) * fade * 1.6 * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
