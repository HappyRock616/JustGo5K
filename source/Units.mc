import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Distance and pace formatting. Units follow the watch unless overridden.
module Units {
    const METERS_PER_MILE = 1609.344;

    function imperial() as Boolean {
        var v = Properties.getValue("units");
        if (v == 1) { return true; }
        if (v == 2) { return false; }
        return System.getDeviceSettings().paceUnits == System.UNIT_STATUTE;
    }

    function unitMeters() as Float { return imperial() ? METERS_PER_MILE : 1000.0; }

    function paceLabel() as String { return imperial() ? "/mi" : "/km"; }

    function distLabel() as String { return imperial() ? "mi" : "km"; }

    // Pace from speed in metres per second
    function paceFromSpeed(mps as Float or Null) as String {
        if (mps == null || mps < 0.3) { return "--"; }
        var sec = (unitMeters() / mps).toNumber();
        if (sec > 5999) { return "--"; }
        return Draw.mmss(sec);
    }

    // Pace from total seconds and metres
    function paceFrom(seconds as Number, meters as Float or Null) as String {
        if (meters == null || meters < 10) { return "--"; }
        return Draw.mmss((seconds * unitMeters() / meters).toNumber());
    }

    function dist(meters as Float or Null) as String {
        if (meters == null) { return "--"; }
        return (meters / unitMeters()).format("%.2f");
    }
}
