import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Press-and-hold confirmation. Fills over `ms`, fires `done` when complete,
// resets if released early.
class Hold {
    var ms as Number;
    var done as Method;
    var started as Number = 0;
    var active as Boolean = false;
    var timer as Timer.Timer or Null = null;

    function initialize(durationMs as Number, callback as Method) {
        ms = durationMs;
        done = callback;
    }

    function start() as Void {
        if (active) { return; }
        active = true;
        started = System.getTimer();
        timer = new Timer.Timer();
        timer.start(method(:tick), 100, true);
    }

    function cancel() as Void {
        active = false;
        if (timer != null) { timer.stop(); timer = null; }
        WatchUi.requestUpdate();
    }

    function frac() as Float {
        if (!active) { return 0.0; }
        var f = (System.getTimer() - started).toFloat() / ms;
        return f > 1.0 ? 1.0 : f;
    }

    function tick() as Void {
        WatchUi.requestUpdate();
        if (frac() >= 1.0) {
            cancel();
            done.invoke();
        }
    }
}
