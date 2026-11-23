import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Page 4: settings. Also reachable by holding Menu/Up on the home screen.
class SettingsView extends WatchUi.View {
    const ROWS = 6;
    var focus as Number = 0;
    var hold as Hold or Null = null;     // for rows 4 (redo) and 5 (restart)
    var holdRow as Number = -1;
    var rowY as Array<Number> = [0, 0, 0, 0, 0, 0] as Array<Number>;
    var rowH as Number = 0;
    var message as String = "";

    function initialize() {
        View.initialize();
    }

    function label(i as Number) as String {
        return ["Theme", "Units", "Alerts", "Dim runs", "Redo last run", "Restart plan"][i] as String;
    }

    // Value wordings for rows 1-3, longest first
    function values(i as Number) as Array<String> {
        if (i == 1) {
            var u = Properties.getValue("units");
            if (u == 1) { return ["Miles", "mi"]; }
            if (u == 2) { return ["Km"]; }
            return Units.imperial() ? ["Auto (mi)", "Auto"] : ["Auto (km)", "Auto"];
        }
        if (i == 2) { return Properties.getValue("alerts") == 0 ? ["Vibe"] : ["Vibe + tone", "Vibe+tone", "Tone on"]; }
        return [Properties.getValue("dim") == true ? "On" : "Off"];
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        var head = message.length() > 0 ? message : (focus >= 4 ? "Hold to confirm" : "SETTINGS");
        Draw.text(dc, f.cx, f.y(44), Graphics.FONT_XTINY, head, (message.length() > 0 || focus >= 4) ? Theme.primary() : Theme.TEXT_MUTED);
        rowH = f.d(32);
        var x0 = f.x(56), x1 = f.x(244);
        // Small screens with large fonts: labels drop to the smaller font if a
        // label and its value would touch
        var lf = Graphics.FONT_TINY;
        for (var i = 1; i < 4; i++) {
            var vs = values(i);
            if (dc.getTextWidthInPixels(label(i), lf) + dc.getTextWidthInPixels(vs[vs.size() - 1], Graphics.FONT_XTINY) + f.d(8) > x1 - x0) {
                lf = Graphics.FONT_XTINY;
            }
        }
        for (var i = 0; i < ROWS; i++) {
            var y = f.y(76 + i * 34);
            rowY[i] = y;
            if (i == focus) {
                dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x0 - f.d(8), y - rowH / 2, x1 - x0 + f.d(16), rowH, rowH / 2);
            }
            if (i == holdRow && hold != null && hold.frac() > 0) {
                dc.setClip(x0 - f.d(8), y - rowH / 2, ((x1 - x0 + f.d(16)) * hold.frac()).toNumber(), rowH);
                dc.setColor(i == 5 ? 0x791F1F : Theme.PAUSED, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x0 - f.d(8), y - rowH / 2, x1 - x0 + f.d(16), rowH, rowH / 2);
                dc.clearClip();
            }
            var lc = i == 5 ? 0xF09595 : Theme.TEXT;
            dc.setColor(lc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, y, lf, label(i), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            if (i == 0) {
                dc.setColor(Theme.primary(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x1 - f.d(18), y, f.d(7));
                dc.setColor(Theme.secondary(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x1 - f.d(3), y, f.d(7));
            } else if (i < 4) {
                dc.setColor(Theme.primary(), Graphics.COLOR_TRANSPARENT);
                var room = x1 - x0 - dc.getTextWidthInPixels(label(i), lf) - f.d(8);
                dc.drawText(x1, y, Graphics.FONT_XTINY, Draw.pick(dc, values(i), room, Graphics.FONT_XTINY), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    // Leaving the page stops any hold in progress
    function onHide() as Void {
        if (hold != null) { hold.cancel(); }
    }

    function rowAt(y as Number) as Number {
        for (var i = 0; i < ROWS; i++) {
            if (y >= rowY[i] - rowH / 2 && y <= rowY[i] + rowH / 2) { return i; }
        }
        return -1;
    }
}

class SettingsDelegate extends WatchUi.BehaviorDelegate {
    var v as SettingsView;

    function initialize(view as SettingsView) {
        BehaviorDelegate.initialize();
        v = view;
    }

    function onNextPage() as Boolean { v.focus = (v.focus + 1) % v.ROWS; v.message = ""; WatchUi.requestUpdate(); return true; }
    function onPreviousPage() as Boolean { v.focus = (v.focus + v.ROWS - 1) % v.ROWS; v.message = ""; WatchUi.requestUpdate(); return true; }
    function onBack() as Boolean { Pages.show(Pages.HOME, false); return true; }

    function onSelect() as Boolean {
        if (v.focus < 4) { change(v.focus); }
        return true;
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER && v.focus >= 4) { startHold(v.focus); return true; }
        return false;
    }
    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER && v.hold != null) { v.hold.cancel(); }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var r = v.rowAt(evt.getCoordinates()[1]);
        if (r >= 0) {
            v.focus = r;
            if (r < 4) { change(r); } else { v.message = "Hold to confirm"; WatchUi.requestUpdate(); }
        }
        return true;
    }
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var r = v.rowAt(evt.getCoordinates()[1]);
        if (r >= 4) { v.focus = r; startHold(r); }
        return true;
    }
    function onRelease(evt as WatchUi.ClickEvent) as Boolean {
        if (v.hold != null) { v.hold.cancel(); }
        return true;
    }

    function startHold(row as Number) as Void {
        // One hold at a time: a second press or touch must never leave an
        // earlier countdown running in the background
        if (v.hold != null) { v.hold.cancel(); }
        v.holdRow = row;
        v.hold = new Hold(3000, row == 5 ? method(:doRestart) : method(:doRedoLast));
        v.hold.start();
    }

    function change(i as Number) as Void {
        if (i == 0) { Properties.setValue("theme", (Theme.index() + 1) % Theme.THEMES.size()); }
        else if (i == 1) {
            var u = Properties.getValue("units");
            Properties.setValue("units", ((u instanceof Number ? u : 0) + 1) % 3);
        }
        else if (i == 2) { Properties.setValue("alerts", Properties.getValue("alerts") == 0 ? 1 : 0); }
        else if (i == 3) { Properties.setValue("dim", Properties.getValue("dim") != true); }
        v.message = "";
        WatchUi.requestUpdate();
    }

    function doRedoLast() as Void {
        v.message = Program.removeLastRun() ? "Last run cleared" : "No run this week";
        WatchUi.requestUpdate();
    }

    function doRestart() as Void {
        Program.restart();
        v.message = "Plan restarted";
        WatchUi.requestUpdate();
    }
}
