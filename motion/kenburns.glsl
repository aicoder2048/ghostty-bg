// kenburns — the whole picture slowly pushes in and drifts, like a documentary camera.
// Part of ghostty-bg, used by the viewing mode (bgv) only: it moves every pixel,
// so any text on screen would move with it. That is why bgv clears the screen first.

const float ZOOM_MIN = 1.05;    // never below 1: the edges must stay off screen
const float ZOOM_MAX = 1.15;
const float DRIFT    = 0.018;   // how far the centre wanders (fraction of the window)
const float PERIOD   = 36.0;    // seconds for one push in and back out

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    float zoom = mix(ZOOM_MIN, ZOOM_MAX, 0.5 - 0.5 * cos(iTime * 6.2831 / PERIOD));
    // The centre wanders on two different rhythms, so the path does not repeat soon.
    vec2 centre = 0.5 + DRIFT * vec2(sin(iTime * 6.2831 / (PERIOD * 1.3)),
                                     cos(iTime * 6.2831 / (PERIOD * 0.9)));

    // At ZOOM_MIN the picture overhangs the window by 0.5 * (1 - 1/1.05) = 0.0238
    // on each side, which is more than DRIFT, so the sample never leaves the frame.
    vec2 src = centre + (uv - 0.5) / zoom;
    fragColor = texture(iChannel0, clamp(src, 0.0, 1.0));
}
