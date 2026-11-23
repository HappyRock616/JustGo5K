import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class HomeView extends WatchUi.View {
    const DAY_LABELS = ["Su", "M", "T", "W", "Th", "F", "Sa"];

    // Start button bounds in pixels, used for touch hit-testing
    var btnX as Number = 0;
    var btnY as Number = 0;
    var btnW as Number = 0;
    var btnH as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        var st = Program.status();
        var week = Program.currentWeek();

        Draw.weekRing(dc, f, week < 1 ? 0 : week);   // not started or warm-up: all grey

        // Title and subtitle
        var title = "WEEK " + week.format("%d");
        var sub = "Run " + Program.nextRun().format("%d") + " of 3 next";
        if (st == Program.NOT_STARTED) { title = "JUST GO 5K"; sub = "9 weeks · 3 runs a week"; }
        else if (week < 1) { title = "WARM-UP"; sub = "Week 1 starts Sunday"; }
        else if (st == Program.COMPLETE) { sub = "All 3 runs done"; }
        else if (st == Program.GRADUATED) { title = "5K READY"; sub = "Plan complete"; }
        Draw.fitText(dc, f.cx, f.y(64), title, f.d(150), [Graphics.FONT_SMALL, Graphics.FONT_TINY], Theme.TEXT);
        Draw.fitText(dc, f.cx, f.y(88), sub, f.d(170), [Graphics.FONT_XTINY], Theme.TEXT_DIM);

        // Day dots, Sunday to Saturday
        var states = Program.dayStates();
        var dotY = f.y(122);
        // Small screens: fall back to one-letter day labels if two letters crowd
        var labels = DAY_LABELS;
        if (dc.getTextWidthInPixels("Th", Graphics.FONT_XTINY) > f.d(30) * 8 / 10) {
            labels = ["S", "M", "T", "W", "T", "F", "S"];
        }
        for (var i = 0; i < 7; i++) {
            var x = f.x(60 + i * 30);
            var s = states[i];
            var labelColor = Theme.TEXT_DIM;
            if (s == Program.DAY_RUN || s == Program.DAY_TODAY_RUN) {
                dc.setColor(Theme.primary(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, f.d(12));
                Draw.tick(dc, f, x, dotY, Theme.onPrimary());
            } else if (s == Program.DAY_REST) {
                dc.setColor(Theme.restBg(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, f.d(12));
                Draw.sofa(dc, f, x, dotY + f.d(1));
            } else if (s == Program.DAY_FUTURE) {
                dc.setColor(Theme.futureDot(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, f.d(5));
            }
            if (s == Program.DAY_TODAY || s == Program.DAY_TODAY_RUN) {
                dc.setColor(Theme.secondary(), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(f.d(2.5));
                dc.drawCircle(x, dotY, f.d(s == Program.DAY_TODAY ? 11 : 14));
                labelColor = Theme.secondary();
            }
            Draw.text(dc, x, dotY + f.d(26), Graphics.FONT_XTINY, labels[i], labelColor);
        }

        // Status line
        var statusText = "";
        var statusColor = Theme.secondary();
        var remaining = Plan.RUNS_PER_WEEK - Program.countedThisWeek();
        var days = Program.daysLeft();
        var dayWord = days == 1 ? " day left" : " days left";
        var runWord = remaining == 1 ? " run · " : " runs · ";
        if (st == Program.NOT_STARTED) { statusText = "Ready when you are"; }
        else if (st == Program.WARMUP) { statusText = "Bonus warm-up runs"; }
        else if (st == Program.READY) { statusText = remaining.format("%d") + runWord + days.format("%d") + dayWord; }
        else if (st == Program.GO_TODAY) { statusText = "Go today · " + remaining.format("%d") + (remaining == 1 ? " run left" : " runs left"); statusColor = Theme.primary(); }
        else if (st == Program.REST_TODAY) { statusText = "Nice work · rest today"; }
        else if (st == Program.COMPLETE) { statusText = "Week complete"; statusColor = Theme.primary(); }
        else { statusText = "You did it"; statusColor = Theme.primary(); }
        Draw.fitText(dc, f.cx, f.y(186), statusText, f.d(190), [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY], statusColor);

        // Start button
        // Button wordings, longest first; small screens get the shorter one
        var canStart = Program.canStart();
        var opts = ["See results", "Results"];
        if (canStart) {
            var mins = (Plan.totalSeconds(Program.sessionWeek(), Program.nextRun()) + 30) / 60;
            opts = ["Start · " + mins.format("%d") + " min", "Start"];
        } else if (st == Program.REST_TODAY) {
            opts = ["Back tomorrow", "Tomorrow"];
        } else if (st == Program.COMPLETE) {
            var d = Program.daysLeft();
            opts = ["Locked · " + d.format("%d") + (d == 1 ? " day" : " days"), "Locked"];
        }
        btnW = f.d(140);
        btnH = f.d(36);
        btnX = f.cx - btnW / 2;
        btnY = f.y(206);
        var label = Draw.pick(dc, opts, btnW - f.d(8), Graphics.FONT_XTINY);
        Draw.pill(dc, f, btnX, btnY, btnW, btnH, label, canStart || st == Program.GRADUATED);
    }

    function hitStart(x as Number, y as Number) as Boolean {
        var pad = btnH / 2;
        return x >= btnX - pad && x <= btnX + btnW + pad && y >= btnY - pad && y <= btnY + btnH + pad;
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {
    var view as HomeView;

    function initialize(v as HomeView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() as Boolean {
        start();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        if (view.hitStart(c[0], c[1])) { start(); }
        return true;
    }

    // Page loop: swipe/Down -> history, Up -> settings, hold Menu -> settings
    function onNextPage() as Boolean { Pages.show(Pages.HISTORY, true); return true; }
    function onPreviousPage() as Boolean { Pages.show(Pages.SETTINGS, false); return true; }
    function onMenu() as Boolean { Pages.show(Pages.SETTINGS, true); return true; }

    function start() as Void {
        if (Program.status() == Program.GRADUATED) {
            var gv = new GraduationView();
            WatchUi.pushView(gv, new GraduationDelegate(gv), WatchUi.SLIDE_UP);
            return;
        }
        if (!Program.canStart()) {
            if (WatchUi has :showToast) { WatchUi.showToast("Not yet", null); }
            return;
        }
        var pv = new PreviewView();
        WatchUi.pushView(pv, new PreviewDelegate(pv), WatchUi.SLIDE_UP);
    }
}
