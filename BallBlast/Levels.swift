import Foundation

/// Procedurally generated difficulty curve for each level.
/// Every level spawns `ballCount` big balls of `ballTier`; balls split in half
/// (with half the HP) when destroyed until they reach tier 0 and pop.
/// Levels are endless — the formulas below scale for any level number.
struct LevelConfig {
    let number: Int
    let ballCount: Int
    let ballTier: Int
    let ballHP: Int
    let spawnInterval: Double
    let isBoss: Bool
    let firstClearReward: Int
    let replayReward: Int

    /// Sum of HP across every ball and all of its split children,
    /// used for the level progress bar.
    var totalHPPool: Int {
        var perBall = 0
        var hp = ballHP
        var count = 1
        for _ in 0...ballTier {
            perBall += hp * count
            hp = max(1, hp / 2)
            count *= 2
        }
        return max(1, perBall * ballCount)
    }

    static func level(_ n: Int) -> LevelConfig {
        let n = max(1, n)
        let isBoss = n % 10 == 0
        let baseHP = max(5, Int(5.5 * pow(Double(n), 1.3)))

        if isBoss {
            // A few enormous balls that split three times.
            return LevelConfig(number: n,
                               ballCount: min(1 + n / 15, 6),
                               ballTier: 3,
                               ballHP: baseHP * 4,
                               spawnInterval: 7.0,
                               isBoss: true,
                               firstClearReward: 80 + 45 * n,
                               replayReward: 12 + 5 * n)
        }

        let tier: Int
        if n < 4 {
            tier = 1
        } else if n % 7 == 0, n >= 8 {
            tier = 3
        } else {
            tier = 2
        }

        return LevelConfig(number: n,
                           ballCount: min(3 + (n - 1) / 2, 12),
                           ballTier: tier,
                           ballHP: baseHP,
                           spawnInterval: max(2.0, 4.6 - 0.07 * Double(n)),
                           isBoss: false,
                           firstClearReward: 50 + 28 * n,
                           replayReward: 8 + 4 * n)
    }
}

/// Compact display for big numbers ("12.4K").
func shortNumber(_ value: Int) -> String {
    switch value {
    case ..<1000:
        return "\(value)"
    case ..<1_000_000:
        let k = Double(value) / 1000.0
        return k < 10 ? String(format: "%.1fK", k) : "\(Int(k.rounded()))K"
    default:
        let m = Double(value) / 1_000_000.0
        return m < 10 ? String(format: "%.1fM", m) : "\(Int(m.rounded()))M"
    }
}
