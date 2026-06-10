import Foundation
import Combine

/// All gameplay/economy tuning knobs in one place.
enum Balance {
    static func bulletDamage(_ level: Int) -> Int { 1 + level }
    static func shotsPerSecond(_ level: Int) -> Double { 3.0 + 0.35 * Double(level) }
    static func bulletStreams(_ level: Int) -> Int { 1 + level }
    static func coinMultiplier(_ level: Int) -> Double { 1.0 + 0.12 * Double(level) }
    /// Coins dropped when a ball pops, before the coin multiplier.
    static let coinsPerHP: Double = 0.4
}

/// Stats the cannon carries into a level, derived from purchased upgrades.
struct PlayerLoadout {
    let bulletDamage: Int
    let shotsPerSecond: Double
    let bulletStreams: Int
    let coinMultiplier: Double
}

enum UpgradeType: String, CaseIterable, Identifiable {
    case firepower
    case fireRate
    case multiShot
    case coinBonus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firepower: return "Firepower"
        case .fireRate: return "Fire Rate"
        case .multiShot: return "Multi-Shot"
        case .coinBonus: return "Coin Bonus"
        }
    }

    var blurb: String {
        switch self {
        case .firepower: return "Each bullet deals more damage"
        case .fireRate: return "Shoot faster"
        case .multiShot: return "Fire extra bullet streams"
        case .coinBonus: return "Balls drop more coins"
        }
    }

    var symbolName: String {
        switch self {
        case .firepower: return "flame.fill"
        case .fireRate: return "bolt.fill"
        case .multiShot: return "arrow.triangle.branch"
        case .coinBonus: return "dollarsign.circle.fill"
        }
    }

    var maxLevel: Int {
        switch self {
        case .firepower: return 40
        case .fireRate: return 25
        case .multiShot: return 4
        case .coinBonus: return 20
        }
    }

    var baseCost: Int {
        switch self {
        case .firepower: return 30
        case .fireRate: return 25
        case .multiShot: return 400
        case .coinBonus: return 60
        }
    }

    var costGrowth: Double {
        switch self {
        case .firepower: return 1.42
        case .fireRate: return 1.45
        case .multiShot: return 5.0
        case .coinBonus: return 1.6
        }
    }

    func cost(atLevel level: Int) -> Int {
        max(baseCost, Int((Double(baseCost) * pow(costGrowth, Double(level))).rounded()))
    }

    func effectText(atLevel level: Int) -> String {
        switch self {
        case .firepower: return "\(Balance.bulletDamage(level)) dmg"
        case .fireRate: return String(format: "%.1f shots/s", Balance.shotsPerSecond(level))
        case .multiShot: return "\(Balance.bulletStreams(level)) streams"
        case .coinBonus: return "+\(Int((Balance.coinMultiplier(level) - 1.0) * 100))% coins"
        }
    }
}

/// Persistent progression: coins, unlocked levels and purchased upgrades.
/// Saved to UserDefaults — fully local and offline.
final class GameState: ObservableObject {
    @Published private(set) var coins: Int
    @Published private(set) var highestUnlockedLevel: Int
    @Published private(set) var completedLevels: Set<Int>
    @Published private(set) var upgradeLevels: [String: Int]

    private static let storageKey = "BallBlastSave.v1"

    private struct Snapshot: Codable {
        var coins: Int
        var highestUnlockedLevel: Int
        var completedLevels: Set<Int>
        var upgradeLevels: [String: Int]
    }

    init(coins: Int = 0,
         highestUnlockedLevel: Int = 1,
         completedLevels: Set<Int> = [],
         upgradeLevels: [String: Int] = [:]) {
        self.coins = coins
        self.highestUnlockedLevel = max(1, highestUnlockedLevel)
        self.completedLevels = completedLevels
        self.upgradeLevels = upgradeLevels
    }

    static func load() -> GameState {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return GameState()
        }
        return GameState(coins: snap.coins,
                         highestUnlockedLevel: snap.highestUnlockedLevel,
                         completedLevels: snap.completedLevels,
                         upgradeLevels: snap.upgradeLevels)
    }

    private func save() {
        let snap = Snapshot(coins: coins,
                            highestUnlockedLevel: highestUnlockedLevel,
                            completedLevels: completedLevels,
                            upgradeLevels: upgradeLevels)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Upgrades

    func level(of upgrade: UpgradeType) -> Int {
        upgradeLevels[upgrade.rawValue] ?? 0
    }

    /// Cost of the next level, or nil when maxed out.
    func cost(of upgrade: UpgradeType) -> Int? {
        let current = level(of: upgrade)
        guard current < upgrade.maxLevel else { return nil }
        return upgrade.cost(atLevel: current)
    }

    func canAfford(_ upgrade: UpgradeType) -> Bool {
        guard let cost = cost(of: upgrade) else { return false }
        return coins >= cost
    }

    @discardableResult
    func buy(_ upgrade: UpgradeType) -> Bool {
        guard let cost = cost(of: upgrade), coins >= cost else { return false }
        coins -= cost
        upgradeLevels[upgrade.rawValue] = level(of: upgrade) + 1
        save()
        return true
    }

    var loadout: PlayerLoadout {
        PlayerLoadout(bulletDamage: Balance.bulletDamage(level(of: .firepower)),
                      shotsPerSecond: Balance.shotsPerSecond(level(of: .fireRate)),
                      bulletStreams: Balance.bulletStreams(level(of: .multiShot)),
                      coinMultiplier: Balance.coinMultiplier(level(of: .coinBonus)))
    }

    // MARK: - Coins & level progression

    func addCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
        save()
    }

    /// Banks the coins collected in a run plus the completion reward.
    /// Returns the reward granted (0 on defeat).
    func finishLevel(_ number: Int, victory: Bool, runCoins: Int) -> Int {
        var reward = 0
        if victory {
            let config = LevelConfig.level(number)
            reward = completedLevels.contains(number) ? config.replayReward : config.firstClearReward
            completedLevels.insert(number)
            highestUnlockedLevel = max(highestUnlockedLevel, number + 1)
        }
        coins += max(0, runCoins) + reward
        save()
        return reward
    }

    func resetProgress() {
        coins = 0
        highestUnlockedLevel = 1
        completedLevels = []
        upgradeLevels = [:]
        save()
    }
}
