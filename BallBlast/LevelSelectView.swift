import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var state: GameState
    let onPlay: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    /// Levels are endless: always show a few locked rows past the frontier.
    private var displayedCount: Int {
        max(60, state.highestUnlockedLevel + 12)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...displayedCount, id: \.self) { number in
                    cell(for: number)
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.14).ignoresSafeArea())
        .navigationTitle("Levels")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func cell(for number: Int) -> some View {
        let unlocked = number <= state.highestUnlockedLevel
        let completed = state.completedLevels.contains(number)
        let isBoss = number % 10 == 0
        let isCurrent = unlocked && !completed && number == state.highestUnlockedLevel

        Button {
            onPlay(number)
        } label: {
            VStack(spacing: 4) {
                if isBoss {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(unlocked ? .orange : .white.opacity(0.25))
                }
                if unlocked {
                    Text("\(number)")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(isCurrent ? .black : .white)
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(isCurrent ? .black.opacity(0.6) : .green)
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(cellBackground(unlocked: unlocked, isCurrent: isCurrent),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!unlocked)
    }

    private func cellBackground(unlocked: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return .yellow }
        if unlocked { return .white.opacity(0.12) }
        return .white.opacity(0.05)
    }
}
