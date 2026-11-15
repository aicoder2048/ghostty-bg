// jellyfish — glowing jellyfish drift upward, bells pulsing, tentacles trailing.
// zh: 水母
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.50;   // overall strength (0 = off)
const int   COUNT     = 5;      // number of jellyfish
const int   TENTACLES = 5;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// q is in jellyfish units (the bell is about 2 wide, 0.85 tall, sitting on y = 0);
// pulse runs from -1 (bell tall and narrow) to 1 (bell wide and flat).
float jellyfish(vec2 q, float pulse, float wave) {
    float wide = 1.0 + 0.18 * pulse;
    vec2 b = vec2(q.x / wide, q.y / (0.85 - 0.12 * pulse));
    float r = length(b);
    float above = step(0.0, q.y);
    float bell = above * (smoothstep(1.0, 0.9, r) * 0.35                    // soft fill
                        + smoothstep(0.10, 0.0, abs(r - 0.93)) * 0.8);      // bright rim

    float tentacles = 0.0;
    for (int k = 0; k < TENTACLES; k++) {
        float fk = float(k);
        float x0 = (fk - float(TENTACLES - 1) * 0.5) * 0.38 * wide;
        float depth = clamp(-q.y, 0.0, 1.0);                                // sway more lower down
        float x = x0 + 0.10 * sin(q.y * 5.0 + wave + fk * 1.3) * depth;
        float len = 2.2 + 0.5 * sin(fk * 2.1);
        float fade = (1.0 - above) * smoothstep(-len, -0.1, q.y);           // thin out at the end
        tentacles += smoothstep(0.07, 0.0, abs(q.x - x)) * fade;
    }
    return bell + tentacles * 0.45;
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
    vec2 p = vec2(uv.x * aspect, uv.y);

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float size = mix(0.045, 0.075, c);
        float phase = fi * 2.4;
        float pulse = sin(iTime * (1.3 + 0.5 * a) + phase);

        // Rise slowly, wrap around from top to bottom, sway a little sideways.
        float x = (0.12 + 0.76 * hash1(fi * 5.17 + 4.0)) * aspect + 0.02 * sin(iTime * 0.3 + phase);
        float y = mod(b * 1.6 + iTime * (0.018 + 0.014 * c), 1.6) - 0.25;

        vec2 q = (p - vec2(x, y)) / size;
        vec3 color = mix(vec3(0.40, 0.90, 1.0), vec3(0.90, 0.55, 1.0), a);
        rgb = blend(rgb, color, jellyfish(q, pulse, iTime * 2.5 + phase) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
