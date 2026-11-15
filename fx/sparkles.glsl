// sparkles — glittering four-point star sparkles twinkle in and out, some drifting upward.
// zh: 魔法火花
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const int   COUNT     = 24;     // number of sparkles alive at any moment
const float PI        = 3.14159265;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// A four-point star: a small round core plus two thin crossing rays that
// taper to a point. d is in star units (the rays are 1 long).
float star(vec2 d) {
    vec2 a = abs(d);
    float core = 0.02 / (dot(d, d) + 0.02);
    vec2 len = max(1.0 - a, 0.0);                       // how much ray is left
    float rx = len.x * len.x * exp(-a.y * 12.0 / (len.x + 0.15));
    float ry = len.y * len.y * exp(-a.x * 12.0 / (len.y + 0.15));
    return core * 0.7 + rx + ry;
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
        // Each slot lives through short cycles; every cycle picks a new spot.
        float period = 2.5 + 3.0 * hash1(fi * 3.17 + 0.5);
        float tt = iTime / period + hash1(fi * 7.71 + 1.0);
        float cyc = floor(tt);
        float life = fract(tt);
        float seed = fi * 13.1 + cyc * 7.31;

        vec2 pos = vec2(hash1(seed) * aspect, 0.03 + 0.94 * hash1(seed + 1.7));
        // About a third of them float upward while they shine.
        pos.y += step(0.65, hash1(seed + 2.3)) * life * 0.12;

        float env = sin(life * PI);
        env *= env;                                        // quick swell, quick fade
        float twinkle = 0.6 + 0.4 * sin(iTime * 11.0 + fi * 3.7);
        float size = mix(0.025, 0.06, hash1(seed + 3.9)) * (0.5 + 0.5 * env);

        vec2 d = p - pos;
        if (dot(d, d) > size * size * 4.0) continue;      // far away: skip the math
        float ang = life * 0.8 + fi;                       // a slow spin while alive
        d = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * d / size;

        vec3 col = mix(vec3(1.0, 0.86, 0.50), vec3(0.75, 0.85, 1.0), hash1(seed + 5.1));
        glow += col * star(d) * env * twinkle;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
