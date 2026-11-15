// crystals — faceted crystals grow from the bottom corners and shimmer with travelling highlights.
// zh: 水晶
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const int   PER_SIDE  = 6;      // crystals in each bottom corner
const float GROW      = 6.0;    // seconds to grow in when the effect starts

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// One crystal in its own frame: x across, y along it from the base (y = 0).
// A six-sided column seen from the side: three faces with a pointed tip.
vec3 crystal(vec2 q, float w, float len, float shine, vec3 col) {
    float tipLen = w * 1.7;
    float taper = clamp((len - q.y) / tipLen, 0.0, 1.0);    // narrows to the point
    float hw = w * taper;
    if (q.y < 0.0 || abs(q.x) > hw + 0.004) return vec3(0.0);

    float xf = q.x / max(hw, 1e-4);                       // -1..1 across
    float face = xf < -0.33 ? 0.35 : (xf < 0.33 ? 0.75 : 0.5);
    float inside = smoothstep(hw + 0.002, hw - 0.001, abs(q.x));

    // Edges: the outline and the two lines between faces (they meet at the tip).
    float px = 1.5 / iResolution.y;
    float edge = smoothstep(px, 0.0, abs(abs(q.x) - hw))
               + 0.7 * smoothstep(px, 0.0, abs(abs(q.x) - hw * 0.33));

    // A slanted band of light sliding up the crystal.
    float band = exp(-pow((q.y / len - shine - xf * 0.12) * 9.0, 2.0));

    return col * (inside * (face * 0.35 + band * 0.55) + edge * 0.55);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 glow = vec3(0.0);
    for (int i = 0; i < PER_SIDE * 2; i++) {
        float fi = float(i);
        float side = i < PER_SIDE ? 1.0 : -1.0;              // +1 left corner, -1 right
        float k = mod(fi, float(PER_SIDE)) / float(PER_SIDE - 1);   // 0 = tallest, upright

        // Clustered at the corner, leaning out toward the middle of the screen.
        float h = hash1(fi * 7.3 + 1.0);
        vec2 root = vec2(0.03 + 0.10 * k + 0.03 * h, -0.02);
        if (side < 0.0) root.x = aspect - root.x;
        float ang = side * (0.08 + 1.0 * k * (0.8 + 0.3 * h));
        vec2 dir = vec2(sin(ang), cos(ang));
        float len = mix(0.30, 0.10, k) * (0.85 + 0.3 * hash1(fi * 3.1 + 2.0));
        float w = len * 0.16;

        // Grow in once, one after another.
        len *= smoothstep(0.0, 1.0, (iTime - k * 1.2) / GROW);
        if (len < 0.002) continue;

        vec2 d = p - root;
        if (dot(d, d) > (len + 0.03) * (len + 0.03)) continue;   // far away: skip
        vec2 q = vec2(dot(d, vec2(dir.y, -dir.x)), dot(d, dir));

        float shine = fract(iTime * 0.10 + h) * 1.6 - 0.3;
        vec3 col = mix(vec3(0.65, 0.48, 1.0), vec3(0.45, 0.90, 1.0), hash1(fi * 5.7 + 3.0));
        glow += crystal(q, w, len, shine, col);

        // Now and then a glint flashes at the tip.
        vec2 td = p - (root + dir * len);
        float glint = pow(max(0.0, sin(iTime * 0.7 + fi * 2.3)), 30.0);
        glow += vec3(1.0) * glint * (0.00004 / (dot(td, td) + 0.00003));
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
