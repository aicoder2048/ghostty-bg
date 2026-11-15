// comet — a bright comet drifts across the sky trailing a curved dust tail and a straight ion tail.
// zh: 彗星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.75;   // overall brightness (0 = off)
const float CROSSING  = 45.0;   // seconds for one pass
const float TAIL      = 0.80;   // tail length, in screen heights

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

    // The head moves right to left and a little down; each pass on its own line.
    float t = iTime / CROSSING;
    float n = floor(t);
    float k = fract(t);
    float y0 = mix(0.50, 0.68, hash1(n * 3.1 + 1.0));      // below most text
    vec2 from = vec2(aspect + 0.15, y0);
    vec2 to = vec2(-0.75, y0 - mix(0.20, 0.35, hash1(n * 6.7 + 2.0)));
    vec2 head = mix(from, to, k);

    // Tail frame: `along` runs back from the head, `across` sideways.
    vec2 back = normalize(from - to + vec2(0.0, 0.35));     // tail points back and a bit up
    vec2 side = vec2(-back.y, back.x);
    vec2 d = p - head;
    float along = dot(d, back);
    float across = dot(d, side);
    float behind = smoothstep(-0.01, 0.02, along) * smoothstep(TAIL * 1.2, TAIL * 0.4, along);

    // Ion tail: thin, straight and blue.
    float wi = 0.004 + along * 0.028;
    float ion = exp(-pow(across / wi, 2.0)) * exp(-along * 2.2 / TAIL) * behind;

    // Dust tail: wider, yellow-white, curving away to one side and fading sooner.
    float bend = across - along * along * 0.6;
    float wd = 0.006 + along * 0.12;
    float dust = exp(-pow(bend / wd, 2.0)) * exp(-along * 3.0 / TAIL) * behind;
    dust *= 0.85 + 0.15 * sin(along * 60.0 - iTime * 1.5);   // faint streamers

    // Head: a small sharp nucleus inside a soft coma.
    float r2 = dot(d, d);
    float coma = 0.00012 / (r2 + 0.00020);
    float nucleus = smoothstep(0.008, 0.002, sqrt(r2));

    vec3 color = vec3(0.45, 0.70, 1.00) * ion * 0.70
               + vec3(1.00, 0.90, 0.70) * dust * 1.30
               + vec3(0.85, 0.95, 1.00) * (coma * 0.6 + nucleus);
    color = min(color, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
