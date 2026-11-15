// radar — a radar scope in the corner: rings, a rotating sweep with an afterglow, and blips it lights up.
// zh: 雷达
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const float RADIUS    = 0.17;   // scope radius, in window-heights
const float SWEEP     = 1.3;    // sweep speed, radians per second
const int   BLIPS     = 7;

const vec3 GREEN = vec3(0.30, 1.00, 0.50);

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // The scope sits in the bottom-right corner, away from most text.
    vec2 c = vec2(aspect - RADIUS - 0.05, RADIUS + 0.05);
    vec2 d = p - c;
    float r = length(d);
    float inside = step(r, RADIUS);

    float light = 0.0;

    // Range rings and a crosshair.
    float rings = 0.0;
    for (int i = 1; i <= 3; i++) {
        rings += smoothstep(0.0025, 0.0, abs(r - RADIUS * float(i) / 3.0));
    }
    float hair = smoothstep(0.0015, 0.0, min(abs(d.x), abs(d.y))) * inside;
    light += (rings * 0.35 + hair * 0.15) + inside * 0.025;

    // The sweep turns clockwise; what it just passed still glows and fades.
    float a = -iTime * SWEEP;
    float ang = atan(d.y, d.x);
    float behind = mod(ang - a, 6.2831853);                     // radians since the beam passed
    light += inside * (exp(-behind * 2.5) * 0.45 + smoothstep(0.03, 0.0, behind) * 0.4);

    // Blips: targets that flare when the beam crosses them, then fade out.
    // The set of targets changes every so often.
    float epoch = floor(iTime / 20.0);
    for (int i = 0; i < BLIPS; i++) {
        float s = float(i) * 7.31 + epoch * 13.7;
        float ba = hash1(s) * 6.2831853;
        float br = mix(0.15, 0.92, hash1(s + 1.0)) * RADIUS;
        vec2 bp = br * vec2(cos(ba), sin(ba));
        float since = mod(ba - a, 6.2831853);
        float dot2 = dot(d - bp, d - bp);
        light += exp(-dot2 / 0.000025) * exp(-since * 0.9) * 1.2;
    }

    fragColor = vec4(base.rgb + GREEN * min(light, 1.2) * INTENSITY, base.a);
}
