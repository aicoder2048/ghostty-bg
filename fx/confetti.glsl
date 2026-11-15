// confetti — bright paper strips flutter down, flipping over as they fall.
// zh: 彩纸
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const int   COUNT     = 16;     // number of paper pieces

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 palette(float h) {
    if (h < 0.2) return vec3(1.0, 0.35, 0.40);    // red
    if (h < 0.4) return vec3(1.0, 0.80, 0.25);    // yellow
    if (h < 0.6) return vec3(0.35, 0.85, 0.50);   // green
    if (h < 0.8) return vec3(0.40, 0.65, 1.0);    // blue
    return vec3(0.85, 0.45, 1.0);                 // purple
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
    float px = 1.5 / iResolution.y;                  // about one pixel, for soft edges

    vec3 rgb = base.rgb;
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float c = hash1(fi * 39.425 + 3.0);

        float speed = mix(0.05, 0.09, c);
        float y = 1.1 - mod(b * 1.3 + iTime * speed, 1.3);
        float x = a * aspect + 0.04 * sin(iTime * (0.6 + c) + fi * 2.7);   // drift side to side

        vec2 q = p - vec2(x, y);
        if (dot(q, q) > 0.0016) continue;            // cheap reject: far from this piece

        float ang = iTime * mix(0.8, 2.0, a) * (b > 0.5 ? 1.0 : -1.0) + fi;
        q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * q;

        // Flipping: the piece turns edge-on, so its width swings through zero.
        float flip = cos(iTime * mix(3.0, 6.0, b) + fi * 1.9);
        vec2 hs = vec2(0.015 * max(abs(flip), 0.08), 0.0075);
        vec2 d = abs(q) - hs;
        float box = max(d.x, d.y);
        float cover = smoothstep(px, -px, box);

        // The back face is a little darker, which sells the flip.
        vec3 color = palette(hash1(fi * 5.31 + 7.0)) * (flip > 0.0 ? 1.0 : 0.65);
        rgb = blend(rgb, color, cover * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
