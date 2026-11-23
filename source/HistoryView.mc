import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Page 2: run history bar chart. One bar per run, newest on the right.
// Stacked run (primary) / walk (secondary) / paused (grey) minutes, fixed
// scale, calories on top. Missed runs show as red slots.
class HistoryView extends WatchUi.View {
    const MAX_BARS = 6;
    const MAX_MIN = 36.0;        // fixed y scale so bars are comparable
    const DAY_LABELS = ["Su", "M", "T", "W", "Th", "F", "Sa"];
    var slots as Array<Dictionary>;
    var offset as Number = 0;    // bars scrolled back from the newest
    var scrolling as Boolean = false;
    var visible as Number = MAX_BARS;    // bars that fit (fewer on small screens)

    function initialize() {
        View.initialize();
        slots = Program.historySlots();
    }

    function maxOffset() as Number {
        var m = slots.size() - visible;
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
        Draw.text(dc, f.cx, f.y(42), Graphics.FONT_XTINY, scrolling ? "SCROLL < >" : "RUN HISTORY", Theme.TEXT_MUTED);

        if (slots.size() == 0) {
            Draw.text(dc, f.cx, f.cy, Graphics.FONT_SMALL, "No runs yet", Theme.TEXT_DIM);
            Draw.text(dc, f.cx, f.cy + f.d(28), Graphics.FONT_XTINY, "Your bars appear here", Theme.TEXT_DIM);
            return;
        }

        var bw = f.d(22), gap = f.d(12);
        // Calorie and week labels must not touch: widen the bar spacing where
        // the font is large for the screen, and show fewer bars
        var lw = dc.getTextWidthInPixels("000", Graphics.FONT_XTINY);
        var ww = dc.getTextWidthInPixels("W0", Graphics.FONT_XTINY);
        if (ww > lw) { lw = ww; }
        if (lw + f.d(7) > bw + gap) { gap = lw + f.d(7) - bw; }
        // labels wider than the bars overhang the outer bars: keep them off the arrows
        var over = lw > bw ? lw - bw : 0;
        visible = (f.d(204) - over + gap) / (bw + gap);
        if (visible > MAX_BARS) { visible = MAX_BARS; }
        if (visible < 1) { visible = 1; }
        if (offset > maxOffset()) { offset = maxOffset(); }
        var base = f.y(212);
        var perMin = f.d(118).toFloat() / MAX_MIN;
        var first = slots.size() - visible - offset;
        if (first < 0) { first = 0; }
        var n = slots.size() - offset - first;
        var x0 = f.cx - (visible * (bw + gap) - gap) / 2;

        dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x0 - f.d(6), base, x0 + visible * (bw + gap), base);

        var prevWeek = -1;
        for (var i = 0; i < n; i++) {
            var s = slots[first + i];
            var x = x0 + i * (bw + gap);
            var wk = s["wu"] == true ? 0 : (s["wk"] as Number);
            if (wk != prevWeek) {
                if (i > 0) {
                    // dotted divider between weeks
                    var lx = x - gap / 2;
                    dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
                    for (var yy = base - f.d(120); yy < base + f.d(8); yy += f.d(5)) { dc.drawPoint(lx, yy); }
                }
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, base + f.d(30), Graphics.FONT_XTINY, wk == 0 ? "WU" : "W" + wk.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                prevWeek = wk;
            }
            if (s["miss"] == true) {
                var h = f.d(14);
                dc.setColor(Theme.MISSED, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(f.d(1.5));
                dc.drawRoundedRectangle(x, base - h, bw, h, f.d(3));
                dc.drawLine(x + f.d(6), base - h + f.d(3), x + bw - f.d(6), base - f.d(3));
                dc.drawLine(x + bw - f.d(6), base - h + f.d(3), x + f.d(6), base - f.d(3));
                continue;
            }
            var walkH = (num(s["walk"]) / 60.0 * perMin).toNumber();
            var runH = (num(s["run"]) / 60.0 * perMin).toNumber();
            var pauseH = (num(s["pause"]) / 60.0 * perMin).toNumber();
            var y = base;
            dc.setColor(Theme.secondary(), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y - walkH, bw, walkH); y -= walkH;
            dc.setColor(Theme.primary(), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y - runH, bw, runH); y -= runH;
            if (pauseH > 0) {
                dc.setColor(Theme.PAUSED, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y - pauseH, bw, pauseH); y -= pauseH;
            }
            if (s["kcal"] != null) {
                Draw.text(dc, x + bw / 2, y - f.d(8), Graphics.FONT_XTINY, num(s["kcal"]).format("%d"), 0xFAC775);
            }
            var d = Program.dayIndexOf(s["t"] as Number);
            Draw.text(dc, x + bw / 2, base + f.d(13), Graphics.FONT_XTINY, DAY_LABELS[d], Theme.TEXT_MUTED);
        }
        if (offset < maxOffset()) { Draw.text(dc, f.x(28), f.y(150), Graphics.FONT_SMALL, "<", Theme.TEXT_DIM); }
        if (offset > 0) { Draw.text(dc, f.x(272), f.y(150), Graphics.FONT_SMALL, ">", Theme.TEXT_DIM); }
    }

    function num(v) as Number {
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double) { return v.toNumber(); }
        return 0;
    }
}

class HistoryDelegate extends WatchUi.BehaviorDelegate {
    var v as HistoryView;

    function initialize(view as HistoryView) {
        BehaviorDelegate.initialize();
        v = view;
    }

    // Touch: swipe right = older, swipe left = newer
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_RIGHT) { v.scroll(2); return true; }
        if (d == WatchUi.SWIPE_LEFT) { v.scroll(-2); return true; }
        return false;
    }

    // Buttons: Start toggles scroll mode; in scroll mode Up/Down scroll
    function onSelect() as Boolean {
        v.scrolling = !v.scrolling;
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        if (v.scrolling) { v.scroll(-1); } else { Pages.show(Pages.STATS, true); }
        return true;
    }

    function onPreviousPage() as Boolean {
        if (v.scrolling) { v.scroll(1); } else { Pages.show(Pages.HOME, false); }
        return true;
    }

    function onBack() as Boolean {
        if (v.scrolling) { v.scrolling = false; WatchUi.requestUpdate(); }
        else { Pages.show(Pages.HOME, false); }
        return true;
    }
}
