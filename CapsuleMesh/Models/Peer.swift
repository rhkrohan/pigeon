import Foundation
import MultipeerConnectivity

struct Peer: Identifiable, Hashable {
    let id: MCPeerID
    var displayName: String { id.displayName }
    var isConnected: Bool
    var lastSeen: Date
    var hopDistance: Int

    init(peerID: MCPeerID, isConnected: Bool = false, hopDistance: Int = 1) {
        self.id = peerID
        self.isConnected = isConnected
        self.lastSeen = Date()
        self.hopDistance = hopDistance
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id
    }
}
