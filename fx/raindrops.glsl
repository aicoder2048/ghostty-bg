// raindrops — rain beads on the window glass; every second or so one slides down, leaving a beaded trail.
// zh: 窗上雨滴
// group: weather
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float BIG_CELL  = 0.135;  // grid size for the big resting drops (smaller = more drops)
const float SMALL_CELL = 0.050; // grid size for the small resting drops
const float LANE      = 0.15;   // width of a lane a sliding drop runs down
const float FALL      = 0.20;   // how fast a sliding drop speeds up
const float TRAIL_DRY = 2.2;    // seconds for the trail behind a slider to dry out

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One drop on glass, seen from the front. d = offset from its centre, r = radius.
// Returns (light, shade): light is added, shade darkens and cools the terminal.
// No refraction: water reads as a filled, slightly darker body with a soft
// shadow along its upper edge, a small sharp glint near the top-left and a
// bright caustic crescent inside the bottom edge (light focused through it).
vec2 drop(vec2 d, float r) {
    vec2 q = d / r;
    // Big drops sag under their weight: wider than tall, flatter underneath.
    float big = smoothstep(0.015, 0.05, r);
    q.x *= 1.0 - 0.12 * big;
    q.y *= q.y < 0.0 ? 1.0 + 0.25 * big : 1.05;
    float l = length(q);
    float aa = 1.5 / (r * iResolution.y);
    float inside = smoothstep(1.0, 1.0 - aa, l);

    float body = 0.32 * inside;
    float upper = smoothstep(0.5, 1.0, l) * smoothstep(-0.4, 0.6, q.y) * inside;
    float shade = body + 0.45 * upper;

    float lower = smoothstep(0.05, -0.75, q.y);
    float caustic = exp(-pow((l - 0.70) / 0.14, 2.0)) * lower * inside;
    float glow = smoothstep(0.9, 0.2, length(q - vec2(0.0, -0.45))) * inside;
    vec2 g = (q - vec2(-0.36, 0.40)) * vec2(1.0, 1.35);
    float spec = smoothstep(0.17, 0.08, length(g));
    float light = caustic * 0.75 + glow * 0.10 + spec * 1.1;
    return vec2(light, shade);
}

// Pop-in with a small overshoot, then a quick shrink-and-fade at the end of life.
float lifeScale(float t, float life) {
    float pop = clamp(t / 0.35, 0.0, 1.0);
    float grow = 1.0 + 0.25 * sin(pop * 3.14159) * (1.0 - pop * 0.3);
    grow *= smoothstep(0.0, 1.0, pop);
    return grow * smoothstep(life, life - 0.5, t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // 0 near the top-left (where the shell text is), 1 elsewhere.
    float open = 1.0 - smoothstep(1.35, 0.9, p.x) * smoothstep(0.40, 0.58, p.y);
    float density = mix(0.25, 1.0, open);

    float light = 0.0;
    float shade = 0.0;

    // Resting drops: a big and a small grid, one drop per cell at most. Each cell
    // lives through cycles: a drop pops in, sits, then fades, and a new one takes
    // its place somewhere else in the cell. The drop is kept inside its cell, so
    // only the pixel's own cell needs checking.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float cs = i == 0 ? BIG_CELL : SMALL_CELL;
        vec2 g = p / cs + fi * 7.3;
        vec2 id = floor(g);
        vec2 f = fract(g) * cs;

        float life = 5.0 + 7.0 * hash(id + 1.7 + fi);
        float t = iTime + life * hash(id + 5.3 + fi);  // random phase: full scene at t=0
        float k = floor(t / life);
        float lt = t - k * life;
        vec2 kid = id + k * 17.0;

        float present = step(1.0 - (i == 0 ? 0.62 : 0.55) * density, hash(kid + 2.9));
        float h = hash(kid + 4.4);
        float r = i == 0 ? mix(0.012, 0.056, h * h) : mix(0.004, 0.011, h);
        vec2 c = vec2(hash(kid + 8.1), hash(kid + 3.6));
        c = r * 1.15 + c * (cs - 2.3 * r);
        // Drops already present at start skip the pop-in so frame 0 is full.
        float s = (k == 0.0 && iTime < life) ? smoothstep(life, life - 0.5, lt) : lifeScale(lt, life);
        if (present > 0.5 && s > 0.01) {
            vec2 ds = drop(f - c, r * max(s, 0.05)) * min(s, 1.0);
            light += ds.x * (1.0 - fi * 0.25);
            shade = max(shade, ds.y);
        }
    }

    // Sliders: each lane holds one drop that sits for a moment, then runs down,
    // wobbling and speeding up, and leaves a trail of tiny beads that dries out.
    float lane = floor(p.x / LANE);
    float hl = hash(vec2(lane, 9.1));
    float period = 4.5 + 5.0 * hl;
    float t = iTime + period * hash(vec2(lane, 2.2));
    float k = floor(t / period);
    float lt = t - k * period;
    vec2 kid = vec2(lane, k);
    float laneOn = step(0.15 + 0.5 * (1.0 - density), hash(kid + 6.6));

    float x0 = (lane + 0.5) * LANE + (hash(kid + 1.3) - 0.5) * LANE * 0.3;
    float y0 = 0.35 + 0.6 * hash(kid + 7.7);
    float sit = 0.6 + 1.2 * hash(kid + 3.1);
    float r0 = mix(0.032, 0.046, hash(kid + 5.5));
    float wph = hash(kid + 8.8) * 6.28;
    float fade = smoothstep(period, period - 0.6, lt) * laneOn;

    float sl = max(lt - sit, 0.0);                    // time spent sliding
    float yc = y0 - 0.03 * sl - FALL * sl * sl;       // accelerates as it goes
    // Wobble is a function of height, so the trail follows the same crooked path.
    float xc = x0 + 0.007 * sin(yc * 17.0 + wph) + 0.004 * sin(yc * 53.0 + wph * 2.0);
    float rc = r0 * (1.0 - 0.3 * clamp((y0 - yc) / 0.9, 0.0, 1.0)); // loses water on the way
    float popIn = smoothstep(0.0, 0.3, lt);
    // A moving drop is pulled into a teardrop: stretched up, along its trail.
    vec2 dd = p - vec2(xc, yc);
    float speed = 0.03 + 2.0 * FALL * sl;
    if (dd.y > 0.0) dd.y /= 1.0 + min(speed * 1.5, 0.6);
    vec2 dm = drop(dd, rc * popIn);
    light += dm.x * fade * 1.3;
    shade = max(shade, dm.y * fade);

    // Trail above the slider: tiny beads in small rows plus a faint wet streak.
    if (sl > 0.0 && p.y > yc && p.y < y0) {
        float px = x0 + 0.007 * sin(p.y * 17.0 + wph) + 0.004 * sin(p.y * 53.0 + wph * 2.0);
        // When did the slider pass this height? Invert yc(sl).
        float dy = y0 - p.y;
        float tp = (-0.03 + sqrt(0.0009 + 4.0 * FALL * dy)) / (2.0 * FALL);
        float dry = exp(-(sl - tp) / TRAIL_DRY) * fade;

        float streak = smoothstep(0.0035, 0.0, abs(p.x - px));
        light += streak * 0.16 * dry;

        float row = 0.016;
        float j = floor(p.y / row);
        vec2 bid = vec2(lane * 31.0 + j, k);
        float by = (j + 0.5 + 0.3 * (hash(bid + 1.1) - 0.5)) * row;
        float bx = x0 + 0.007 * sin(by * 17.0 + wph) + 0.004 * sin(by * 53.0 + wph * 2.0)
                 + (hash(bid + 2.2) - 0.5) * 0.006;
        float br = mix(0.0030, 0.0065, hash(bid + 3.3));
        if (hash(bid + 4.4) > 0.3 && by > yc + rc && by < y0) {
            vec2 db = drop(p - vec2(bx, by), br);
            light += db.x * dry;
            shade = max(shade, db.y * dry);
        }
    }

    // Keep the text area calmer still.
    float calm = mix(0.45, 1.0, open);
    light = min(light, 1.2) * calm;
    shade *= calm;

    // Water on glass looks a bit darker and cooler: dim red/green more than blue.
    vec3 col = base.rgb * (1.0 - min(shade, 1.0) * INTENSITY * vec3(0.75, 0.62, 0.45));
    col += vec3(0.82, 0.9, 1.0) * light * INTENSITY;
    fragColor = vec4(col, base.a);
}
