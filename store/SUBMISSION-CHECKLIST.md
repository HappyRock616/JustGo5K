# Just Go 5K — Submission checklist

## Files (all in this folder)
| File | Purpose |
|---|---|
| release/JustGo5K-1.0.0.iq | Public release package (111 watches) |
| LISTING.md | Name, description, what's new, keywords |
| PRIVACY.md | Privacy statement |
| hero-1440x720.png | Hero / featured image |
| store-icon-500.png | Store icon (solid background, as Garmin requires) |
| device-icon-128.png, device-icon-128-mip64.png | Optional on-device icons (full colour / 64-colour) |
| screenshots/*.png | 600×600 screenshots, recommended order in LISTING.md |

Rebuild packages after code changes:
`monkeyc -e -r -f monkey.jungle -o store/release/JustGo5K-1.0.0.iq -y <developer key>`

## Before uploading
- [ ] Real-watch test on the vívoactive 5: an outdoor run (GPS, heart rate, vibrations, pace map), an indoor run, pause, discard, redo
- [ ] Sync with Gadgetbridge and check the activity, laps and GPX export; also check Garmin Connect if available
- [ ] Try buttons-only use (Start, Back, Up/Down, the holds)
- [ ] Create a dedicated public support email (an alias or new mailbox)

## Stay anonymous on the store
- [ ] **Developer name:** HappyRock616. You'll be asked on your first upload; it can be changed later in Developer Dashboard → Settings.
- [ ] **Contact email:** use the dedicated support address, not your Garmin account email.
- [ ] **Skip "verified developer":** it shows your city, state and country.
- [ ] Reviews you write on the store show your Garmin Connect display name.

## Test on your watch first (no store needed)
1. Use `release/JustGo5K-vivoactive5.prg`: a clean release build with no demo data. Rebuild with `monkeyc -r -f monkey.jungle -d vivoactive5 -o store/release/JustGo5K-vivoactive5.prg -y <developer key>`. Don't use the `bin/` test builds on your watch: they add demo runs.
2. Connect the watch by USB and copy the .prg into **GARMIN/Apps** on the watch (Gadgetbridge can also install .prg files).
3. Run it, sync, check. Delete it from GARMIN/Apps before installing the store version, so you don't end up with two copies.

## Publish
1. Upload `release/JustGo5K-1.0.0.iq` (do **not** tick Beta App).
2. Paste the description, what's new and keywords from LISTING.md.
3. Add the screenshots, hero image and store icon. Price: free.
4. Support email: your dedicated address. Privacy: the PRIVACY.md text.
5. Submit for review. The app stays hidden until Garmin approves it, and you can preview and download it yourself in the meantime.

## Content rules followed
- No "Couch to 5K" or "C25K" (trademarks of Active Network and Zen Labs) in the name, description, keywords or images.
- No claims of being official or endorsed. The 9-week run/walk method itself is generic.
- A health disclaimer is included in the description.
- Garmin's app review guidelines: developer.garmin.com/connect-iq/app-review-guidelines/

## After release
- Watch for reviews, and for crash reports from users' watches (Garmin's ERA reports, viewable with the ERA viewer included in the SDK).
- To update: change the code, rebuild the .iq, then upload a new version from the app's page.
