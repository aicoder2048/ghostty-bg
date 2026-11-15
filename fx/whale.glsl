// whale — a big whale glides slowly across, fluke beating, now and then blowing a spout.
// zh: 鲸鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.32;   // overall strength (0 = off); kept low because the whale is big
const float PERIOD    = 42.0;   // seconds from the start of one crossing to the next
const float CROSS     = 30.0;   // seconds one crossing takes (then about 12 s of open water)
const float WIDTH     = 0.38;   // whale length as a fraction of the window width
const float SPOUT     = 7.0;    // seconds between two spouts
const int   DROPS     = 20;     // water drops in one spout

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// How far the spine is lifted at x: only the back half bends, more toward the tail.
float bendAt(float x, float beat) {
    float t = clamp((0.25 - x) / 1.25, 0.0, 1.5);
    return beat * 0.16 * t * t;
}

// A whale seen from the side, facing +x. The body runs from x = -1 (tail root)
// to about x = 1.05 (snout); beat runs from -1 to 1 and moves the tail up and down;
// fin swings the long pectoral fin. aa is the edge softness in whale units.
float whale(vec2 q, float beat, float fin, float aa) {
    float bend = bendAt(q.x, beat);
    float y = q.y - bend;

    // Half thickness along the body: a round head, thickest behind it, then a long
    // taper to a thin tail stock. The belly hangs a bit lower than the back.
    float h;
    if (q.x > 0.25) {
        float k = (q.x - 0.25) / 0.80;
        h = 0.20 * pow(max(1.0 - k * k, 0.0), 0.45);
    } else {
        float k = (0.25 - q.x) / 1.25;
        h = 0.032 + 0.168 * (1.0 - k * k);
    }
    h *= y > 0.0 ? 0.85 : 1.10;
    float body = smoothstep(aa, -aa, max(abs(y) - h, max(-1.0 - q.x, q.x - 1.05)));

    // Tail fluke: two swept-back lobes that tilt with the tail as it beats.
    vec2 root = vec2(-1.0, bendAt(-1.0, beat));
    float slope = -0.256 * beat;                                  // d(bend)/dx at the root
    vec2 back = normalize(vec2(-1.0, -slope));
    vec2 f = q - root;
    float fx = dot(f, back);
    float fy = abs(dot(f, vec2(-back.y, back.x)));
    float fluke = smoothstep(aa, -aa, max(max(0.80 * fy - 0.03 - fx, fx - 0.08 - 1.0 * fy), fy - 0.26));

    // Long pectoral fin under the front of the body, rowing slowly.
    vec2 froot = vec2(0.40, -0.12 + bendAt(0.40, beat));
    float ang = -2.05 + 0.25 * fin;
    vec2 pf = segment(q, froot, froot + 0.50 * vec2(cos(ang), sin(ang)));
    float pec = smoothstep(aa, -aa, pf.x - mix(0.055, 0.018, pf.y));

    // Small hooked dorsal fin far back on the spine.
    float b = bendAt(-0.40, beat);
    vec2 df = segment(q, vec2(-0.32, 0.12 + b), vec2(-0.50, 0.20 + b));
    float dorsal = smoothstep(aa, -aa, df.x - mix(0.04, 0.008, df.y));

    float shape = max(max(body, fluke), max(pec, dorsal));

    // Darker details cut into the light shape: eye, mouth line, throat grooves.
    float eye = smoothstep(0.026, 0.014, length(q - vec2(0.74, -0.02)));
    float mouth = smoothstep(0.022, 0.008, segment(q, vec2(1.02, -0.07), vec2(0.56, -0.11)).x);
    float grooves = step(y, -0.10) * step(0.30, q.x) * smoothstep(0.5, 0.9, sin(y * 110.0));
    float shade = smoothstep(-0.10, 0.18, y) * body;              // darker back, pale belly
    return shape * (1.0 - 0.3 * shade) * (1.0 - 0.85 * eye - 0.6 * mouth - 0.3 * grooves);
}

// A spout: drops thrown up from the blowhole in a narrow fan, falling back
// under gravity and drifting behind the whale as it swims on. q is in whale
// units, age is seconds since the spout started.
float spout(vec2 q, float age) {
    vec2 hole = vec2(0.52, 0.17);
    float light = 0.0;
    for (int k = 0; k < DROPS; k++) {
        float fk = float(k);
        float a = age - fk * 0.04;                                // drops leave one after another
        if (a < 0.0 || a > 2.2) continue;
        float h1 = hash1(fk * 12.9898 + 1.0);
        float h2 = hash1(fk * 78.233 + 2.0);
        vec2 v = vec2((h1 - 0.5) * 0.8, 2.0 + 0.8 * h2);           // up, spreading into a V
        vec2 pos = hole + v * a + vec2(-0.25 * a, -1.4 * a * a);  // gravity, and left behind
        float r = mix(0.030, 0.055, h2) * (1.0 + 0.6 * a);         // drops spread into mist
        float fade = 1.0 - a / 2.2;
        light += smoothstep(r, r * 0.3, length(q - pos)) * fade * 0.8;
    }
    // A soft misty column shooting up first, then thinning out.
    float rise = min(age * 2.5, 1.0) * 0.85;
    vec2 pa = q - hole;
    float hcol = clamp(pa.y / max(rise, 0.01), 0.0, 1.0);
    float col = smoothstep(0.10, 0.0, length(pa - vec2(-0.08 * hcol, rise * hcol)) - 0.03 * hcol);
    light += col * 0.5 * max(0.0, 1.0 - age / 1.6);
    return min(light, 1.0);
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

    // Big things big: the whale is a fixed share of the window width, capped so a
    // very wide window does not make it taller than the lower half.
    float size = min(WIDTH * aspect / 2.45, 0.42);               // half the body length

    // Shift the clock so the whale is already well inside the window at start.
    float clock = iTime + 0.30 * CROSS;
    float t = mod(clock, PERIOD) / CROSS;                        // 0..1 while crossing
    float dir = mod(floor(clock / PERIOD), 2.0) < 0.5 ? 1.0 : -1.0;   // alternate sides

    vec3 rgb = base.rgb;
    if (t < 1.0) {
        float margin = 1.45 * size;                              // fluke tip to snout
        float x = mix(-margin, aspect + margin, t);
        if (dir < 0.0) x = aspect - x;
        float y = 0.30 + 0.03 * sin(clock * 0.25);
        float tilt = 0.06 * cos(clock * 0.25);                   // nose follows the slow rise and fall

        vec2 q = (p - vec2(x, y)) / size;
        q.x *= dir;                                              // face the way it swims
        q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;

        float beat = sin(clock * 0.9);
        float fin = sin(clock * 0.45 + 1.0);
        float aa = 1.5 / (iResolution.y * size);
        float a = whale(q, beat, fin, aa);
        a = max(a, spout(q, mod(iTime - 1.5, SPOUT)) * 0.9);   // first spout 1.5 s in
        rgb = blend(rgb, vec3(0.62, 0.82, 1.0), a * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
