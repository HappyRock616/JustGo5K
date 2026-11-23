import Toybox.Lang;

// The 9-week run/walk plan. Each session is the MAIN SET only:
// an array of [type, seconds]. Warm-up and cool-down are added separately.
(:glance)
module Plan {
    const RUN = 0;
    const WALK = 1;
    const WARMUP = 2;
    const COOLDOWN = 3;
    const WEEKS = 9;
    const RUNS_PER_WEEK = 3;
    const WARMUP_SEC = 300;
    const COOLDOWN_SEC = 300;

    // week: 1..9, run: 1..3
    function session(week as Number, run as Number) as Array<Array<Number> > {
        var s = [] as Array<Array<Number> >;
        if (week <= 1) {
            repeatPair(s, 60, 90, 7);
            s.add([RUN, 60]);
        } else if (week == 2) {
            repeatPair(s, 90, 120, 5);
            s.add([RUN, 90]);
        } else if (week == 3) {
            for (var i = 0; i < 2; i++) {
                s.add([RUN, 90]); s.add([WALK, 90]);
                s.add([RUN, 180]);
                if (i == 0) { s.add([WALK, 180]); }
            }
        } else if (week == 4) {
            s.add([RUN, 180]); s.add([WALK, 90]);
            s.add([RUN, 300]); s.add([WALK, 150]);
            s.add([RUN, 180]); s.add([WALK, 90]);
            s.add([RUN, 300]);
        } else if (week == 5) {
            if (run == 1) {
                repeatPair(s, 300, 180, 2);
                s.add([RUN, 300]);
            } else if (run == 2) {
                s.add([RUN, 480]); s.add([WALK, 300]); s.add([RUN, 480]);
            } else {
                s.add([RUN, 1200]);
            }
        } else if (week == 6) {
            if (run == 1) {
                s.add([RUN, 300]); s.add([WALK, 180]);
                s.add([RUN, 480]); s.add([WALK, 180]);
                s.add([RUN, 300]);
            } else if (run == 2) {
                s.add([RUN, 600]); s.add([WALK, 180]); s.add([RUN, 600]);
            } else {
                s.add([RUN, 1500]);
            }
        } else if (week == 7) {
            s.add([RUN, 1500]);
        } else if (week == 8) {
            s.add([RUN, 1680]);
        } else {
            s.add([RUN, 1800]);
        }
        return s;
    }

    function repeatPair(s as Array<Array<Number> >, runSec as Number, walkSec as Number, times as Number) as Void {
        for (var i = 0; i < times; i++) {
            s.add([RUN, runSec]);
            s.add([WALK, walkSec]);
        }
    }

    function mainSeconds(week as Number, run as Number) as Number {
        var total = 0;
        var s = session(week, run);
        for (var i = 0; i < s.size(); i++) { total += s[i][1]; }
        return total;
    }

    function runSeconds(week as Number, run as Number) as Number {
        var total = 0;
        var s = session(week, run);
        for (var i = 0; i < s.size(); i++) {
            if (s[i][0] == RUN) { total += s[i][1]; }
        }
        return total;
    }

    function totalSeconds(week as Number, run as Number) as Number {
        return mainSeconds(week, run) + WARMUP_SEC + COOLDOWN_SEC;
    }
}
