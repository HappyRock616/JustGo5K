import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Screen 1: session preview. Start Outdoor (left) or Start Indoor (right).
class PreviewView extends WatchUi.View {
    var week as Number;
    var run as Number;
    var warmup as Boolean;
    var indoor as Boolean;

    function initialize() {
        View.initialize();
        warmup = Program.nextIsWarmup();
        week = Program.sessionWeek();
        run = warmup ? 1 : Program.nextRun();
        indoor = Storage.getValue("lastIn") == true;
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        Draw.sessionRing(dc, f, Plan.session(week, run), -1, 0.0, true);

        var label = warmup ? "WARM-UP RUN" : "WEEK " + week.format("%d") + " · RUN " + run.format("%d");
        Draw.fitText(dc, f.cx, f.y(96), label, f.d(130), [Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.TEXT_MUTED);
        Draw.fitText(dc, f.cx, f.y(148), Draw.mmss(Plan.mainSeconds(week, run)), f.d(104),
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>, Theme.TEXT);
        var runMin = Plan.runSeconds(week, run) / 60;
        // Below the start panels so they never cover it
        Draw.fitText(dc, f.cx, f.y(206), runMin.format("%d") + " min running", f.d(150), [Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.secondary());

        startPanel(dc, f, Draw.PANEL_L, false);
        startPanel(dc, f, Draw.PANEL_R, true);
    }

    function startPanel(dc as Dc, f as Draw.Frame, p as Array<Number>, isIndoor as Boolean) as Void {
        // Outdoor is always the primary colour, Indoor the secondary.
        // The remembered choice gets a white outline.
        var bg = isIndoor ? Theme.secondary() : Theme.primary();
        var fg = isIndoor ? Theme.onSecondary() : Theme.onPrimary();
        Draw.panelBox(dc, f, p, bg);
        if (isIndoor == indoor) {
            dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(f.d(2.5));
            dc.drawRoundedRectangle(f.x(p[0]) - f.d(3), f.y(p[1]) - f.d(3), f.d(p[2] + 6), f.d(p[3] + 6), f.d(12));
        }
        var cx = f.x(p[0] + p[2] / 2);
        // Stack icon, "START" and the label, centred in the panel using the real font height
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var iconH = f.d(22);
        var line = (fh * 0.85).toNumber();
        var total = iconH + line * 2;
        var top = f.y(p[1]) + (f.d(p[3]) - total) / 2;
        var iy = top + iconH * 6 / 10;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(f.d(2));
        if (isIndoor) {
            // house
            var w = f.d(10), h = f.d(9);
            dc.drawLine(cx - w - f.d(2), iy, cx, iy - f.d(10));
            dc.drawLine(cx, iy - f.d(10), cx + w + f.d(2), iy);
            dc.drawRectangle(cx - w, iy - f.d(1), w * 2, h);
        } else {
            // sun
            dc.drawCircle(cx, iy - f.d(2), f.d(5));
            for (var k = 0; k < 8; k++) {
                var a = k * Math.PI / 4;
                dc.drawLine(cx + (f.d(8) * Math.cos(a)).toNumber(), iy - f.d(2) + (f.d(8) * Math.sin(a)).toNumber(),
                            cx + (f.d(11) * Math.cos(a)).toNumber(), iy - f.d(2) + (f.d(11) * Math.sin(a)).toNumber());
            }
        }
        Draw.text(dc, cx, top + iconH + line / 2, Graphics.FONT_XTINY, Draw.pick(dc, ["START", "Start", "GO"], f.d(p[2]), Graphics.FONT_XTINY), fg);
        var name = isIndoor ? "Indoor" : "Outdoor";
        if (dc.getTextWidthInPixels(name, Graphics.FONT_XTINY) > f.d(p[2] - 6)) { name = isIndoor ? "In" : "Out"; }
        Draw.text(dc, cx, top + iconH + line + line / 2, Graphics.FONT_XTINY, name, fg);
    }
}

class PreviewDelegate extends WatchUi.BehaviorDelegate {
    var view as PreviewView;

    function initialize(v as PreviewView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() as Boolean { go(view.indoor); return true; }

    function onNextPage() as Boolean { toggle(); return true; }
    function onPreviousPage() as Boolean { toggle(); return true; }

    function toggle() as Void {
        view.indoor = !view.indoor;
        WatchUi.requestUpdate();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var x = evt.getCoordinates()[0];
        var w = System.getDeviceSettings().screenWidth;
        if (x < w / 3) { go(false); } else if (x > w * 2 / 3) { go(true); }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function go(indoor as Boolean) as Void {
        Storage.setValue("lastIn", indoor);
        Program.startProgram();
        var s = new RunSession(view.week, view.run, view.warmup, indoor);
        Live.session = s;
        var rv = new RunView(s);
        WatchUi.switchToView(rv, new RunDelegate(s), WatchUi.SLIDE_UP);
        s.begin();
    }
}
