import Foundation
import UIKit

class DeviceIdentity {
    static let shared = DeviceIdentity()

    private let deviceIdKey = "CapsuleMesh.DeviceId"
    private let deviceNameKey = "CapsuleMesh.DeviceName"
    private let onboardingCompleteKey = "CapsuleMesh.OnboardingComplete"

    var deviceId: String {
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey) {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    var deviceName: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: deviceNameKey) {
                return stored
            }
            let suffix = String(deviceId.prefix(4))
            return "Pigeon-\(suffix)"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: deviceNameKey)
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: onboardingCompleteKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: onboardingCompleteKey)
        }
    }

    private init() {}
}
