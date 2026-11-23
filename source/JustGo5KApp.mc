import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class JustGo5KApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart/onStop also run for the glance, so app-only work is guarded.
    var appOpened as Boolean = false;

    function onStart(state as Dictionary?) as Void {
    }

    // If the app is closed mid-run or before the summary saves, keep the run
    // (the summary's default is to save). Nothing recorded yet = discard.
    function onStop(state as Dictionary?) as Void {
        if (appOpened) { saveRunOnExit(); }
    }

    function saveRunOnExit() as Void {
        var s = Live.session;
        if (s == null) { return; }
        if (s.mainStarted) {
            if (!s.finished) { s.endEarly(); }
            s.save();
        } else {
            s.discard();
        }
    }

    (:pagetour)
    var tour as Tour or Null = null;
    (:pagetour)
    function startTour() as Void { tour = new Tour(); }
    (:nopagetour)
    function startTour() as Void {}

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        appOpened = true;
        seedDemoData();
        startTour();
        if (Dbg.autorun()) {
            var s = new RunSession(4, 3, false, false);
            Live.session = s;
            s.begin();
            return [new RunView(s), new RunDelegate(s)];
        }
        var v = new HomeView();
        return [v, new HomeDelegate(v)];
    }

    (:glance, :nopagetour)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new JustGo5KGlance()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Debug builds only: fill an empty program with sample history so the
    // screens can be checked in the simulator. Never included in release builds.
    (:debug)
    function seedDemoData() as Void {
        if (Program.isStarted()) { return; }
        var sun = Program.thisSunday();
        var w1 = sun - 3 * Program.WEEK;
        Application.Storage.setValue("w1", w1);
        var hour = 7 * 3600;
        // [week, day-of-week index, run number]; week 3 deliberately misses two runs
        var plan = [[1,0,1],[1,2,2],[1,5,3],[2,1,1],[2,3,2],[2,6,3],[3,2,1]];
        var runs = [];
        for (var i = 0; i < plan.size(); i++) {
            var p = plan[i];
            runs.add(demoRun(w1 + (p[0] - 1) * Program.WEEK + p[1] * Program.DAY + hour, p[0], p[2]));
        }
        // This week: runs on Sunday and Tuesday if those days have passed
        var dow = Program.todayDow();
        if (dow >= 2) { runs.add(demoRun(sun + hour, 4, 1)); }
        if (dow >= 4) { runs.add(demoRun(sun + 2 * Program.DAY + hour, 4, 2)); }
        Application.Storage.setValue("runs", runs);
        // Sample GPS loop for the latest run so the pace map has something to draw
        var last = runs[runs.size() - 1] as Dictionary;
        var la = [], lo = [], sp = [];
        for (var i = 0; i < 120; i++) {
            var a = i * 2 * Math.PI / 120;
            la.add((42.30 + 0.004 * Math.cos(a) + 0.0008 * Math.sin(3 * a)).toFloat());
            lo.add((-83.20 + 0.006 * Math.sin(a)).toFloat());
            var phase = (i / 10) % 2;
            sp.add(phase == 0 ? (2.2 + 0.6 * Math.sin(a * 4)).toFloat() : (1.5 + 0.2 * Math.cos(a)).toFloat());
        }
        Application.Storage.setValue("trk" + (last["t"] as Number).format("%d"), {"lat" => la, "lon" => lo, "spd" => sp});
    }

    (:release)
    function seedDemoData() as Void {}

    (:debug)
    function demoRun(t as Number, wk as Number, rn as Number) as Dictionary {
        var runSec = Plan.runSeconds(wk, rn);
        var walkSec = Plan.mainSeconds(wk, rn) - runSec;
        return {"t" => t, "wu" => false, "wk" => wk, "rn" => rn, "run" => runSec, "walk" => walkSec,
                "pause" => 0, "dist" => 2600 + wk * 250, "kcal" => 200 + wk * 30,
                "hra" => 128 + wk * 3, "hrm" => 150 + wk * 4};
    }
}
