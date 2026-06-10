import SwiftUI
import SpriteKit

/// Hosts the SpriteKit scene and draws the HUD, pause menu and result overlays.
struct GameView: View {
    @EnvironmentObject private var state: GameState
    @Environment(\.scenePhase) private var scenePhase

    let onExit: () -> Void

    @State private var level: Int
    @State private var scene: GameScene?
    @State private var sceneID = UUID()
    @State private var started = false
    @State private var paused = false
    @State private var runCoins = 0
    @State private var progress = 0.0
    @State private var result: GameResult?
    @State private var showUpgrades = false

    struct GameResult {
        let victory: Bool
        let runCoins: Int
        let reward: Int
    }

    init(initialLevel: Int, onExit: @escaping () -> Void) {
        self.onExit = onExit
        _level = State(initialValue: initialLevel)
    }

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, isPaused: paused, preferredFramesPerSecond: 60)
                    .id(sceneID)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            hud

            if !started && result == nil {
                startHint
            }
            if paused {
                pauseMenu
            }
            if let result {
                resultOverlay(result)
            }
        }
        .statusBarHidden()
        .onAppear {
            if scene == nil { buildScene() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && started && result == nil {
                paused = true
            }
        }
        .sheet(isPresented: $showUpgrades) {
            NavigationStack {
                UpgradesView()
            }
            .environmentObject(state)
        }
    }

    // MARK: - Scene lifecycle

    private func buildScene() {
        let config = LevelConfig.level(level)
        let newScene = GameScene(size: UIScreen.main.bounds.size,
                                 config: config,
                                 loadout: state.loadout)
        newScene.onStarted = { started = true }
        newScene.onRunCoinsChanged = { runCoins = $0 }
        newScene.onProgressChanged = { progress = $0 }
        newScene.onGameEnded = { victory, coins in
            let reward = state.finishLevel(level, victory: victory, runCoins: coins)
            result = GameResult(victory: victory, runCoins: coins, reward: reward)
        }

        started = false
        paused = false
        runCoins = 0
        progress = 0
        result = nil
        scene = newScene
        sceneID = UUID()
    }

    /// Coins collected mid-run are kept even when bailing out early.
    private func quitToMenu() {
        if result == nil {
            state.addCoins(runCoins)
        }
        onExit()
    }

    private func restart() {
        if result == nil {
            state.addCoins(runCoins)
        }
        buildScene()
    }

    // MARK: - HUD

    private var hud: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    paused = true
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .opacity(started && result == nil && !paused ? 1 : 0)
                .disabled(!(started && result == nil && !paused))

                VStack(spacing: 5) {
                    Text(levelTitle)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(.yellow)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                }

                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text(shortNumber(displayedCoins))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private var levelTitle: String {
        LevelConfig.level(level).isBoss ? "BOSS \(level)" : "LEVEL \(level)"
    }

    private var displayedCoins: Int {
        result == nil ? state.coins + runCoins : state.coins
    }

    private var startHint: some View {
        VStack(spacing: 10) {
            Text("TAP TO START")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Drag anywhere to move the cannon")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Pause

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)
                BigButton(title: "Resume", color: .yellow) { paused = false }
                BigButton(title: "Restart Level", color: .white.opacity(0.2)) { restart() }
                BigButton(title: "Main Menu", color: .white.opacity(0.2)) { quitToMenu() }
            }
            .padding(32)
        }
    }

    // MARK: - Result

    private func resultOverlay(_ result: GameResult) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(result.victory ? "LEVEL \(level) CLEAR!" : "GAME OVER")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(result.victory ? .yellow : .red)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    resultRow("Coins collected", "+\(shortNumber(result.runCoins))")
                    if result.victory {
                        resultRow("Level reward", "+\(shortNumber(result.reward))")
                    }
                    Divider().overlay(.white.opacity(0.2))
                    resultRow("Total coins", shortNumber(state.coins))
                }
                .padding(18)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    if result.victory {
                        BigButton(title: "Next Level", color: .yellow) {
                            level += 1
                            buildScene()
                        }
                        BigButton(title: "Replay", color: .white.opacity(0.2)) { buildScene() }
                    } else {
                        BigButton(title: "Retry", color: .yellow) { buildScene() }
                    }
                    BigButton(title: "Upgrades", color: .white.opacity(0.2)) { showUpgrades = true }
                    BigButton(title: "Main Menu", color: .white.opacity(0.2)) { quitToMenu() }
                }
            }
            .padding(28)
        }
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
        }
    }
}

/// Shared chunky menu button.
struct BigButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color == .yellow ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
