import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Page 3: stats table. One column per run, newest on the right.
// Tap a column (or Start in scroll mode) to open that run's pace map.
class StatsView extends WatchUi.View {
    const MAX_COLS = 3;
    const DAY_LABELS = ["Su", "M", "T", "W", "Th", "F", "Sa"];
    var runs as Array<Dictionary>;
    var offset as Number = 0;
    var scrolling as Boolean = false;
    var colX as Array<Number> = [0, 0, 0] as Array<Number>;
    var firstIdx as Number = 0;
    var visible as Number = MAX_COLS;   // columns that fit (fewer on small screens)
    var pitch as Number = 0;            // column spacing in pixels

    function initialize() {
        View.initialize();
        runs = Program.runs();
    }

    function maxOffset() as Number {
        var m = runs.size() - visible;
        return m > 0 ? m : 0;
    }

    function scroll(by as Number) as Void {
        offset += by;
        if (offset < 0) { offset = 0; }
        if (offset > maxOffset()) { offset = maxOffset(); }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        Draw.text(dc, f.cx, f.y(44), Graphics.FONT_XTINY, scrolling ? "SCROLL < >" : "RUN STATS", Theme.TEXT_MUTED);
        if (runs.size() == 0) {
            Draw.text(dc, f.cx, f.cy, Graphics.FONT_SMALL, "No runs yet", Theme.TEXT_DIM);
            return;
        }
        var labels = ["", Units.distLabel(), "Pace", "HR avg", "HR max", "kcal", "SpO2"];
        // Column spacing: the design spacing, or wider where values don't fit
        // (small screens with large fonts, or paces over 10:00). Then as many
        // columns as fit between the row labels and the right edge; short row
        // labels are used only when they let more columns fit.
        var need = 0;
        var from = runs.size() - MAX_COLS - offset;
        for (var i = (from < 0 ? 0 : from); i < runs.size() - offset; i++) {
            for (var row = 1; row < labels.size(); row++) {
                var w = dc.getTextWidthInPixels(cell(runs[i], row), Graphics.FONT_XTINY);
                if (w > need) { need = w; }
            }
        }
        var gap = f.d(7);                 // space kept between neighbouring values
        need += gap;
        pitch = f.d(46);
        var lastX = f.x(232);
        var labelX = f.x(48);
        if (need > pitch) {
            pitch = need;
            labelX = f.x(40);
            lastX = (Draw.isRect() ? dc.getWidth() - f.d(12) : f.x(262)) - pitch / 2;
        }
        visible = colsFor(dc, labels, labelX + f.d(4), lastX);
        if (visible < MAX_COLS) {
            var short = ["", Units.distLabel(), "Pace", "HR", "Max", "kcal", "SpO2"];
            var v2 = colsFor(dc, short, labelX + f.d(4), lastX);
            if (v2 > visible) { visible = v2; labels = short; }
        }
        if (offset > maxOffset()) { offset = maxOffset(); }
        var firstX = lastX - (visible - 1) * pitch;
        firstIdx = runs.size() - visible - offset;
        if (firstIdx < 0) { firstIdx = 0; }
        var n = runs.size() - offset - firstIdx;
        var valFonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
        // Two-line column header: week on top, day below
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        for (var c = 0; c < n; c++) {
            var hr = runs[firstIdx + c];
            var hx = firstX + c * pitch;
            colX[c] = hx;
            var wkLabel = hr["wu"] == true ? "WU" : "W" + toN(hr["wk"]).format("%d");
            Draw.text(dc, hx, f.y(84) - fh / 2, Graphics.FONT_XTINY, wkLabel, Theme.TEXT_DIM);
            Draw.text(dc, hx, f.y(84) + fh / 2, Graphics.FONT_XTINY, DAY_LABELS[Program.dayIndexOf(hr["t"] as Number)], Theme.TEXT_MUTED);
        }
        for (var row = 1; row < labels.size(); row++) {
            var y = f.y(84 + row * 23) + fh / 2;
            if (row > 0) {
                dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.drawLine(f.x(44), y - f.d(12), f.x(256), y - f.d(12));
            }
            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, y, Graphics.FONT_XTINY, labels[row], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            for (var c = 0; c < n; c++) {
                var r = runs[firstIdx + c];
                var x = firstX + c * pitch;
                colX[c] = x;
                var v = cell(r, row);
                if (row == 0) {
                    Draw.fitText(dc, x, y, v, f.d(44), [Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.TEXT_MUTED);
                } else {
                    Draw.fitText(dc, x, y, v, pitch - gap, valFonts, Theme.TEXT);
                }
            }
        }
        if (offset < maxOffset()) { Draw.text(dc, f.x(28), f.y(150), Graphics.FONT_SMALL, "<", Theme.TEXT_DIM); }
        if (offset > 0) { Draw.text(dc, Draw.isRect() ? dc.getWidth() - f.d(5) : f.x(272), f.y(150), Graphics.FONT_SMALL, ">", Theme.TEXT_DIM); }
    }

    // Columns that fit to the right of the widest row label
    function colsFor(dc as Dc, labels as Array<String>, x0 as Number, lastX as Number) as Number {
        var labelW = 0;
        for (var row = 1; row < labels.size(); row++) {
            var lw = dc.getTextWidthInPixels(labels[row], Graphics.FONT_XTINY);
            if (lw > labelW) { labelW = lw; }
        }
        var cols = MAX_COLS;
        while (cols > 1 && lastX - (cols - 1) * pitch - pitch / 2 < x0 + labelW) { cols--; }
        return cols;
    }

    function cell(r as Dictionary, row as Number) as String {
        var dist = r["dist"];
        var d = (dist instanceof Number) ? dist.toFloat() : ((dist instanceof Float || dist instanceof Double) ? dist.toFloat() : null);
        var secs = toN(r["run"]) + toN(r["walk"]);   // moving time, pauses excluded
        if (row == 0) {
            var wk = r["wu"] == true ? "WU" : "W" + toN(r["wk"]).format("%d");
            return wk + " " + DAY_LABELS[Program.dayIndexOf(r["t"] as Number)];
        }
        if (row == 1) { return Units.dist(d); }
        if (row == 2) { return Units.paceFrom(secs, d); }
        if (row == 3) { return r["hra"] == null ? "--" : toN(r["hra"]).format("%d"); }
        if (row == 4) { return r["hrm"] == null ? "--" : toN(r["hrm"]).format("%d"); }
        if (row == 5) { return r["kcal"] == null ? "--" : toN(r["kcal"]).format("%d"); }
        return r["o2"] == null ? "--" : toN(r["o2"]).format("%d");
    }

    function toN(v) as Number {
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double) { return v.toNumber(); }
        return 0;
    }

    // Run under a tap x position, or null
    function runAtX(x as Number) as Dictionary or Null {
        var n = runs.size() - offset - firstIdx;
        var half = pitch / 2;
        for (var c = 0; c < n; c++) {
            if ((x - colX[c]).abs() <= half) { return runs[firstIdx + c]; }
        }
        return null;
    }

    function newestVisible() as Dictionary or Null {
        var i = runs.size() - 1 - offset;
        return i >= 0 ? runs[i] : null;
    }
}

class StatsDelegate extends WatchUi.BehaviorDelegate {
    var v as StatsView;

    function initialize(view as StatsView) {
        BehaviorDelegate.initialize();
        v = view;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_RIGHT) { v.scroll(1); return true; }
        if (d == WatchUi.SWIPE_LEFT) { v.scroll(-1); return true; }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var r = v.runAtX(evt.getCoordinates()[0]);
        if (r != null) { openMap(r); }
        return true;
    }

    function onSelect() as Boolean {
        if (v.scrolling) {
            var r = v.newestVisible();
            if (r != null) { openMap(r); }
        } else {
            v.scrolling = true;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onNextPage() as Boolean {
        if (v.scrolling) { v.scroll(-1); } else { Pages.show(Pages.SETTINGS, true); }
        return true;
    }

    function onPreviousPage() as Boolean {
        if (v.scrolling) { v.scroll(1); } else { Pages.show(Pages.HISTORY, false); }
        return true;
    }

    function onBack() as Boolean {
        if (v.scrolling) { v.scrolling = false; WatchUi.requestUpdate(); }
        else { Pages.show(Pages.HOME, false); }
        return true;
    }

    function openMap(r as Dictionary) as Void {
        var mv = new PaceMapView(r);
        WatchUi.pushView(mv, new PaceMapDelegate(), WatchUi.SLIDE_LEFT);
    }
}
