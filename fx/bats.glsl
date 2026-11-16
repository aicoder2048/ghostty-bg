// bats — a swarm of bats streams out of a cave off the lower right and twists up across the sky.
// zh: 蝙蝠
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (dark moonlit silhouettes that read on dark themes and photos).

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float FLOW      = 0.17;   // how fast the far swarm climbs the column (stream lengths per second)
const float WAVE      = 0.70;   // gap between dense waves, in stream lengths (about 4 s apart)
const float CELLS     = 24.0;   // slots along the column; each slot holds up to 4 far bats
const int   NEAR      = 6;      // large bats that fly close past the viewer
const float NEAR_SIZE = 0.068;  // half a wingspan of a near bat, in window WIDTHS (0.062 = 12% span)
const float NEAR_LIFE = 3.6;    // seconds a near bat takes to cross the window
const vec3  BODY      = vec3(0.020, 0.020, 0.035);   // silhouette colour
const vec3  MEMBRANE  = vec3(0.075, 0.080, 0.120);   // moonlight seen through the wing skin
const vec3  RIM       = vec3(0.640, 0.760, 1.000);   // cool moonlit edge
const vec2  MOON      = vec2(-0.37, 0.93);           // direction the light comes from (upper left)

const float TAU = 6.28318530718;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0,  v1 = p - p1,  v2 = p - p2;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// A round bite out of the trailing edge between two finger tips. The circle
// passes just inside both tips, so the tips stay pointed: the scalloped edge.
float scallop(vec2 p, vec2 a, vec2 b, vec2 wrist) {
    vec2 e = b - a, mid = 0.5 * (a + b);
    vec2 n = normalize(vec2(e.y, -e.x));
    n *= sign(dot(n, mid - wrist));                 // push the circle away from the wing
    float h = 0.5 * length(e);
    return length(p - mid - n * 0.8 * h) - 1.25 * h;
}

// A bat seen from below/behind, head along +y, half a wingspan = 1.
// Each wing has its own lift angle (asymmetric beats); fold (0..1) pulls the
// wing in on the upstroke. Returns (signed distance, membrane 0..1) where
// membrane is 1 on bare wing skin and 0 on body and finger bones.
vec2 bat(vec2 q, float liftL, float liftR, float fold) {
    float lift = q.x < 0.0 ? liftL : liftR;
    vec2 a = vec2(abs(q.x), q.y);                   // mirror: draw one wing

    // Into the wing's own frame: shoulder at the origin, rotated by the beat.
    vec2 w = rot(a - vec2(0.07, 0.06), -lift);
    w.x /= mix(1.0, 0.55, fold);

    const vec2 S  = vec2(0.00,  0.00);              // shoulder
    const vec2 W  = vec2(0.40,  0.11);              // wrist
    const vec2 F2 = vec2(0.95,  0.03);              // leading finger tip
    const vec2 F3 = vec2(0.80, -0.30);
    const vec2 F4 = vec2(0.56, -0.45);
    const vec2 F5 = vec2(0.29, -0.43);
    const vec2 H  = vec2(-0.03, -0.33);             // ankle, where the skin meets the leg

    // Membrane: a fan of triangles from the wrist, then bites between the tips.
    float m = triangle(w, S, W, H);
    m = min(m, triangle(w, W, F5, H));
    m = min(m, triangle(w, W, F4, F5));
    m = min(m, triangle(w, W, F3, F4));
    m = min(m, triangle(w, W, F2, F3));
    m = max(m, -scallop(w, F2, F3, W));
    m = max(m, -scallop(w, F3, F4, W));
    m = max(m, -scallop(w, F4, F5, W));
    m = max(m, -scallop(w, F5, H,  W));
    m = max(m, -w.x - 0.05);                        // nothing past the body's middle

    // Arm and finger bones show as dark lines through the lit skin.
    float bone = segment(w, S, W) - 0.030;
    bone = min(bone, segment(w, W, F2) - 0.014);
    bone = min(bone, segment(w, W, F3) - 0.012);
    bone = min(bone, segment(w, W, F4) - 0.011);
    bone = min(bone, segment(w, W, F5) - 0.011);
    bone = min(bone, length(w - W - vec2(0.03, 0.05)) - 0.030);   // thumb claw

    float body = ellipse(a, vec2(0.0, -0.04), vec2(0.085, 0.20));
    body = min(body, length(a - vec2(0.0, 0.17)) - 0.075);                          // head
    body = min(body, triangle(a, vec2(0.012, 0.19), vec2(0.085, 0.36), vec2(0.07, 0.14)));  // ears
    body = min(body, triangle(a, vec2(0.0, -0.20), vec2(0.0, -0.36), vec2(0.07, -0.30)));   // tail skin

    float d = min(m, body);
    float membrane = body < m ? 0.0 : smoothstep(0.0, 0.02, bone);
    return vec2(d, membrane);
}

// Centre line of the column: rises out of the lower right, then bends up and
// left toward the upper middle, with a slow snaking wave running up it.
float centerX(float s, float aspect, float t) {
    float x = aspect + 0.05 - (0.34 * aspect + 0.05) * s - 0.12 * aspect * sin(3.14159 * clamp(s, 0.0, 1.0));
    return x + 0.05 * sin(s * 5.0 - t * 0.9) * (0.3 + s);
}

float streamY(float s) {
    return -0.15 + 1.3 * s;                         // s = 0 below the window, s = 1 above it
}

// Heading angle so the bat's head points along the column.
float heading(float s, float aspect, float t) {
    vec2 tg = vec2(centerX(s + 0.01, aspect, t) - centerX(s, aspect, t), 0.013);
    return atan(-tg.x, tg.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    float D = 1e5;          // distance to the nearest bat, in pixels
    float memb = 0.0;       // membrane flag of that bat
    float rimW = 1.2;       // rim width of that bat, in pixels
    float rimA = 0.5;       // rim strength of that bat (tiny far bats get less, or they sparkle)

    // Far swarm. The column height maps straight to the stream position s, so
    // the pixel only needs the slots at its own height and one either side.
    // Slots move up with the flow; each holds up to 4 bats.
    float sp = (p.y + 0.15) / 1.3;
    float c0 = floor((sp - t * FLOW) * CELLS);
    for (int j = -1; j <= 1; j++) {
        float cell = c0 + float(j);
        for (int k = 0; k < 4; k++) {
            float id = cell * 4.0 + float(k);
            float h1 = hash1(id * 12.9898 + 1.3);
            float h2 = hash1(id * 78.233 + 2.7);
            float h3 = hash1(id * 39.425 + 3.1);
            float h4 = hash1(id * 93.989 + 4.9);
            float h5 = hash1(id * 27.191 + 5.5);

            float sig = (cell + h1) / CELLS;
            float sb = sig + t * FLOW;
            if (sb < 0.0 || sb > 1.1) continue;

            // Waves: dense bands ride up the column, thinner traffic between.
            float wave = 0.5 + 0.5 * sin(sig * TAU / WAVE);
            float dens = 0.45 + 0.55 * smoothstep(0.25, 0.85, wave);
            if (h2 > dens) continue;

            // A twisting ribbon: each bat sits at a lane across the ribbon, and
            // the ribbon turns as it climbs, so lanes cross over and pinch.
            float phi = sb * 7.0 - t * 1.1;
            float u = h3 * 2.0 - 1.0, v = h4 * 2.0 - 1.0;
            float ribbon = 0.06 + 0.14 * sb;
            float lat = ribbon * (u * cos(phi) + 0.35 * v * sin(phi));
            // Near the top they scatter, mostly to the right, away from the text.
            float disp = smoothstep(0.62, 1.0, sb);
            lat += disp * (0.45 * u + 0.45 + 0.5 * (h5 - 0.3));

            vec2 pos = vec2(centerX(sb, aspect, t) + lat, streamY(sb));
            pos.x += 0.012 * sin(t * 6.3 + id) + 0.007 * sin(t * 11.7 + id * 1.7);   // jitter

            float z = u * sin(phi) - 0.35 * v * cos(phi);       // depth in the ribbon
            float hs = (0.020 + 0.012 * h5) * (1.0 + 0.2 * z) * (0.85 + 0.35 * sb);

            vec2 q = (p - pos) / hs;
            if (dot(q, q) > 1.6) continue;                       // too far: skip the shape

            float ang = heading(sb, aspect, t) + 0.35 * sin(t * 3.1 + id) + disp * (h4 - 0.5) * 2.0;
            q = rot(q, -ang);

            float ph = t * (28.0 + 8.0 * h3) + id * 2.3;
            float liftR = 0.15 + 0.85 * sin(ph);
            float liftL = 0.15 + 0.85 * sin(ph + 0.3 + 0.3 * sin(t * 2.3 + id));
            vec2 b = bat(q, liftL, liftR, 0.7 * max(cos(ph), 0.0));

            float dp = b.x * hs * iResolution.y;
            if (dp < D) { D = dp; memb = b.y; rimW = 0.9; rimA = 0.45; }
        }
    }

    // Near bats: a few big ones that burst out of the cave and sweep up past
    // the viewer, each on its own staggered loop so one is on screen at start.
    for (int i = 0; i < NEAR; i++) {
        float fi = float(i);
        float a = hash1(fi * 17.13 + 7.0);
        float c = hash1(fi * 41.71 + 9.0);
        float period = 7.0 + 3.0 * a;
        float age = mod(t + period * fract(0.27 + fi * 0.618), period);
        if (age > NEAR_LIFE) continue;

        float sn = age / NEAR_LIFE * 1.2 - 0.08;
        float ribbon = 0.06 + 0.14 * sn;
        vec2 pos = vec2(centerX(sn, aspect, t), streamY(sn));
        pos.x += ribbon * (c * 1.2 - 0.1) * 1.8 + 0.25 * smoothstep(0.6, 1.1, sn) + 0.08 * sin(age * 1.7 + fi * 3.0);
        pos.x += 0.016 * sin(age * 9.1 + fi) + 0.010 * sin(age * 14.3);    // jittery flight
        pos.y += 0.025 * sin(age * 5.3 + fi * 2.0);

        float hs = NEAR_SIZE * aspect * mix(0.80, 1.20, c) * (0.85 + 0.3 * sn);
        vec2 q = (p - pos) / hs;
        if (dot(q, q) > 1.6) continue;

        float ang = heading(sn, aspect, t) + 0.30 * sin(age * 2.9 + fi) + 0.12 * sin(age * 8.0);
        q = rot(q, -ang);

        float ph = t * (19.0 + 5.0 * a) + fi * 1.9;
        float liftR = 0.15 + 0.85 * sin(ph);
        float liftL = 0.15 + 0.85 * sin(ph + 0.25 + 0.35 * sin(t * 1.9 + fi));
        vec2 b = bat(q, liftL, liftR, 0.7 * max(cos(ph), 0.0));

        float dp = b.x * hs * iResolution.y;
        if (dp < D) { D = dp; memb = b.y; rimW = 1.8; rimA = 0.85; }
    }

    // Dark silhouette with see-through moonlit skin, plus a thin rim lit from
    // the moon's side. The gradient of D gives the outward edge direction.
    float alpha = smoothstep(0.8, -0.8, D);
    float rim = smoothstep(-rimW - 0.8, -rimW * 0.3, D) * smoothstep(0.6, -0.4, D);
    vec2 g = vec2(dFdx(D), -dFdy(D));
    float lit = clamp(dot(g / (length(g) + 1e-4), MOON), 0.0, 1.0);
    rim *= 0.15 + 0.85 * lit;

    // Keep the top-left (where the shell text usually is) mostly clear.
    float clearTL = (1.0 - smoothstep(0.30, 0.50, uv.x)) * (1.0 - smoothstep(0.40, 0.60, uv.y));
    float k = INTENSITY * (1.0 - 0.75 * clearTL);

    vec3 fill = mix(BODY, MEMBRANE, memb);
    vec3 rgb = mix(base.rgb, fill, alpha * 0.92 * k);
    rgb += RIM * rim * rimA * k;
    fragColor = vec4(rgb, base.a);
}
