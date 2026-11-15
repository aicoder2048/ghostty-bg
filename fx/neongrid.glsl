// neongrid — a glowing synthwave grid rolls toward you along the bottom, a faint sun on the horizon.
// zh: 霓虹网格
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const float HORIZON   = 0.30;   // horizon height, from the bottom, in window-heights
const float SPEED     = 1.2;    // grid lines per second rolling toward you

const vec3 MAGENTA = vec3(1.00, 0.25, 0.80);
const vec3 CYAN    = vec3(0.20, 0.85, 1.00);

// An anti-aliased line wherever x is a whole number (in grid units).
float gridLine(float x) {
    float d = abs(fract(x + 0.5) - 0.5) / max(fwidth(x), 1e-4);
    return 1.0 - smoothstep(0.0, 1.5, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float cx = aspect * 0.5;

    vec3 light = vec3(0.0);

    // The floor: each pixel below the horizon maps to a point on a flat plane;
    // the closer to the horizon, the farther away the point.
    float dy = HORIZON - p.y;
    if (dy > 0.0) {
        float z = 0.3 / dy;                                   // 1 at the bottom edge, huge at the horizon
        float gx = (p.x - cx) * z * 8.0;
        float gz = z * 3.0 + iTime * SPEED;
        float near = smoothstep(0.0, 0.10, dy);               // dense lines melt into the horizon
        light += CYAN * gridLine(gx) * near * 0.8;
        light += MAGENTA * gridLine(gz) * near;
        light += MAGENTA * 0.10 * near * (1.0 - dy / HORIZON); // a faint haze toward the horizon
    }

    // A thin glowing horizon line.
    light += MAGENTA * exp(-abs(p.y - HORIZON) * 60.0) * 0.5;

    // A low striped sun sitting on the horizon.
    vec2 s = p - vec2(cx, HORIZON);
    float r = 0.13;
    if (s.y > 0.0 && length(s) < r) {
        float v = s.y / r;                                    // 0 at the horizon, 1 at the top
        float gap = step(fract(v * 7.0), (0.55 - v) * 0.9);   // slits that widen downward
        float disc = smoothstep(r, r - 0.004, length(s)) * (1.0 - gap);
        light += mix(MAGENTA, vec3(1.0, 0.75, 0.25), v) * disc * 0.35;
    }

    fragColor = vec4(base.rgb + min(light, vec3(1.0)) * INTENSITY, base.a);
}
