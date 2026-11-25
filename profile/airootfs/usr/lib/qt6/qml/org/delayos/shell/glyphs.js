.pragma library
// DelayOS shell line glyphs (24x24 grid, Lucide-style 1.5 px strokes). Drawn by Glyph.qml.
// "f:" prefix = filled shape (odd-even fill), everything else is stroked.

function c(cx, cy, r) {
    return "M" + (cx - r) + " " + cy + "a" + r + " " + r + " 0 1 0 " + (2 * r) + " 0a" + r + " " + r + " 0 1 0 " + (-2 * r) + " 0";
}
function rr(x, y, w, h, r) {
    return "M" + (x + r) + " " + y + "h" + (w - 2 * r) + "a" + r + " " + r + " 0 0 1 " + r + " " + r +
           "v" + (h - 2 * r) + "a" + r + " " + r + " 0 0 1 " + (-r) + " " + r +
           "h" + (-(w - 2 * r)) + "a" + r + " " + r + " 0 0 1 " + (-r) + " " + (-r) +
           "v" + (-(h - 2 * r)) + "a" + r + " " + r + " 0 0 1 " + r + " " + (-r) + "Z";
}

var SPEAKER = "M11 4.7a.7.7 0 0 0-1.2-.5L6.4 7.6A1.4 1.4 0 0 1 5.4 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.4a1.4 1.4 0 0 1 1 .4l3.4 3.4a.7.7 0 0 0 1.2-.5Z";

var paths = {
    "search": c(11, 11, 7) + " M21 21l-4.3-4.3",
    // dock Task View: two stacked rounded rectangles, the back one offset up-right
    "taskview": "M7.5 7.5V6a2.5 2.5 0 0 1 2.5-2.5h8A2.5 2.5 0 0 1 20.5 6v7a2.5 2.5 0 0 1-2.5 2.5h-1.5 " + rr(3.5, 8.5, 13, 12, 2.5),
    "wifi": "M12 19.5h.01 M2 8.8a15 15 0 0 1 20 0 M5 12.9a10 10 0 0 1 14 0 M8.5 16.4a5 5 0 0 1 7 0",
    "wifi-off": "M12 19.5h.01 M8.5 16.4a5 5 0 0 1 7 0 M2 8.8a15 15 0 0 1 4.2-2.8 M19 12.9a10 10 0 0 0-2.1-1.4 M22 8.8a15 15 0 0 0-11.3-3.7 M5 12.9a10 10 0 0 1 5-2.4 M2 2l20 20",
    "wired": rr(2, 3, 20, 14, 2) + " M8 21h8 M12 17v4",
    "volume": SPEAKER + " M16 9a5 5 0 0 1 0 6 M19.4 18.4a9 9 0 0 0 0-12.8",
    "volume-low": SPEAKER + " M16 9a5 5 0 0 1 0 6",
    "volume-x": SPEAKER + " M22 9l-6 6 M16 9l6 6",
    "battery": rr(2, 7, 16, 10, 2.5) + " M22 11v2",
    "bolt-small": "M10.6 8.6 8.4 12.2h3.3l-2.1 3.4",
    "bluetooth": "M7 7l10 10-5 5V2l5 5L7 17",
    "bell": "M10.3 21a2 2 0 0 0 3.4 0 M3.3 15.3A1 1 0 0 0 4 17h16a1 1 0 0 0 .7-1.7C19.4 14 18 12.5 18 8A6 6 0 0 0 6 8c0 4.5-1.4 6-2.7 7.3",
    "zap": "M13 2 4.5 13.2a.5.5 0 0 0 .4.8H11l-1 8 8.5-11.2a.5.5 0 0 0-.4-.8H12l1-8Z",
    "sun": c(12, 12, 4) + " M12 2v2 M12 20v2 M4.9 4.9l1.4 1.4 M17.7 17.7l1.4 1.4 M2 12h2 M20 12h2 M6.3 17.7l-1.4 1.4 M19.1 4.9l-1.4 1.4",
    "monitor": rr(2, 3, 20, 14, 2) + " M8 21h8 M12 17v4",
    "pin": "M12 17v5 M9 10.8a2 2 0 0 1-1.1 1.8l-1.8.9A2 2 0 0 0 5 15.2V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.8a2 2 0 0 0-1.1-1.8l-1.8-.9A2 2 0 0 1 15 10.8V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1Z",
    "pin-off": "M12 17v5 M15 9.3V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H7.9 M2 2l20 20 M9 9v1.8a2 2 0 0 1-1.1 1.8l-1.8.9A2 2 0 0 0 5 15.2V16a1 1 0 0 0 1 1h11",
    "trash": "M3 6h18 M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6 M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",
    "x": "M18 6 6 18 M6 6l12 12",
    "check": "M20 6 9 17l-5-5",
    "plus": "M12 5v14 M5 12h14",
    "window": rr(3, 4, 18, 16, 2.5) + " M3 9h18",
    // filled glyphs
    "f:windows": rr(3, 3, 8.2, 8.2, 1.2) + " " + rr(12.8, 3, 8.2, 8.2, 1.2) + " " + rr(3, 12.8, 8.2, 8.2, 1.2) + " " + rr(12.8, 12.8, 8.2, 8.2, 1.2),
    "f:gamepad": "M7.2 5.5h9.6a4.8 4.8 0 0 1 4.7 3.9l1.1 6a2.9 2.9 0 0 1-5 2.5L15.4 16H8.6l-2.2 1.9a2.9 2.9 0 0 1-5-2.5l1.1-6a4.8 4.8 0 0 1 4.7-3.9Z" +
                 " M6.3 9.4h1.4v1.6h1.6v1.4H7.7V14H6.3v-1.6H4.7V11h1.6Z " + c(16.2, 10.2, 1.05) + " " + c(18.3, 12.5, 1.05),
    "f:dot": c(12, 12, 4)
};

function path(name) {
    var p = paths[name];
    if (p === undefined) p = paths["f:" + name];
    return p === undefined ? "" : p;
}
function isFilled(name) {
    return paths[name] === undefined && paths["f:" + name] !== undefined || name.indexOf("f:") === 0;
}
