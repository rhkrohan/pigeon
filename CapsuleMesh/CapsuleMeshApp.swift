import SwiftUI

@main
struct CapsuleMeshApp: App {
    @StateObject private var viewModel = MeshViewModel()
    @State private var hasCompletedOnboarding: Bool

    init() {
        // Clear data if build version changed (new build deployed)
        Self.clearDataIfNewBuild()

        // Initialize onboarding state after potential data clear
        _hasCompletedOnboarding = State(initialValue: DeviceIdentity.shared.hasCompletedOnboarding)

        // Request location permission and start updates
        LocationService.shared.requestPermission()
    }

    /// Clears all app data when a new build is detected
    private static func clearDataIfNewBuild() {
        let buildKey = "CapsuleMesh.LastBuildNumber"
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        let lastBuild = UserDefaults.standard.string(forKey: buildKey)

        if lastBuild != currentBuild {
            print("🧹 New build detected (\(lastBuild ?? "none") → \(currentBuild)). Clearing all data...")

            // Clear all UserDefaults for this app
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }

            // Store the new build number
            UserDefaults.standard.set(currentBuild, forKey: buildKey)

            print("🧹 Data cleared. Fresh start for build \(currentBuild)")
        }
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
