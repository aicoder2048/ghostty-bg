// rocket — a little rocket climbs diagonally across the sky on a flickering flame, leaving puffs.
// zh: 火箭
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const float PERIOD    = 16.0;   // seconds between launches
const float FLIGHT    = 9.0;    // seconds a flight takes
const float SIZE      = 0.070;  // half the rocket length, in screen heights
const int   PUFFS     = 7;      // smoke puffs left behind

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Where the rocket is at flight fraction k: a gentle arc from lower left to upper right.
vec2 path(float k, float aspect, float seed) {
    float x0 = mix(0.05, 0.40, hash1(seed)) * aspect;
    vec2 a = vec2(x0, -0.15);
    vec2 b = vec2(x0 + mix(0.45, 0.70, hash1(seed + 1.0)) * aspect, 1.20);
    vec2 pos = mix(a, b, k);
    pos.x -= 0.12 * sin(k * 3.14159);          // bows a little, like it is turning
    return pos;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float n = floor(iTime / PERIOD);
    float age = mod(iTime, PERIOD);
    float k = age / FLIGHT;
    vec3 color = vec3(0.0);

    // Smoke puffs: dropped along the path at earlier moments, growing and fading.
    for (int i = 0; i < PUFFS; i++) {
        float fi = float(i);
        float dropped = (floor(age / 0.35) - fi) * 0.35;      // puffs drop every 0.35 s
        float since = age - dropped;
        if (dropped < 0.0 || dropped > FLIGHT) continue;
        vec2 c = path(dropped / FLIGHT, aspect, n * 3.3)
               + vec2(hash1(dropped * 9.1) - 0.5, -0.3) * 0.02 * since;   // drift and sink
        float rad = SIZE * (0.22 + 0.30 * since);
        float a = smoothstep(rad, rad * 0.3, length(p - c)) * exp(-since * 1.1);
        color += vec3(0.60, 0.60, 0.68) * a * 0.45;
    }

    if (k < 1.0) {
        vec2 pos = path(k, aspect, n * 3.3);
        vec2 vel = path(k + 0.01, aspect, n * 3.3) - pos;
        float heading = atan(vel.x, vel.y);                   // angle from straight up
        vec2 q = rot(p - pos, heading) / SIZE;                // rocket units: nose at +y, 2 long
        float aa = 1.5 / (iResolution.y * SIZE);

        // Body: a tall ellipse cut flat at the bottom; the nose gets a red cap.
        float body = smoothstep(1.0 + aa, 1.0 - aa, length(q * vec2(1.0 / 0.26, 1.0 / 1.0)))
                   * smoothstep(-0.72 - aa, -0.72 + aa, q.y);
        float nose = step(0.55, q.y);
        // Fins: a triangle each side near the tail.
        vec2 f = vec2(abs(q.x), q.y);
        float fin = step(0.15, f.x) * step(f.x, 0.48) * step(-0.95, f.y)
                  * step(f.y, -0.25 - (f.x - 0.15) * 1.6);
        // Porthole: a blue window with a light rim.
        float wd = length(q - vec2(0.0, 0.18));
        float window = smoothstep(0.11 + aa, 0.11 - aa, wd);
        float rim = smoothstep(0.15 + aa, 0.15 - aa, wd) - window;

        float shade = 0.70 + 0.30 * clamp(-q.x / 0.26, -1.0, 1.0);   // lit from the left
        vec3 hull = mix(vec3(0.92, 0.93, 0.96), vec3(1.0, 0.35, 0.30), nose) * shade;
        color = mix(color, hull, body);
        color += vec3(1.0, 0.35, 0.30) * fin * (1.0 - body) * 0.9;
        color = mix(color, vec3(0.35, 0.70, 1.0), window);
        color = mix(color, vec3(0.75, 0.78, 0.85), rim * body);

        // Flame: a flickering teardrop under the tail, yellow core, orange edge.
        float flick = 0.75 + 0.15 * sin(iTime * 31.0) + 0.10 * sin(iTime * 47.0 + 1.3);
        vec2 fq = q - vec2(0.0, -0.75);
        float len = 1.0 * flick;
        float t = clamp(-fq.y / len, 0.0, 1.0);
        float width = 0.20 * (1.0 - t) * sqrt(t * 4.0 + 0.1);
        float flame = step(fq.y, 0.0) * smoothstep(width + aa, width * 0.3, abs(fq.x)) * step(t, 0.99);
        vec3 fire = mix(vec3(1.0, 0.95, 0.60), vec3(1.0, 0.45, 0.10), t);
        color += fire * flame * (1.0 - body) * 1.2
               + vec3(1.0, 0.6, 0.2) * 0.25 * exp(-length(fq * vec2(2.5, 1.2)) * 3.0);   // glow
    }

    color = min(color, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
