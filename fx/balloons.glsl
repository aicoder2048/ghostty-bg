// balloons — shiny balloons on wavy strings rise and bob across the screen.
// zh: 气球
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.55;   // overall strength (0 = off)
const int   COUNT     = 8;      // number of balloons

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

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float size = mix(0.030, 0.048, c);
        float speed = mix(0.025, 0.045, c);
        float y = mod(b * 1.6 + iTime * speed, 1.6) - 0.3;
        float x = (0.08 + 0.86 * a) * aspect + 0.02 * sin(iTime * 0.6 + fi * 1.9);
        y += 0.008 * sin(iTime * 1.3 + fi * 2.2);                 // bob

        // Balloon units: body radius about 1, string hanging down to y = -4.
        vec2 q = (p - vec2(x, y)) / size;
        if (q.y > 1.6 || q.y < -4.5 || abs(q.x) > 1.6) continue;
        float tilt = 0.10 * sin(iTime * 0.6 + fi * 1.9);
        q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;

        // Body: an egg, a bit narrower toward the bottom.
        vec2 e = vec2(q.x / (0.86 - 0.08 * q.y), q.y);
        float r = length(e);
        float body = smoothstep(1.0, 0.92, r);

        // Knot: a tiny triangle just below the body.
        vec2 k = q - vec2(0.0, -1.0);
        float knot = step(-0.18, k.y) * step(k.y, 0.02) * step(abs(k.x), 0.04 + (0.02 - k.y) * 0.5);

        // String: a thin wave that sways more toward its free end.
        float sy = clamp(q.y, -4.2, -1.15);
        float sx = 0.12 * sin(sy * 3.0 + iTime * 2.0 + fi) * (-1.15 - sy) * 0.4;
        float string = smoothstep(0.07, 0.0, abs(q.x - sx)) * step(-4.2, q.y) * step(q.y, -1.15);

        vec3 tint = 0.5 + 0.5 * cos(6.2831 * (hash1(fi * 3.7) + vec3(0.0, 0.33, 0.67)));
        tint = mix(tint, vec3(1.0, 0.3, 0.35), 0.2);
        // Shade toward the lower right; a soft white highlight upper left.
        float shade = mix(1.0, 0.55, smoothstep(-0.3, 1.0, dot(e, vec2(0.6, -0.8))));
        float shine = smoothstep(0.32, 0.05, length((q - vec2(-0.35, 0.42)) * vec2(1.0, 0.7)));

        rgb = blend(rgb, vec3(0.75), string * 0.45 * INTENSITY);
        rgb = blend(rgb, tint * shade, max(body * 0.8, knot * 0.8) * INTENSITY);
        rgb = blend(rgb, vec3(1.0), shine * body * 0.6 * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
