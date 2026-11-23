import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Screen 8: summary. Save (right edge) runs automatically after 10 s.
// Redo (left edge) needs a 3 s hold.
class SummaryView extends WatchUi.View {
    const AUTO_MS = 10000;
    var s as RunSession;
    var shownAt as Number;
    var redoHold as Hold or Null = null;
    var timer as Timer.Timer or Null = null;
    var saved as Boolean = false;
    var showMap as Boolean = false;

    function initialize(session as RunSession) {
        View.initialize();
        s = session;
        shownAt = System.getTimer();
    }

    function onShow() as Void {
        if (timer == null) {
            timer = new Timer.Timer();
            timer.start(method(:tick), 100, true);
        }
    }

    function onHide() as Void {
        if (timer != null) { timer.stop(); timer = null; }
    }

    function autoFrac() as Float {
        var f = (System.getTimer() - shownAt).toFloat() / AUTO_MS;
        return f > 1.0 ? 1.0 : f;
    }

    var onAutoSave as Method or Null = null;

    function tick() as Void {
        WatchUi.requestUpdate();
        if (!saved && autoFrac() >= 1.0 && onAutoSave != null) { onAutoSave.invoke(); }
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);

        var recorded = s.mainStarted;
        var title = s.warmupRun ? "WARM-UP DONE" : "RUN " + s.run.format("%d") + " DONE";
        if (!recorded) { title = "NOT RECORDED"; }
        Draw.fitText(dc, f.cx, f.y(60), title, f.d(170), [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, Theme.primary());

        var sub = "";
        if (!recorded) { sub = "Ended during warm-up"; }
        else if (s.warmupRun) { sub = "Week 1 starts Sunday"; }
        else {
            var left = Plan.RUNS_PER_WEEK - (Program.countedThisWeek() + 1);
            sub = left <= 0 ? "Week " + s.week.format("%d") + " complete" : left.format("%d") + (left == 1 ? " run to go" : " runs to go");
        }
        Draw.fitText(dc, f.cx, f.y(84), sub, f.d(170), [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.secondary());

        if (recorded && showMap) {
            // Screen 9: pace map, between the same Redo / Save buttons
            PaceMap.draw(dc, f, s.trackLat, s.trackLon, s.trackSpd, s.indoor || s.trackLat.size() < 2);
            var dm = s.stats["dist"] as Float or Null;
            if (s.indoor || s.trackLat.size() < 2) {
                Draw.text(dc, f.cx, f.y(150), Graphics.FONT_XTINY, s.indoor ? "INDOOR" : "NO GPS", Theme.TEXT_MUTED);
            }
            Draw.fitText(dc, f.cx, f.y(250), Units.dist(dm) + " " + Units.distLabel() + " · " + Units.paceFrom(s.mainSec(), dm),
                f.d(150), [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.TEXT);
        } else if (recorded) {
            var d = s.stats["dist"] as Float or Null;
            var rows = [
                ["Time", Draw.mmss(s.mainSec())],
                [Units.distLabel(), Units.dist(d)],
                ["Pace", Units.paceFrom(s.mainSec(), d)],
                ["Avg HR", s.stats["hra"] == null ? "--" : (s.stats["hra"] as Number).format("%d")],
                ["kcal", s.stats["kcal"] == null ? "--" : (s.stats["kcal"] as Number).format("%d")]
            ];
            for (var i = 0; i < rows.size(); i++) {
                var y = f.y(116 + i * 30);
                dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
                dc.drawText(f.x(142), y, Graphics.FONT_TINY, rows[i][0], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(f.x(152), y, Graphics.FONT_MEDIUM, rows[i][1], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // Page dots: stats / map
        if (recorded) {
            for (var p = 0; p < 2; p++) {
                dc.setColor((p == 1) == showMap ? Theme.TEXT : Theme.track(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(f.cx - f.d(6) + p * f.d(12), f.y(274), f.d(3));
            }
        }

        // Left: hold to redo. Right: auto save.
        var rf = redoHold == null ? 0.0 : redoHold.frac();
        Draw.edgeButton(dc, f, true, "REDO", Theme.track(), Theme.PAUSED, rf, Theme.TEXT, 0.0);
        var af = autoFrac();
        var scroll = ((System.getTimer() - shownAt) / 250 % 40).toFloat() / 4.0;
        Draw.edgeButton(dc, f, false, recorded ? "SAVE" : "DONE", Theme.track(), Theme.primary(), af,
            af > 0.5 ? Theme.onPrimary() : Theme.TEXT, recorded ? scroll : 0.0);
    }

    function hitLeft(x as Number) as Boolean { return x < System.getDeviceSettings().screenWidth / 4; }
    function hitRight(x as Number) as Boolean { return x > System.getDeviceSettings().screenWidth * 3 / 4; }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    var v as SummaryView;
    var s as RunSession;

    function initialize(view as SummaryView, session as RunSession) {
        BehaviorDelegate.initialize();
        v = view;
        s = session;
        v.redoHold = new Hold(3000, method(:doRedo));
        v.onAutoSave = method(:doSave);
    }

    function onSelect() as Boolean { doSave(); return true; }

    // Down or swipe up: switch between the stats and the pace map (screen 9).
    // Up is reserved for hold-to-redo on button watches.
    function onNextPage() as Boolean { v.showMap = !v.showMap; WatchUi.requestUpdate(); return true; }
    function onPreviousPage() as Boolean { return true; }
    function onBack() as Boolean { doSave(); return true; }

    // Buttons: hold Up to redo
    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_UP) { v.redoHold.start(); return true; }
        return false;
    }
    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_UP) { v.redoHold.cancel(); }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (v.hitRight(evt.getCoordinates()[0])) { doSave(); }
        return true;
    }
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        if (v.hitLeft(evt.getCoordinates()[0])) { v.redoHold.start(); }
        return true;
    }
    function onRelease(evt as WatchUi.ClickEvent) as Boolean {
        v.redoHold.cancel();
        return true;
    }

    function doSave() as Void {
        if (v.saved) { return; }
        v.saved = true;
        var wasGraduated = Program.status() == Program.GRADUATED;
        s.save();
        if (!wasGraduated && Program.status() == Program.GRADUATED) {
            // Final run of week 9: show the graduation screen once
            var gv = new GraduationView();
            WatchUi.switchToView(gv, new GraduationDelegate(gv), WatchUi.SLIDE_UP);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    function doRedo() as Void {
        if (v.saved) { return; }
        v.saved = true;
        var indoor = s.indoor;
        s.discard();
        var pv = new PreviewView();
        pv.indoor = indoor;
        WatchUi.switchToView(pv, new PreviewDelegate(pv), WatchUi.SLIDE_DOWN);
    }
}
