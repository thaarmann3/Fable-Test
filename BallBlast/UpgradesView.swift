import SwiftUI

struct UpgradesView: View {
    @EnvironmentObject private var state: GameState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text(shortNumber(state.coins))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white.opacity(0.1), in: Capsule())
                .padding(.top, 8)

                ForEach(UpgradeType.allCases) { upgrade in
                    UpgradeCard(upgrade: upgrade)
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.14).ignoresSafeArea())
        .navigationTitle("Upgrades")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UpgradeCard: View {
    @EnvironmentObject private var state: GameState
    let upgrade: UpgradeType

    var body: some View {
        let level = state.level(of: upgrade)
        let cost = state.cost(of: upgrade)
        let affordable = state.canAfford(upgrade)

        HStack(spacing: 14) {
            Image(systemName: upgrade.symbolName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 52, height: 52)
                .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(upgrade.displayName)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Lv \(level)/\(upgrade.maxLevel)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text(upgrade.blurb)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 5) {
                    Text(upgrade.effectText(atLevel: level))
                        .foregroundStyle(.white.opacity(0.8))
                    if cost != nil {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text(upgrade.effectText(atLevel: level + 1))
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
            }

            Spacer(minLength: 8)

            Button {
                state.buy(upgrade)
            } label: {
                VStack(spacing: 1) {
                    if let cost {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                        Text(shortNumber(cost))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    } else {
                        Text("MAX")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(buttonForeground(cost: cost, affordable: affordable))
                .frame(width: 64, height: 46)
                .background(buttonBackground(cost: cost, affordable: affordable),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(cost == nil || !affordable)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func buttonForeground(cost: Int?, affordable: Bool) -> Color {
        guard cost != nil else { return .white.opacity(0.5) }
        return affordable ? .black : .white.opacity(0.4)
    }

    private func buttonBackground(cost: Int?, affordable: Bool) -> Color {
        guard cost != nil else { return .white.opacity(0.08) }
        return affordable ? .yellow : .white.opacity(0.08)
    }
}
