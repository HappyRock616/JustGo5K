import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Program state and the weekly rules (calendar weeks, Sunday to Saturday).
(:glance)
module Program {
    const DAY = 86400;
    const WEEK = 604800;

    enum Status {
        NOT_STARTED,   // never pressed Start
        WARMUP,        // started mid-week, week 1 begins next Sunday
        READY,         // a run is available and there is time
        GO_TODAY,      // remaining runs only just fit before Saturday
        REST_TODAY,    // already ran today
        COMPLETE,      // all 3 runs done, locked until Sunday
        GRADUATED      // past week 9
    }

    enum DayState { DAY_FUTURE, DAY_TODAY, DAY_RUN, DAY_REST, DAY_TODAY_RUN }

    // ---------- time helpers ----------
    // Unit tests set testNow to a fixed epoch time; null means the real clock.
    var testNow as Number or Null = null;

    function nowSec() as Number { return testNow != null ? testNow : Time.now().value(); }

    // 1 = Sunday ... 7 = Saturday
    function todayDow() as Number {
        return Gregorian.info(new Time.Moment(nowSec()), Time.FORMAT_SHORT).day_of_week as Number;
    }

    // Seconds the local clock is ahead of UTC at a given time (daylight saving included)
    function utcOffset(t as Number) as Number {
        var i = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
        return Gregorian.moment({
            :year => i.year as Number, :month => i.month as Number, :day => i.day as Number,
            :hour => i.hour as Number, :minute => i.min as Number, :second => i.sec as Number
        }).value() - t;
    }

    // Local midnight at the start of a given day. On a daylight-saving change
    // day the clock skipped or repeated an hour, so allow for the offset change.
    function dayStart(t as Number) as Number {
        var i = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
        var m = t - ((i.hour as Number) * 3600 + (i.min as Number) * 60 + (i.sec as Number));
        m += utcOffset(t) - utcOffset(m);
        // Where clocks go back from 1 am to midnight (Cuba), midnight happens
        // twice: the day starts at the first one
        var e = m - 3600;
        var j = Gregorian.info(new Time.Moment(e), Time.FORMAT_SHORT);
        if (j.day == i.day && j.hour == 0) { m = e - ((j.min as Number) * 60 + (j.sec as Number)); }
        return m;
    }

    // Local midnight at the start of this Sunday. Steps back from midday, so a
    // 23- or 25-hour day can never land on the wrong date.
    function thisSunday() as Number {
        var today = dayStart(nowSec());
        var back = todayDow() - 1;
        return back == 0 ? today : dayStart(today + DAY / 2 - back * DAY);
    }

    // Days left in this week including today
    function daysLeft() as Number { return 8 - todayDow(); }

    // ---------- storage ----------
    function week1() as Number or Null {
        var v = Storage.getValue("w1");
        return (v instanceof Number) ? v : null;
    }

    function runs() as Array<Dictionary> {
        var v = Storage.getValue("runs");
        return (v instanceof Array) ? v as Array<Dictionary> : [] as Array<Dictionary>;
    }

    function isStarted() as Boolean { return week1() != null; }

    // Called the first time the user presses Start.
    function startProgram() as Void {
        if (isStarted()) { return; }
        var sun = thisSunday();
        Storage.setValue("w1", todayDow() == 1 ? sun : dayStart(sun + WEEK + DAY / 2));
    }

    // True when the next run is a bonus warm-up run (before week 1 starts).
    // Pressing Start for the first time on a Sunday makes today day 1 of week 1.
    function nextIsWarmup() as Boolean {
        return isStarted() ? isWarmupPhase() : todayDow() != 1;
    }

    function restart() as Void {
        pruneTracks(nowSec() + WEEK);
        Storage.deleteValue("w1");
        Storage.deleteValue("runs");
    }

    // Storage key of a run's simplified route
    function trackKey(t as Number) as String { return "trk" + t.format("%d"); }

    // Routes are kept on the watch for this week's runs only; the full route
    // is in each run's Garmin activity. Deletes the route of every run that
    // started before the time given.
    function pruneTracks(from as Number) as Void {
        var r = runs();
        for (var i = 0; i < r.size(); i++) {
            var t = r[i]["t"] as Number;
            if (t < from) { Storage.deleteValue(trackKey(t)); }
        }
    }

    function addRun(rec as Dictionary) as Void {
        var r = runs();
        r.add(rec);
        try {
            Storage.setValue("runs", r);
        } catch (e) {
            // Storage full: free every stored route and try once more. The
            // Garmin activity is already saved, so never crash here.
            pruneTracks(nowSec() + WEEK);
            try { Storage.setValue("runs", r); } catch (e2) { }
        }
    }

    // ---------- derived state ----------
    // Plan week for the current calendar week. <1 means warm-up phase.
    function currentWeek() as Number {
        var w1 = week1();
        if (w1 == null) { return 0; }
        var diff = thisSunday() - w1;
        return Math.round(diff.toFloat() / WEEK).toNumber() + 1;
    }

    function isWarmupPhase() as Boolean { return isStarted() && currentWeek() < 1; }

    // Runs recorded this calendar week (warm-up runs included when flag set)
    function runsThisWeek(includeWarmup as Boolean) as Array<Dictionary> {
        var sun = thisSunday();
        var out = [] as Array<Dictionary>;
        var all = runs();
        for (var i = 0; i < all.size(); i++) {
            var t = all[i]["t"] as Number;
            if (t >= sun && t < sun + WEEK) {
                if (includeWarmup || all[i]["wu"] != true) { out.add(all[i]); }
            }
        }
        return out;
    }

    function countedThisWeek() as Number { return runsThisWeek(false).size(); }

    function ranToday() as Boolean {
        var today = dayStart(nowSec());
        var r = runsThisWeek(true);
        for (var i = 0; i < r.size(); i++) {
            if ((r[i]["t"] as Number) >= today) { return true; }
        }
        return false;
    }

    // Next run number in this week (1..3)
    function nextRun() as Number {
        var n = countedThisWeek() + 1;
        return n > Plan.RUNS_PER_WEEK ? Plan.RUNS_PER_WEEK : n;
    }

    // Plan week the next session uses (warm-up runs use week 1)
    function sessionWeek() as Number {
        var w = currentWeek();
        if (w < 1) { return 1; }
        return w > Plan.WEEKS ? Plan.WEEKS : w;
    }

    function status() as Status {
        if (!isStarted()) { return NOT_STARTED; }
        var w = currentWeek();
        if (w < 1) { return ranToday() ? REST_TODAY : WARMUP; }
        if (w > Plan.WEEKS) { return GRADUATED; }
        var done = countedThisWeek();
        if (done >= Plan.RUNS_PER_WEEK) {
            return (w == Plan.WEEKS) ? GRADUATED : COMPLETE;
        }
        if (ranToday()) { return REST_TODAY; }
        var remaining = Plan.RUNS_PER_WEEK - done;
        // remaining runs with a rest day between each need (2r - 1) days
        if (daysLeft() <= 2 * remaining - 1) { return GO_TODAY; }
        return READY;
    }

    function canStart() as Boolean {
        var s = status();
        return s == NOT_STARTED || s == WARMUP || s == READY || s == GO_TODAY;
    }

    // Day of week (0 = Sunday) for an epoch time
    function dayIndexOf(t as Number) as Number {
        return (Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT).day_of_week as Number) - 1;
    }

    // Completed plan runs only (no warm-up runs), oldest first
    function planRuns() as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        var all = runs();
        for (var i = 0; i < all.size(); i++) {
            if (all[i]["wu"] != true) { out.add(all[i]); }
        }
        return out;
    }

    // History slots for the chart: every week shows 3 slots. Past weeks with
    // fewer than 3 runs get {"miss" => true} placeholders. Warm-up runs first.
    function historySlots() as Array<Dictionary> {
        var all = runs();
        var slots = [] as Array<Dictionary>;
        for (var i = 0; i < all.size(); i++) {
            if (all[i]["wu"] == true) { slots.add(all[i]); }
        }
        var cw = currentWeek();
        var last = cw > Plan.WEEKS ? Plan.WEEKS : cw;
        for (var w = 1; w <= last; w++) {
            var n = 0;
            for (var i = 0; i < all.size(); i++) {
                if (all[i]["wu"] != true && all[i]["wk"] == w) { slots.add(all[i]); n++; }
            }
            if (w < cw) {
                for (var k = n; k < Plan.RUNS_PER_WEEK; k++) { slots.add({"miss" => true, "wk" => w}); }
            }
        }
        return slots;
    }

    // Remove this week's most recent run so it can be done again (its Garmin
    // activity stays). Runs from earlier weeks are never removed.
    function removeLastRun() as Boolean {
        var r = runs();
        if (r.size() == 0) { return false; }
        var t = r[r.size() - 1]["t"] as Number;
        if (t < thisSunday()) { return false; }
        Storage.deleteValue(trackKey(t));
        r = r.slice(0, r.size() - 1);
        Storage.setValue("runs", r);
        return true;
    }

    // State of each day dot, index 0 = Sunday
    function dayStates() as Array<Number> {
        var sun = thisSunday();
        var todayIdx = todayDow() - 1;
        var ran = [false, false, false, false, false, false, false];
        var r = runsThisWeek(true);
        for (var i = 0; i < r.size(); i++) {
            var d = dayIndexOf(r[i]["t"] as Number);
            if (d >= 0 && d < 7) { ran[d] = true; }
        }
        var out = [] as Array<Number>;
        for (var d = 0; d < 7; d++) {
            if (d == todayIdx) { out.add(ran[d] ? DAY_TODAY_RUN : DAY_TODAY); }
            else if (d < todayIdx) { out.add(ran[d] ? DAY_RUN : DAY_REST); }
            else { out.add(DAY_FUTURE); }
        }
        return out;
    }
}
