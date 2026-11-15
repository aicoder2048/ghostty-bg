// hearts — soft pink hearts float upward, swaying and pulsing, fading near the top.
// zh: 爱心
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const int   COUNT     = 10;     // number of hearts

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float dot2(vec2 v) { return dot(v, v); }

// Signed distance to a heart: tip at (0,0), top lobes near y = 1 (by Inigo Quilez).
float sdHeart(vec2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0)
        return sqrt(dot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
    return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 col = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float speed = mix(0.025, 0.05, c);
        float y = mod(b * 1.3 + iTime * speed, 1.3) - 0.15;
        float x = a * aspect + 0.035 * sin(iTime * 0.7 + fi * 2.3);
        float pulse = 1.0 + 0.08 * sin(iTime * 3.0 + fi * 1.7);      // a gentle heartbeat
        float size = mix(0.030, 0.052, c) * pulse;

        vec2 q = (p - vec2(x, y)) / size;
        if (dot(q, q) > 12.0) continue;              // too far to matter
        float tilt = 0.25 * sin(iTime * 0.7 + fi * 2.3);              // lean into the sway
        q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;
        q.y += 0.55;                                  // centre the heart on its position

        float d = sdHeart(q);
        float fill = smoothstep(0.04, -0.04, d);
        float glow = 0.03 / (max(d, 0.0) * max(d, 0.0) + 0.06) * 0.25;
        float fade = smoothstep(1.15, 0.7, y) * smoothstep(-0.15, 0.0, y);

        vec3 tint = mix(vec3(1.0, 0.35, 0.50), vec3(1.0, 0.60, 0.75), hash1(fi * 4.1));
        // A lighter spot on the upper lobe so each heart looks soft and round.
        float shine = smoothstep(0.35, 0.0, length(q - vec2(-0.28, 0.78))) * 0.5;
        col += (tint * (fill * 0.75 + glow) + vec3(1.0) * shine * fill) * fade;
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
