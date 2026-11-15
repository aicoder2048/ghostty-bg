// embers — glowing sparks rise from the bottom like from a campfire, flickering out as they climb.
// zh: 火星
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const int   COUNT     = 16;     // number of sparks

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

    vec3 glow = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);

        // Each spark lives for one cycle: born at the bottom, gone near the top.
        float speed = 0.06 + 0.06 * b;
        float cycle = iTime * speed + a * 7.0;
        float life = fract(cycle);
        float gen = floor(cycle);                       // new spark, new place

        // Sparks start near the bottom-middle-right and spread as they climb.
        float x0 = (0.25 + 0.7 * hash1(fi * 3.1 + gen * 17.3)) * aspect;
        float rise = life * (0.55 + 0.35 * hash1(fi + gen * 5.7));
        float drift = 0.10 * life * (hash1(fi * 9.2 + gen) - 0.4);
        float wobble = 0.025 * sin(iTime * (2.0 + 2.0 * a) + fi * 3.0) * life;
        vec2 pos = vec2(x0 + drift + wobble, -0.02 + rise);

        // Bright when young, fading out; with a quick fire-like flicker.
        float fade = (1.0 - life) * smoothstep(0.0, 0.05, life);
        float flicker = 0.65 + 0.35 * sin(iTime * (11.0 + 7.0 * a) + fi * 5.0)
                             * sin(iTime * (7.0 + 5.0 * b) + fi);

        // A short streak below the spark: it moves fast enough to smear a little.
        // It fades along the streak so the head stays the brightest point.
        vec2 tail = vec2(-wobble * 0.3, -0.016);
        vec2 pa = p - pos;
        float h = clamp(dot(pa, tail) / dot(tail, tail), 0.0, 1.0);
        float d = length(pa - tail * h);
        float g = 0.00005 / (d * d + 0.000015) * (1.0 - 0.85 * h)   // hot core
                + 0.0004 / (length(pa) * length(pa) * 400.0 + 0.004) * 0.15;  // wide soft halo
        vec3 hot = mix(vec3(1.0, 0.25, 0.05), vec3(1.0, 0.72, 0.30), fade);  // cools to red
        glow += hot * g * fade * flicker;
    }

    // A faint warm glow along the bottom edge, where the fire would be.
    float fire = smoothstep(0.12, 0.0, p.y) * (0.75 + 0.25 * sin(iTime * 3.1) * sin(iTime * 1.7))
               * smoothstep(0.0, 0.5, uv.x);
    glow += vec3(1.0, 0.35, 0.08) * fire * 0.35;

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
