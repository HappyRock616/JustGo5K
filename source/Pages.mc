import Toybox.Lang;
import Toybox.WatchUi;

// Vertical page loop: Home -> History -> Stats -> Settings -> Home.
module Pages {
    const HOME = 0;
    const HISTORY = 1;
    const STATS = 2;
    const SETTINGS = 3;
    const COUNT = 4;

    function show(page as Number, forward as Boolean) as Void {
        var p = (page + COUNT) % COUNT;
        var slide = forward ? WatchUi.SLIDE_UP : WatchUi.SLIDE_DOWN;
        if (p == HOME) {
            var v = new HomeView();
            WatchUi.switchToView(v, new HomeDelegate(v), slide);
        } else if (p == HISTORY) {
            var h = new HistoryView();
            WatchUi.switchToView(h, new HistoryDelegate(h), slide);
        } else if (p == STATS) {
            var s = new StatsView();
            WatchUi.switchToView(s, new StatsDelegate(s), slide);
        } else {
            var st = new SettingsView();
            WatchUi.switchToView(st, new SettingsDelegate(st), slide);
        }
    }
}
