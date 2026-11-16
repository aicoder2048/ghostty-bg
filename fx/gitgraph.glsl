// gitgraph — a git client's history view on the right: coloured branch lanes fork off main, collect commits and merge back while the graph scrolls down.
// zh: Git 分支图
// group: geek
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float RATE      = 0.55;   // new commits per second
const float ROW       = 0.052;  // row height (commit spacing), in window heights
const float LANE_GAP  = 0.042;  // spacing between lanes, in window heights
const float GRAPH_X   = 0.68;   // left edge of the graph area, in window widths
const float TOP_Y     = 0.86;   // where new commits appear, in window heights from the bottom
const float BOTTOM_Y  = 0.05;   // the graph fades out below this
const float DOT_R     = 0.0110; // commit dot radius, in window heights
const float LINE_W    = 0.0021; // lane line width, in window heights
const float LINE_A    = 0.70;   // lane line opacity
const float DOT_A     = 0.92;   // commit dot opacity
const float MSG_A     = 0.13;   // opacity of the faint "commit message" bars (0 = none)
const float TAG_CHANCE = 0.13;  // share of plain main commits that get a tag

const int   LANES = 4;          // side lanes next to main
const int   MAXSCAN = 24;       // rows searched back for a lane's head commit
// Each side lane hosts one branch per block of PER rows (some blocks stay empty).
const float PER[4] = float[4](13.0, 16.0, 19.0, 23.0);
const float OFF[4] = float[4](0.0, 6.0, 11.0, 3.0);
const float SKIP[4] = float[4](0.0, 0.08, 0.20, 0.35);

// Calm, slightly desaturated lane colours in the spirit of GitKraken / Fork.
const vec3 COL[5] = vec3[5](
    vec3(0.38, 0.64, 1.00),     // main: blue
    vec3(0.72, 0.52, 0.98),     // violet
    vec3(0.32, 0.80, 0.62),     // green
    vec3(0.98, 0.64, 0.32),     // orange
    vec3(0.95, 0.45, 0.60)      // pink
);
const vec3 DARK = vec3(0.075, 0.085, 0.105);
const vec3 TAG  = vec3(0.98, 0.80, 0.38);
const float INF = 1e9;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// The branch that side lane l holds around row r: it forks off main at row s
// and merges back into main at row e. on = 0 when this block has no branch.
void branchAt(int l, float r, out float s, out float e, out float on) {
    float P = PER[l];
    float b = floor((r - OFF[l]) / P);
    float seed = b * 1.731 + float(l) * 17.13;
    on = step(SKIP[l], hash1(seed + 0.3));
    s = b * P + OFF[l] + floor(hash1(seed + 1.1) * 3.0);
    e = s + 3.0 + floor(hash1(seed + 2.7) * (P - 6.0));   // always ends before the next block
}

// Which lane commit row k sits on (0 = main), and whether it is a merge commit.
int commitLane(float k, out bool merge) {
    merge = false;
    bool forceMain = false;
    int first = -1;
    int n = 1;
    for (int l = 0; l < LANES; l++) {
        float s, e, on;
        branchAt(l, k, s, e, on);
        if (on < 0.5) continue;
        if (k == s) forceMain = true;                 // fork point lives on main
        if (k == e) { forceMain = true; merge = true; }
        if (k > s && k < e) {
            n++;
            if (k == s + 1.0 && first < 0) first = l + 1;   // first commit on a new branch
        }
    }
    if (forceMain) return 0;
    if (first >= 0) return first;
    if (hash1(k * 3.17 + 0.5) < 0.12) return 0;       // main keeps getting commits too
    int pick = int(floor(hash1(k * 1.37 + 9.1) * float(n)));
    if (pick == 0) return 0;
    int seen = 0;
    for (int l = 0; l < LANES; l++) {
        float s, e, on;
        branchAt(l, k, s, e, on);
        if (on > 0.5 && k > s && k < e) {
            seen++;
            if (seen == pick) return l + 1;
        }
    }
    return 0;
}

// Where lane `lane`'s line currently ends (a row coordinate): its newest node at
// or below `hi`, scanning down to `lo`. Nodes are the lane's commits plus `endRow`
// (the merge it flows into). If that node is brand new, the line grows toward it
// from the node before.
float laneTip(int lane, float lo, float hi, float endRow, float newest, float grow) {
    float h = -1.0, prev = lo;
    float r = hi;
    for (int i = 0; i < MAXSCAN; i++) {
        if (r <= lo) break;
        bool m;
        if (r == endRow || commitLane(r, m) == lane) {
            if (h < 0.0) {
                h = r;
                if (h < newest) return h;
            } else { prev = r; break; }
        }
        r -= 1.0;
    }
    if (h < 0.0) return lo;
    return mix(prev, h, grow);
}

float easeOutBack(float t) {
    float c = 1.6;
    t -= 1.0;
    return 1.0 + (c + 1.0) * t * t * t + c * t * t;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;                  // one pixel, in scene units

    float x0 = GRAPH_X * aspect + 0.055;              // main lane (room for tags on its left)
    // Pixels well away from the graph cost nothing.
    if (p.x < x0 - 0.06 || p.y > TOP_Y + ROW || p.y < BOTTOM_Y - ROW) {
        fragColor = base;
        return;
    }

    // Start deep into the history so the graph is full from the first frame.
    float T = iTime * RATE + 1000.0;
    float newest = floor(T);                         // the latest commit row
    float fr = fract(T);
    float grow = smoothstep(0.0, 0.35, fr);          // line reaching up to the new commit

    // Continuous row coordinate of this pixel (row k sits at y = TOP_Y - (T - k) * ROW).
    float rf = T - (TOP_Y - p.y) / ROW;
    float rowFloor = floor(rf);

    // Fade the oldest rows out at the bottom.
    float fade = smoothstep(BOTTOM_Y - 0.5 * ROW, BOTTOM_Y + 2.0 * ROW, p.y);

    vec4 acc = vec4(0.0);

    // ---------------------------------------------------------------- lane lines
    // Each lane's line ends at its newest node (its head commit, or the merge it
    // flows into), and grows smoothly up to a node that has just appeared.
    float hw = 0.5 * LINE_W;
    {
        float dm = abs(p.x - x0);
        float cov = smoothstep(hw + px, hw, dm);
        if (cov > 0.0 && rf > newest - float(MAXSCAN)) {
            float tip = laneTip(0, newest - float(MAXSCAN), newest, -1.0, newest, grow);
            cov *= smoothstep(tip + 0.03, tip - 0.03, rf);
        }
        over(acc, COL[0], cov * LINE_A);
    }
    for (int l = 0; l < LANES; l++) {
        float s, e, on;
        branchAt(l, rowFloor, s, e, on);
        if (on < 0.5 || rf < s || rf > e || s >= newest) continue;
        float xl = x0 + float(l + 1) * LANE_GAP;
        float d;
        if (rf < s + 1.0 || rf > e - 1.0) {
            // S-shaped connector over one row: fork out of main, or merge back.
            float t = rf < s + 1.0 ? rf - s : e - rf;
            float sm = t * t * (3.0 - 2.0 * t);
            float xc = mix(x0, xl, sm);
            float slope = (xl - x0) * 6.0 * t * (1.0 - t) / ROW;
            d = abs(p.x - xc) / sqrt(1.0 + slope * slope);
        } else {
            d = abs(p.x - xl);
        }
        float cov = smoothstep(hw + px, hw, d);
        if (cov <= 0.0) continue;
        float tip = laneTip(l + 1, s, min(e, newest), e, newest, grow);
        cov *= smoothstep(tip + 0.03, tip - 0.03, rf);
        over(acc, COL[l + 1], cov * LINE_A);
    }

    // ---------------------------------------------------------------- commits
    float k = floor(rf + 0.5);
    if (k <= newest) {
        bool merge;
        int lane = commitLane(k, merge);
        vec2 c = vec2(x0 + float(lane) * LANE_GAP, TOP_Y - (T - k) * ROW);
        // The newest commit pops in once its line has arrived.
        float pop = k < newest ? 1.0 : easeOutBack(clamp((fr - 0.25) / 0.3, 0.0, 1.0));
        pop = max(pop, 0.0);
        float R = (merge ? 1.25 : 1.0) * DOT_R * pop;
        float d = length(p - c);
        vec3 col = COL[lane];

        // dark gap ring that separates the dot from the lines running into it
        over(acc, DARK, smoothstep(R + 2.0 * px + px, R + 2.0 * px, d) * 0.75 * step(0.001, pop));
        // the dot: coloured disc with a dark centre (merge commits: solid, light core)
        float disc = smoothstep(R + px, R, d);
        over(acc, col, disc * DOT_A);
        float ri = R * (merge ? 0.32 : 0.50);
        vec3 core = merge ? mix(col, vec3(1.0), 0.65) : DARK;
        over(acc, core, smoothstep(ri + px, ri, d) * DOT_A);

        // a thin ring ripples out from a brand-new commit
        if (k == newest) {
            float t = clamp((fr - 0.3) / 0.6, 0.0, 1.0);
            float rr = DOT_R * (1.2 + 1.8 * t);
            float ring = smoothstep(1.4 * px, 0.4 * px, abs(d - rr));
            over(acc, col, ring * (1.0 - t) * 0.6 * step(0.001, t));
        }

        // a tag flag on some plain main commits, pointing at the dot
        if (lane == 0 && !merge && hash1(k * 7.31 + 2.2) < TAG_CHANCE) {
            float th = 0.017, tw = 0.032;
            vec2 q = p - vec2(c.x - R - 0.006, c.y);   // tip of the flag
            vec2 bq = q - vec2(-0.5 * (tw + 0.5 * th), 0.0);
            vec2 dd = abs(bq) - vec2(0.5 * (tw + 0.5 * th), 0.5 * th);
            float box = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0);
            float tagD = max(box, (abs(q.y) + q.x) * 0.7071);
            float tag = smoothstep(px, 0.0, tagD) * pop;
            over(acc, TAG * 0.92, tag * 0.88);
            // eyelet
            float hole = smoothstep(0.0024 + px, 0.0024, length(q - vec2(-0.5 * th - 0.002, 0.0)));
            over(acc, DARK, hole * tag * 0.9);
        }

        // faint "message" bars to the right, like the text column of the history view
        if (MSG_A > 0.0) {
            float mx = x0 + float(LANES + 1) * LANE_GAP;
            float len = (0.07 + 0.12 * hash1(k * 4.13 + 1.7)) * pop;
            float bh = 0.0055;
            vec2 m = p - vec2(mx + 0.5 * len, c.y);
            vec2 dd = abs(m) - vec2(0.5 * len, 0.0);
            float bar = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0) - bh * 0.5;
            over(acc, vec3(0.80, 0.84, 0.90), smoothstep(px, 0.0, bar) * MSG_A);
            // a lane-coloured stub at the start (branch badge feel), only on fresh branch heads
            float stub = length(max(abs(p - vec2(mx - 0.012, c.y)) - vec2(0.004, 0.0), 0.0)) - bh * 0.5;
            over(acc, col, smoothstep(px, 0.0, stub) * MSG_A * 1.6);
        }
    }

    acc *= fade * INTENSITY;
    vec3 rgb = base.rgb * (1.0 - acc.a) + acc.rgb;
    fragColor = vec4(rgb, base.a);
}
