import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;

// Colour themes. Primary = run colour, secondary = walk colour.
module Theme {
    const BG = 0x0B0B0B;
    const TEXT = 0xF1EFE8;
    const TEXT_DIM = 0x888780;
    const TEXT_MUTED = 0xB4B2A9;
    const TRACK = 0x2C2C2A;
    const DONE = 0x3A3A38;
    const FUTURE_DOT = 0x444441;
    const MISSED = 0xFF453A;
    const PAUSED = 0x5F5E5A;
    const REST_BG = 0x1F1F1E;

    // Neutral greys. MIP screens get exact palette greys so they don't snap to olive.
    function track() as Number { return Draw.isMip() ? 0x555555 : TRACK; }
    function done() as Number { return Draw.isMip() ? 0x555555 : DONE; }
    function futureDot() as Number { return Draw.isMip() ? 0x555555 : FUTURE_DOT; }
    function restBg() as Number { return Draw.isMip() ? 0x000055 : REST_BG; }

    //               primary,  secondary, text on primary, text on secondary
    const THEMES = [
        [0x19D3C5, 0xFFD84D, 0x04342C, 0x412402], // Turquoise
        [0xBD93F9, 0x7CC8FF, 0x26215C, 0x042C53], // Purple
        [0xFF8A1F, 0x4DABF7, 0x412402, 0x042C53], // Orange
        [0xF5B841, 0x2E9E5B, 0x412402, 0xE8F5EC], // Yellow
        [0x2E9E5B, 0xF5B841, 0xE8F5EC, 0x412402]  // Forest
    ];

    function index() as Number {
        var v = Properties.getValue("theme");
        if (v instanceof Number && v >= 0 && v < THEMES.size()) { return v; }
        return 2;
    }

    function primary() as Number { return THEMES[index()][0] as Number; }
    function secondary() as Number { return THEMES[index()][1] as Number; }
    function onPrimary() as Number { return THEMES[index()][2] as Number; }
    function onSecondary() as Number { return THEMES[index()][3] as Number; }
}
