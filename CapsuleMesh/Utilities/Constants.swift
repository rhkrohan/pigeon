import Foundation

enum MeshConstants {
    static let serviceType = "pigeon-mesh"  // Max 15 chars, lowercase + hyphens only
    static let maxHops = 10
    static let maxPeers = 8
    static let messageQueueSize = 500
    static let gatewayBroadcastInterval: TimeInterval = 30  // Broadcast gateway status every 30 seconds
}
