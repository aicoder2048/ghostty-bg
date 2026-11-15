// phoenix — a bird of flame flies across, wings beating, long fiery tail streaming and shedding embers.
// zh: 凤凰
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const float SIZE      = 0.055;  // bird units: the body is about 2 long
const float SPEED     = 0.14;   // screen heights per second
const float PERIOD    = 28.0;   // seconds between passes
const int   EMBERS    = 14;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Where the bird is at time t: it enters on the right and flies left,
// at a new height each pass.
vec2 birdPos(float t, float aspect) {
    float local = mod(t, PERIOD);
    float y0 = 0.36 + 0.14 * hash1(floor(t / PERIOD) * 5.3 + 2.0);
    return vec2(aspect + 0.35 - local * SPEED, y0 + 0.035 * sin(t * 0.9));
}

// How "hot" point q is, in bird units with the bird facing +x. 1 = white-hot core.
float phoenix(vec2 q, float t) {
    float heat = 0.0;

    // Body and head.
    heat = max(heat, smoothstep(1.1, 0.1, length(q / vec2(1.0, 0.40))));
    vec2 nk = segment(q, vec2(0.6, 0.1), vec2(1.3, 0.45));
    heat = max(heat, smoothstep(0.30, 0.05, nk.x));
    heat = max(heat, smoothstep(0.36, 0.08, length(q - vec2(1.42, 0.52))));
    vec2 bk = segment(q, vec2(1.55, 0.52), vec2(1.95, 0.40));                  // beak
    heat = max(heat, smoothstep(0.09 * (1.0 - bk.y) + 0.02, 0.0, bk.x));
    // Crest: three plumes swept back from the head.
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        vec2 cr = segment(q, vec2(1.35, 0.7), vec2(0.75 - fj * 0.2, 1.05 + fj * 0.12 + 0.06 * sin(t * 6.0 + fj)));
        heat = max(heat, smoothstep(0.08, 0.0, cr.x) * 0.8);
    }

    // Wing: a fan of long feathers from the shoulder, sweeping from up-back
    // to down-back. Mid-stroke the wing points at us, so it looks shorter.
    float beat = sin(t * 5.0);
    float theta = 3.05 + 1.3 * beat;
    float spread = clamp((3.1416 - theta) * 3.0, -1.0, 1.0);           // fan toward the tail
    float reach = 0.55 + 0.45 * abs(beat);
    vec2 sh = vec2(0.2, 0.2);
    for (int j = 0; j < 5; j++) {
        float fj = float(j);
        float th = theta + spread * fj * 0.2;
        vec2 fe = segment(q, sh, sh + vec2(cos(th), sin(th)) * (2.4 - fj * 0.3) * reach);
        heat = max(heat, smoothstep(mix(0.40, 0.10, fe.y), 0.0, fe.x) * mix(1.0, 0.65, fe.y));
    }

    // Tail: three long plumes streaming behind, waving and flaring at the ends.
    float back = -q.x - 0.7;                                          // distance behind the body
    if (back > -0.2 && back < 4.6) {
        float flick = 0.75 + 0.5 * noise(vec2(q.x * 2.0 + t * 6.0, q.y * 3.0));
        for (int j = 0; j < 3; j++) {
            float fj = float(j) - 1.0;
            float len = 3.6 + 0.4 * fj;
            float u = clamp(back / len, 0.0, 1.0);
            float y = fj * 0.45 * u - 0.25 * u + 0.35 * sin(back * 1.3 - t * 4.0 + fj * 2.0) * u;
            float w = mix(0.22, 0.06, u);
            float plume = smoothstep(w, 0.0, abs(q.y - y)) * step(back, len) * mix(0.9, 0.5, u);
            float eye = smoothstep(0.24, 0.05, length(vec2(back - len, q.y - y)));   // flame tip
            heat = max(heat, max(plume, eye * 0.8) * flick);
        }
    }
    return heat;
}

// Fire colours: deep red at the edges, through orange and yellow to white-hot.
vec3 fire(float h) {
    return vec3(1.0, 0.25, 0.05) * smoothstep(0.0, 0.4, h)
         + vec3(0.0, 0.50, 0.12) * smoothstep(0.3, 0.75, h)
         + vec3(0.0, 0.20, 0.50) * smoothstep(0.75, 1.0, h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 glow = vec3(0.0);
    vec2 pos = birdPos(iTime, aspect);
    vec2 q = (p - pos) / SIZE;
    q.x = -q.x;                                       // flying left: mirror so it faces +x
    if (q.x > -6.0 && q.x < 3.0 && abs(q.y) < 3.5) {
        float h = phoenix(q, iTime);
        glow += fire(h);
        glow += vec3(1.0, 0.4, 0.1) * 0.12 * exp(-length(q * vec2(0.5, 1.0)) * 0.8);  // warm aura
    }

    // Embers shed from the tail, sinking and dying out behind the bird.
    for (int i = 0; i < EMBERS; i++) {
        float fi = float(i);
        float age = fract(iTime * 0.4 + hash1(fi * 3.7));
        float born = iTime - age * 2.5;
        vec2 ep = birdPos(born, aspect) + vec2(0.04 + 0.08 * hash1(fi * 5.1), -0.01)
                + vec2((hash1(fi * 9.3) - 0.5) * 0.10, -0.06 - 0.04 * hash1(fi * 2.9)) * age;
        vec2 ed = p - ep;
        float tw = 0.6 + 0.4 * sin(iTime * 15.0 + fi * 4.0);
        glow += vec3(1.0, 0.55, 0.15) * (0.000008 / (dot(ed, ed) + 0.000006)) * (1.0 - age) * tw;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
