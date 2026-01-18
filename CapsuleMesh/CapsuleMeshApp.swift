import SwiftUI

@main
struct CapsuleMeshApp: App {
    @StateObject private var viewModel = MeshViewModel()
    @State private var hasCompletedOnboarding = DeviceIdentity.shared.hasCompletedOnboarding

    init() {
        // Request location permission and start updates
        LocationService.shared.requestPermission()
    }

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
            .onAppear {
                // Start location updates after view appears
                LocationService.shared.startUpdating()
            }
        }
    }
}
