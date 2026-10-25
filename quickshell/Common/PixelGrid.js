.pragma library

// At a fractional scale only every step-th logical position lands on a device pixel. Wayland scales come in 120ths
// (wp_fractional_scale_v1), so the step is 120 / gcd(120, scale * 120): 2 at 1.5, 4 at 1.25.
function _gcd(a, b) {
    while (b) {
        const t = b;
        b = a % b;
        a = t;
    }
    return a;
}

function gridStep(dpr) {
    const k = Math.round((dpr || 1) * 120);
    return k > 0 ? 120 / _gcd(120, k) : 1;
}

function gridFloor(value, dpr) {
    const step = gridStep(dpr);
    return Math.floor(value / step) * step;
}
