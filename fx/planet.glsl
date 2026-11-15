// planet — a ringed planet rests in the lower-right corner, its cloud bands slowly turning.
// zh: 行星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const float RADIUS    = 0.12;   // planet radius, in screen heights
const float TILT      = 0.38;   // ring tilt (radians)
const float SPIN      = 0.06;   // how fast the bands turn

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Lower-right corner keeps it away from where the prompt and output live.
    vec2 centre = vec2(aspect - 0.30, 0.27);
    vec2 q = (p - centre) / RADIUS;            // planet units: the disc is radius 1
    vec2 qr = rot(q, -TILT);                   // planet frame: equator and ring are horizontal
    float px = 1.5 / (iResolution.y * RADIUS); // one pixel in planet units, for soft edges

    // --- the sphere ---
    float r2 = dot(q, q);
    float disc = smoothstep(1.0 + px, 1.0 - px, sqrt(r2));
    float z = sqrt(max(1.0 - r2, 0.0));
    vec3 n = vec3(q, z);
    vec3 sun = normalize(vec3(-0.65, 0.45, 0.6));            // lit from the upper left
    float lit = smoothstep(-0.25, 0.7, dot(n, sun));          // soft terminator

    // Bands follow latitude; their wiggles follow longitude, which turns with time.
    float lat = qr.y;
    float lon = atan(qr.x, z) + iTime * SPIN;
    float wave = 0.5 + 0.5 * sin(lat * 13.0 + 0.7 * sin(lon * 3.0 + lat * 6.0));
    vec3 bands = mix(vec3(0.98, 0.78, 0.50), vec3(0.72, 0.45, 0.30), wave);
    float storm = smoothstep(0.30, 0.12, length(vec2(sin(lon - 1.0) * 1.6, lat + 0.35)))
                * step(0.0, cos(lon - 1.0));                  // one storm, front side only
    bands = mix(bands, vec3(1.0, 0.85, 0.70), storm * 0.7);
    float rim = pow(1.0 - z, 3.0) * 0.5;                      // thin atmosphere at the edge
    vec3 planet = (bands * lit + vec3(0.55, 0.70, 1.0) * rim * lit) * disc;

    // --- the ring: a flattened annulus in the planet frame ---
    vec2 e = vec2(qr.x, qr.y / 0.26);
    float er = length(e);
    float band = smoothstep(1.35, 1.40, er) * smoothstep(2.15, 2.08, er);
    float gaps = 0.80 + 0.20 * sin(er * 30.0);                // faint ringlets
    gaps *= 1.0 - 0.8 * smoothstep(0.04, 0.0, abs(er - 1.78)); // the dark division
    float ringA = band * gaps;
    // The planet's shadow falls on the far ring, behind and away from the sun.
    float shadow = smoothstep(0.85, 1.05, length(qr - vec2(0.35, 0.0)));
    vec3 ring = vec3(0.90, 0.82, 0.68) * ringA * 0.8;

    // The near half (below the equator) passes in front, the far half hides behind.
    float front = step(qr.y, 0.0);
    vec3 color = mix(planet, ring, ringA * front * 0.9)
               + ring * (1.0 - front) * (1.0 - disc) * mix(0.5, 1.0, shadow);

    color *= INTENSITY;
    fragColor = vec4(base.rgb + color, base.a);
}
