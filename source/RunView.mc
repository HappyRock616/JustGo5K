import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Screens 2-5 and 7: warm-up, run, 3-2-1 transition, walk, cool-down.
// One view; what it shows follows the session timer automatically.
class RunView extends WatchUi.View {
    var s as RunSession;

    function initialize(session as RunSession) {
        View.initialize();
        s = session;
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        var f = new Draw.Frame(dc);
        var t = s.phaseType();
        var transition = s.inTransition();
        var bg = Theme.BG, fg = Theme.TEXT;
        // "Dim runs" setting: keep the background black and colour the text instead
        var dim = Application.Properties.getValue("dim") == true;
        if (!transition && t == Plan.RUN) {
            if (dim) { fg = Theme.primary(); } else { bg = Theme.primary(); fg = Theme.onPrimary(); }
        } else if (!transition && t == Plan.WALK) {
            if (dim) { fg = Theme.secondary(); } else { bg = Theme.secondary(); fg = Theme.onSecondary(); }
        }
        Draw.clear(dc, Theme.BG);
        if (bg != Theme.BG) {
            dc.setColor(bg, bg);
            dc.fillCircle(f.cx, f.cy, f.size / 2 + 2);
            if (Draw.isRect()) { dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight()); }
        }

        // Session ring: same thickness everywhere; blinks during 3-2-1
        var blinkOn = !transition || (System.getTimer() % 1000) < 500;
        // dark track behind the ring so it reads on coloured backgrounds
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(f.ringW() + f.d(6));
        dc.drawCircle(f.cx, f.cy, f.ringR());
        Draw.sessionRing(dc, f, s.main, s.mainIndex(), s.phaseFrac(), blinkOn);

        Draw.hrPacePanels(dc, f, s.hr, Units.paceFromSpeed(s.liveSpeed()), f.d(Draw.PANEL_OFF));

        var next = s.nextPhase();
        if (transition) {
            Draw.text(dc, f.cx, f.y(170), Graphics.FONT_NUMBER_THAI_HOT, s.remainingSec().format("%d"), Theme.TEXT);
            if (next != null) {
                var nt = next[0];
                var label = nt == Plan.RUN ? "Run next" : (nt == Plan.WALK ? "Walk next" : "Cool-down next");
                var c = nt == Plan.RUN ? Theme.primary() : (nt == Plan.WALK ? Theme.secondary() : Theme.TEXT_MUTED);
                Draw.fitText(dc, f.cx, f.y(238), label, f.d(170), [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, c);
            }
            return;
        }

        var title = "WARM-UP";
        if (t == Plan.RUN) { title = "RUN"; }
        else if (t == Plan.WALK) { title = "WALK"; }
        else if (t == Plan.COOLDOWN) { title = "COOL-DOWN"; }
        var titleColor = (bg == Theme.BG) ? Theme.TEXT_MUTED : fg;
        Draw.fitText(dc, f.cx, f.y(86), title, f.d(150), [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>, titleColor);

        Draw.fitText(dc, f.cx, f.y(155), Draw.mmss(s.remainingSec()), f.d(112),
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>, fg);

        var bottom = "";
        var bottomColor = fg;
        if (t == Plan.COOLDOWN) {
            bottom = "Nice work";
            bottomColor = Theme.secondary();
        } else if (next != null) {
            var nt2 = next[0];
            if (nt2 == Plan.RUN) { bottom = "Run " + Draw.mmss(next[1]) + " next"; }
            else if (nt2 == Plan.WALK) { bottom = "Walk " + Draw.mmss(next[1]) + " next"; }
            else { bottom = "Cool-down next"; }
            if (bg == Theme.BG) { bottomColor = nt2 == Plan.RUN ? Theme.primary() : Theme.secondary(); }
        }
        var bigFonts = (bg == Theme.BG)
            ? [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>
            : [Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
        Draw.fitText(dc, f.cx, f.y(232), bottom, f.d(180), bigFonts, bottomColor);
    }
}

class RunDelegate extends WatchUi.BehaviorDelegate {
    var s as RunSession;

    function initialize(session as RunSession) {
        BehaviorDelegate.initialize();
        s = session;
    }

    // Back never exits a run: it pauses.
    function onBack() as Boolean { openPause(); return true; }
    function onSelect() as Boolean { openPause(); return true; }
    function onTap(evt as WatchUi.ClickEvent) as Boolean { return true; }
    function onNextPage() as Boolean { return true; }
    function onPreviousPage() as Boolean { return true; }

    function openPause() as Void {
        s.pause();
        var v = new PauseView(s);
        WatchUi.pushView(v, new PauseDelegate(v, s), WatchUi.SLIDE_IMMEDIATE);
    }
}

// Called by the session when the cool-down ends.
function showSummary() as Void {
    var s = Live.session;
    if (s == null) { return; }
    var v = new SummaryView(s);
    WatchUi.switchToView(v, new SummaryDelegate(v, s), WatchUi.SLIDE_UP);
}
