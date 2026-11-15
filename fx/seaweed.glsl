// seaweed — kelp fronds rise from the bottom edge and sway with the current.
// zh: 海草
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.45;   // overall strength (0 = off)
const int   COUNT     = 14;     // number of fronds

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
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

    float aa = 1.5 / iResolution.y;
    // One slow current pushes every frond the same way; each adds its own wobble.
    float current = 0.05 * sin(iTime * 0.21) + 0.02 * sin(iTime * 0.37 + 1.0);

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float height = mix(0.20, 0.55, b);
        if (p.y > height + 0.02) continue;                         // cheap early out above the tip

        float far = step(0.5, c);                                  // half the fronds sit further back
        float x0 = (fi + 0.2 + 0.6 * a) / float(COUNT) * aspect;
        float yn = clamp(p.y / height, 0.0, 1.0);                  // 0 at the root, 1 at the tip
        float phase = fi * 2.3;

        // The root is anchored; the tip moves most. The wave travels up the stem.
        float sway = (0.040 * sin(iTime * 0.8 + phase - p.y * 5.0)
                    + 0.012 * sin(iTime * 1.5 + phase * 1.7 - p.y * 11.0)) * pow(yn, 1.3)
                   + current * yn * yn;
        float dx = p.x - x0 - sway;

        // The stem tapers to the tip; leaf blades bulge out, alternating sides.
        float w0 = mix(0.009, 0.006, far);
        float side = dx > 0.0 ? 1.0 : -1.0;
        float leaf = max(0.0, sin(p.y * 32.0 / (0.6 + height) + phase + side * 1.57));
        float w = w0 * (1.0 - 0.85 * yn) * (1.0 + 2.4 * leaf * leaf * leaf);

        float frond = smoothstep(w + aa, w - aa, abs(dx)) * smoothstep(height + 0.01, height - 0.02, p.y);
        float rib = smoothstep(0.0025, 0.0, abs(dx)) * (1.0 - yn);  // darker midrib
        frond *= (1.0 - 0.45 * rib) * mix(1.0, 0.55, far) * mix(1.0, 0.7, yn);

        vec3 color = mix(vec3(0.35, 0.85, 0.45), vec3(0.70, 0.85, 0.35), a);
        rgb = blend(rgb, color, frond * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
