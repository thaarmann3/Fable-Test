import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: GameState
    @State private var activeGame: LevelSelection?
    @State private var showResetAlert = false

    struct LevelSelection: Identifiable {
        let id = UUID()
        let number: Int
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 16) {
                    Spacer()

                    VStack(spacing: 0) {
                        Text("BALL")
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text("BLAST")
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text(shortNumber(state.coins))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.1), in: Capsule())

                    Text(statsLine)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))

                    Spacer()

                    VStack(spacing: 14) {
                        Button {
                            activeGame = LevelSelection(number: nextLevel)
                        } label: {
                            VStack(spacing: 2) {
                                Text("PLAY")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                Text("Level \(nextLevel)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .opacity(0.7)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 16))
                        }

                        NavigationLink {
                            LevelSelectView { selected in
                                activeGame = LevelSelection(number: selected)
                            }
                        } label: {
                            menuRowLabel("square.grid.3x3.fill", "Levels")
                        }

                        NavigationLink {
                            UpgradesView()
                        } label: {
                            menuRowLabel("arrow.up.circle.fill", "Upgrades")
                        }

                        VStack(spacing: 7) {
                            Text("BALL SPEED")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                            Picker("Ball Speed", selection: difficultyBinding) {
                                ForEach(Difficulty.allCases) { difficulty in
                                    Text(difficulty.displayName).tag(difficulty)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 36)

                    Spacer()

                    Button("Reset Progress") {
                        showResetAlert = true
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 8)
                }
            }
        }
        .statusBarHidden()
        .fullScreenCover(item: $activeGame) { selection in
            GameView(initialLevel: selection.number) {
                activeGame = nil
            }
            .environmentObject(state)
        }
        .alert("Reset all progress?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) { state.resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Coins, upgrades and level progress will be erased.")
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.20),
                                Color(red: 0.05, green: 0.05, blue: 0.10)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var nextLevel: Int {
        state.highestUnlockedLevel
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding(get: { state.difficulty },
                set: { state.setDifficulty($0) })
    }

    private var statsLine: String {
        let loadout = state.loadout
        return "\(loadout.bulletDamage) dmg  •  "
            + String(format: "%.1f/s", loadout.shotsPerSecond)
            + "  •  \(loadout.bulletStreams) streams"
    }

    private func menuRowLabel(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
