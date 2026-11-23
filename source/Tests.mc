import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Unit tests for the plan and weekly rules. Compiled only with --unit-test.
// Run: monkeyc -t ... then monkeydo <prg> <device> -t
// Dates are January-March 2027 (no daylight-saving change) unless a test says otherwise. 3 Jan 2027 is a Sunday.
(:test)
module T {
    function local(y as Number, m as Number, d as Number, h as Number, mi as Number) as Number {
        var utc = Gregorian.moment({:year => y, :month => m, :day => d, :hour => h, :minute => mi, :second => 0}).value();
        return utc - System.getClockTime().timeZoneOffset;
    }

    // Local time using that date's own daylight-saving offset (local() uses today's)
    function localDst(y as Number, m as Number, d as Number, h as Number, mi as Number) as Number {
        var utc = Gregorian.moment({:year => y, :month => m, :day => d, :hour => h, :minute => mi, :second => 0}).value();
        return utc - Program.utcOffset(utc - System.getClockTime().timeZoneOffset);
    }

    function reset(now as Number) as Void {
        Storage.deleteValue("w1");
        Storage.deleteValue("runs");
        Program.testNow = now;
    }

    function addRun(t as Number, wk as Number, rn as Number) as Void {
        Program.addRun({"t" => t, "wu" => false, "wk" => wk, "rn" => rn, "run" => 600, "walk" => 600, "pause" => 0});
    }

    function check(logger as Logger, ok as Boolean, what as String) as Boolean {
        if (!ok) { logger.error("FAILED: " + what); }
        return ok;
    }
}

(:test)
function planTotals(logger as Logger) as Boolean {
    var ok = true;
    ok = T.check(logger, Plan.mainSeconds(1, 1) == 1110, "week 1 main set 18:30") && ok;
    ok = T.check(logger, Plan.runSeconds(1, 1) == 480, "week 1 runs 8 min") && ok;
    ok = T.check(logger, Plan.mainSeconds(3, 2) == 900, "week 3 main set 15:00") && ok;
    ok = T.check(logger, Plan.mainSeconds(4, 3) == 1290, "week 4 main set 21:30") && ok;
    ok = T.check(logger, Plan.mainSeconds(5, 3) == 1200, "week 5 run 3 = 20 min") && ok;
    ok = T.check(logger, Plan.mainSeconds(6, 3) == 1500, "week 6 run 3 = 25 min") && ok;
    ok = T.check(logger, Plan.mainSeconds(9, 1) == 1800, "week 9 = 30 min") && ok;
    ok = T.check(logger, Plan.totalSeconds(9, 1) == 2400, "warm-up and cool-down add 10 min") && ok;
    var s = Plan.session(2, 1);
    ok = T.check(logger, s[0][0] == Plan.RUN && s[s.size() - 1][0] == Plan.RUN, "sessions start and end on a run") && ok;
    return ok;
}

(:test)
function startMidWeekIsWarmup(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 6, 10, 0));          // Wednesday
    Program.startProgram();
    var ok = T.check(logger, Program.week1() == T.local(2027, 1, 10, 0, 0), "week 1 starts next Sunday");
    ok = T.check(logger, Program.status() == Program.WARMUP, "status is warm-up") && ok;
    ok = T.check(logger, Program.currentWeek() == 0, "current week 0") && ok;
    ok = T.check(logger, Program.canStart(), "warm-up runs allowed") && ok;
    return ok;
}

(:test)
function startOnSundayIsWeekOne(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 3, 9, 0));           // Sunday
    Program.startProgram();
    var ok = T.check(logger, Program.week1() == T.local(2027, 1, 3, 0, 0), "week 1 starts today");
    ok = T.check(logger, Program.currentWeek() == 1, "current week 1") && ok;
    ok = T.check(logger, Program.status() == Program.READY, "ready") && ok;
    return ok;
}

(:test)
function firstRunOnSundayCountsForWeekOne(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 3, 9, 0));           // Sunday, plan not started
    var ok = T.check(logger, !Program.nextIsWarmup(), "Sunday first run is not a warm-up");
    Program.startProgram();
    ok = T.check(logger, !Program.nextIsWarmup(), "still week 1 after Start") && ok;
    T.reset(T.local(2027, 1, 6, 9, 0));           // Wednesday, plan not started
    ok = T.check(logger, Program.nextIsWarmup(), "mid-week first run is a warm-up") && ok;
    Program.startProgram();
    ok = T.check(logger, Program.nextIsWarmup(), "still a warm-up after Start") && ok;
    return ok;
}

(:test)
function routesKeptForThisWeekOnly(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 13, 9, 0));          // Wednesday of the second week
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    var lastWeek = T.local(2027, 1, 7, 9, 0), thisWeek = T.local(2027, 1, 11, 9, 0);
    T.addRun(lastWeek, 1, 3);
    T.addRun(thisWeek, 2, 1);
    Storage.setValue(Program.trackKey(lastWeek), {"spd" => [1.0]});
    Storage.setValue(Program.trackKey(thisWeek), {"spd" => [1.0]});
    Program.pruneTracks(Program.thisSunday());
    var ok = T.check(logger, Storage.getValue(Program.trackKey(lastWeek)) == null, "last week's route deleted");
    ok = T.check(logger, Storage.getValue(Program.trackKey(thisWeek)) != null, "this week's route kept") && ok;
    ok = T.check(logger, Program.runs().size() == 2, "run history kept") && ok;
    Program.restart();
    ok = T.check(logger, Storage.getValue(Program.trackKey(thisWeek)) == null, "restart deletes all routes") && ok;
    return ok;
}

(:test)
function goTodayWarning(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 4, 9, 0));           // Monday, 6 days left
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    var ok = T.check(logger, Program.status() == Program.READY, "Monday with 3 runs left is ready");
    Program.testNow = T.local(2027, 1, 7, 9, 0);  // Thursday, 3 days left, 3 runs need 5
    ok = T.check(logger, Program.status() == Program.GO_TODAY, "Thursday with 3 runs left is go today") && ok;
    return ok;
}

(:test)
function restTodayAfterRun(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 4, 18, 0));
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 4, 7, 0), 1, 1);
    var ok = T.check(logger, Program.status() == Program.REST_TODAY, "rest after running today");
    ok = T.check(logger, !Program.canStart(), "second run today blocked") && ok;
    Program.testNow = T.local(2027, 1, 5, 7, 0);
    ok = T.check(logger, Program.status() == Program.READY, "next day ready") && ok;
    ok = T.check(logger, Program.nextRun() == 2, "next is run 2") && ok;
    return ok;
}

(:test)
function weekCompleteLocksUntilSunday(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 8, 9, 0));           // Friday
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 3, 7, 0), 1, 1);
    T.addRun(T.local(2027, 1, 5, 7, 0), 1, 2);
    T.addRun(T.local(2027, 1, 7, 7, 0), 1, 3);
    var ok = T.check(logger, Program.status() == Program.COMPLETE, "complete after 3 runs");
    ok = T.check(logger, !Program.canStart(), "start locked") && ok;
    Program.testNow = T.local(2027, 1, 10, 6, 0); // Sunday
    ok = T.check(logger, Program.currentWeek() == 2, "Sunday starts week 2") && ok;
    ok = T.check(logger, Program.status() == Program.READY, "week 2 ready") && ok;
    return ok;
}

(:test)
function saturdayMidnightBoundary(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 9, 23, 59));
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 9, 23, 58), 1, 1);
    var ok = T.check(logger, Program.countedThisWeek() == 1, "11:58 pm Saturday counts in week 1");
    Program.testNow = T.local(2027, 1, 10, 0, 1);
    ok = T.check(logger, Program.countedThisWeek() == 0, "12:01 am Sunday is a fresh week") && ok;
    ok = T.check(logger, Program.currentWeek() == 2, "and it is week 2") && ok;
    return ok;
}

(:test)
function missedRunsShowInHistory(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 18, 9, 0));          // Monday of week 3
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 3, 7, 0), 1, 1);
    T.addRun(T.local(2027, 1, 5, 7, 0), 1, 2);
    T.addRun(T.local(2027, 1, 7, 7, 0), 1, 3);
    T.addRun(T.local(2027, 1, 11, 7, 0), 2, 1);
    var slots = Program.historySlots();
    var missed = 0;
    for (var i = 0; i < slots.size(); i++) { if (slots[i]["miss"] == true) { missed++; } }
    var ok = T.check(logger, slots.size() == 6, "3 + 1 runs + 2 missed slots");
    ok = T.check(logger, missed == 2, "week 2 shows 2 missed") && ok;
    ok = T.check(logger, Program.currentWeek() == 3, "plan moved on to week 3") && ok;
    return ok;
}

(:test)
function graduation(logger as Logger) as Boolean {
    T.reset(T.local(2027, 3, 4, 9, 0));           // Thursday of week 9
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    var ok = T.check(logger, Program.currentWeek() == 9, "week 9");
    ok = T.check(logger, Program.status() != Program.GRADUATED, "not graduated mid week 9") && ok;
    T.addRun(T.local(2027, 2, 28, 7, 0), 9, 1);
    T.addRun(T.local(2027, 3, 2, 7, 0), 9, 2);
    T.addRun(T.local(2027, 3, 3, 7, 0), 9, 3);
    ok = T.check(logger, Program.status() == Program.GRADUATED, "graduated after week 9 run 3") && ok;
    Program.testNow = T.local(2027, 3, 8, 9, 0);  // week 10, never reset automatically
    ok = T.check(logger, Program.status() == Program.GRADUATED && Program.isStarted(), "stays graduated, no auto reset") && ok;
    return ok;
}

(:test)
function dayDots(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 7, 12, 0));          // Thursday
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 3, 7, 0), 1, 1);    // Sunday
    T.addRun(T.local(2027, 1, 5, 7, 0), 1, 2);    // Tuesday
    var d = Program.dayStates();
    var want = [Program.DAY_RUN, Program.DAY_REST, Program.DAY_RUN, Program.DAY_REST,
                Program.DAY_TODAY, Program.DAY_FUTURE, Program.DAY_FUTURE];
    var ok = true;
    for (var i = 0; i < 7; i++) { ok = T.check(logger, d[i] == want[i], "day " + i.format("%d")) && ok; }
    return ok;
}

(:test)
function restartClearsEverything(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 7, 12, 0));
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 3, 7, 0), 1, 1);
    Program.restart();
    var ok = T.check(logger, !Program.isStarted(), "not started after restart");
    ok = T.check(logger, Program.runs().size() == 0, "history cleared") && ok;
    ok = T.check(logger, Program.status() == Program.NOT_STARTED, "status not started") && ok;
    return ok;
}

(:test)
function paceColoursAreFixed(logger as Logger) as Boolean {
    var mile = Units.METERS_PER_MILE;
    var ok = T.check(logger, PaceMap.colorFor(mile / 420.0) == 0xE24B4A, "7:00/mi is red (sprint)");
    ok = T.check(logger, PaceMap.colorFor(mile / 540.0) == 0xF0802A, "9:00/mi is orange") && ok;
    ok = T.check(logger, PaceMap.colorFor(mile / 660.0) == 0xF5C542, "11:00/mi is yellow") && ok;
    ok = T.check(logger, PaceMap.colorFor(mile / 780.0) == 0x7ED957, "13:00/mi is green") && ok;
    ok = T.check(logger, PaceMap.colorFor(mile / 900.0) == 0x2DB3C9, "15:00/mi is teal") && ok;
    ok = T.check(logger, PaceMap.colorFor(mile / 1200.0) == 0x3C6FD8, "20:00/mi is blue") && ok;
    ok = T.check(logger, PaceMap.colorFor(0.0) == 0x3C6FD8, "standing still is blue") && ok;
    return ok;
}

(:test)
function unitFormatting(logger as Logger) as Boolean {
    var saved = Properties.getValue("units");
    Properties.setValue("units", 1);              // imperial
    var ok = T.check(logger, Units.paceFromSpeed(Units.METERS_PER_MILE / 600.0).equals("10:00"), "10:00 /mi");
    ok = T.check(logger, Units.paceFrom(1800, 3.0 * Units.METERS_PER_MILE).equals("10:00"), "30 min over 3 mi") && ok;
    ok = T.check(logger, Units.dist(Units.METERS_PER_MILE).equals("1.00"), "1.00 mi") && ok;
    Properties.setValue("units", 2);              // metric
    ok = T.check(logger, Units.dist(5000.0).equals("5.00"), "5.00 km") && ok;
    ok = T.check(logger, Units.paceFromSpeed(0.0).equals("--"), "no pace when stopped") && ok;
    Properties.setValue("units", saved);
    Program.testNow = null;
    return ok;
}

// Weeks still start at local midnight on Sunday in the weeks the clocks change.
// Only meaningful where the watch's time zone has daylight saving (US dates).
(:test)
function daylightSavingWeeks(logger as Logger) as Boolean {
    var dst = Program.utcOffset(T.localDst(2027, 3, 13, 12, 0)) != Program.utcOffset(T.localDst(2027, 3, 17, 12, 0));
    logger.debug(dst ? "time zone has daylight saving" : "no daylight saving here: checks are trivial");
    T.reset(T.localDst(2027, 3, 17, 10, 0));      // Wednesday after clocks go forward (14 Mar)
    Storage.setValue("w1", T.localDst(2027, 3, 7, 0, 0));
    var ok = T.check(logger, Program.thisSunday() == T.localDst(2027, 3, 14, 0, 0), "spring: week starts Sunday midnight");
    ok = T.check(logger, Program.dayStart(T.localDst(2027, 3, 14, 12, 0)) == T.localDst(2027, 3, 14, 0, 0), "spring: midnight on change day") && ok;
    T.addRun(T.localDst(2027, 3, 13, 23, 30), 1, 1);   // Saturday night, last week
    ok = T.check(logger, Program.runsThisWeek(true).size() == 0, "spring: Saturday 11:30 pm is last week") && ok;
    ok = T.check(logger, Program.currentWeek() == 2, "spring: week 2") && ok;
    T.reset(T.localDst(2027, 11, 10, 10, 0));     // Wednesday after clocks go back (7 Nov)
    Storage.setValue("w1", T.localDst(2027, 11, 7, 0, 0));
    ok = T.check(logger, Program.thisSunday() == T.localDst(2027, 11, 7, 0, 0), "autumn: week starts Sunday midnight") && ok;
    T.addRun(T.localDst(2027, 11, 7, 0, 30), 1, 1);    // Sunday 12:30 am, this week
    ok = T.check(logger, Program.runsThisWeek(true).size() == 1, "autumn: Sunday 12:30 am is this week") && ok;
    ok = T.check(logger, Program.dayStates()[0] == Program.DAY_RUN, "autumn: Sunday dot shows the run") && ok;
    return ok;
}

(:test)
function redoOnlyThisWeek(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 13, 9, 0));          // Wednesday of week 2
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 7, 9, 0), 1, 3);    // last week
    var ok = T.check(logger, !Program.removeLastRun(), "last week's run is never removed");
    ok = T.check(logger, Program.runs().size() == 1, "history unchanged") && ok;
    T.addRun(T.local(2027, 1, 11, 9, 0), 2, 1);   // this week
    ok = T.check(logger, Program.removeLastRun(), "this week's run removed") && ok;
    ok = T.check(logger, Program.runs().size() == 1, "only that run removed") && ok;
    return ok;
}

(:test)
function routeSpacingStaysEven(logger as Logger) as Boolean {
    var s = new RunSession(1, 1, false, false);
    for (var i = 0; i < 400; i++) { s.trackLat.add(i.toFloat()); s.trackLon.add(i.toFloat()); s.trackSpd.add(i.toFloat()); }
    s.thinTrack();
    var ok = T.check(logger, s.trackSpd.size() == 200 && s.trackLat.size() == 200, "halved to 200 points");
    ok = T.check(logger, s.trackSpd[1] == 2.0 && s.trackSpd[199] == 398.0, "every other point kept") && ok;
    ok = T.check(logger, s.trackEveryMs == 6000, "new points every 6 s, matching the kept ones") && ok;
    // Saved route: simplified, but always ends at the finish
    s.trackLat = [] as Array<Float>; s.trackLon = [] as Array<Float>; s.trackSpd = [] as Array<Float>;
    for (var i = 0; i < 300; i++) { s.trackLat.add(i.toFloat()); s.trackLon.add(i.toFloat()); s.trackSpd.add(i.toFloat()); }
    s.startTime = 1;
    s.saveTrack();
    var trk = Storage.getValue(Program.trackKey(1)) as Dictionary;
    var lat = trk["lat"] as Array<Float>;
    ok = T.check(logger, lat.size() == 151 && lat[lat.size() - 1] == 299.0, "saved route ends at the finish") && ok;
    Storage.deleteValue(Program.trackKey(1));
    return ok;
}

(:test)
function stalePaceShowsDashes(logger as Logger) as Boolean {
    var s = new RunSession(1, 1, false, false);
    var ok = T.check(logger, s.liveSpeed() == null, "no pace before any GPS fix");
    s.setSpeed(2.5);
    ok = T.check(logger, s.liveSpeed() == 2.5, "fresh speed shown") && ok;
    s.speedAt = System.getTimer() - 11000;
    ok = T.check(logger, s.liveSpeed() == null, "11 s without a fix shows --") && ok;
    return ok;
}

(:test)
function glanceSaysRuns(logger as Logger) as Boolean {
    T.reset(T.local(2027, 1, 5, 9, 0));           // Tuesday of week 1, one run done
    Storage.setValue("w1", T.local(2027, 1, 3, 0, 0));
    T.addRun(T.local(2027, 1, 3, 7, 0), 1, 1);
    var l = new JustGo5KGlance().lines();
    var ok = T.check(logger, l[l.size() - 1].equals("2 runs · 5d left"), "plural runs: " + l[l.size() - 1]);
    T.addRun(T.local(2027, 1, 4, 7, 0), 1, 2);
    l = new JustGo5KGlance().lines();
    ok = T.check(logger, l[l.size() - 1].equals("1 run · 5d left"), "single run: " + l[l.size() - 1]) && ok;
    Program.testNow = null;
    return ok;
}
