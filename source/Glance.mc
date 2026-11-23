import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance: one-line summary in the watch's widget/glance list.
(:glance)
class JustGo5KGlance extends WatchUi.GlanceView {
    const PRIMARY = [0x19D3C5, 0xBD93F9, 0xFF8A1F, 0xF5B841, 0x2E9E5B];

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var t = Properties.getValue("theme");
        var color = PRIMARY[(t instanceof Number && t >= 0 && t < 5) ? t : 2];
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 4, Graphics.FONT_GLANCE, "JUST GO 5K", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        // Longest wording that fits the glance width
        var options = lines();
        var text = options[options.size() - 1];
        for (var i = 0; i < options.size(); i++) {
            if (dc.getTextWidthInPixels(options[i], Graphics.FONT_GLANCE) <= dc.getWidth()) { text = options[i]; break; }
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 3 / 4, Graphics.FONT_GLANCE, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Status wordings, longest first
    function lines() as Array<String> {
        var st = Program.status();
        var w = Program.currentWeek().format("%d");
        var n = Plan.RUNS_PER_WEEK - Program.countedThisWeek();
        var left = n.format("%d") + (n == 1 ? " run" : " runs");
        var days = Program.daysLeft().format("%d");
        if (st == Program.NOT_STARTED) { return ["Ready when you are", "Ready to go"]; }
        if (st == Program.WARMUP) { return ["Week 1 starts Sunday", "Wk 1 on Sunday"]; }
        if (st == Program.GRADUATED) { return ["5K ready"]; }
        if (st == Program.COMPLETE) { return ["Week " + w + " complete", "Wk " + w + " done"]; }
        if (st == Program.REST_TODAY) { return ["Wk " + w + " · rest today", "Rest today"]; }
        if (st == Program.GO_TODAY) { return ["Wk " + w + " · go today", "Go today"]; }
        return ["Wk " + w + " · " + left + " · " + days + "d left", "Wk " + w + " · " + left + " · " + days + "d", left + " · " + days + "d left"];
    }
}
