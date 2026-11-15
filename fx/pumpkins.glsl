// pumpkins — a few jack-o'-lanterns sit along the bottom, carved faces flickering with candlelight.
// zh: 南瓜灯
// group: festival
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   COUNT     = 4;      // number of pumpkins

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Rough signed distance to an axis-aligned ellipse (good enough for outlines).
float sdEllipse(vec2 p, vec2 r) {
    return (length(p / r) - 1.0) * min(r.x, r.y);
}

// Signed distance to a triangle a-b-c (by Inigo Quilez).
float sdTri(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 e0 = b - a, e1 = c - b, e2 = a - c;
    vec2 v0 = p - a, v1 = p - b, v2 = p - c;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// The carved holes in pumpkin units: two triangle eyes, a nose and a toothy grin.
float sdFace(vec2 q) {
    vec2 m = vec2(abs(q.x), q.y);                                   // mirror the eyes
    float eyes = sdTri(m, vec2(0.18, 0.05), vec2(0.50, 0.05), vec2(0.34, 0.32));
    float nose = sdTri(q, vec2(-0.09, -0.15), vec2(0.09, -0.15), vec2(0.0, 0.0));

    // Grin: between two upward curves, so the corners turn up.
    float top = -0.28 + 0.70 * q.x * q.x;
    float bot = -0.56 + 1.30 * q.x * q.x;
    float mouth = max(q.y - top, bot - q.y) * 0.8;
    // Teeth: one hangs from the top in the middle, two stand up from the bottom.
    mouth = max(mouth, -max(abs(q.x) - 0.07, -(q.y + 0.40)));       // top tooth
    mouth = max(mouth, -max(abs(abs(q.x) - 0.25) - 0.06, q.y + 0.44)); // bottom teeth

    return min(min(eyes, nose), mouth);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // The pumpkins sit near the bottom; skip the rest of the screen.
    if (p.y > 0.32) {
        fragColor = base;
        return;
    }

    vec3 col = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float size = mix(0.065, 0.085, hash1(fi * 3.3 + 1.0));
        vec2 c = vec2((0.14 + 0.24 * fi + 0.04 * (hash1(fi * 7.7) - 0.5)) * aspect, size * 0.95 + 0.02);
        vec2 q = (p - c) / size;
        if (dot(q, q) > 9.0) continue;

        // Candle flicker: two fast wobbles and a slower one, so it never looks periodic.
        float flick = 0.70 + 0.15 * sin(iTime * 11.0 + fi * 2.0) + 0.10 * sin(iTime * 17.3 + fi * 5.0)
                    + 0.05 * sin(iTime * 2.3 + fi);

        // Body: three overlapping lobes; their outlines read as the pumpkin ribs.
        float mid  = sdEllipse(q, vec2(0.55, 0.85));
        float side = sdEllipse(vec2(abs(q.x) - 0.48, q.y), vec2(0.62, 0.80));
        float body = min(mid, side);
        float outline = smoothstep(0.045, 0.0, abs(body));
        float ribs = smoothstep(0.035, 0.0, abs(mid)) * step(body, 0.0) * 0.45;
        float fill = smoothstep(0.02, -0.02, body);

        // Stem: a short stubby rectangle on top.
        vec2 s = q - vec2(0.04, 0.92);
        float stem = smoothstep(0.03, 0.0, max(abs(s.x + s.y * 0.2) - 0.08, abs(s.y) - 0.13));

        float face = sdFace(q);
        float holes = smoothstep(0.03, -0.03, face);
        float faceGlow = 0.02 / (max(face, 0.0) * max(face, 0.0) * 6.0 + 0.02) * step(body, 0.0) * 0.25;

        vec3 orange = vec3(1.0, 0.45, 0.08);
        vec3 candle = vec3(1.0, 0.72, 0.28);
        col += orange * (outline * 0.9 + ribs + fill * 0.22);
        col += vec3(0.35, 0.55, 0.15) * stem * 0.7;
        col += candle * (holes * 1.1 + faceGlow) * flick;
        // A warm pool of light on the ground and around the pumpkin.
        col += orange * 0.06 / (dot(q * vec2(0.6, 1.0), q * vec2(0.6, 1.0)) + 0.6) * flick;
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
