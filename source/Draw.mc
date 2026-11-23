import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Shared drawing helpers. Layouts are designed on a 300x300 grid and scaled.
module Draw {
    const RING_W = 22.0;     // one ring thickness everywhere (design units)
    const GAP_DEG = 2.5;     // gap between ring segments, degrees

    class Frame {
        var cx as Number;
        var cy as Number;
        var size as Number;
        var s as Float;
        function initialize(dc as Dc) {
            var w = dc.getWidth();
            var h = dc.getHeight();
            size = w < h ? w : h;
            cx = w / 2;
            cy = h / 2;
            s = size / 300.0;
        }
        // design coordinates -> pixels
        function x(v as Numeric) as Number { return (cx + (v - 150) * s).toNumber(); }
        function y(v as Numeric) as Number { return (cy + (v - 150) * s).toNumber(); }
        function d(v as Numeric) as Number {
            var r = (v * s).toNumber();
            return r < 1 ? 1 : r;
        }
        function ringW() as Number { return d(RING_W); }
        function ringR() as Number { return size / 2 - ringW() / 2 - d(3); }
    }

    // Rectangular screen? (Venu Sq is 240x240, so width = height proves nothing)
    function isRect() as Boolean {
        return System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_RECTANGLE;
    }

    function aa(dc as Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    function clear(dc as Dc, color as Number) as Void {
        dc.setColor(color, color);
        dc.clear();
    }

    // MIP (memory-in-pixel) screens only have a 64-colour palette, so blended
    // shades snap to odd colours. AMOLED watches report burn-in protection.
    var mipChecked as Boolean = false;
    var mip as Boolean = false;
    function isMip() as Boolean {
        if (!mipChecked) {
            var ds = System.getDeviceSettings();
            mip = !((ds has :requiresBurnInProtection) && ds.requiresBurnInProtection);
            mipChecked = true;
        }
        return mip;
    }

    // Blend a colour toward the background (f = 0 keeps colour, 1 = background).
    // On MIP screens, step each channel down one palette level instead.
    function dim(color as Number, f as Float) as Number {
        var r = (color >> 16) & 0xFF, g = (color >> 8) & 0xFF, b = color & 0xFF;
        if (isMip()) {
            var lv = [Math.round(r / 85.0).toNumber(), Math.round(g / 85.0).toNumber(), Math.round(b / 85.0).toNumber()];
            for (var i = 0; i < 3; i++) { lv[i] = lv[i] > 0 ? (lv[i] - 1) * 85 : 0; }
            return (lv[0] << 16) | (lv[1] << 8) | lv[2];
        }
        var br = (Theme.BG >> 16) & 0xFF, bg = (Theme.BG >> 8) & 0xFF, bb = Theme.BG & 0xFF;
        r = (r + (br - r) * f).toNumber();
        g = (g + (bg - g) * f).toNumber();
        b = (b + (bb - b) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Clockwise arc from fraction a0 to a1 of a full turn, starting at 12 o'clock
    function arcFrac(dc as Dc, f as Frame, a0 as Float, a1 as Float, color as Number) as Void {
        var start = 90.0 - a0 * 360.0;
        var end = 90.0 - a1 * 360.0;
        if (start - end < 0.5) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(f.ringW());
        dc.drawArc(f.cx, f.cy, f.ringR(), Graphics.ARC_CLOCKWISE, start, end);
    }

    // Home screen: 9 equal week segments
    function weekRing(dc as Dc, f as Frame, week as Number) as Void {
        var n = Plan.WEEKS;
        var gap = GAP_DEG / 360.0;
        for (var k = 0; k < n; k++) {
            var a0 = k.toFloat() / n + gap / 2;
            var a1 = (k + 1).toFloat() / n - gap / 2;
            var c = Theme.track();
            if (k + 1 < week) { c = Theme.primary(); }
            else if (k + 1 == week) { c = Theme.secondary(); }
            arcFrac(dc, f, a0, a1, c);
        }
    }

    // Session ring for the main set.
    // cur: -1 = preview (all full colour), -2 = not started (all dimmed),
    //      99 = finished (all grey), otherwise index of current segment.
    // frac: elapsed fraction of the current segment.
    function sessionRing(dc as Dc, f as Frame, seg as Array<Array<Number> >, cur as Number, frac as Float, visible as Boolean) as Void {
        if (!visible) { return; }
        var total = 0;
        for (var i = 0; i < seg.size(); i++) { total += seg[i][1]; }
        var gap = (seg.size() > 1) ? GAP_DEG / 360.0 : 0.0;
        var pos = 0.0;
        for (var i = 0; i < seg.size(); i++) {
            var span = seg[i][1].toFloat() / total;
            var a0 = pos + gap / 2;
            var a1 = pos + span - gap / 2;
            if (seg.size() == 1) { a0 = 0.0; a1 = 0.9999; }
            var c = (seg[i][0] == Plan.RUN) ? Theme.primary() : Theme.secondary();
            if (cur == -1) {
                arcFrac(dc, f, a0, a1, c);
            } else if (cur == -2 || (cur != 99 && i > cur)) {
                arcFrac(dc, f, a0, a1, dim(c, 0.55));
            } else if (cur == 99 || i < cur) {
                arcFrac(dc, f, a0, a1, Theme.done());
            } else {
                var m = a0 + (a1 - a0) * frac;
                arcFrac(dc, f, a0, m, Theme.done());
                arcFrac(dc, f, m, a1, c);
            }
            pos += span;
        }
    }

    function text(dc as Dc, x as Number, y as Number, font as Graphics.FontType, s as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Largest font from the list (big to small) whose text fits within maxW pixels
    function fit(dc as Dc, s as String, maxW as Number, fonts as Array<Graphics.FontType>) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(s, fonts[i]) <= maxW) { return fonts[i]; }
        }
        return fonts[fonts.size() - 1];
    }

    // First wording that fits maxW pixels in the font, or the last (shortest)
    function pick(dc as Dc, options as Array<String>, maxW as Number, font as Graphics.FontType) as String {
        for (var i = 0; i < options.size() - 1; i++) {
            if (dc.getTextWidthInPixels(options[i], font) <= maxW) { return options[i]; }
        }
        return options[options.size() - 1];
    }

    function fitText(dc as Dc, x as Number, y as Number, s as String, maxW as Number, fonts as Array<Graphics.FontType>, color as Number) as Void {
        text(dc, x, y, fit(dc, s, maxW, fonts), s, color);
    }

    function tick(dc as Dc, f as Frame, cx as Number, cy as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(f.d(2.6));
        dc.drawLine(cx - f.d(5), cy, cx - f.d(1.5), cy + f.d(3.5));
        dc.drawLine(cx - f.d(1.5), cy + f.d(3.5), cx + f.d(5), cy - f.d(3.5));
    }

    // Cartoon sofa with a sleeping person, centred on (cx, cy)
    function sofa(dc as Dc, f as Frame, cx as Number, cy as Number) as Void {
        var sofaBack = 0x378ADD, sofaSeat = 0x85B7EB, skin = 0xF5C4B3, blanket = 0xB5D4F4;
        var r = f.d(2);
        dc.setColor(sofaBack, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - f.d(9), cy - f.d(6), f.d(18), f.d(6), r);          // back
        dc.fillRoundedRectangle(cx - f.d(11), cy - f.d(3), f.d(4), f.d(9), r);          // left arm
        dc.fillRoundedRectangle(cx + f.d(7), cy - f.d(3), f.d(4), f.d(9), r);           // right arm
        dc.setColor(sofaSeat, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - f.d(8), cy, f.d(16), f.d(5), r);                   // seat
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - f.d(4), cy - f.d(2), f.d(2.6));                               // head
        dc.setColor(blanket, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - f.d(2), cy - f.d(3.5), f.d(8), f.d(3.5), r);       // body
        dc.setColor(Theme.TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + f.d(9), cy - f.d(10), Graphics.FONT_XTINY, "z", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Pill button. filled = true for an active button, false for a locked outline.
    function pill(dc as Dc, f as Frame, x0 as Number, y0 as Number, w as Number, h as Number, label as String, filled as Boolean) as Void {
        if (filled) {
            dc.setColor(Theme.primary(), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, y0, w, h, h / 2);
            fitText(dc, x0 + w / 2, y0 + h / 2, label, w - h / 2, [Graphics.FONT_TINY, Graphics.FONT_XTINY], Theme.onPrimary());
        } else {
            dc.setColor(Theme.PAUSED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(f.d(1.5));
            dc.drawRoundedRectangle(x0, y0, w, h, h / 2);
            fitText(dc, x0 + w / 2, y0 + h / 2, label, w - h / 2, [Graphics.FONT_TINY, Graphics.FONT_XTINY], Theme.TEXT_DIM);
        }
    }

    // Heart icon centred on (cx, cy)
    function heart(dc as Dc, f as Frame, cx as Number, cy as Number, color as Number) as Void {
        var r = f.d(3.6);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r, cy - r / 2, r);
        dc.fillCircle(cx + r, cy - r / 2, r);
        dc.fillPolygon([[cx - 2 * r, cy - r / 3], [cx + 2 * r, cy - r / 3], [cx, cy + 2 * r]]);
    }

    // Side panel rectangles in design units: [x, y, w, h] (start screen)
    const PANEL_L = [32, 112, 60, 76];
    const PANEL_R = [208, 112, 60, 76];

    function panelBox(dc as Dc, f as Frame, p as Array<Number>, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(f.x(p[0]), f.y(p[1]), f.d(p[2]), f.d(p[3]), f.d(10));
    }

    // Heart rate and pace panels: same box, centres PANEL_OFF design units
    // left and right of the middle.
    const PANEL_OFF = 88;

    // Panel width in pixels: the design width, or wider where the watch's
    // smallest font is large for its screen (Venu Sq), so labels stay inside
    function panelW(dc as Dc, f as Frame) as Number {
        var w = f.d(60);
        var labels = ["PACE", "bpm", Units.paceLabel()];
        for (var i = 0; i < labels.size(); i++) {
            var lw = dc.getTextWidthInPixels(labels[i], Graphics.FONT_XTINY) + f.d(6);
            if (lw > w) { w = lw; }
        }
        return w;
    }

    // Heart rate (left) and pace (right) panels used on screens 2-7.
    // off: pixels from the middle to each panel's centre.
    function hrPacePanels(dc as Dc, f as Frame, hr as Number or Null, pace as String, off as Number) as Void {
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
        var lx = f.cx - off, rx = f.cx + off;
        var w = panelW(dc, f);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(lx - w / 2, f.y(112), w, f.d(76), f.d(10));
        dc.fillRoundedRectangle(rx - w / 2, f.y(112), w, f.d(76), f.d(10));
        heart(dc, f, lx, f.y(128), 0xF09595);
        fitText(dc, lx, f.y(153), hr == null ? "--" : hr.format("%d"), w - f.d(4), fonts, Theme.TEXT);
        text(dc, lx, f.y(176), Graphics.FONT_XTINY, "bpm", Theme.TEXT_DIM);
        text(dc, rx, f.y(128), Graphics.FONT_XTINY, "PACE", Theme.TEXT_DIM);
        fitText(dc, rx, f.y(153), pace, w - f.d(4), fonts, Theme.TEXT);
        text(dc, rx, f.y(176), Graphics.FONT_XTINY, Units.paceLabel(), Theme.TEXT_DIM);
    }

    // Edge button on the left or right side. fill = 0..1, fills top to bottom.
    // Letters are stacked vertically; offset scrolls them (in letter steps).
    function edgeButton(dc as Dc, f as Frame, left as Boolean, label as String,
                        base as Number, fillColor as Number, fill as Float,
                        textColor as Number, offset as Float) as Void {
        var w = f.d(46);
        var x0 = left ? f.cx - f.size / 2 : f.cx + f.size / 2 - w;
        var y0 = f.y(70), h = f.d(160);
        var shape = edgeShape(dc, f, left, x0, y0, w, h);
        dc.setColor(base, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(shape);
        if (fill > 0) {
            dc.setClip(x0, y0, w, (h * fill).toNumber());
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(shape);
            dc.clearClip();
        }
        var chars = label.toCharArray();
        // one letter per line, spaced by the real font height so letters never overlap
        var step = (dc.getFontHeight(Graphics.FONT_XTINY) * 0.82).toNumber();
        var tx = left ? x0 + w * 6 / 10 : x0 + w * 4 / 10;
        var total = chars.size() * step;
        var startY = f.cy - total / 2 + step / 2;
        dc.setClip(x0, y0, w, h);
        for (var i = 0; i < chars.size(); i++) {
            var y = startY + i * step;
            if (offset != 0.0) {
                // continuous top-to-bottom scroll, wrapping within the button
                var span = h + step;
                y = y0 - step / 2 + ((y - y0 + (offset * step).toNumber()) % span + span) % span;
            }
            text(dc, tx, y, Graphics.FONT_XTINY, chars[i].toString(), textColor);
        }
        dc.clearClip();
    }

    // Outline of an edge button: straight inner side, outer side follows the
    // round screen edge (plain rectangle on rectangular screens).
    function edgeShape(dc as Dc, f as Frame, left as Boolean, x0 as Number, y0 as Number, w as Number, h as Number) as Array<[Numeric, Numeric]> {
        var inner = left ? x0 + w : x0;
        var pts = [] as Array<[Numeric, Numeric]>;
        if (isRect()) {
            return [[x0, y0], [x0 + w, y0], [x0 + w, y0 + h], [x0, y0 + h]];
        }
        var R = f.size / 2.0;
        pts.add([inner, y0]);
        var steps = 12;
        for (var i = 0; i <= steps; i++) {
            var y = y0 + h * i / steps;
            var dy = y - f.cy;
            var dx = Math.sqrt(R * R - dy * dy);
            pts.add([left ? f.cx - dx : f.cx + dx, y]);
        }
        pts.add([inner, y0 + h]);
        return pts;
    }

    function mmss(sec as Number) as String {
        if (sec < 0) { sec = 0; }
        return (sec / 60).format("%d") + ":" + (sec % 60).format("%02d");
    }
}
