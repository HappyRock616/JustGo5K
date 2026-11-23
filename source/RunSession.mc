import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Holds the run in progress so every view can reach it.
module Live {
    var session as RunSession or Null = null;
}

// The run engine: phase timer, alerts, activity recording and stats.
// Phases are warm-up, the plan's main set, then cool-down. Only the main set
// is recorded as the Garmin activity.
class RunSession {
    const TICK_MS = 250;
    const MAX_TRACK = 180;
    const SPEED_STALE_MS = 10000;     // no fresh speed for 10 s (GPS lost): pace shows "--"
    const PAUSE_LIMIT_MS = 1800000;   // 30 min paused: end and save automatically

    var week as Number;
    var run as Number;
    var warmupRun as Boolean;   // bonus run before week 1 starts
    var indoor as Boolean;

    var phases as Array<Array<Number> > = [] as Array<Array<Number> >;
    var main as Array<Array<Number> >;
    var idx as Number = 0;
    var phaseMs as Number = 0;
    var lastTick as Number = 0;
    var lastCountdown as Number = 99;

    var paused as Boolean = false;
    var pauseStart as Number = 0;
    var pauseMs as Number = 0;       // paused time during the main set
    var lastPausedSec as Number = -1;
    var runMs as Number = 0;
    var walkMs as Number = 0;

    var rec as ActivityRecording.Session or Null = null;
    var mainStarted as Boolean = false;
    var mainEnded as Boolean = false;
    var finished as Boolean = false;
    var startTime as Number = 0;
    var stats as Dictionary = {};

    var hr as Number or Null = null;
    var speed as Float or Null = null;
    var speedAt as Number = 0;        // System.getTimer() of the last fresh speed
    var gpsAt as Number = 0;          // System.getTimer() of the last usable GPS fix
    var trackEveryMs as Number = 3000;
    var trackLat as Array<Float> = [] as Array<Float>;
    var trackLon as Array<Float> = [] as Array<Float>;
    var trackSpd as Array<Float> = [] as Array<Float>;
    var lastTrackMs as Number = 0;

    var timer as Timer.Timer or Null = null;

    function initialize(wk as Number, rn as Number, isWarmupRun as Boolean, isIndoor as Boolean) {
        week = wk;
        run = rn;
        warmupRun = isWarmupRun;
        indoor = isIndoor;
        main = Plan.session(week, run);
        phases.add([Plan.WARMUP, Plan.WARMUP_SEC]);
        for (var i = 0; i < main.size(); i++) { phases.add(main[i]); }
        phases.add([Plan.COOLDOWN, Plan.COOLDOWN_SEC]);
    }

    // ---------- lifecycle ----------
    function begin() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>);
        if (!indoor) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
        lastTick = System.getTimer();
        timer = new Timer.Timer();
        timer.start(method(:tick), TICK_MS, true);
        alert(Plan.WARMUP);
    }

    function shutdownSensors() as Void {
        if (timer != null) { timer.stop(); timer = null; }
        if (!indoor) { Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition)); }
    }

    // ---------- queries used by the views ----------
    function phaseType() as Number { return phases[idx < phases.size() ? idx : phases.size() - 1][0]; }
    function phaseSec() as Number { return phases[idx < phases.size() ? idx : phases.size() - 1][1]; }
    function remainingSec() as Number {
        var r = phaseSec() * 1000 - phaseMs;
        return r <= 0 ? 0 : (r + 999) / 1000;
    }
    function phaseFrac() as Float {
        var f = phaseMs.toFloat() / (phaseSec() * 1000);
        return f > 1.0 ? 1.0 : f;
    }
    // Index of the current main-set segment, or -2 before / 99 after the main set
    function mainIndex() as Number {
        if (idx == 0) { return -2; }
        if (idx > main.size()) { return 99; }
        return idx - 1;
    }
    function inTransition() as Boolean {
        return !paused && idx < phases.size() - 1 && remainingSec() <= 3 && phaseType() != Plan.COOLDOWN;
    }
    // [type, seconds] of the next phase, or null
    function nextPhase() as Array<Number> or Null {
        return (idx + 1 < phases.size()) ? phases[idx + 1] : null;
    }
    function pausedForSec() as Number {
        return paused ? (System.getTimer() - pauseStart) / 1000 : 0;
    }
    // Current speed in m/s, or null when it is out of date (GPS lost)
    function liveSpeed() as Float or Null {
        return (System.getTimer() - speedAt <= SPEED_STALE_MS) ? speed : null;
    }
    function setSpeed(v as Float) as Void {
        speed = v;
        speedAt = System.getTimer();
    }
    function elapsedSec() as Number {
        var total = 0;
        for (var i = 0; i < idx && i < phases.size(); i++) { total += phases[i][1]; }
        return total + phaseMs / 1000;
    }

    // ---------- timer ----------
    function tick() as Void {
        var now = System.getTimer();
        var dt = (now - lastTick) * Dbg.speed();
        lastTick = now;
        updateLive();
        if (finished) { WatchUi.requestUpdate(); return; }
        if (paused) {
            // A forgotten pause would keep GPS and the screen running, so a
            // long pause ends the run; the summary then saves it.
            if ((now - pauseStart) * Dbg.speed() >= PAUSE_LIMIT_MS) { $.endPausedRun(); return; }
            // Only the pause clock changes: redraw once a second
            var ps = pausedForSec();
            if (ps != lastPausedSec) { lastPausedSec = ps; WatchUi.requestUpdate(); }
            return;
        }

        phaseMs += dt;
        var t = phaseType();
        if (t == Plan.RUN) { runMs += dt; } else if (t == Plan.WALK) { walkMs += dt; }

        // 3-2-1 countdown pulses
        var rem = remainingSec();
        if (rem <= 3 && rem >= 1 && rem < lastCountdown && idx < phases.size() - 1 && t != Plan.COOLDOWN) {
            lastCountdown = rem;
            pulse();
        }
        if (phaseMs >= phaseSec() * 1000) { advance(); }
        WatchUi.requestUpdate();
    }

    function advance() as Void {
        var over = phaseMs - phaseSec() * 1000;
        var leaving = idx;
        idx += 1;
        phaseMs = over > 0 ? over : 0;
        lastCountdown = 99;

        if (leaving == 0) {
            startRecording();
        } else if (leaving == main.size()) {
            endMainSet();
        } else if (rec != null) {
            rec.addLap();
        }
        if (idx >= phases.size()) {
            finished = true;
            shutdownSensors();
            $.showSummary();
            return;
        }
        alert(phaseType());
    }

    // ---------- recording ----------
    function startRecording() as Void {
        if (mainStarted) { return; }
        mainStarted = true;
        startTime = Time.now().value();
        if (Toybox has :ActivityRecording) {
            rec = ActivityRecording.createSession({
                :name => "Just Go 5K",
                :sport => ActivityRecording.SPORT_RUNNING,
                :subSport => indoor ? ActivityRecording.SUB_SPORT_TREADMILL : ActivityRecording.SUB_SPORT_GENERIC
            });
            rec.start();
        }
    }

    function endMainSet() as Void {
        if (mainEnded) { return; }
        mainEnded = true;
        captureStats();
        if (rec != null && rec.isRecording()) { rec.stop(); }
    }

    function captureStats() as Void {
        var info = Activity.getActivityInfo();
        var dist = null, kcal = null, hra = null, hrm = null;
        if (info != null) {
            dist = info.elapsedDistance;
            kcal = info.calories;
            hra = info.averageHeartRate;
            hrm = info.maxHeartRate;
        }
        stats = {"dist" => dist, "kcal" => kcal, "hra" => hra, "hrm" => hrm};
    }

    // ---------- pause / end ----------
    function pause() as Void {
        if (paused || finished) { return; }
        paused = true;
        pauseStart = System.getTimer();
        if (rec != null && rec.isRecording()) { rec.stop(); }
    }

    function resume() as Void {
        if (!paused) { return; }
        paused = false;
        var p = System.getTimer() - pauseStart;
        if (mainStarted && !mainEnded) { pauseMs += p; }
        lastTick = System.getTimer();
        if (rec != null && mainStarted && !mainEnded) { rec.start(); }
    }

    // End early from the pause screen. Returns false if nothing was recorded.
    function endEarly() as Boolean {
        if (paused) {
            var p = System.getTimer() - pauseStart;
            if (mainStarted && !mainEnded) { pauseMs += p; }
            paused = false;
        }
        finished = true;
        if (mainStarted && !mainEnded) { endMainSet(); }
        shutdownSensors();
        return mainStarted;
    }

    function discard() as Void {
        finished = true;
        shutdownSensors();
        if (rec != null) {
            if (rec.isRecording()) { rec.stop(); }
            rec.discard();
            rec = null;
        }
        Live.session = null;
    }

    // Save the Garmin activity and add the run to the program history.
    function save() as Void {
        if (rec != null) {
            if (rec.isRecording()) { rec.stop(); }
            rec.save();
            rec = null;
        }
        if (mainStarted) {
            var r = {
                "t" => startTime, "wu" => warmupRun, "wk" => week, "rn" => run,
                "in" => indoor,
                "run" => runMs / 1000, "walk" => walkMs / 1000, "pause" => pauseMs / 1000,
                "dist" => stats["dist"], "kcal" => stats["kcal"],
                "hra" => stats["hra"], "hrm" => stats["hrm"], "o2" => latestO2()
            };
            // Keep routes for this week's runs only (full routes are in the activities)
            Program.pruneTracks(Program.thisSunday());
            Program.addRun(r);
            saveTrack();
        }
        Live.session = null;
    }

    // Latest background SpO2 reading, where the watch supports it
    function latestO2() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getOxygenSaturationHistory)) {
            var it = SensorHistory.getOxygenSaturationHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (it != null) {
                var smp = it.next();
                if (smp != null && smp.data != null) { return smp.data.toNumber(); }
            }
        }
        return null;
    }

    // Main-set moving time, pauses excluded (matches the activity's timer
    // time, so pace agrees with Garmin Connect)
    function mainSec() as Number { return (runMs + walkMs) / 1000; }

    // ---------- sensors ----------
    function updateLive() as Void {
        var info = Activity.getActivityInfo();
        var now = System.getTimer();
        if (info != null) {
            hr = info.currentHeartRate;
            // The watch's own (smoothed) speed: always indoors, outdoors only
            // while GPS fixes keep arriving, so a lost signal shows "--"
            var v = info.currentSpeed;
            if (v != null && (indoor || now - gpsAt <= SPEED_STALE_MS)) { setSpeed(v); }
        }
        if (indoor && mainStarted && !mainEnded && !paused) {
            if (now - lastTrackMs >= 10000) {
                lastTrackMs = now;
                var s = liveSpeed();
                trackSpd.add(s == null ? 0.0 : s);
            }
        }
    }

    function onPosition(info as Position.Info) as Void {
        // Lost or last-known fixes are ignored, so pace goes stale and shows "--"
        if (info.accuracy != null && info.accuracy < Position.QUALITY_POOR) { return; }
        var now = System.getTimer();
        gpsAt = now;
        if (info.speed != null) { setSpeed(info.speed); }
        if (!mainStarted || mainEnded || paused || info.position == null) { return; }
        if (now - lastTrackMs < trackEveryMs) { return; }
        lastTrackMs = now;
        var deg = info.position.toDegrees();
        trackLat.add(deg[0].toFloat());
        trackLon.add(deg[1].toFloat());
        trackSpd.add(info.speed == null ? 0.0 : info.speed);
        // Keep memory bounded on 128 KB watches: halve the track when it grows large
        if (trackSpd.size() >= 400) { thinTrack(); }
    }

    // Halve the track and the sampling rate together, so points stay evenly
    // spaced over the whole run (the start never ends up coarser than the end)
    function thinTrack() as Void {
        var la = [] as Array<Float>, lo = [] as Array<Float>, sp = [] as Array<Float>;
        for (var i = 0; i < trackSpd.size(); i += 2) {
            if (i < trackLat.size()) { la.add(trackLat[i]); lo.add(trackLon[i]); }
            sp.add(trackSpd[i]);
        }
        trackLat = la; trackLon = lo; trackSpd = sp;
        trackEveryMs *= 2;
    }

    // Store a simplified track (max MAX_TRACK points) under its own key
    function saveTrack() as Void {
        var n = trackSpd.size();
        if (n == 0) { return; }
        var step = (n + MAX_TRACK - 1) / MAX_TRACK;
        var la = [] as Array<Float>, lo = [] as Array<Float>, sp = [] as Array<Float>;
        for (var i = 0; i < n; i += step) {
            if (!indoor) { la.add(trackLat[i]); lo.add(trackLon[i]); }
            sp.add(trackSpd[i]);
        }
        // Always end at the finish point
        if ((n - 1) % step != 0) {
            if (!indoor) { la.add(trackLat[n - 1]); lo.add(trackLon[n - 1]); }
            sp.add(trackSpd[n - 1]);
        }
        var key = Program.trackKey(startTime);
        var data = {"lat" => la, "lon" => lo, "spd" => sp};
        try {
            Storage.setValue(key, data);
        } catch (e) {
            // Storage full: drop every other stored route and try once more.
            // The run itself is already saved, so never crash here.
            Program.pruneTracks(startTime);
            try { Storage.setValue(key, data); } catch (e2) { }
        }
    }

    // ---------- alerts ----------
    function tonesOn() as Boolean { return Properties.getValue("alerts") != 0; }

    function pulse() as Void {
        if (Attention has :vibrate) { Attention.vibrate([new Attention.VibeProfile(60, 120)]); }
        if (tonesOn() && Attention has :playTone) { Attention.playTone(Attention.TONE_KEY); }
    }

    // Distinct patterns: run = 3 sharp, walk = 2 soft, warm-up/cool-down = 1 long
    function alert(type as Number) as Void {
        if (Attention has :backlight) {
            try { Attention.backlight(true); } catch (e) { }
        }
        var v = [] as Array<Attention.VibeProfile>;
        if (type == Plan.RUN) {
            v = [new Attention.VibeProfile(100, 200), new Attention.VibeProfile(0, 120),
                 new Attention.VibeProfile(100, 200), new Attention.VibeProfile(0, 120),
                 new Attention.VibeProfile(100, 200)];
        } else if (type == Plan.WALK) {
            v = [new Attention.VibeProfile(50, 350), new Attention.VibeProfile(0, 200),
                 new Attention.VibeProfile(50, 350)];
        } else {
            v = [new Attention.VibeProfile(70, 800)];
        }
        if (Attention has :vibrate) { Attention.vibrate(v); }
        if (tonesOn() && Attention has :playTone) {
            Attention.playTone(type == Plan.RUN ? Attention.TONE_START : Attention.TONE_LAP);
        }
    }
}
