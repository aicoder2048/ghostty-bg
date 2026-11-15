// fairies — a few tiny glowing fairies with fluttering wings flit about, leaving sparkly trails.
// zh: 小精灵
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   COUNT     = 4;      // number of fairies
const int   TRAIL     = 5;      // sparkles left behind each one
const float SIZE      = 0.028;  // wing size in screen heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Where fairy fi is at time t: a slow wide loop plus a quicker wiggle,
// so the flight path keeps curving.
vec2 path(float t, float fi, float aspect) {
    vec2 home = vec2((0.25 + 0.5 * hash1(fi * 12.9898 + 1.0)) * aspect,
                     0.30 + 0.40 * hash1(fi * 78.233 + 2.0));
    return home + vec2(0.30 * aspect * sin(t * 0.21 + fi * 2.0) + 0.07 * sin(t * 0.93 + fi),
                       0.20 * sin(t * 0.33 + fi * 4.0) + 0.06 * sin(t * 1.37 + fi * 1.7));
}

// A soft-edged ellipse with a brighter rim: one translucent wing.
float wing(vec2 q, vec2 c, vec2 r) {
    float e = length((q - c) / r);
    return smoothstep(1.0, 0.8, e) * 0.25 + smoothstep(0.2, 0.0, abs(e - 0.9)) * 0.45;
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
        vec3 col = vec3(1.0, 0.65, 0.85);                           // pink, mint, gold, lilac
        if (i == 1) col = vec3(0.55, 1.0, 0.80);
        if (i == 2) col = vec3(1.0, 0.88, 0.50);
        if (i == 3) col = vec3(0.75, 0.65, 1.0);

        vec2 pos = path(iTime, fi, aspect);
        vec2 d = p - pos;

        // Glowing body: bright core, soft halo.
        glow += col * (0.00008 / (dot(d, d) + 0.00005));
        glow += vec3(1.0) * (0.000012 / (dot(d, d) + 0.000008));

        // Wings: two pairs, mirrored, beating fast (width shrinks as they fold).
        vec2 q = d / SIZE;
        if (dot(q, q) < 9.0) {
            float flap = 0.35 + 0.65 * abs(sin(iTime * 16.0 + fi * 2.0));
            vec2 m = vec2(abs(q.x), q.y);
            float w = wing(m, vec2(0.85 * flap, 0.55), vec2(0.85 * flap, 0.55))
                    + wing(m, vec2(0.55 * flap, -0.35), vec2(0.55 * flap, 0.35));
            glow += mix(col, vec3(1.0), 0.5) * w;
        }

        // Trail: little sparkles at earlier positions, sinking and fading.
        for (int k = 1; k <= TRAIL; k++) {
            float fk = float(k);
            vec2 tp = path(iTime - fk * 0.14, fi, aspect) - vec2(0.0, fk * 0.006);
            vec2 td = p - tp;
            float tw = 0.5 + 0.5 * sin(iTime * 13.0 + fk * 2.3 + fi * 5.0);
            float fade = 1.0 - fk / float(TRAIL + 1);
            glow += col * (0.000014 / (dot(td, td) + 0.000006)) * fade * tw;
        }
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
