// moon — a softly glowing moon arcs slowly across the upper right as thin clouds drift past.
// zh: 月亮
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const float PERIOD    = 900.0;  // seconds for one full rise and set
const float RADIUS    = 0.07;   // moon size, in window-heights

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // One arc per PERIOD: up from the right side, over, and down again, always
    // in the right third. It starts part way up so it shows at once.
    float phase = fract(iTime / PERIOD + 0.35);
    vec2 moon = vec2(aspect - 0.10 - 0.40 * phase, 0.50 + 0.32 * sin(phase * 3.1416));
    float visible = smoothstep(0.0, 0.04, phase) * smoothstep(1.0, 0.96, phase);

    vec2 q = (p - moon) / RADIUS;
    float r = length(q);

    // The disc: a little darker at the edge, with darker patches (the "seas").
    float disc = smoothstep(1.0, 0.96, r);
    float seas = noise(q * 1.6 + 3.0) * 0.6 + noise(q * 3.5 + 7.0) * 0.4;
    float shade = (0.80 - 0.30 * smoothstep(0.45, 0.75, seas)) * (1.0 - 0.25 * r * r);
    vec3 color = vec3(1.0, 0.97, 0.88) * disc * shade;

    // Halo: a soft glow that falls off around the disc.
    float halo = exp(-max(r - 1.0, 0.0) * 0.9) * 0.18 + exp(-max(r - 1.0, 0.0) * 4.0) * 0.20;
    color += vec3(0.80, 0.85, 1.0) * halo * (1.0 - disc);

    // A thin streak of cloud drifting left to right at the moon's height. It
    // dims the moon behind it and catches some of its light.
    vec2 c = vec2((p.x - iTime * 0.012) * 1.6, (p.y - moon.y + 0.02) * 9.0);
    float cloud = noise(c * 2.0) * 0.6 + noise(c * 4.0) * 0.3 + noise(c * 8.0) * 0.1;
    cloud = smoothstep(0.38, 0.68, cloud) * smoothstep(1.2, 0.0, abs(c.y));
    float lit = exp(-max(r - 1.0, 0.0) * 0.6);         // brighter close to the moon
    color = color * (1.0 - 0.7 * cloud) + vec3(0.75, 0.78, 0.85) * cloud * (0.08 + 0.35 * lit);

    color *= visible;
    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
