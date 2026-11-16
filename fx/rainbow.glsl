// rainbow — a big vivid rainbow with a faint second bow, a glint that runs along it and drifting sparkles.
// zh: 彩虹
// group: weather
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float RADIUS    = 1.00;   // arc radius (window height = 1)
const float BAND      = 0.13;   // width of the main bow, red edge to violet edge
const float SECOND    = 0.38;   // brightness of the outer bow, relative to the main one
const float GLINT_GAP = 4.5;    // seconds between glints running along the arc
const float BREATH    = 7.0;    // seconds per slow brightness swell
const int   SPARKS    = 12;     // sparkles drifting near the arc
const float PI        = 3.14159265;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Rainbow colour: k = 0 is red (outer edge), k = 1 is violet (inner edge).
// Hand-picked stops so red, yellow, green and blue each get a clear stripe.
vec3 spectrum(float k) {
    k = clamp(k, 0.0, 1.0) * 5.0;
    vec3 c = mix(vec3(1.00, 0.10, 0.08), vec3(1.00, 0.55, 0.05), clamp(k, 0.0, 1.0));      // red -> orange
    c = mix(c, vec3(1.00, 0.95, 0.15), clamp(k - 1.0, 0.0, 1.0));                          // -> yellow
    c = mix(c, vec3(0.15, 0.95, 0.25), clamp(k - 2.0, 0.0, 1.0));                          // -> green
    c = mix(c, vec3(0.15, 0.45, 1.00), clamp(k - 3.0, 0.0, 1.0));                          // -> blue
    c = mix(c, vec3(0.55, 0.20, 0.95), clamp(k - 4.0, 0.0, 1.0));                          // -> violet
    return c;
}

// Soft-edged band: 1 inside [0,1], fading over `e` at both edges.
float bandMask(float k, float e) {
    return smoothstep(0.0, e, k) * smoothstep(1.0, 1.0 - e, k);
}

// A four-point star sparkle (rays 1 long in star units).
float star(vec2 d) {
    vec2 a = abs(d);
    float core = 0.03 / (dot(d, d) + 0.03);
    vec2 len = max(1.0 - a, 0.0);
    float rx = len.x * len.x * exp(-a.y * 14.0 / (len.x + 0.15));
    float ry = len.y * len.y * exp(-a.x * 14.0 / (len.y + 0.15));
    return core * 0.6 + rx + ry;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Centre below the window, right of middle: the arc spans nearly the full
    // width, its top sits right of centre and its left foot lands low,
    // under the shell text rather than across it.
    vec2 c = vec2(aspect * 0.68, -0.45);
    vec2 q = p - c;
    float r = length(q);
    float ang = atan(q.y, q.x);               // PI = left foot side, 0 = right side
    float s = 1.0 - ang / PI;                 // 0 at the left end, 1 at the right end

    // Opening: the bow sweeps in from the left foot over ~1.2 s, then stays.
    float reveal = smoothstep(s - 0.12, s + 0.05, iTime / 1.2 - 0.05);

    // Breathing: a gentle swell between 75% and 100%, never fading out.
    float breath = 0.875 + 0.125 * sin(iTime * 2.0 * PI / BREATH);

    // Main bow.
    float k = (RADIUS - r) / BAND;
    float a1 = bandMask(k, 0.22);
    vec3 col = spectrum(k) * a1;

    // A soft brighter sky just inside the bow, as in a real rainbow.
    float inside = smoothstep(0.0, 0.05, -k * BAND) * exp(-max(RADIUS - BAND - r, 0.0) * 6.0);
    col += vec3(0.9, 0.85, 1.0) * inside * 0.10;

    // Outer bow: wider, fainter, colours reversed (violet outside... red inside).
    float R2 = RADIUS * 1.24;
    float k2 = (r - (R2 - BAND * 1.4)) / (BAND * 1.4);   // 0 = red (inner edge), 1 = violet
    float a2 = bandMask(k2, 0.25);
    col += spectrum(k2) * a2 * SECOND;

    // Glint: a bright spot runs along the main bow from left to right every
    // GLINT_GAP seconds (first one right after the bow appears).
    float gt = mod(iTime - 1.3, GLINT_GAP);
    float gpos = gt / 1.8;                                // 0..1 while running
    float glint = exp(-pow((s - gpos) * 12.0, 2.0)) * step(0.0, iTime - 1.3)
                * smoothstep(0.0, 0.1, gpos) * smoothstep(1.0, 0.85, gpos);
    float gband = exp(-pow((k - 0.5) * 1.6, 2.0));        // centred on the bow, a bit wider
    col += (spectrum(k) * 0.7 + vec3(0.35)) * glint * gband * 0.8;

    // Keep the arc out of the bottom edge and calmer at its far left end,
    // where it passes under the start of the shell lines.
    float fade = smoothstep(0.0, 0.22, p.y) * mix(0.55, 1.0, smoothstep(0.05, 0.40, s));
    float bow = (a1 + a2 * SECOND) * fade * reveal * breath;
    col *= fade * reveal * breath;

    // Sparkles drifting slowly upward along the arc, twinkling in and out.
    vec3 spark = vec3(0.0);
    for (int i = 0; i < SPARKS; i++) {
        float fi = float(i);
        float period = 3.0 + 2.5 * hash1(fi * 3.17 + 0.5);
        float tt = iTime / period + hash1(fi * 7.71 + 1.0);
        float cyc = floor(tt);
        float life = fract(tt);
        float seed = fi * 13.1 + cyc * 7.31;

        float sa = PI * mix(0.12, 0.85, hash1(seed));      // spot along the arc (skips the far left)
        float sr = RADIUS + BAND * mix(-1.6, 2.2, hash1(seed + 1.7));
        vec2 pos = c + sr * vec2(cos(sa), sin(sa));
        pos.y += life * 0.06;                               // slow drift upward
        pos.x += (hash1(seed + 2.3) - 0.5) * life * 0.05;

        float env = sin(life * PI);
        env *= env;
        float size = mix(0.018, 0.04, hash1(seed + 3.9)) * (0.6 + 0.4 * env);
        vec2 d = p - pos;
        if (dot(d, d) > size * size * 4.0) continue;      // far away: skip the math
        float rot = life * 1.2 + fi;
        d = mat2(cos(rot), -sin(rot), sin(rot), cos(rot)) * d / size;
        vec3 tint = mix(vec3(1.0, 0.95, 0.8), spectrum(hash1(seed + 5.1)), 0.4);
        spark += tint * star(d) * env * smoothstep(0.0, 0.15, pos.y);
    }
    spark *= smoothstep(1.0, 2.0, iTime);

    // Darken the sky a little under the bands so the colours read as colours
    // (not just "brighter orange") on a warm sunset, then add the light.
    vec3 rgb = base.rgb * (1.0 - 0.30 * min(bow, 1.0) * INTENSITY);
    rgb += col * INTENSITY + min(spark, vec3(1.2)) * INTENSITY * 0.8;
    fragColor = vec4(rgb, base.a);
}
