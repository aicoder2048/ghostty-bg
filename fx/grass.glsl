// grass — blades of grass along the bottom edge sway in waves of wind.
// zh: 草浪
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.45;   // overall strength (0 = off)
const int   LAYERS    = 3;      // back, middle, front
const float HEIGHT    = 0.16;   // tallest blades, in window-heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// The wind: waves that roll from left to right, plus a steady lean.
float wind(float x) {
    return 0.25 + 0.45 * sin(x * 2.2 - iTime * 1.3) + 0.20 * sin(x * 5.1 - iTime * 2.1 + 1.0);
}

// One blade rooted at x0: a thin tapering shape that bends more toward the tip.
float blade(vec2 p, float x0, float h, float w, float lean) {
    float t = p.y / h;                                  // 0 at the root, 1 at the tip
    if (t < 0.0 || t > 1.0) return 0.0;
    float x = x0 + lean * h * 0.6 * t * t;
    float half_w = w * (1.0 - t);
    return smoothstep(0.0015, 0.0, abs(p.x - x) - half_w);
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

    vec3 color = vec3(0.0);
    float shape = 0.0;
    if (p.y < HEIGHT * 1.1) {                           // nothing to do above the grass
        for (int l = 0; l < LAYERS; l++) {
            float fl = float(l);
            float spacing = 0.028 - fl * 0.006;         // front layer: denser
            float cell = floor(p.x / spacing);
            float layer = 0.0;
            // A bent blade can lean into the next cell, so check neighbours too.
            for (int k = -2; k <= 1; k++) {
                float id = cell + float(k);
                float seed = id * 1.37 + fl * 31.0;
                float x0 = (id + hash1(seed)) * spacing;
                float h = HEIGHT * mix(0.35, 1.0, hash1(seed + 2.0)) * (0.6 + 0.2 * fl);
                float w = mix(0.003, 0.006, hash1(seed + 4.0));
                float lean = wind(x0 + fl * 0.3) * mix(0.7, 1.3, hash1(seed + 6.0));
                layer = max(layer, blade(p, x0, h, w, lean));
            }
            // Back layers are dimmer and bluer: that reads as depth.
            vec3 tone = mix(vec3(0.30, 0.50, 0.45), vec3(0.45, 0.75, 0.35), fl * 0.5);
            float strength = 0.45 + fl * 0.28;
            color = mix(color, tone, layer);
            shape = max(shape, layer * strength);
        }
    }

    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
