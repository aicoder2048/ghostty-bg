// snake — a chunky pixel snake hunts food pellets in the lower right, growing with each bite.
// zh: 贪吃蛇
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const float CELL      = 0.042;  // grid cell, in window-heights
const float W         = 16.0;   // board size, in cells
const float H         = 9.0;
const float RATE      = 7.0;    // steps per second
const float MEAL      = 10.0;   // steps from one pellet to the next
const int   MEALS     = 5;      // pellets per round; then it blinks and starts over
const float END       = 12.0;   // steps of blinking at the end of a round
const float START_LEN = 3.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // The board sits in the bottom-right corner, clear of the prompt.
    vec2 origin = vec2(aspect - 0.03 - W * CELL, 0.03);
    vec2 g = (p - origin) / CELL;
    // A thin frame just outside the board, so the snake never sits under it.
    vec2 o = max(-g, g - vec2(W, H));
    float outside = max(o.x, o.y);
    if (outside > 0.0) {
        float frame = smoothstep(0.0, 0.05, outside) * smoothstep(0.22, 0.12, outside);
        fragColor = vec4(base.rgb + vec3(0.30, 0.80, 1.00) * frame * 0.35 * INTENSITY, base.a);
        return;
    }
    vec2 cell = floor(g);
    vec2 f = fract(g);

    // Time -> round and step. Nothing is remembered between frames: the whole
    // game is replayed from the round's seed every frame.
    float roundSteps = float(MEALS) * MEAL + END;
    float steps = iTime * RATE;
    float round_ = floor(steps / roundSteps);
    float n = floor(mod(steps, roundSteps));
    float last = float(MEALS) * MEAL;
    float over = step(last, n);
    n = min(n, last);

    // Where each pellet is. Every pellet is exactly MEAL steps (Manhattan, on a
    // wrapping board) from the previous one: first a horizontal leg, then a
    // vertical one, so the snake only ever makes right-angle turns.
    vec2 food[6];
    vec2 off[5];
    food[0] = floor(vec2(hash(vec2(round_, 1.0)) * W, hash(vec2(round_, 2.0)) * H));
    for (int i = 0; i < MEALS; i++) {
        float fi = float(i);
        float ax = floor(3.0 + 6.0 * hash(vec2(round_, fi + 10.0)));           // 3..8
        float sx = hash(vec2(round_, fi + 20.0)) < 0.5 ? -1.0 : 1.0;
        float sy = hash(vec2(round_, fi + 30.0)) < 0.5 ? -1.0 : 1.0;
        off[i] = vec2(sx * ax, sy * (MEAL - ax));
        food[i + 1] = mod(food[i] + off[i], vec2(W, H));
    }

    // Body: segment i is where the head was i steps ago.
    float meals = min(floor(n / MEAL), float(MEALS));
    float len = START_LEN + meals;
    float hit = -1.0;
    for (int i = 0; i < MEALS + 3; i++) {
        float fi = float(i);
        if (fi >= len) break;
        float k = n - fi;
        vec2 at;
        if (k < 0.0) {
            at = food[0] + vec2(sign(off[0].x) * k, 0.0);                      // starting tail, in line
        } else {
            int m = int(min(floor(k / MEAL), float(MEALS) - 1.0));
            float s = k - float(m) * MEAL;
            vec2 o = off[m];
            float ax = abs(o.x);
            at = food[m] + (s < ax ? vec2(sign(o.x) * s, 0.0)
                                   : vec2(o.x, sign(o.y) * (s - ax)));
        }
        at = mod(at, vec2(W, H));
        if (hit < 0.0 && all(equal(at, cell))) hit = fi;
    }

    vec2 a = abs(f - 0.5);
    float square = step(max(a.x, a.y), 0.42);
    vec3 light = vec3(0.0);

    if (hit >= 0.0) {
        // Bright head, body fading a little toward the tail.
        vec3 body = mix(vec3(0.30, 1.00, 0.60), vec3(0.20, 0.70, 1.00), hit / 8.0);
        vec3 c = hit < 0.5 ? vec3(0.85, 1.00, 0.90) : body;
        float blink = over > 0.5 ? step(0.5, fract(steps / 3.0)) : 1.0;          // game over: blink
        light += c * square * (hit < 0.5 ? 1.0 : 0.8) * blink;
    } else if (over < 0.5) {
        // The pellet it is heading for, gently pulsing.
        vec2 target = food[int(min(floor(n / MEAL), float(MEALS) - 1.0)) + 1];
        if (all(equal(cell, target))) {
            float dot_ = smoothstep(0.30, 0.22, length(f - 0.5));
            light += vec3(1.00, 0.30, 0.75) * dot_ * (0.75 + 0.25 * sin(iTime * 8.0));
        }
    }

    fragColor = vec4(base.rgb + light * INTENSITY, base.a);
}
