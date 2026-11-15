// wind — thin curved wisps of air sweeping sideways across, appearing and fading.
// zh: 风
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.40;   // overall brightness (0 = off)
const int   COUNT     = 8;      // wisps on screen at most

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

    float px = 1.0 / iResolution.y;
    float wisps = 0.0;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float period = 5.0 + 4.0 * hash1(fi * 7.3);
        float lt = iTime / period + hash1(fi * 3.1);
        float cycle = floor(lt);
        float s = fract(lt);                          // 0..1 through this wisp's life
        float seed = fi * 11.0 + cycle * 5.7;         // a new path each time round

        // Mostly in the lower two-thirds, away from the text at the top.
        float y0 = 0.10 + 0.55 * hash1(seed + 1.0);
        float amp = 0.02 + 0.04 * hash1(seed + 2.0);
        float freq = 3.0 + 4.0 * hash1(seed + 3.0);
        float len = 0.35 + 0.35 * hash1(seed + 4.0);

        // The wisp's head travels left to right; the tail trails behind it.
        float head = mix(-0.2, aspect + len + 0.2, s);
        float along = (head - p.x) / len;            // 0 at the head, 1 at the tail
        if (along < 0.0 || along > 1.0) continue;

        // The path is a gentle wave that also slides, so it looks like it flows.
        float ph = p.x * freq + hash1(seed + 5.0) * 6.2831;
        float y = y0 + amp * sin(ph) + 0.6 * amp * sin(ph * 2.3 + 1.0);
        float dy = amp * freq * (cos(ph) + 1.38 * cos(ph * 2.3 + 1.0));
        float d = abs(p.y - y) / sqrt(1.0 + dy * dy);

        // Two hair-thin strands side by side read as a streamline.
        float d2 = abs(p.y - y - 0.012) / sqrt(1.0 + dy * dy);
        float line = smoothstep(1.4 * px, 0.0, d) + 0.5 * smoothstep(1.2 * px, 0.0, d2)
                   + 0.25 * smoothstep(5.0 * px, 0.0, d);

        float taper = sin(3.1416 * along) * (1.0 - 0.5 * along);  // thin ends, bright front
        float life = sin(3.1416 * s);                              // fade in, fade out
        wisps += line * taper * life;
    }

    vec3 color = vec3(0.85, 0.92, 1.0) * min(wisps, 1.0);
    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
