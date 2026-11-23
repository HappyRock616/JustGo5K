# Just Go 5K — Design Spec

Status (2026-11-21): all screens implemented and checked in the simulator —
home, history, stats, settings, preview, run screens, pause, summary, pace map,
graduation, glance. Not yet tested on a real watch (sensors, GPS, buttons-only
use, Gadgetbridge sync).

Builds: `monkey.jungle` (normal/release), `test.jungle` (starts a run at 20x speed), `tour.jungle` (shows every
screen in turn). Unit tests (13, all passing): `monkeyc -t -f monkey.jungle ...`
then `monkeydo <prg> vivoactive5 /t`. Store package: `store/`. Debug builds seed demo data
into an empty program; release builds never do.

## 1. Product

A Garmin Connect IQ **device app** that coaches a complete beginner from walking to
running 30 minutes non-stop over a 9-week run/walk plan, entirely from the watch.

- Primary device: vívoactive 5 (round 390×390 AMOLED, touch + 2 buttons).
- Must support a broad range of watches: round and rectangular, AMOLED and
  memory-in-pixel (MIP), touch and buttons-only.
- Design style: clean, minimalist, strong visual cues, concise words or symbols.
- Tone: positive, motivating, no excuses.

### Naming and legal
- Name: **Just Go 5K**. Never use "Couch to 5K" or "C25K" (registered trademarks of
  Active Network and Zen Labs) in the name, store copy, keywords or artwork.
- The run/walk schedule is a method and free to use; all text, visuals and sounds
  are our own. No claims of being "official" or endorsed by anyone.

## 2. Training plan

3 runs per week, 9 weeks. Every run = 5:00 warm-up walk + main set + 5:00 cool-down walk.

| Week | Run | Main set |
|---|---|---|
| 1 | all | Run 1:00 / walk 1:30 × 7, then run 1:00 |
| 2 | all | Run 1:30 / walk 2:00 × 5, then run 1:30 |
| 3 | all | (Run 1:30, walk 1:30, run 3:00, walk 3:00) × 2 |
| 4 | all | Run 3:00, walk 1:30, run 5:00, walk 2:30, run 3:00, walk 1:30, run 5:00 |
| 5 | 1 | Run 5:00 / walk 3:00 × 2, then run 5:00 |
| 5 | 2 | Run 8:00, walk 5:00, run 8:00 |
| 5 | 3 | Run 20:00 |
| 6 | 1 | Run 5:00, walk 3:00, run 8:00, walk 3:00, run 5:00 |
| 6 | 2 | Run 10:00, walk 3:00, run 10:00 |
| 6 | 3 | Run 25:00 |
| 7 | all | Run 25:00 |
| 8 | all | Run 28:00 |
| 9 | all | Run 30:00 |

## 3. Weekly rules

- **Weeks are calendar weeks, Sunday–Saturday.** No fixed run days. A week
  starts at local midnight on Sunday, including the weeks the clocks change
  (23- and 25-hour days, and Cuba's repeated midnight). Checked against real
  time-zone rules in 11 zones, because the simulator ignores daylight saving.
- Each week has **3 run slots**.
- **Program start:** week 1 begins on the Sunday after the user starts, or
  that same day if they start on a Sunday. Runs before week 1 are **warm-up
  runs** (week 1 session), recorded in history but not counted toward the plan.
- **Missed runs:** at the end of Saturday, any empty slots are marked **missed**
  (red in history). The plan **always moves on** to the next week on Sunday.
- **Week complete:** once all 3 runs are done, Start is **locked until Sunday**
  with the message "Week complete · Next run unlocks Sunday".
- **Rest days:** at least one rest day between runs is recommended. Back-to-back
  days are allowed with a gentle "rest recommended" note. A second run on the same
  day does not count as a plan run.
- **Redo:** only the **most recent** run can be redone, once. Starting the next
  run locks the previous one in. Settings › Redo last run only removes a run
  from the current week ("No run this week" otherwise). A redo replaces that run in app history (the
  original Garmin Connect activity remains).
- **Restart program:** in Settings, with a confirmation step. Wipes progress.
- Completing week 9 = graduation (graduation screen and follow-on options TBD).

## 4. Screens (vertical page loop)

Swipe up/down (touch) or Up/Down buttons move between pages. Holding Menu/Up opens
Settings directly (standard Garmin convention).

### 4.1 Home
- Outer ring: 9 segments = 9 weeks (done = solid run colour, current = highlighted).
- "WEEK n" + which run is next.
- **7 day dots, Su M T W Th F Sa:**
  - run day = filled run-colour circle with tick
  - past rest day = sofa icon (cartoon person sleeping on a sofa)
  - today = outlined ring
  - future days = small dim dots
- Status line, concise: e.g. "1 run · 3 days left", "Rest today",
  "Week complete", "Go today to stay on track".
- Start button showing next session length, e.g. "Start · 22 min"; shows a
  locked state when the week is complete.

### 4.2 Run history (bar chart)
- One bar per run, oldest left, newest right; side-scroll left for history.
- Bar height = main-set duration plus paused time (warm-up and cool-down
  excluded); stacked segments: run (primary), walk (secondary), paused (grey).
- Calories (from the watch's activity estimate) printed above each bar.
- X axis: day-of-week label (Su M T W Th F Sa); rest days omitted.
- Minor ticks/dividers between weeks with "W1, W2…" labels.
- Every week shows 3 slots; missed runs = red outlined slot with ×, no day label.

### 4.3 Run stats (table)
- One column per run, newest right, side-scroll left for older runs.
- Rows: week + day, distance, pace (per mile or km), HR average, HR max,
  calories, SpO2 (latest background reading where the device supports it,
  otherwise "--").

### 4.4 Settings
- Theme (shows run + walk colour swatches)
- Units: Auto (follows watch) / Imperial / Metric. Default Auto.
- Dim during runs: off by default.
- Alerts: vibration only / vibration + tone
- Redo last run
- Restart program (shown in red, confirmation required)
- Theme, units and alerts also editable from the Garmin Connect phone app.

### Buttons-only devices
Up/Down switch pages. On the history and stats pages, Start toggles a
"scroll history" mode where Up/Down scroll sideways; Back exits it.

## 5. Visual style

Black background. Each theme = primary colour + complementary secondary colour.
Red is reserved for missed runs in every theme.

- **Primary**: week ring (completed weeks), run-day ticks, Start button, run
  segment of history bars.
- **Secondary**: current week segment, today marker, status text, walk segment
  of history bars.

| Theme | Primary (run) | Secondary (walk) |
|---|---|---|
| Turquoise | `#19D3C5` | `#FFD84D` |
| Purple | `#BD93F9` | `#7CC8FF` |
| Orange (default candidate) | `#FF8A1F` | `#4DABF7` |
| Yellow | `#F5B841` | `#2E9E5B` |
| Forest | `#2E9E5B` | `#F5B841` |
| Missed (all themes) | `#FF453A` | |

Text on primary-coloured buttons uses a dark shade of the same hue, except
Forest, which uses light text (`#E8F5EC`) because its primary green is darker.

MIP (64-colour) screens use the nearest strong palette colour for each theme.
Text: `#F1EFE8` primary, `#888780` secondary. Icons (sofa, tick) drawn in code
so they scale to every screen size.

## 6. Run screen flow

Draft v2 (2026-11-21).

All screens advance **automatically** with the session timer; the user never
needs to swipe or press anything at a transition.

### 6.1 Session ring (identical on every run screen)
- Covers the **main set only** (run and walk segments). Warm-up and cool-down
  are not in the ring. The **first run segment always starts at 12 o'clock**,
  segments run clockwise, length proportional to duration.
- Colours: run = primary, walk = secondary.
- Behaviour: finished segments = dark grey `#3A3A38`; the **current segment
  drains** from full colour to dark grey as time passes; future segments are
  dimmed (~45%). During warm-up all segments are dimmed; during cool-down all
  are grey.
- **One thickness everywhere** (session preview thickness), including the
  home-screen week ring. The 3-2-1 transition blinks the same ring.

### 6.1b Side panels (screens 2–7)
- Left panel: heart rate (♥, bpm). Right panel: pace (per mile or km).
- Black rounded panels inside the ring, either side of the central timer, so
  they stay readable on the coloured run/walk backgrounds. Panels widen to fit
  their labels where the watch's smallest font is large for its screen (Venu Sq).
- Pace shows "--" when there has been no usable GPS fix for 10 s (indoors:
  no speed estimate for 10 s), instead of freezing on the last value.

### 6.2 Screens
1. **Session preview** (after Start): ring at full colour, week/run label,
   main-set time, minutes of running. Two side panels (same inset rounded
   shape as the HR/pace panels) start the run: **left = "START Outdoor"**
   (sun icon, GPS on), **right = "START Indoor"** (house icon, GPS off,
   pace/distance from wrist motion, recorded as a treadmill run). The last
   choice is remembered and filled in the primary colour. Back cancels.
2. **Warm-up walk**: black background. Segment countdown is the largest
   element; heart rate + pace as a secondary row; large "Run 1:00 next".
3. **Run interval**: whole screen in primary colour. "RUN", segment countdown
   (largest), HR + pace secondary row, "Walk 2:30 next". No interval number.
4. **3-2-1 transition**: last 3 s of each segment. Thick ring blinks in sync
   with each warning buzz; big 3/2/1; heart rate at top; large "Walk next" /
   "Run next". Distinct vibration patterns for run vs walk.
5. **Walk interval**: same as run, in secondary colour.
6. **Paused**: large "PAUSED", pause counter counting up, total time.
   Buttons: Resume, End and save, **Hold to discard** (3 s hold, fill
   progresses across the button, resets if released early).
   After **30 minutes paused** the run ends by itself and the summary saves
   it, so a forgotten watch doesn't keep GPS and the screen running.
   On Venu Sq the HR/pace panels move outward so they never touch the
   buttons, and "Hold discard" widens to fit its label.
7. **Cool-down walk**: like warm-up, with an encouraging message.
8. **Summary**: no ring; maximum text size. Run label + week status, then
   time, distance, pace, average HR, calories.
   - **Right edge semicircle: Save** — default; auto-saves after a countdown
     (~10 s), shown as a fill progressing top to bottom while "AUTO SAVE"
     scrolls.
   - **Left edge semicircle: Redo** — 3 s hold, fill progresses top to bottom.
9. **Pace map** (after summary, same Redo/Save edge buttons):
   - Outdoor: the run's GPS route drawn on black, each part coloured by pace
     on a **fixed scale** (never rescaled per run), start marked with a dot,
     distance and average pace below.
   - Indoor: no route; pace over time drawn as a ring starting at 12 o'clock
     using the same fixed scale.
   - Fixed scale (per mile; metric uses the converted cut-offs):
     sprint < 8:00 red `#E24B4A` · fast 8–10 orange `#F0802A` ·
     steady 10–12 yellow `#F5C542` · jog 12–14 green `#7ED957` ·
     brisk walk 14–17 teal `#2DB3C9` · easy walk > 17 blue `#3C6FD8`.
   - A simplified route (~150–200 points) and pace samples are stored for
     **this week's runs only**; they can be opened from the stats table.
     Older runs show "Map not kept · Full route is in the Garmin activity".
     Saving a run deletes routes from earlier weeks, and a full object store
     never crashes the app (all routes are dropped and the save retried).
10. **Graduation** (once, after the final run of week 9): congratulations,
    week 1 run 1 vs final run (running minutes, distance, pace), and plan
    totals (runs, distance, time). The plan is **never reset automatically**;
    a "Hold to start over" bar (3 s hold) restarts the program. The same
    restart is also in Settings. Until then, home shows the graduated state
    and opens this screen.

### 6.2b During a run
- Back opens the pause screen; it never exits the run.
- Screens stay bright by default. Settings has a "Dim during runs" toggle
  (default off) that switches to a dark style with only the colour ring.

### 6.3 Data rules
- **Paused time** is recorded and shown as its own segment on that day's bar
  in the history chart. Time and pace use **moving time** (pauses excluded),
  matching the activity's timer time in Garmin Connect.
- **Warm-up and cool-down** show live HR and pace, but are excluded from the
  activity's stats entirely: history chart, distance, time, pace, HR averages
  and calories. Activity **recording starts at the first run segment and stops
  at the end of the last segment**, so Garmin Connect totals match the app.
  During warm-up/cool-down, HR and pace come from live sensors without being
  recorded. (The watch's all-day steps and calories still count that walking.)
- History bars therefore stack: run (primary), walk (secondary), paused (grey).

## 7. Device support (checked 2026-11-21, SDK 9.3.0)

Target: 111 colour watches, API 3.2+ (manifest generated from installed device
data). All build without errors (`bin/JustGo5K.iq`, 184 hardware variants).
Primary test device: vívoactive 5.

| Screen | Display | Count | Status |
|---|---|---|---|
| Round 360–466 px | AMOLED, touch | 55 | Verified in simulator (Venu 2S, vívoactive 5, FR 265/965, fēnix 9 Pro 51) |
| Round 260/280 px | MIP 64-colour | 23 | Verified (fēnix 7, 7X); MIP palette handling |
| Round 218/240 px | MIP 64-colour | 28 | Verified (FR 255s, FR 245) |
| Round 208 px | MIP 16-colour | 1 | Works (FR 55); limited colours, 128 KB |
| Rectangular | LCD/AMOLED | 5 | Works (Venu Sq, Sq 2, X1); round ring inside square screen |
| Instinct / Descent G1 | Monochrome | — | Excluded (design depends on colour) |
| Older watches | API < 3.2 | ~30 | Excluded (vívoactive 3/HR, FR 235/645/935, fēnix 5/5S/5X, Descent Mk1, older D2/Approach) |

- Memory: ~43 KB used of 124 KB on 128 KB watches at end of run; ~34 KB on
  larger watches. GPS track thinned in memory past 400 points; the sampling
  interval doubles at the same time, so points stay evenly spaced over the
  whole run. The saved route always includes the finish point.
- MIP screens: dimmed colours step down one palette level; neutral greys use
  exact palette greys (`Draw.isMip()` = no burn-in protection flag).
- Small screens: day labels fall back to single letters when two letters crowd.
- **Text never overlaps on any screen size.** Layouts are measured with
  `getTextWidthInPixels`, so watches whose smallest font is large for their
  screen (Venu Sq, Sq 2, Forerunner 55) get shorter wordings, smaller label
  fonts and wider columns instead of overlapping text:
  - home button: "Start · 32 min" → "Start", "Locked · 3 days" → "Locked"
  - history: wider bar spacing, fewer bars per screen (scroll for more)
  - stats: wider columns, 2 runs per screen instead of 3 where needed
  - settings: smaller label font; "Vibe + tone" → "Tone on" if still tight
  - graduation: wider columns; totals and "Hold to start over" shorten
  - start screen: "START" → "GO" in the panels
  Round watches with room keep the design layout unchanged.
- Rectangular screens are detected from the screen shape (Venu Sq is
  240×240, so width = height proves nothing): run/walk colour fills the whole
  screen and the summary edge buttons are plain rectangles.

## 8. Technical notes

- Records a real activity (FIT) via `ActivityRecording` with **one lap per
  interval**: sport running; sub-sport treadmill for indoor runs.
- Sync: the FIT activity is synced like any watch activity — automatically by
  **Garmin Connect** (map, laps, GPX export there) and by **Gadgetbridge**
  (activity sync; can auto-export GPX/FIT after each workout; laps become GPX
  track segments). Test a real Gadgetbridge sync once recording works.
- Connect IQ apps cannot write user-accessible files, so the GPX comes from
  the phone app, not the watch.
- Glance (widget-loop summary): e.g. "Wk 4 · 2 runs · 5d left", shortened to
  fit the glance width.
- Store listing (icon, screenshots, copy) after features are built and tested.
- Units from `System.getDeviceSettings()` (distance/pace units) unless overridden.
- Run history stored in `Application.Storage` (small: ~30–60 runs, ~14 KB).
  Routes for the current week only (~3 KB each); the object store limit
  varies by watch, and a full plan of routes would not fit on all of them.
- SpO2 via `SensorHistory` where available; never block on it.
- Works fully without the phone.
