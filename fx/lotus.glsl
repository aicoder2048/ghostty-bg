// lotus — a lotus pond along the bottom: lily pads and pink flowers bobbing on the water.
// zh: 荷花
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.60;   // overall strength (0 = off)
const float WATER     = 0.13;   // height of the water line, in window-heights
const int   PADS      = 7;      // lily pads
const int   FLOWERS   = 3;      // lotus flowers

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 q, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * q.x - s * q.y, s * q.x + c * q.y);
}

// A lily pad seen at a low angle: a flat oval with a wedge cut out (the notch).
float pad(vec2 q, float r, float notch) {
    float d = length(q * vec2(1.0, 3.2)) - r;
    float body = smoothstep(0.004, 0.0, d);
    float a = atan(q.y * 3.2, q.x);                          // angle around the pad
    float cut = smoothstep(0.10, 0.16, abs(mod(a - notch + 3.1416, 6.2831) - 3.1416));
    return body * cut;
}

// One petal standing on its base: broad in the middle, pointed at the tip.
// q is relative to the petal base, already rotated so the petal points up.
float petal(vec2 q, float len, float wide) {
    float t = q.y / len;
    if (t < 0.0 || t > 1.0) return 0.0;
    float w = wide * pow(sin(3.1416 * t), 0.7) * (1.0 - 0.25 * t);
    return smoothstep(0.003, 0.0, abs(q.x) - w);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 color = vec3(0.0);
    float shape = 0.0;

    if (p.y < 0.36) {                                        // the pond is all down here
        // The water line: a faint wavy band, and a fainter one a little lower.
        float wave = WATER + 0.004 * sin(p.x * 18.0 - iTime * 1.2);
        float line = smoothstep(0.004, 0.0, abs(p.y - wave)) * 0.35;
        float wave2 = WATER - 0.06 + 0.003 * sin(p.x * 13.0 - iTime * 0.9 + 1.0);
        line = max(line, smoothstep(0.003, 0.0, abs(p.y - wave2)) * 0.15);
        color = vec3(0.55, 0.75, 0.85);
        shape = line;

        // Ripple rings that spread out around each flower now and then.
        for (int i = 0; i < FLOWERS; i++) {
            float fi = float(i);
            float x = (0.18 + 0.33 * fi + 0.06 * hash1(fi + 1.0)) * aspect;
            float ph = fract(iTime * 0.22 + hash1(fi + 9.0));
            float d = length((p - vec2(x, WATER - 0.01)) * vec2(1.0, 3.5));
            float ring = smoothstep(0.004, 0.0, abs(d - ph * 0.22)) * (1.0 - ph) * 0.6;
            color = mix(color, vec3(0.6, 0.8, 0.9), ring);
            shape = max(shape, ring);
        }

        // Lily pads floating on and below the water line.
        for (int i = 0; i < PADS; i++) {
            float fi = float(i);
            float x = (fi + 0.2 + 0.6 * hash1(fi * 3.7)) / float(PADS) * aspect;
            float y = WATER - 0.025 - 0.07 * hash1(fi * 5.1)
                    + 0.006 * sin(iTime * (0.9 + 0.4 * hash1(fi)) + fi * 2.0);   // bobbing
            float r = mix(0.075, 0.115, hash1(fi * 7.3));
            vec2 q = rot(p - vec2(x, y), 0.04 * sin(iTime * 0.7 + fi));
            float m = pad(q, r, 6.2831 * hash1(fi * 2.9));
            // Lighter toward the rim, a little darker in the middle.
            vec3 green = mix(vec3(0.20, 0.50, 0.25), vec3(0.40, 0.72, 0.35), smoothstep(0.0, r, length(q * vec2(1.0, 3.2))));
            color = mix(color, green, m);
            shape = max(shape * (1.0 - m), m * 0.85);
        }

        // The flowers: a short stem, back petals, then front petals over them.
        for (int i = 0; i < FLOWERS; i++) {
            float fi = float(i);
            float x = (0.18 + 0.33 * fi + 0.06 * hash1(fi + 1.0)) * aspect;
            float bob = 0.007 * sin(iTime * 1.1 + fi * 2.1);
            vec2 b = vec2(x + 0.006 * sin(iTime * 0.8 + fi), WATER + 0.04 + 0.03 * hash1(fi + 4.0) + bob);
            float len = mix(0.10, 0.12, hash1(fi + 6.0));
            float open = 1.0 + 0.10 * sin(iTime * 0.6 + fi * 1.7);   // opens and closes a little

            float stem = smoothstep(0.004, 0.0, abs(p.x - b.x)) * step(WATER - 0.01, p.y) * step(p.y, b.y);
            color = mix(color, vec3(0.30, 0.55, 0.30), stem);
            shape = max(shape * (1.0 - stem), stem * 0.8);

            vec2 q = p - b;
            // Back row: wide-open petals, deeper pink.
            for (int k = 0; k < 4; k++) {
                float ang = (float(k) - 1.5) * 0.62 * open;
                float m = petal(rot(q, ang), len * 0.95, len * 0.30);
                color = mix(color, vec3(0.92, 0.40, 0.60), m);
                shape = max(shape * (1.0 - m), m);
            }
            // The seed pod peeks out between the rows.
            float pod = smoothstep(0.004, 0.0, length((q - vec2(0.0, len * 0.35)) * vec2(1.0, 1.8)) - len * 0.22);
            color = mix(color, vec3(1.0, 0.85, 0.35), pod);
            shape = max(shape * (1.0 - pod), pod);
            // Front row: more upright, paler toward the base (the lighter centre).
            for (int k = 0; k < 3; k++) {
                float ang = (float(k) - 1.0) * 0.45 * open;
                vec2 r = rot(q + vec2(0.0, 0.01), ang);
                float m = petal(r, len, len * 0.32);
                vec3 pink = mix(vec3(1.0, 0.90, 0.92), vec3(1.0, 0.50, 0.70), clamp(r.y / len, 0.0, 1.0));
                color = mix(color, pink, m);
                shape = max(shape * (1.0 - m), m);
            }
        }
    }

    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
