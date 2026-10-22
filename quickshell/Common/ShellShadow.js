.pragma library

// One drop shadow for niri's windows and the shell, from one set of values. NiriService writes it into niri's layout
// config (`shadow { ... }`) and the frame shader draws the same model. niri's own numbers: softness 30, spread 5,
// offset (0, 5), color "#0007" (css-style #rgba: the last digit is alpha, unlike Qt's #argb).

var DEFAULTS = { softness: 30, spread: 5, offsetX: 0, offsetY: 5, color: "#0007" };

// "#rgb", "#rgba", "#rrggbb" or "#rrggbbaa" -> { r, g, b, a } in 0..1
function parseColor(text) {
    var m = /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(String(text).trim());
    var hex = m ? m[1] : "000000";
    if (hex.length <= 4)
        hex = hex.split("").map(function (c) { return c + c; }).join("");
    if (hex.length === 6)
        hex += "ff";
    var v = function (i) { return parseInt(hex.substr(i, 2), 16) / 255; };
    return { r: v(0), g: v(2), b: v(4), a: v(6) };
}

// niri rounds spread and offset up to whole logical px (layout/shadow.rs) and takes sigma as half of softness
function params(cfg) {
    var c = cfg || DEFAULTS;
    var softness = Math.max(0, Number(c.softness));
    var spread = Number(c.spread);
    return {
        sigma: softness / 2,
        spread: Math.ceil(Math.abs(spread)) * (spread < 0 ? -1 : 1),
        offsetX: Math.ceil(Number(c.offsetX)),
        offsetY: Math.ceil(Number(c.offsetY)),
        color: parseColor(c.color)
    };
}

// the `shadow` block of niri's layout section
function niriBlock(cfg) {
    var c = cfg || DEFAULTS;
    var color = /^#[0-9a-f]{3,8}$/i.test(String(c.color).trim()) ? String(c.color).trim() : DEFAULTS.color;
    return "    shadow {\n"
        + "        on\n"
        + "        softness " + Number(c.softness) + "\n"
        + "        spread " + Number(c.spread) + "\n"
        + "        offset x=" + Number(c.offsetX) + " y=" + Number(c.offsetY) + "\n"
        + "        color \"" + color + "\"\n"
        + "    }";
}
