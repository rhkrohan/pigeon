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
    // GPS Coordinates
    var latitude: Double? = nil
    var longitude: Double? = nil

    // SOS
    var location: String? = nil
    var description: String? = nil
    var urgency: String? = nil
    var batteryLevel: Int? = nil  // Battery percentage (0-100)

    // Triage
    var patientName: String? = nil
    var age: Int? = nil
    var condition: String? = nil
    var injuries: String? = nil
    var conscious: Bool? = nil
    var breathing: Bool? = nil

    // Shelter
    var shelterName: String? = nil
    var capacity: Int? = nil
    var currentOccupancy: Int? = nil
    var supplies: [String]? = nil
    var acceptingMore: Bool? = nil

    // Missing Person
    var personName: String? = nil
    var lastSeenLocation: String? = nil
    var lastSeenTime: String? = nil
    var physicalDescription: String? = nil
    var contactInfo: String? = nil
    var photoBase64: String? = nil  // Base64 encoded photo

    // Broadcast
    var title: String? = nil
    var message: String? = nil
    var priority: String? = nil

    // Direct Message
    var content: String? = nil

    // Ping/Pong
    var originalSenderId: String? = nil
    var originalTimestamp: Date? = nil

    // Discovery
    var connectedPeers: [String]? = nil
    var requestId: String? = nil

    // Delivery Receipt
    var originalMessageId: String? = nil
    var deliveredAt: Date? = nil

    // Gateway Status
    var isGateway: Bool? = nil
    var gatewayDeviceId: String? = nil
    var gatewayDeviceName: String? = nil
    var syncedCount: Int? = nil
}
