import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Screen 6: paused. Resume, Save (end early), Hold to discard.
class PauseView extends WatchUi.View {
    const LABELS = ["Resume", "Save", "Hold discard"];
    var s as RunSession;
    var focus as Number = 0;
    var discardHold as Hold or Null = null;
    var btnY as Array<Number> = [0, 0, 0] as Array<Number>;
    var btnX as Number = 0;
    var btnW as Number = 0;
    var btnH as Number = 0;
    var wideX as Number = 0;     // discard button, which can be wider
    var wideW as Number = 0;

    function initialize(session as RunSession) {
        View.initialize();
        s = session;
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        btnW = f.d(110);
        btnH = f.d(34);
        btnX = f.cx - btnW / 2;

        // Side panels sit beside the top two buttons. Where the watch's fonts
        // are large for its screen (Venu Sq) they would touch the buttons, so
        // centre them in the space between the buttons and the screen edge.
        var inner = btnW / 2 + f.d(5);                 // button edge plus focus ring
        var off = f.d(Draw.PANEL_OFF);
        if (off - Draw.panelW(dc, f) / 2 < inner) { off = (inner + f.size * 29 / 60) / 2; }
        Draw.hrPacePanels(dc, f, s.hr, "--", off);
        Draw.fitText(dc, f.cx, f.y(66), "PAUSED", f.d(170), [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>, Theme.TEXT);
        Draw.text(dc, f.cx, f.y(96), Graphics.FONT_SMALL, "+" + Draw.mmss(s.pausedForSec()), 0xFAC775);

        for (var i = 0; i < 3; i++) {
            var y = f.y(118 + i * 42);
            btnY[i] = y;
            // The discard button sits below the side panels, so it can widen
            // to fit its label
            var x = btnX, w = btnW;
            if (i == 2) {
                var need = dc.getTextWidthInPixels(LABELS[2], Graphics.FONT_XTINY) + f.d(16);
                if (need > w) { w = need; x = f.cx - w / 2; }
                wideX = x;
                wideW = w;
            }
            var fill = i == 0 ? Theme.primary() : Theme.track();
            var tc = i == 0 ? Theme.onPrimary() : (i == 2 ? Theme.MISSED : Theme.TEXT);
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, btnH, btnH / 2);
            if (i == 2 && discardHold != null && discardHold.frac() > 0) {
                dc.setClip(x, y, (w * discardHold.frac()).toNumber(), btnH);
                dc.setColor(0x791F1F, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, y, w, btnH, btnH / 2);
                dc.clearClip();
            }
            if (i == focus) {
                dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(f.d(2));
                dc.drawRoundedRectangle(x - f.d(3), y - f.d(3), w + f.d(6), btnH + f.d(6), (btnH + f.d(6)) / 2);
            }
            Draw.fitText(dc, f.cx, y + btnH / 2, LABELS[i], w - f.d(10), [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>, tc);
        }
        Draw.text(dc, f.cx, f.y(258), Graphics.FONT_XTINY, "Total " + Draw.mmss(s.elapsedSec()), Theme.TEXT_DIM);
    }

    function hit(x as Number, y as Number) as Number {
        for (var i = 0; i < 3; i++) {
            var x0 = i == 2 ? wideX : btnX, w = i == 2 ? wideW : btnW;
            if (x >= x0 && x <= x0 + w && y >= btnY[i] - 4 && y <= btnY[i] + btnH + 4) { return i; }
        }
        return -1;
    }
}

// Called by the session after 30 minutes paused. Ends the run like Save does;
// the summary then saves it automatically. The pause screen is always on top
// while a run is paused.
function endPausedRun() as Void {
    var s = Live.session;
    if (s == null || s.finished) { return; }
    s.endEarly();
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    $.showSummary();
}

class PauseDelegate extends WatchUi.BehaviorDelegate {
    var v as PauseView;
    var s as RunSession;

    function initialize(view as PauseView, session as RunSession) {
        BehaviorDelegate.initialize();
        v = view;
        s = session;
        v.discardHold = new Hold(3000, method(:doDiscard));
    }

    function onBack() as Boolean { doResume(); return true; }

    function onNextPage() as Boolean { v.focus = (v.focus + 1) % 3; WatchUi.requestUpdate(); return true; }
    function onPreviousPage() as Boolean { v.focus = (v.focus + 2) % 3; WatchUi.requestUpdate(); return true; }

    function onSelect() as Boolean {
        if (v.focus == 0) { doResume(); }
        else if (v.focus == 1) { doSave(); }
        return true;   // discard needs a hold
    }

    // Buttons: hold Start on "Hold discard"
    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER && v.focus == 2) { v.discardHold.start(); return true; }
        return false;
    }
    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { v.discardHold.cancel(); }
        return false;
    }

    // Touch
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var i = v.hit(c[0], c[1]);
        if (i == 0) { doResume(); } else if (i == 1) { doSave(); }
        return true;
    }
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        if (v.hit(c[0], c[1]) == 2) { v.focus = 2; v.discardHold.start(); }
        return true;
    }
    function onRelease(evt as WatchUi.ClickEvent) as Boolean {
        v.discardHold.cancel();
        return true;
    }

    function doResume() as Void {
        s.resume();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function doSave() as Void {
        s.endEarly();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        $.showSummary();
    }

    function doDiscard() as Void {
        s.discard();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);   // pause
        WatchUi.popView(WatchUi.SLIDE_DOWN);        // run -> home
    }
}
