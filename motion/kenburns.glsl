// kenburns — the whole picture pushes in, drifts and tilts a little, like a slow
// documentary camera, with a soft band of light sweeping across now and then.
// Part of ghostty-bg, used by the viewing mode (bgv) only: it moves every pixel,
// so any text on screen would move with it. That is why bgv clears the screen first.

const float ZOOM_MIN = 1.10;    // never near 1: the edges must stay off screen
const float ZOOM_MAX = 1.34;    // how close the push-in gets
const float DRIFT    = 0.024;   // how far the centre wanders (fraction of the window)
const float TILT     = 0.018;   // how far the camera rolls, in radians (about 1 degree)
const float PERIOD   = 18.0;    // seconds for one push in and back out
const float SWEEP    = 0.07;    // brightness of the passing light (0 = off)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float turn = iTime * 6.2831 / PERIOD;

    float zoom = mix(ZOOM_MIN, ZOOM_MAX, 0.5 - 0.5 * cos(turn));
    // The centre and the roll each follow their own rhythm, so the move does not
    // repeat for a long while.
    vec2 centre = 0.5 + DRIFT * vec2(sin(turn / 1.3), cos(turn / 0.9));
    float roll = TILT * sin(turn / 1.7);

    // Rotate around the middle in square units, so the picture is not sheared.
    vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
    float c = cos(roll), s = sin(roll);
    q = vec2(c * q.x - s * q.y, s * q.x + c * q.y) / vec2(aspect, 1.0);

    // At ZOOM_MIN the picture overhangs the window by 0.5 * (1 - 1/1.10) = 0.045 on
    // each side. DRIFT (0.024) plus the corner swing of the roll (about 0.018) stays
    // inside that, so the sample never leaves the frame; clamp is only a safety net.
    vec2 src = centre + q / zoom;
    vec4 color = texture(iChannel0, clamp(src, 0.0, 1.0));

    // A wide, soft diagonal band of light drifts across the picture.
    float band = fract(iTime / (PERIOD * 1.5));
    float d = (uv.x + uv.y * 0.35) - mix(-0.5, 1.85, band);
    color.rgb += SWEEP * exp(-d * d / 0.03);

    fragColor = color;
}
