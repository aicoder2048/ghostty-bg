// ripples — rings spread out and fade, like the first drops of rain on a pond.
// zh: 涟漪
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const int   LAYERS    = 2;
const float SQUASH    = 2.2;    // rings look like flat ovals, as if seen at an angle

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, 1.0 - uv.y);

    float rings = 0.0;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        // One drop per cell at a time; cells are wide and low to match the squash.
        vec2 g = (p0 + fi * 0.37) * vec2(2.4 + fi, (2.4 + fi) * SQUASH);
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        // Every cell runs its own clock, so the drops do not land together.
        float period = 3.0 + 3.0 * hash(id + fi * 4.0);
        float clock = iTime / period + hash(id + 1.9);
        float drop = floor(clock);              // which drop this is
        float t = fract(clock);                 // 0 -> 1 over its life

        // Only some drops show, and each lands somewhere new in its cell.
        float present = step(0.45, hash(id + drop * 0.73 + 3.3));
        vec2 centre = (vec2(hash(id + drop + 5.1), hash(id + drop + 8.7)) - 0.5) * 0.24;
        float d = length(f - centre);

        float radius = t * 0.36;                // stays inside the cell
        float fade = (1.0 - t) * (1.0 - t);
        float ring = smoothstep(0.022, 0.0, abs(d - radius))
                   + smoothstep(0.016, 0.0, abs(d - radius * 0.55)) * 0.5;   // a second, inner ring

        rings += present * ring * fade * (1.0 - fi * 0.3);
    }

    vec3 color = vec3(0.75, 0.90, 1.0) * min(rings, 1.0) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
