import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Test hooks. The "autorun" variants are only compiled by test.jungle and the
// "pagetour" variants only by tour.jungle; monkey.jungle excludes both.
module Dbg {
    (:autorun)
    function speed() as Number { return 20; }
    (:noautorun)
    function speed() as Number { return 1; }

    (:autorun)
    function autorun() as Boolean { return true; }
    (:noautorun)
    function autorun() as Boolean { return false; }

    (:pagetour)
    function tour() as Boolean { return true; }
    (:nopagetour)
    function tour() as Boolean { return false; }
}

// tour.jungle: shows every screen in turn (4 s each) for screenshots.
// Order: home, history, stats, settings, pace map, graduation, preview,
// 3-2-1 transition, pause, summary, summary map.
(:pagetour)
class Tour {
    var step as Number = 0;
    var timer as Timer.Timer;
    var summary as SummaryView or Null = null;

    function initialize() {
        timer = new Timer.Timer();
        timer.start(method(:next), 4000, true);
    }

    function show(v as WatchUi.View, d as WatchUi.BehaviorDelegate) as Void {
        WatchUi.switchToView(v, d, WatchUi.SLIDE_IMMEDIATE);
    }

    function demoSession() as RunSession {
        var s = new RunSession(4, 3, false, false);
        s.hr = 142;
        s.setSpeed(2.6);
        return s;
    }

    function next() as Void {
        step++;
        if (step <= 3) { Pages.show(step, true); return; }
        if (step == 4) {
            var r = Program.runs();
            if (r.size() > 0) { show(new PaceMapView(r[r.size() - 1]), new PaceMapDelegate()); }
        } else if (step == 5) {
            var gv = new GraduationView();
            show(gv, new GraduationDelegate(gv));
        } else if (step == 6) {
            var pv = new PreviewView();
            show(pv, new PreviewDelegate(pv));
        } else if (step == 7) {
            var s = demoSession();
            s.idx = 3;                                  // a 5:00 run segment
            s.phaseMs = s.phaseSec() * 1000 - 2500;     // 3 s left -> countdown
            show(new RunView(s), new RunDelegate(s));
        } else if (step == 8) {
            var s2 = demoSession();
            s2.idx = 4;
            s2.paused = true;
            s2.pauseStart = System.getTimer() - 42000;
            s2.hr = 118;
            var p = new PauseView(s2);
            show(p, new PauseDelegate(p, s2));
        } else if (step == 9) {
            var s3 = demoSession();
            s3.mainStarted = true;
            s3.finished = true;
            s3.runMs = 16 * 60000;
            s3.walkMs = 330000;
            s3.stats = {"dist" => 3060.0, "kcal" => 268, "hra" => 141, "hrm" => 163};
            var r2 = Program.runs();
            var trk = r2.size() > 0 ? PaceMap.loadTrack(r2[r2.size() - 1]["t"] as Number) : null;
            if (trk != null) {
                s3.trackLat = trk["lat"] as Array<Float>;
                s3.trackLon = trk["lon"] as Array<Float>;
                s3.trackSpd = trk["spd"] as Array<Float>;
            }
            summary = new SummaryView(s3);
            show(summary, new SummaryDelegate(summary, s3));
        } else if (step == 10) {
            if (summary != null) { summary.showMap = true; WatchUi.requestUpdate(); }
        } else if (step == 11) {
            var s4 = demoSession();
            s4.idx = 3;                                 // mid-way through a 5:00 run
            s4.phaseMs = 138000;
            s4.setSpeed(2.45);
            show(new RunView(s4), new RunDelegate(s4));
        } else if (step == 12) {
            var s5 = demoSession();
            s5.idx = 4;                                 // walk segment
            s5.phaseMs = 52000;
            s5.hr = 124;
            s5.setSpeed(1.55);
            show(new RunView(s5), new RunDelegate(s5));
        } else {
            timer.stop();
        }
    }
}
