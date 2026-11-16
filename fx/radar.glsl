// radar — a holographic sonar scope in the lower right: fine range rings, a phosphor sweep with a long fading trail, and tracked contacts.
// zh: 雷达
// group: geek
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float RADIUS    = 0.19;   // scope radius, in window-heights (diameter ~38% of the window)
const float MARGIN    = 0.06;   // gap between the scope and the bottom/right edges
const float SWEEP     = 0.85;   // sweep speed, radians per second (one turn ~7.4 s)
const float TRAIL     = 0.40;   // how quickly the phosphor trail behind the beam fades (smaller = longer)
const float AFTERGLOW = 0.32;   // how quickly a contact fades after the beam lights it (smaller = longer)
const float GLASS     = 0.22;   // how much the scope glass dims the background inside it (contrast for the lines)
const float FLICKER   = 0.04;   // CRT phosphor shimmer
const int   CONTACTS  = 6;      // tracked targets; each also leaves 3 history dots

const float PI  = 3.14159265;
const float TAU = 6.28318531;

// Teal-green phosphor, and a paler tint for the hottest spots.
const vec3 PHOS = vec3(0.30, 0.95, 0.78);
const vec3 HOT  = vec3(0.80, 1.00, 0.95);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

// A thin luminous line: crisp core plus a soft phosphor halo.
float line(float dist, float w, float halo) {
    return smoothstep(w, 0.0, dist) + exp(-dist / halo) * 0.25;
}

// Bearing measured clockwise from "north", like a real scope.
float bearing(vec2 v) { return mod(atan(v.x, v.y), TAU); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 c = vec2(aspect - RADIUS - MARGIN, RADIUS + MARGIN);
    vec2 d = p - c;
    float r = length(d);

    // Pixels well outside the scope cost nothing.
    if (r > RADIUS * 1.22 || INTENSITY <= 0.0) {
        fragColor = base;
        return;
    }

    float px = 1.0 / iResolution.y;          // one pixel in scene units
    float R = RADIUS;
    float inside = smoothstep(R + px, R - px, r);
    float th = bearing(d);
    float deg = th * 360.0 / TAU;

    // Gentle power-on fade so the first frame doesn't pop.
    float boot = smoothstep(0.0, 0.8, iTime);

    float light = 0.0;   // ordinary phosphor
    float hot = 0.0;     // extra-bright highlights (beam edge, fresh blips)

    // --- Glass: a faint radial wash so the scope reads as a lit surface.
    light += inside * (0.04 + 0.05 * (1.0 - r / R));

    // --- Bezel: a double outer ring with a soft glow spilling outward.
    light += line(abs(r - R), 1.4 * px, 2.5 * px) * 0.75;
    light += line(abs(r - R * 1.045), 0.9 * px, 1.5 * px) * 0.30;
    light += exp(-max(r - R, 0.0) / (0.02 * R)) * (1.0 - inside) * 0.10;

    // --- Range rings at 1/4, 2/4, 3/4; the 2/4 ring is dashed every 5 degrees.
    float rr = r / (R * 0.25);
    float ringD = abs(rr - floor(rr + 0.5)) * R * 0.25;
    float ringIdx = floor(rr + 0.5);
    float dash = (ringIdx == 2.0) ? step(0.5, fract(deg / 5.0)) * 0.6 + 0.4 : 1.0;
    light += inside * step(0.5, ringIdx) * step(ringIdx, 3.5) * line(ringD, 0.8 * px, 1.6 * px) * 0.32 * dash;

    // --- Spokes every 30 degrees, faint, fading toward the centre.
    float spokeA = abs(fract(deg / 30.0 + 0.5) - 0.5) * 30.0 * TAU / 360.0;
    float spokeD = spokeA * r;
    light += inside * line(spokeD, 0.6 * px, 1.2 * px) * 0.14 * smoothstep(0.08 * R, 0.4 * R, r);

    // --- Faint square grid behind everything, clipped to the glass.
    vec2 g = abs(fract(d / (R * 0.125) + 0.5) - 0.5) * R * 0.125;
    light += inside * smoothstep(0.7 * px, 0.0, min(g.x, g.y)) * 0.05;

    // --- Degree ticks around the rim: 5 deg minor, 10 deg medium, 30 deg major.
    float tick5 = abs(fract(deg / 5.0 + 0.5) - 0.5) * 5.0 * TAU / 360.0 * r;
    float tick10 = abs(fract(deg / 10.0 + 0.5) - 0.5) * 10.0 * TAU / 360.0 * r;
    float tick30 = abs(fract(deg / 30.0 + 0.5) - 0.5) * 30.0 * TAU / 360.0 * r;
    float band5  = step(R - 0.035 * R, r) * step(r, R);
    float band10 = step(R - 0.06 * R, r) * step(r, R);
    float band30 = step(R - 0.10 * R, r) * step(r, R * 1.045);
    light += band5  * smoothstep(0.7 * px, 0.0, tick5)  * 0.40;
    light += band10 * smoothstep(0.8 * px, 0.0, tick10) * 0.45;
    light += band30 * smoothstep(1.0 * px, 0.0, tick30) * 0.60;

    // Degree "labels": a tiny pair of dashes just outside each 30-degree tick,
    // standing in for numerals without needing real text.
    float lr = R * 1.10;
    float labelBand = smoothstep(1.6 * px, 0.0, abs(r - lr) - 0.012 * R);
    float lt = abs(fract(deg / 30.0 + 0.5) - 0.5) * 30.0 * TAU / 360.0 * lr;  // tangential distance
    float glyph = smoothstep(0.8 * px, 0.0, abs(lt - 0.011 * R) - 0.6 * px)
                + smoothstep(0.8 * px, 0.0, abs(lt - 0.026 * R) - 0.6 * px) * step(0.5, fract(deg / 60.0 + 0.25));
    light += labelBand * glyph * step(lt, 0.035 * R) * 0.45;

    // Centre pip and a tiny crosshair.
    light += line(r, 1.5 * px, 2.0 * px) * 0.6;
    light += inside * smoothstep(0.7 * px, 0.0, min(abs(d.x), abs(d.y))) * step(r, 0.06 * R) * 0.35;

    // --- Sweep beam: rotates clockwise; behind = radians since it passed here.
    float sw = mod(iTime * SWEEP + 2.2, TAU);   // start partway round so a trail exists at once
    float behind = mod(sw - th, TAU);
    // Grain in the trail: fine radial striations like a phosphor raster, slowly crawling.
    float grain = 0.75 + 0.25 * hash21(vec2(floor(r / (1.5 * px)), floor(iTime * 12.0)));
    float trail = exp(-behind * TRAIL) * (1.0 - smoothstep(TAU - 0.15, TAU, behind));
    light += inside * trail * 0.55 * grain * smoothstep(0.0, 0.25 * R, r + 0.05 * R);
    // Leading edge: a thin bright line with a soft forward bleed.
    float edge = behind * r;                     // arc distance behind the beam
    float ahead = (TAU - behind) * r;            // arc distance in front of it
    hot += inside * (smoothstep(1.6 * px, 0.0, edge) * 0.9 + exp(-edge / (4.0 * px)) * 0.35
                     + exp(-ahead / (1.5 * px)) * 0.25);

    // --- Contacts: each drifts along a straight track; the beam lights it up
    // and it fades with afterglow. A few earlier positions remain as history dots.
    float br = 0.0;
    float sweepPeriod = TAU / SWEEP;
    for (int i = 0; i < CONTACTS; i++) {
        float fi = float(i);
        float life = 46.0 + 9.0 * fi;                      // each contact lives this long, then is replaced
        float tl = iTime + fi * 13.0 + 20.0;
        float ep = floor(tl / life);
        float age = tl - ep * life;
        float s = fi * 17.13 + ep * 5.71;
        float fade = smoothstep(0.0, 6.0, age) * smoothstep(life, life - 6.0, age);

        // Start somewhere in the outer two-thirds, move slowly (some barely move).
        float a0 = hash1(s) * TAU;
        float r0 = mix(0.25, 0.85, hash1(s + 1.0)) * R;
        vec2 start = r0 * vec2(sin(a0), cos(a0));
        float hd = hash1(s + 2.0) * TAU;
        float spd = (hash1(s + 3.0) < 0.35 ? 0.0 : mix(0.0012, 0.0035, hash1(s + 4.0))) * R / 0.19;
        vec2 vel = spd * vec2(sin(hd), cos(hd));

        vec2 q = start + vel * age;
        float qr = length(q);
        fade *= smoothstep(R * 0.97, R * 0.9, qr);
        if (fade <= 0.001) continue;

        // Afterglow: brightest just after the beam crossed it.
        float since = mod(sw - bearing(q), TAU);
        float glow = exp(-since * AFTERGLOW) * fade;
        float flash = exp(-since * 6.0) * fade;

        vec2 dq = d - q;
        float dd = length(dq);
        float blip = exp(-dd * dd / (2.0 * pow(0.017 * R, 2.0)));
        light += blip * glow * 1.6 + exp(-dd / (0.03 * R)) * glow * 0.22;
        hot += blip * flash * 0.8 + exp(-dd / (0.05 * R)) * flash * 0.25;

        // History: where it was on the last three sweeps, fainter each time.
        if (spd > 0.0) {
            for (int k = 1; k <= 3; k++) {
                vec2 h = q - vel * sweepPeriod * float(k);
                float hdd = length(d - h);
                light += smoothstep(0.013 * R, 0.004 * R, hdd) * fade * (0.6 - 0.15 * float(k));
            }
        }

        // Track brackets: four corner marks and a short "label" tick to the right,
        // shown while the contact is still glowing.
        float bs = 0.055 * R;                      // half-size of the bracket box
        vec2 ad = abs(dq);
        float onBox = max(ad.x, ad.y);
        float corner = step(bs * 0.45, min(ad.x, ad.y));   // keep only the corners
        float bracket = smoothstep(0.8 * px, 0.0, abs(onBox - bs)) * corner * step(onBox, bs + px);
        // Label: two tiny stacked dashes beside the box.
        vec2 lp = dq - vec2(bs * 1.5, bs * 0.55);
        float lab = smoothstep(0.7 * px, 0.0, abs(lp.y) - 0.5 * px) * step(0.0, lp.x) * step(lp.x, bs * 1.1)
                  + smoothstep(0.7 * px, 0.0, abs(lp.y + bs * 0.45) - 0.5 * px) * step(0.0, lp.x) * step(lp.x, bs * 0.7);
        float show = smoothstep(0.05, 0.35, glow) * step(fi, 3.5);
        light += (bracket * 0.55 + lab * 0.4) * show;
        br = max(br, blip * glow);
    }

    // --- CRT feel: faint horizontal scanlines and a gentle shimmer.
    float scan = 0.9 + 0.1 * sin(fragCoord.y * PI * 0.5);
    float flick = 1.0 + FLICKER * (sin(iTime * 47.0) * 0.5 + hash1(floor(iTime * 24.0)) - 0.5);
    float noise = (hash21(fragCoord + floor(iTime * 30.0)) - 0.5) * 0.04 * inside;

    light = (light + noise) * scan * flick * boot;
    hot *= flick * boot;

    // Bloom-ish tone curve: soft saturation keeps the brightest parts from clipping hard.
    vec3 col = PHOS * (1.0 - exp(-light * 1.4)) + HOT * (1.0 - exp(-hot * 1.2)) * 0.8;

    // Glass dims the background a little inside the scope, then light is added on top.
    vec3 bg = base.rgb * (1.0 - GLASS * inside * boot);
    fragColor = vec4(bg + col * 0.75 * INTENSITY, base.a);
}
