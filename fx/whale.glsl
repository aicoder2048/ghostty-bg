// whale — now and then a big whale glides slowly across, its tail fluke beating.
// zh: 鲸鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.30;   // overall strength (0 = off); kept low because the whale is big
const float PERIOD    = 80.0;   // seconds from the start of one crossing to the next
const float CROSS     = 48.0;   // seconds one crossing takes
const float SIZE      = 0.20;   // half the body length, as a fraction of the window height

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

    // Shift the clock so a whale is already crossing when the effect starts.
    float clock = iTime + 20.0;
    float t = mod(clock, PERIOD) / CROSS;                        // 0..1 while crossing
    float dir = mod(floor(clock / PERIOD), 2.0) < 0.5 ? 1.0 : -1.0;   // alternate sides

    vec3 rgb = base.rgb;
    if (t < 1.0) {
        float margin = 1.5 * SIZE;                               // fluke tip to snout
        float x = mix(-margin, aspect + margin, t);
        if (dir < 0.0) x = aspect - x;
        float y = 0.30 + 0.03 * sin(clock * 0.25);
        float tilt = 0.06 * cos(clock * 0.25);                   // nose follows the slow rise and fall

        vec2 q = (p - vec2(x, y)) / SIZE;
        q.x *= dir;                                              // face the way it swims
        q = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * q;

        float beat = sin(clock * 0.9);
        float fin = sin(clock * 0.45 + 1.0);
        float aa = 1.5 / (iResolution.y * SIZE);
        vec3 color = vec3(0.62, 0.82, 1.0);
        rgb = blend(rgb, color, whale(q, beat, fin, aa) * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
