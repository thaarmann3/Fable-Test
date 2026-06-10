# Ball Blast

A fully offline, local Ball Blast clone for iPhone, built with SwiftUI + SpriteKit. No network access, no ads, no analytics — all progress is saved on-device.

## Gameplay

- Drag anywhere to move the cannon; it fires automatically.
- Balls bounce across the screen and **split in half** when destroyed, with the HP shown on each ball.
- If a ball touches your cannon, the run is over — but you keep every coin you collected.
- **Endless levels** with a rising difficulty curve — every level is procedurally tuned, and there is no cap. Every 10th level is a **boss level** (crown in the level grid) with huge multi-split balls. Clearing a level unlocks the next and pays a one-time reward (replays pay a smaller reward).

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
