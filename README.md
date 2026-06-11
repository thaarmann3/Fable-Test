# Ball Blast

A fully offline, local Ball Blast clone for iPhone, built with SwiftUI + SpriteKit. No network access, no ads, no analytics — all progress is saved on-device.

> **No Mac handy?** There is also a complete single-file web version at [`docs/index.html`](docs/index.html) — this is now the most feature-complete version (coin pickups, power-ups, win streaks, boss attacks, full customization). Host it anywhere (GitHub Pages works: Settings → Pages → deploy from branch → `/docs`), open it in Safari on your iPhone, and use **Share → Add to Home Screen** to install it like an app.

## Getting updates on your home-screen app (web version)

The web version has no service worker, so each launch loads the latest deployed page from the network:

- **Normal case:** after a new commit lands, GitHub Pages redeploys in about a minute. Force-quit the home-screen app (swipe it away in the app switcher) and reopen it to pick up the new version.
- **If it still looks stale:** open the same URL in Safari proper and pull down to refresh, then relaunch the home-screen app. As a last resort, remove the icon and re-add it via Share → Add to Home Screen.
- **App icon:** iOS captures the icon once, at Add-to-Home-Screen time. If the icon changes (or you added the app before `icon.png` existed), remove the icon and re-add it to pick up the new artwork — your save is untouched by this.
- **Your save is safe through all of this.** Progress lives in `localStorage`, keyed to the site's domain — updating the page, force-quitting, or re-adding the home screen icon does **not** touch it. New game versions migrate old saves automatically (e.g., retired upgrades convert to their modern equivalent). The only things that erase a save: the in-game *Reset Progress* button, clearing Safari website data for the domain, or hosting the game at a different URL (saves don't transfer between domains).

## Gameplay

- Drag anywhere to move the cannon; it fires automatically.
- Balls bounce across the screen and **split in half** when destroyed, with the HP shown on each ball.
- If a ball touches your cannon, the run is over — but you keep every coin you collected.
- **Endless levels** with a rising difficulty curve — every level is procedurally tuned, and there is no cap. Every 10th level is a **boss level** (crown in the level grid) with huge multi-split balls. Clearing a level unlocks the next and pays a one-time reward (replays pay a smaller reward).
- **Ball speed setting** on the main menu (Easy / Normal / Hard / Insane) scales how fast balls fall. Bounce heights stay the same — only gravity changes.

## Progression & upgrades

Coins drop from every ball you pop and from level rewards. Spend them in the **Upgrades** shop:

| Upgrade | Effect |
|---|---|
| Firepower | +1 damage per bullet per level |
| Fire Rate | Shoot faster |
| Multi-Shot | Extra parallel bullet streams (up to 5) |
| Coin Bonus | +12% coins per level |

Coins, upgrades, and unlocked levels persist between launches (stored in `UserDefaults`).

## Running it on your iPhone

Requirements: a Mac with **Xcode 16 or newer** (use the latest Xcode for an iPhone on iOS 26.x), a USB cable or same-network Wi-Fi, and a free Apple ID.

1. Open `BallBlast.xcodeproj` in Xcode.
2. Select the **BallBlast** target → **Signing & Capabilities** tab:
   - Check **Automatically manage signing**.
   - Pick your **Team** (add your Apple ID under Xcode → Settings → Accounts if needed — a free Personal Team works).
   - If Xcode complains about the bundle identifier, change `com.example.BallBlast` to something unique, e.g. `com.yourname.BallBlast`.
3. Plug in your iPhone and select it as the run destination (enable **Developer Mode** on the phone when prompted: Settings → Privacy & Security → Developer Mode).
4. Press **Run** (⌘R). On the first install, trust the developer certificate on the phone: Settings → General → VPN & Device Management.

> Note: apps signed with a free Personal Team expire after 7 days — just press Run again to reinstall. A paid Apple Developer account extends this to 1 year.

## Tuning

All balance knobs live in two places:

- `BallBlast/GameState.swift` — the `Balance` enum (damage/fire-rate/coin formulas) and `UpgradeType` (costs, max levels).
- `BallBlast/Levels.swift` — `LevelConfig.level(_:)` (ball HP, counts, tiers, spawn pacing, rewards).

Physics feel (gravity, bounce heights, ball sizes, bullet speed) is at the top of `BallBlast/GameScene.swift`.
