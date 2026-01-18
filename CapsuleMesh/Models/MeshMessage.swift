import Foundation

struct MeshMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let type: MessageType
    let data: MessageData
    let senderId: String
    let senderName: String
    let timestamp: Date
    var hops: [String]
    var hopCount: Int
    var targetDeviceId: String?  // For direct messages

    init(
        type: MessageType,
        data: MessageData,
        senderId: String,
        senderName: String,
        targetDeviceId: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.senderId = senderId
        self.senderName = senderName
        self.timestamp = Date()
        self.hops = [senderId]
        self.hopCount = 0
        self.targetDeviceId = targetDeviceId
    }

    mutating func addHop(deviceId: String) {
        hops.append(deviceId)
        hopCount += 1
    }

    static func == (lhs: MeshMessage, rhs: MeshMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessageData: Codable {
    // SOS
    var location: String?
    var description: String?
    var urgency: String?

    // Triage
    var patientName: String?
    var age: Int?
    var condition: String?
    var injuries: String?
    var conscious: Bool?
    var breathing: Bool?

    // Shelter
    var shelterName: String?
    var capacity: Int?
    var currentOccupancy: Int?
    var supplies: [String]?
    var acceptingMore: Bool?

    // Missing Person
    var personName: String?
    var lastSeenLocation: String?
    var lastSeenTime: String?
    var physicalDescription: String?
    var contactInfo: String?

    // Broadcast
    var title: String?
    var message: String?
    var priority: String?

    // Direct Message
    var content: String?

    // Ping/Pong
    var originalSenderId: String?
    var originalTimestamp: Date?

    // Discovery
    var connectedPeers: [String]?
    var requestId: String?

    // Delivery Receipt
    var originalMessageId: String?
    var deliveredAt: Date?
}
