// turtle — two sea turtles, seen from above, paddle slowly across at different depths.
// zh: 海龟
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.50;   // overall strength (0 = off)

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// A limb that is thick at the root (r0) and thin at the tip (r1).
float limb(vec2 p, vec2 a, vec2 b, float r0, float r1, float aa) {
    vec2 s = segment(p, a, b);
    return smoothstep(aa, -aa, s.x - mix(r0, r1, s.y));
}

vec2 dir(float a) { return vec2(cos(a), sin(a)); }

// A sea turtle seen from above, head toward +x. The shell is about 2 long.
// stroke runs from -1 (front flippers swept forward) to 1 (pulled back).
// Returns (shape, plate lines) so the caller can darken the seams.
vec2 turtle(vec2 q, float stroke, float aa) {
    vec2 m = vec2(q.x, abs(q.y));                                 // mirror: draw one side

    // Front flippers: long and curved, both sides beat together like wings.
    vec2 root = vec2(0.45, 0.55);
    float ang = 1.95 + 0.6 * stroke;
    vec2 mid = root + 0.55 * dir(ang);
    vec2 tip = mid + 0.60 * dir(ang + 0.55);                      // the outer half sweeps back
    float limbs = max(limb(m, root, mid, 0.17, 0.12, aa), limb(m, mid, tip, 0.12, 0.03, aa));

    // Small rear flippers that steer, moving a little out of step.
    float rang = 2.55 + 0.25 * sin(stroke * 1.6 + 1.0);
    limbs = max(limbs, limb(m, vec2(-0.70, 0.40), vec2(-0.70, 0.40) + 0.42 * dir(rang), 0.12, 0.04, aa));

    // Head on a short neck, and a stubby tail.
    float head = smoothstep(aa, -aa, length((q - vec2(1.20, 0.0)) / vec2(1.0, 0.80)) - 0.23);
    head = max(head, limb(q, vec2(0.85, 0.0), vec2(1.10, 0.0), 0.15, 0.13, aa));
    limbs = max(max(limbs, head), limb(q, vec2(-0.90, 0.0), vec2(-1.18, 0.0), 0.08, 0.02, aa));

    // Shell: an oval with a row of centre plates, side plates and a rim.
    vec2 s = q / vec2(1.0, 0.78);
    float r = length(s);
    float shell = smoothstep(aa, -aa, (r - 1.0) * 0.8);

    vec2 c[5];
    c[0] = vec2(0.48, 0.0); c[1] = vec2(0.0, 0.0); c[2] = vec2(-0.46, 0.0);
    c[3] = vec2(0.24, 0.46); c[4] = vec2(-0.24, 0.46);
    float d1 = 9.0, d2 = 9.0;
    vec2 ms = vec2(s.x, abs(s.y));
    for (int k = 0; k < 5; k++) {
        float d = length(ms - c[k]);
        d2 = min(d2, max(d, d1));
        d1 = min(d1, d);
    }
    float seams = smoothstep(0.07, 0.02, d2 - d1) * step(r, 0.80);   // borders between plates
    seams = max(seams, smoothstep(0.035, 0.0, abs(r - 0.82)));       // ring of rim plates
    seams *= shell;

    return vec2(max(shell, limbs * 0.85), seams);
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

    vec3 rgb = base.rgb;
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        // The far turtle is smaller, higher, slower and fainter: that reads as depth.
        float size = mix(0.075, 0.045, fi);
        float dir = fi < 0.5 ? 1.0 : -1.0;
        float travel = aspect + 6.0 * size;
        float speed = mix(0.022, 0.015, fi);

        // Each power stroke gives a little push, so the glide is not perfectly even.
        float rate = 0.9 - 0.15 * fi;
        float clock = iTime * rate + fi * 2.0;
        float stroke = sin(clock);
        float surge = -0.25 * size * cos(clock) / rate;

        float x = mod(iTime * speed + (0.3 + fi * 0.45) * travel + surge, travel) - 3.0 * size;
        if (dir < 0.0) x = aspect - x;
        float y = mix(0.32, 0.66, fi) + 0.025 * sin(iTime * 0.2 + fi * 3.0);

        vec2 q = (p - vec2(x, y)) / size;
        q.x *= dir;                                               // face the way it swims
        float tilt = 0.12 * sin(iTime * 0.2 + fi * 3.0 + 1.2);    // drift up and down a little
        q = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * q;

        float aa = 1.5 / (iResolution.y * size);
        vec2 t = turtle(q, stroke, aa);
        float a = t.x * (1.0 - 0.65 * t.y) * mix(1.0, 0.6, fi);

        vec3 color = vec3(0.55, 0.92, 0.62);
        rgb = blend(rgb, color, a * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
