// portal — a swirling magic portal in the lower-right corner, drawing sparks in.
// zh: 传送门
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const float RADIUS    = 0.19;   // ring radius in screen heights
const int   SPARKS    = 16;     // sparks spiralling in
const float PI        = 3.14159265;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Lower-right corner, far from where text starts (top left).
    vec2 c = vec2(aspect - 0.30, 0.27);
    vec2 d = p - c;
    float x = length(d) / RADIUS;                     // 1 on the ring
    float a = atan(d.y, d.x);
    float t = iTime;

    // The ring: a bright band with light running around it.
    float ring = exp(-pow((x - 1.0) * 12.0, 2.0)) * (0.7 + 0.3 * sin(a * 6.0 - t * 3.0));
    float halo = 0.012 / ((x - 1.0) * (x - 1.0) + 0.012) * 0.25;

    // Spiral arms inside; the log makes them wind tighter toward the centre.
    // The pattern rotates clockwise (angle falls as time grows).
    float arms = 0.5 + 0.5 * sin(a * 4.0 + log(x + 0.01) * 5.0 + t * 2.2);
    arms = pow(arms, 3.0) * smoothstep(1.0, 0.65, x) * smoothstep(0.05, 0.45, x);
    float arms2 = 0.5 + 0.5 * sin(-a * 3.0 + log(x + 0.01) * 7.0 + t * 1.3);
    arms2 = pow(arms2, 4.0) * smoothstep(0.95, 0.5, x) * smoothstep(0.1, 0.5, x) * 0.5;
    float core = smoothstep(0.5, 0.0, x) * 0.25;

    vec3 violet = vec3(0.70, 0.40, 1.0);
    vec3 cyan = vec3(0.40, 0.90, 1.0);
    vec3 glow = mix(cyan, violet, smoothstep(0.3, 1.0, x)) * (arms * 0.8 + arms2 + core)
              + mix(violet, vec3(0.9, 0.85, 1.0), ring) * (ring + halo);

    // Sparks: start outside, spiral in clockwise, flare and vanish at the ring.
    for (int i = 0; i < SPARKS; i++) {
        float fi = float(i);
        float life = fract(t * (0.25 + 0.15 * hash1(fi * 3.3)) + hash1(fi * 7.7));
        float r = RADIUS * mix(2.3, 0.95, life * life);
        float ang = hash1(fi * 5.1) * 2.0 * PI - life * 2.5;
        vec2 sp = c + r * vec2(cos(ang), sin(ang));
        vec2 sd = p - sp;
        float bright = smoothstep(0.0, 0.3, life) * smoothstep(1.0, 0.9, life);
        glow += mix(vec3(1.0, 0.9, 0.7), cyan, hash1(fi)) * (0.000015 / (dot(sd, sd) + 0.000008)) * bright;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
