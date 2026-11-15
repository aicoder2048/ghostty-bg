// tornado — a twisting funnel sways across the lower right, spinning, with debris whirling around it.
// zh: 龙卷风
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.45;   // overall brightness (0 = off)
const float GROUND    = 0.04;   // where the funnel touches down (scene y)
const float TOP       = 0.88;   // where it meets the cloud
const int   DEBRIS    = 14;     // specks whirling around it

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Height 0 (ground) .. 1 (cloud) to funnel radius: a thin rope that flares out.
float radiusAt(float h) {
    return 0.018 + 0.30 * pow(h, 2.2);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float t = iTime;
    // The base wanders back and forth across the right half; the funnel
    // above it bends and sways, the top lagging behind the bottom.
    float baseX = aspect * (0.75 + 0.12 * sin(t * 0.09) + 0.04 * sin(t * 0.23));
    float h = clamp((p.y - GROUND) / (TOP - GROUND), 0.0, 1.0);
    float axis = baseX + 0.04 * h + 0.06 * sin(t * 0.6 - h * 3.0) * h + 0.015 * sin(t * 1.7 - h * 9.0);
    float r = radiusAt(h);

    float u = (p.x - axis) / r;                       // -1..1 across the funnel
    float inside = smoothstep(1.0, 0.75, abs(u)) * step(GROUND, p.y) * smoothstep(TOP + 0.02, TOP - 0.06, p.y);

    // Treat the funnel as a spinning cylinder: angle on the front and back
    // surface, plus a steady spin. (A spin that differs with height would
    // wind the bands tighter and tighter as time goes on.)
    float front = asin(clamp(u, -1.0, 1.0));
    float back = 3.1416 - front;
    float spin = t * 4.0;
    float tilt = h * 45.0 + 4.0 * sin(h * 7.0 - t * 0.8);   // bands wind upward: spiral streaks
    float bandsF = pow(0.5 + 0.5 * sin(3.0 * (front + spin) + tilt), 3.0)
                 + 0.5 * pow(0.5 + 0.5 * sin(7.0 * (front + spin) + tilt * 1.7 + 1.0), 4.0);
    float bandsB = pow(0.5 + 0.5 * sin(3.0 * (back + spin) + tilt), 3.0);

    float rim = pow(abs(u), 4.0);                     // edges brighter: you see more dust edge-on
    float funnel = inside * (0.18 + 0.55 * bandsF + 0.2 * bandsB + 0.35 * rim);
    funnel *= mix(1.0, 0.6, h);                       // a little fainter up top, where text may be

    // Dust cloud churning at the base.
    vec2 dq = (p - vec2(baseX, GROUND + 0.02)) * vec2(1.0, 2.6);
    float dust = 0.35 * exp(-dot(dq, dq) * 90.0) * (0.8 + 0.2 * sin(t * 3.0 + p.x * 40.0));

    // Debris orbiting the funnel; the ones behind it are dimmer.
    float specks = 0.0;
    float px = 1.0 / iResolution.y;
    for (int i = 0; i < DEBRIS; i++) {
        float fi = float(i);
        float rise = fract(t * (0.05 + 0.05 * hash1(fi * 3.7)) + hash1(fi * 1.3));
        float dh = rise * 0.55;                       // mostly the lower half
        float dy = GROUND + dh * (TOP - GROUND);
        float dAxis = baseX + 0.04 * dh + 0.06 * sin(t * 0.6 - dh * 3.0) * dh + 0.015 * sin(t * 1.7 - dh * 9.0);
        float ang = t * (4.0 + 2.0 * hash1(fi * 9.1)) + fi * 2.4;
        float orbit = radiusAt(dh) * 1.4 + 0.02;
        vec2 sp = vec2(dAxis + orbit * cos(ang), dy + 0.01 * sin(ang));
        float depth = 0.55 + 0.45 * sin(ang);         // sin > 0: in front
        float d = length(p - sp);
        specks += smoothstep(3.0 * px, 0.5 * px, d) * depth * (1.0 - rise * 0.6);
    }

    vec3 color = vec3(0.78, 0.80, 0.84) * (funnel + dust) + vec3(0.95, 0.90, 0.80) * specks;
    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
