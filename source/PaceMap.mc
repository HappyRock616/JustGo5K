import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Screen 9: route coloured by pace on a FIXED scale (never rescaled per run).
// Outdoor: GPS route. Indoor: pace over time as a ring from 12 o'clock.
module PaceMap {
    // Upper pace limits in seconds per mile, fastest first, and their colours.
    const LIMITS = [480, 600, 720, 840, 1020];
    const COLORS = [0xE24B4A, 0xF0802A, 0xF5C542, 0x7ED957, 0x2DB3C9, 0x3C6FD8];

    function colorFor(mps as Float) as Number {
        if (mps < 0.3) { return COLORS[5]; }
        var secPerMile = Units.METERS_PER_MILE / mps;
        for (var i = 0; i < LIMITS.size(); i++) {
            if (secPerMile < LIMITS[i]) { return COLORS[i]; }
        }
        return COLORS[5];
    }

    // Draw a stored track: {"lat"=>[], "lon"=>[], "spd"=>[]}
    function draw(dc as Dc, f as Draw.Frame, lat as Array<Float>, lon as Array<Float>, spd as Array<Float>, indoor as Boolean) as Void {
        if (indoor || lat.size() < 2) {
            drawRing(dc, f, spd);
            return;
        }
        var minLa = lat[0], maxLa = lat[0], minLo = lon[0], maxLo = lon[0];
        for (var i = 1; i < lat.size(); i++) {
            if (lat[i] < minLa) { minLa = lat[i]; } if (lat[i] > maxLa) { maxLa = lat[i]; }
            if (lon[i] < minLo) { minLo = lon[i]; } if (lon[i] > maxLo) { maxLo = lon[i]; }
        }
        var midLa = (minLa + maxLa) / 2, midLo = (minLo + maxLo) / 2;
        var k = Math.cos(Math.toRadians(midLa));
        var spanX = (maxLo - minLo) * k, spanY = maxLa - minLa;
        var boxW = f.d(150).toFloat(), boxH = f.d(116).toFloat();
        var sx = spanX > 0 ? boxW / spanX : 1e9;
        var sy = spanY > 0 ? boxH / spanY : 1e9;
        var s = sx < sy ? sx : sy;
        if (s > 1e8) { drawRing(dc, f, spd); return; }
        var cx = f.cx, cy = f.y(146);
        dc.setPenWidth(f.d(5));
        var px = cx + ((lon[0] - midLo) * k * s).toNumber();
        var py = cy - ((lat[0] - midLa) * s).toNumber();
        var startX = px, startY = py;
        for (var i = 1; i < lat.size(); i++) {
            var nx = cx + ((lon[i] - midLo) * k * s).toNumber();
            var ny = cy - ((lat[i] - midLa) * s).toNumber();
            var sp = i < spd.size() ? (spd[i] + spd[i - 1]) / 2 : 0.0;
            dc.setColor(colorFor(sp), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px, py, nx, ny);
            px = nx; py = ny;
        }
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(startX, startY, f.d(5));
    }

    // Pace over time as a ring starting at 12 o'clock
    function drawRing(dc as Dc, f as Draw.Frame, spd as Array<Float>) as Void {
        var n = spd.size();
        var r = f.d(90);
        dc.setPenWidth(f.d(24));
        if (n == 0) {
            dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(f.cx, f.cy, r);
            return;
        }
        for (var i = 0; i < n; i++) {
            var a0 = 90.0 - 360.0 * i / n;
            var a1 = 90.0 - 360.0 * (i + 1) / n - 0.6;
            dc.setColor(colorFor(spd[i]), Graphics.COLOR_TRANSPARENT);
            dc.drawArc(f.cx, f.cy, r, Graphics.ARC_CLOCKWISE, a0, a1);
        }
    }

    function loadTrack(t as Number) as Dictionary or Null {
        var v = Storage.getValue("trk" + t.format("%d"));
        return (v instanceof Dictionary) ? v : null;
    }
}

// Read-only pace map for a past run, opened from the stats table.
class PaceMapView extends WatchUi.View {
    var rec as Dictionary;
    var trk as Dictionary or Null;

    function initialize(r as Dictionary) {
        View.initialize();
        rec = r;
        trk = PaceMap.loadTrack(r["t"] as Number);
    }

    function onUpdate(dc as Dc) as Void {
        Draw.aa(dc);
        Draw.clear(dc, Theme.BG);
        var f = new Draw.Frame(dc);
        var indoor = rec["in"] == true;
        var wk = rec["wu"] == true ? "WARM-UP" : "WEEK " + (rec["wk"] as Number).format("%d") + " · RUN " + (rec["rn"] as Number).format("%d");
        Draw.fitText(dc, f.cx, f.y(52), wk, f.d(170), [Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.TEXT_MUTED);
        if (trk == null) {
            // Routes are kept on the watch for the current week only
            var old = (rec["t"] as Number) < Program.thisSunday();
            var xt = [Graphics.FONT_XTINY] as Array<Graphics.FontType>;
            Draw.fitText(dc, f.cx, f.y(old ? 126 : 146), old ? "Map not kept" : "No route saved", f.d(170),
                [Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>, Theme.TEXT_DIM);
            if (old) {
                Draw.fitText(dc, f.cx, f.y(156), "Full route is in", f.d(170), xt, Theme.TEXT_MUTED);
                Draw.fitText(dc, f.cx, f.y(176), "the Garmin activity", f.d(170), xt, Theme.TEXT_MUTED);
            }
        } else {
            PaceMap.draw(dc, f, trk["lat"] as Array<Float>, trk["lon"] as Array<Float>, trk["spd"] as Array<Float>, indoor);
        }
        var d = rec["dist"];
        var df = (d instanceof Number || d instanceof Float || d instanceof Double) ? d.toFloat() : null;
        var secs = (rec["run"] as Number) + (rec["walk"] as Number);   // moving time, pauses excluded
        if (indoor && trk != null) {
            Draw.text(dc, f.cx, f.y(140), Graphics.FONT_XTINY, "INDOOR", Theme.TEXT_MUTED);
            Draw.text(dc, f.cx, f.y(162), Graphics.FONT_SMALL, Units.dist(df) + " " + Units.distLabel(), Theme.TEXT);
        }
        Draw.fitText(dc, f.cx, f.y(248), Units.dist(df) + " " + Units.distLabel() + " · " + Units.paceFrom(secs, df) + " " + Units.paceLabel(),
            f.d(170), [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>, Theme.TEXT);
    }
}

class PaceMapDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onSelect() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
}
