import SwiftUI

@main
struct BallBlastApp: App {
    @StateObject private var gameState = GameState.load()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameState)
                .preferredColorScheme(.dark)
        }
    }
}
