// phoenix — a great bird of flame sweeps across, wings beating slowly, long tail plumes flowing and shedding embers.
// zh: 凤凰
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const float SIZE      = 0.075;  // bird units in screen heights: the body is about 2 long
const float SPEED     = 0.115;  // screen heights per second
const float TAIL      = 0.48;   // tail plume length in screen heights
const float PAUSE     = 2.0;    // extra seconds off screen between passes
const int   LINKS     = 12;     // tail links (they follow the flight path, like a ribbon)
const int   FEATHERS  = 6;      // long feathers per wing
const int   EMBERS    = 18;
const float PI        = 3.14159265;

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

// The flight path by distance s travelled. dir = 1 flies right, -1 flies left.
// The tail follows this same curve behind the bird, so it ripples as it trails.
vec2 path(float s, float dir, float y0, float aspect) {
    float x = dir > 0.0 ? s : aspect - s;
    return vec2(x, y0 + 0.045 * sin(s * 5.5) + 0.02 * sin(s * 2.1 + 1.0));
}

// Body, head, crest and wings, in bird units with the bird facing +x.
// Returns heat: 0 = nothing, 1 = white-hot core.
float bird(vec2 q, float t) {
    float heat = smoothstep(1.1, 0.0, length(q / vec2(1.05, 0.42)));         // body
    vec2 nk = segment(q, vec2(0.6, 0.1), vec2(1.3, 0.45));                    // neck
    heat = max(heat, smoothstep(0.32, 0.04, nk.x));
    heat = max(heat, smoothstep(0.36, 0.06, length(q - vec2(1.42, 0.52))));   // head
    vec2 bk = segment(q, vec2(1.6, 0.52), vec2(2.0, 0.38));                   // beak
    heat = max(heat, smoothstep(0.10 * (1.0 - bk.y) + 0.03, 0.0, bk.x));
    // Crest: three flame plumes swept back from the head, flickering.
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        vec2 tip = vec2(0.55 - fj * 0.25, 1.15 + fj * 0.1 + 0.08 * sin(t * 5.0 + fj * 2.0));
        vec2 cr = segment(q, vec2(1.35, 0.72), tip);
        heat = max(heat, smoothstep(mix(0.13, 0.04, cr.y), 0.0, cr.x) * 0.85);
    }

    // Wings: a broad fan of feathers from the shoulder, beating slowly from
    // up-back to down-back. Mid-stroke the wing points at us, so it looks shorter.
    // The far wing is drawn a little behind and dimmer.
    for (int w = 0; w < 2; w++) {
        float far = float(w);
        float beat = sin(t * 2.3 - far * 0.35);
        beat = sign(beat) * pow(abs(beat), 0.7);                              // linger at the ends
        float theta = 3.05 + 1.35 * beat;
        float spread = clamp((PI - theta) * 3.0, -1.0, 1.0);                  // fan toward the tail
        float reach = (0.55 + 0.45 * abs(beat)) * (1.0 - 0.15 * far);
        vec2 sh = vec2(0.25 - far * 0.25, 0.25 + far * 0.1);
        // Soft flame membrane filling the fan between the feathers.
        vec2 dq = q - sh;
        float rel = (atan(dq.y, dq.x) - theta) / (spread * 0.17 * float(FEATHERS - 1) + 1e-3);
        float mem = step(0.0, rel) * step(rel, 1.0) * step(0.1, abs(spread));
        heat = max(heat, mem * smoothstep(3.0 * reach, 1.2 * reach, length(dq)) * 0.6 * mix(1.0, 0.55, far));
        for (int j = 0; j < FEATHERS; j++) {
            float fj = float(j);
            float th = theta + spread * fj * 0.17;
            vec2 fe = segment(q, sh, sh + vec2(cos(th), sin(th)) * (3.3 - fj * 0.32) * reach);
            float flick = 0.8 + 0.4 * noise(q * 2.5 + vec2(0.0, -t * 4.0));
            float f = smoothstep(mix(0.60, 0.20, fe.y), 0.0, fe.x) * mix(1.0, 0.7, fe.y);
            heat = max(heat, f * mix(1.0, 0.55, far) * mix(1.0, flick, fe.y));
        }
    }
    return heat;
}

// Fire colours: deep red at the edges, through orange and gold to white-hot.
vec3 fire(float h) {
    return vec3(0.9, 0.12, 0.03) * smoothstep(0.0, 0.35, h)
         + vec3(0.1, 0.45, 0.07) * smoothstep(0.25, 0.7, h)
         + vec3(0.0, 0.25, 0.45) * smoothstep(0.7, 1.0, h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Passes alternate direction and height. The clock is offset so the bird
    // is already well on screen when the effect starts.
    float travel = aspect + TAIL + 0.6;
    float period = travel / SPEED + PAUSE;
    float tt = iTime + 4.0;
    float cyc = floor(tt / period);
    float dir = mod(cyc, 2.0) < 0.5 ? 1.0 : -1.0;
    float y0 = mix(0.30, 0.46, hash1(cyc * 4.1 + 1.0));
    float sh = mod(tt, period) * SPEED - 0.25;               // bird position along the path

    vec3 glow = vec3(0.0);
    vec2 head = path(sh, dir, y0, aspect);
    vec2 f = normalize(path(sh + 0.01, dir, y0, aspect) - path(sh - 0.01, dir, y0, aspect));
    vec2 n = vec2(-f.y, f.x) * dir;                          // keep "up" up in either direction

    // Only work near the bird.
    float behind = dot(p - head, f);
    if (behind > -TAIL - 0.2 && behind < 0.25 && abs(p.y - head.y) < 0.35) {
        // Body and wings in the bird's own frame.
        vec2 q = vec2(dot(p - head, f), dot(p - head, n)) / SIZE;
        float heat = bird(q, iTime);

        // Tail: find the nearest point on a chain that follows the path, then
        // draw three plumes in (along, across) coordinates around it.
        float best = 1e5, u = 0.0, v = 0.0;
        float s0 = sh - SIZE * 0.7;
        vec2 prev = path(s0, dir, y0, aspect);
        for (int k = 1; k <= LINKS; k++) {
            vec2 cur = path(s0 - TAIL * float(k) / float(LINKS), dir, y0, aspect);
            vec2 sg = segment(p, prev, cur);
            if (sg.x < best) {
                best = sg.x;
                u = (float(k - 1) + sg.y) / float(LINKS);
                vec2 ba = cur - prev, pa = p - prev;
                v = -(ba.x * pa.y - ba.y * pa.x) / length(ba) * dir;   // + is above the tail
            }
            prev = cur;
        }
        // Nothing in front of where the tail starts (the nearest-link trick
        // would otherwise smear the first plume forward).
        float tailSide = step(dot(p - path(s0, dir, y0, aspect), f), 0.0)
                       * smoothstep(0.01, 0.0, best - abs(v));   // and nothing past its end
        float flick = 0.75 + 0.45 * noise(vec2(u * 14.0 - iTime * 5.0, v * 40.0));
        for (int j = 0; j < 3; j++) {
            float fj = float(j) - 1.0;
            float end = 0.84 + 0.12 * (1.0 - abs(fj));                      // middle plume longest
            float vj = (fj * 0.07 - 0.015) * u + 0.035 * sin(u * 7.0 - iTime * 3.0 + fj * 1.7) * u;
            float w = mix(0.020, 0.006, u);
            float plume = smoothstep(w, 0.0, abs(v - vj)) * step(u, end) * mix(1.0, 0.55, u);
            float vEnd = (fj * 0.07 - 0.015) * end + 0.035 * sin(end * 7.0 - iTime * 3.0 + fj * 1.7) * end;
            float eye = smoothstep(0.022, 0.004, length(vec2((u - end) * TAIL, v - vEnd)));   // flame tip
            heat = max(heat, max(plume * flick, eye * 0.85) * tailSide);
        }

        glow += fire(heat);
        glow += vec3(1.0, 0.35, 0.08) * 0.10 * exp(-length(q * vec2(0.45, 0.8)) * 0.9);   // warm aura
    }

    // Embers shed from wings and tail, sinking and dying out behind the bird.
    for (int i = 0; i < EMBERS; i++) {
        float fi = float(i);
        float age = fract(iTime * 0.35 + hash1(fi * 3.7));
        float sb = sh - age * 2.8 * SPEED - TAIL * 0.6 * hash1(fi * 7.9);  // where along the trail it fell
        vec2 ep = path(sb, dir, y0, aspect)
                + vec2(0.0, (hash1(fi * 5.1) - 0.4) * 0.18)
                + vec2((hash1(fi * 9.3) - 0.5) * 0.06, -0.10 * age * age - 0.03 * age);
        vec2 ed = p - ep;
        float tw = 0.6 + 0.4 * sin(iTime * 14.0 + fi * 4.0);
        glow += mix(vec3(1.0, 0.45, 0.1), vec3(1.0, 0.8, 0.4), hash1(fi)) *
                (0.000010 / (dot(ed, ed) + 0.000007)) * (1.0 - age) * tw;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
