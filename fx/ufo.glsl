// ufo — a flying saucer glides in, hovers with a wobble and a soft tractor beam, then zips off.
// zh: 飞碟
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const float PERIOD    = 24.0;   // seconds between visits
const float SIZE      = 0.075;  // half the saucer width, in screen heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // One visit per period: glide in (0-4 s), hover (4-16 s), zip off (16-17.5 s), gone.
    float n = floor(iTime / PERIOD);
    float s = mod(iTime, PERIOD);
    vec2 hover = vec2(mix(0.55, 0.85, hash1(n * 4.1 + 1.0)) * aspect,
                      mix(0.55, 0.72, hash1(n * 2.3 + 2.0)));
    float side = hash1(n * 7.7 + 3.0) > 0.5 ? 1.0 : -1.0;     // enter from the right or left

    float glide = smoothstep(0.0, 4.0, s);                     // eases in and settles
    vec2 start = hover + vec2(side * (aspect + 0.3), 0.12);
    float zip = max(s - 16.0, 0.0);
    vec2 pos = mix(start, hover, glide)
             + vec2(0.0, 0.012 * sin(iTime * 1.3))                    // gentle bob
             + vec2(-side * 0.9, 0.55) * zip * zip * 2.2;            // accelerate away
    float wobble = 0.10 * sin(iTime * 1.7) + (1.0 - glide) * 0.25 * side;   // banks while gliding in

    // Saucer units: the hull is 2 wide.
    vec2 q = rot(p - pos, -wobble) / SIZE;
    float aa = 1.5 / (iResolution.y * SIZE);

    float hull = smoothstep(1.0 + aa, 1.0 - aa, length(q * vec2(1.0, 4.2)));
    float dome = smoothstep(0.45 + aa, 0.45 - aa, length((q - vec2(0.0, 0.10)) * vec2(1.0, 1.15)))
               * step(0.08, q.y);
    float skirt = smoothstep(0.55 + aa, 0.55 - aa, length((q + vec2(0.0, 0.16)) * vec2(1.0, 3.2)))
                * step(q.y, -0.10);
    float shade = 0.65 + 0.45 * clamp(q.y * 4.0, -1.0, 1.0);    // brighter on top

    vec3 color = vec3(0.72, 0.78, 0.86) * max(hull, skirt * 0.8) * shade
               + vec3(0.45, 0.90, 1.0) * dome * (0.55 + 0.35 * (q.y - 0.1)) * (1.0 - hull * 0.5);

    // Rim lights chasing round.
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 l = vec2(-0.64 + fi * 0.32, -0.02);
        float on = 0.35 + 0.65 * step(0.5, fract(iTime * 1.5 - fi * 0.2));
        vec3 lc = mod(fi, 2.0) < 0.5 ? vec3(1.0, 0.85, 0.30) : vec3(1.0, 0.35, 0.30);
        color += lc * on * smoothstep(0.10, 0.04, length(q - l));
    }

    // Tractor beam: fades on and off while hovering, a cone widening downward.
    float beamOn = smoothstep(6.0, 7.5, s) * smoothstep(13.5, 12.0, s);
    vec2 b = (p - pos) / SIZE;                                    // beam stays vertical
    float down = -b.y - 0.2;
    float halfW = 0.45 + down * 0.35;
    float beam = step(0.0, down) * smoothstep(halfW, halfW * 0.6, abs(b.x))
               * exp(-down * 0.35) * (0.8 + 0.2 * sin(down * 6.0 - iTime * 4.0));
    color += vec3(0.55, 1.0, 0.70) * beam * beamOn * 0.30 * (1.0 - hull);

    // Only show the visit itself; between visits the sky is empty.
    color *= step(s, 19.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
