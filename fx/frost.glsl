// frost — ice crystals slowly creep in from the corners and edges, glinting now and then.
// zh: 霜花
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.40;   // overall brightness (0 = off)
const float CYCLE     = 60.0;   // seconds to grow, rest, and melt away
const float REACH     = 0.24;   // how far in from the edges the frost gets (window heights)

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Ridged noise: thin bright veins where the noise crosses its middle, like
// the branching ferns frost draws on glass.
float veins(vec2 p) {
    float v = 0.0, a = 0.6;
    for (int i = 0; i < 3; i++) {
        v += a * pow(1.0 - abs(noise(p) * 2.0 - 1.0), 8.0);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p;
        a *= 0.6;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Distance to the nearest edge; corners get a big head start (frost loves corners).
    float dx = min(p.x, aspect - p.x);
    float dy = min(p.y, 1.0 - p.y);
    float edge = min(dx, dy);
    float corner = length(vec2(dx, dy));
    float d = min(edge * 2.8, corner * 0.75);
    // The top left holds the text: the frost barely reaches in there.
    d *= mix(1.0, 3.0, smoothstep(0.7, 0.0, length(vec2(p.x / aspect, 1.0 - p.y))));
    // A ragged, lobed front instead of a clean frame.
    d += 0.10 * (noise(p * 4.0) - 0.5) + 0.04 * (noise(p * 17.0) - 0.5);

    // Grow slowly, hold, then melt; then a short clear pause.
    float s = fract(iTime / CYCLE);
    float grow = smoothstep(0.0, 0.6, s) * smoothstep(0.95, 0.8, s);
    float front = REACH * grow;

    float inside = smoothstep(front, front - 0.03, d);
    float depth = clamp((front - d) / max(front, 0.001), 0.0, 1.0);   // 0 at the front, 1 at the edge

    // Fern-like veins on mostly clear glass: thicker near the edge, wispy at the front.
    float v = veins(p * 14.0);
    float frost = inside * (0.06 + 0.12 * depth + v * mix(0.5, 1.0, depth));

    // Six-armed ice crystals scattered through the frost, bigger where it is older.
    vec2 cg = p * 16.0;
    vec2 cid = floor(cg);
    vec2 cq = fract(cg) - 0.5 - (vec2(hash(cid + 1.3), hash(cid + 7.1)) - 0.5) * 0.3;
    float ca = hash(cid + 3.3) * 1.047;
    float arm = 0.0;
    for (int k = 0; k < 3; k++) {
        float a = ca + float(k) * 1.0472;
        vec2 dir = vec2(cos(a), sin(a));
        float along = abs(dot(cq, dir));
        float across = abs(dot(cq, vec2(-dir.y, dir.x)));
        arm = max(arm, smoothstep(0.035, 0.0, across) * step(along, 0.28 * depth + 0.06));
    }
    float crystal = arm * step(0.6, hash(cid + 9.9)) * inside * smoothstep(0.0, 0.3, depth);
    frost += crystal * 0.7;

    // Sparkle: a few cells glint briefly, only where there is frost.
    vec2 g = p * 60.0;
    vec2 id = floor(g);
    float h = hash(id);
    float tw = pow(max(sin(iTime * (1.0 + 2.0 * h) + h * 50.0), 0.0), 40.0);
    float spot = smoothstep(0.35, 0.0, length(fract(g) - 0.5));
    float sparkle = step(0.93, h) * tw * spot * inside * 1.5;

    vec3 color = vec3(0.78, 0.90, 1.0) * frost + vec3(1.0) * sparkle;
    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
