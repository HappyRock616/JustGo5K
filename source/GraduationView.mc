import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Screen 10: graduation. First run vs final run, plan totals, and a
// hold-to-start-over bar. The plan is never reset automatically.
class GraduationView extends WatchUi.View {
    var hold as Hold or Null = null;
    var btnX as Number = 0;
    var btnY as Number = 0;
    var btnW as Number = 0;
    var btnH as Number = 0;

    function initialize() {
        View.initialize();
    }

    function toN(v) as Number {
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double) { return v.toNumber(); }
        return 0;
    }
    function toF(v) as Float or Null {
        if (v instanceof Number || v instanceof Float || v instanceof Double) { return v.toFloat(); }
        return null;
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        Draw.weekRing(dc, f, Plan.WEEKS + 1);
        Draw.fitText(dc, f.cx, f.y(58), "5K READY", f.d(160), [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, Theme.primary());
        Draw.text(dc, f.cx, f.y(82), Graphics.FONT_XTINY, "You did it", Theme.secondary());

        var runs = Program.planRuns();
        if (runs.size() > 0) {
            var a = runs[0], b = runs[runs.size() - 1];
            // Pace uses moving time, pauses excluded
            var secsA = toN(a["run"]) + toN(a["walk"]);
            var secsB = toN(b["run"]) + toN(b["walk"]);
            var rows = [
                ["Run", (toN(a["run"]) / 60).format("%d") + "m", (toN(b["run"]) / 60).format("%d") + "m"],
                [Units.distLabel(), Units.dist(toF(a["dist"])), Units.dist(toF(b["dist"]))],
                ["Pace", Units.paceFrom(secsA, toF(a["dist"])), Units.paceFrom(secsB, toF(b["dist"]))]
            ];
            // Three columns: label (right-aligned), first, last - each fitted to
            // its width. Where values don't fit the design columns (small
            // screens with large fonts), widen the columns and centre the block.
            var colFonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
            var lr = f.x(108), c1 = f.x(146), c2 = f.x(204), colW = f.d(58);
            var need = 0, labelW = 0;
            for (var i = 0; i < rows.size(); i++) {
                for (var k = 1; k < 3; k++) {
                    var w = dc.getTextWidthInPixels(rows[i][k], Graphics.FONT_XTINY);
                    if (w > need) { need = w; }
                }
                var lw = dc.getTextWidthInPixels(rows[i][0], Graphics.FONT_XTINY);
                if (lw > labelW) { labelW = lw; }
            }
            need += f.d(8);
            if (need > colW) {
                colW = need;
                lr = f.cx - (labelW + f.d(6) + 2 * colW) / 2 + labelW;
                c1 = lr + f.d(6) + colW / 2;
                c2 = c1 + colW;
            }
            Draw.text(dc, c1, f.y(104), Graphics.FONT_XTINY, "First", Theme.TEXT_MUTED);
            Draw.text(dc, c2, f.y(104), Graphics.FONT_XTINY, "Last", Theme.TEXT_MUTED);
            for (var i = 0; i < rows.size(); i++) {
                var y = f.y(128 + i * 24);
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
                dc.drawText(lr, y, Graphics.FONT_XTINY, rows[i][0], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                Draw.fitText(dc, c1, y, rows[i][1], colW - f.d(6), colFonts, Theme.TEXT_MUTED);
                Draw.fitText(dc, c2, y, rows[i][2], colW - f.d(6), colFonts, Theme.TEXT);
            }
            var dist = 0.0, secs = 0;
            for (var i = 0; i < runs.size(); i++) {
                var d = toF(runs[i]["dist"]);
                if (d != null) { dist += d; }
                secs += toN(runs[i]["run"]) + toN(runs[i]["walk"]);
            }
            var nRuns = runs.size().format("%d") + " runs";
            var miles = Units.dist(dist) + " " + Units.distLabel();
            var totals = Draw.pick(dc, [nRuns + " · " + miles + " · " + (secs / 3600.0).format("%.1f") + " h", nRuns + " · " + miles, miles],
                f.d(220), Graphics.FONT_XTINY);
            Draw.text(dc, f.cx, f.y(204), Graphics.FONT_XTINY, totals, Theme.secondary());
        }

        // Hold to start over
        btnW = f.d(150); btnH = f.d(30);
        btnX = f.cx - btnW / 2; btnY = f.y(220);
        dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, btnH / 2);
        var fr = hold == null ? 0.0 : hold.frac();
        if (fr > 0) {
            dc.setClip(btnX, btnY, (btnW * fr).toNumber(), btnH);
            dc.setColor(0x791F1F, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, btnH / 2);
            dc.clearClip();
        }
        Draw.text(dc, f.cx, btnY + btnH / 2, Graphics.FONT_XTINY, Draw.pick(dc, ["Hold to start over", "Hold: start over", "Start over"], btnW - f.d(8), Graphics.FONT_XTINY), 0xF09595);
    }

    function hitButton(x as Number, y as Number) as Boolean {
        return x >= btnX && x <= btnX + btnW && y >= btnY - btnH / 2 && y <= btnY + btnH * 3 / 2;
    }
}

class GraduationDelegate extends WatchUi.BehaviorDelegate {
    var v as GraduationView;

    function initialize(view as GraduationView) {
        BehaviorDelegate.initialize();
        v = view;
        v.hold = new Hold(3000, method(:doRestart));
    }

    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { v.hold.start(); return true; }
        return false;
    }
    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { v.hold.cancel(); }
        return false;
    }
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        if (v.hitButton(c[0], c[1])) { v.hold.start(); }
        return true;
    }
    function onRelease(evt as WatchUi.ClickEvent) as Boolean { v.hold.cancel(); return true; }

    function doRestart() as Void {
        Program.restart();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
