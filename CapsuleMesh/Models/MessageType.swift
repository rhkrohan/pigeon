import Foundation

enum MessageType: String, Codable, CaseIterable {
    case sos = "sos"
    case triage = "triage"
    case shelter = "shelter"
    case missingPerson = "missing-person"
    case broadcast = "broadcast"
    case ping = "ping"
    case pong = "pong"
    case direct = "direct"
    case discovery = "discovery"
    case discoveryReply = "discovery-reply"
    case deliveryReceipt = "delivery-receipt"

    var displayName: String {
        switch self {
        case .sos: return "SOS Emergency"
        case .triage: return "Medical Triage"
        case .shelter: return "Shelter Status"
        case .missingPerson: return "Missing Person"
        case .broadcast: return "Broadcast"
        case .ping: return "Ping"
        case .pong: return "Pong"
        case .direct: return "Direct Message"
        case .discovery: return "Discovery"
        case .discoveryReply: return "Discovery Reply"
        case .deliveryReceipt: return "Delivery Receipt"
        }
    }

    var icon: String {
        switch self {
        case .sos: return "exclamationmark.triangle.fill"
        case .triage: return "cross.case.fill"
        case .shelter: return "house.fill"
        case .missingPerson: return "person.fill.questionmark"
        case .broadcast: return "megaphone.fill"
        case .ping, .pong: return "wave.3.right"
        case .direct: return "envelope.fill"
        case .discovery, .discoveryReply: return "network"
        case .deliveryReceipt: return "checkmark.circle.fill"
        }
    }
}
