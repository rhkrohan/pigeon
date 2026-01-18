import SwiftUI

@main
struct CapsuleMeshApp: App {
    @StateObject private var viewModel = MeshViewModel()
    @State private var hasCompletedOnboarding = DeviceIdentity.shared.hasCompletedOnboarding

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(viewModel)
                        .transition(.opacity)
                } else {
                    WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
