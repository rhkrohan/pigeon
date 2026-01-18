import Foundation
import CoreLocation
import Combine

// MARK: - Simulated Peer

struct SimulatedPeer: Identifiable, Equatable {
    let id: String
    var name: String
    var location: CLLocationCoordinate2D
    var batteryLevel: Int
    var isGateway: Bool
    var hops: Int
    var isMoving: Bool
    var movementSpeed: Double // meters per update
    var movementDirection: Double // radians

    static func == (lhs: SimulatedPeer, rhs: SimulatedPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Simulation Service

class SimulationService: ObservableObject {
    static let shared = SimulationService()

    @Published private(set) var isRunning = false
    @Published private(set) var simulatedPeers: [SimulatedPeer] = []
    @Published private(set) var simulatedMessages: [MeshMessage] = []

    private var updateTimer: Timer?
    private var messageTimer: Timer?
    private var baseLocation: CLLocationCoordinate2D?

    // Simulation settings
    var peerCount: Int = 8
    var spreadRadius: Double = 0.01 // ~1km in lat/lng
    var updateInterval: TimeInterval = 2.0
    var messageInterval: TimeInterval = 10.0

    // Names for simulated peers
    private let peerNames = [
        "Alex", "Jordan", "Sam", "Riley", "Casey",
        "Morgan", "Quinn", "Avery", "Blake", "Drew",
        "Ellis", "Finley", "Gray", "Harper", "Indigo",
        "Jules", "Kai", "Lane", "Marley", "Nico"
    ]

    // Locations around the world for variety
    private let scenarioLocations: [(name: String, coord: CLLocationCoordinate2D)] = [
        ("San Francisco", CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        ("New York", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
        ("Tokyo", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
        ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
        ("Dubai", CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)),
        ("Singapore", CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)),
        ("Los Angeles", CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437))
    ]

    private init() {}

    // MARK: - Public Methods

    func start(around location: CLLocationCoordinate2D? = nil, scenario: SimulationScenario = .normal) {
        guard !isRunning else { return }

        // Use provided location, current device location, or default to SF
        baseLocation = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        isRunning = true
        generatePeers(scenario: scenario)
        startUpdateTimer()
        startMessageTimer(scenario: scenario)

        print("📍 Simulation started with \(simulatedPeers.count) peers around \(baseLocation!)")
    }

    func stop() {
        isRunning = false
        updateTimer?.invalidate()
        updateTimer = nil
        messageTimer?.invalidate()
        messageTimer = nil
        simulatedPeers.removeAll()
        simulatedMessages.removeAll()

        print("📍 Simulation stopped")
    }

    func setScenario(_ scenario: SimulationScenario) {
        let wasRunning = isRunning
        let location = baseLocation

        if wasRunning {
            stop()
        }

        if wasRunning {
            start(around: location, scenario: scenario)
        }
    }

    // MARK: - Peer Generation

    private func generatePeers(scenario: SimulationScenario) {
        simulatedPeers.removeAll()

        guard let base = baseLocation else { return }

        let count: Int
        let gatewayCount: Int

        switch scenario {
        case .normal:
            count = 8
            gatewayCount = 2
        case .disaster:
            count = 15
            gatewayCount = 1
        case .dense:
            count = 25
            gatewayCount = 5
        case .sparse:
            count = 4
            gatewayCount = 1
        case .noInternet:
            count = 10
            gatewayCount = 0
        }

        for i in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0.001...spreadRadius)

            let lat = base.latitude + (distance * cos(angle))
            let lng = base.longitude + (distance * sin(angle))

            let peer = SimulatedPeer(
                id: "SIM-\(UUID().uuidString.prefix(8))",
                name: peerNames[i % peerNames.count],
                location: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                batteryLevel: Int.random(in: 5...100),
                isGateway: i < gatewayCount,
                hops: min(i / 3 + 1, 5),
                isMoving: Bool.random(),
                movementSpeed: Double.random(in: 0.0001...0.0005),
                movementDirection: Double.random(in: 0...(2 * .pi))
            )

            simulatedPeers.append(peer)
        }
    }

    // MARK: - Movement Updates

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updatePeerPositions()
        }
    }

    private func updatePeerPositions() {
        guard let base = baseLocation else { return }

        for i in 0..<simulatedPeers.count {
            guard simulatedPeers[i].isMoving else { continue }

            var peer = simulatedPeers[i]

            // Move in current direction
            let newLat = peer.location.latitude + (peer.movementSpeed * cos(peer.movementDirection))
            let newLng = peer.location.longitude + (peer.movementSpeed * sin(peer.movementDirection))

            // Check if too far from base, if so change direction back
            let distFromBase = sqrt(pow(newLat - base.latitude, 2) + pow(newLng - base.longitude, 2))
            if distFromBase > spreadRadius {
                peer.movementDirection = atan2(base.longitude - newLng, base.latitude - newLat)
            } else {
                // Random direction change occasionally
                if Double.random(in: 0...1) < 0.1 {
                    peer.movementDirection += Double.random(in: -0.5...0.5)
                }
            }

            peer.location = CLLocationCoordinate2D(latitude: newLat, longitude: newLng)

            // Occasionally change battery
            if Double.random(in: 0...1) < 0.05 && peer.batteryLevel > 1 {
                peer.batteryLevel -= 1
            }

            simulatedPeers[i] = peer
        }

        // Occasionally toggle movement
        if Double.random(in: 0...1) < 0.02 {
            let idx = Int.random(in: 0..<simulatedPeers.count)
            simulatedPeers[idx].isMoving.toggle()
        }
    }

    // MARK: - Message Generation

    private func startMessageTimer(scenario: SimulationScenario) {
        let interval: TimeInterval
        switch scenario {
        case .disaster:
            interval = 5.0
        case .dense:
            interval = 3.0
        default:
            interval = messageInterval
        }

        messageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.generateRandomMessage(scenario: scenario)
        }
    }

    private func generateRandomMessage(scenario: SimulationScenario) {
        guard !simulatedPeers.isEmpty else { return }

        let sender = simulatedPeers.randomElement()!
        let messageType: MessageType

        switch scenario {
        case .disaster:
            // More SOS and triage in disaster
            let roll = Double.random(in: 0...1)
            if roll < 0.3 {
                messageType = .sos
            } else if roll < 0.5 {
                messageType = .triage
            } else if roll < 0.7 {
                messageType = .missingPerson
            } else {
                messageType = .broadcast
            }
        case .noInternet:
            // More broadcasts seeking help
            messageType = Double.random(in: 0...1) < 0.4 ? .sos : .broadcast
        default:
            let types: [MessageType] = [.broadcast, .shelter, .triage, .missingPerson]
            messageType = types.randomElement()!
        }

        let message = createMessage(type: messageType, from: sender)
        simulatedMessages.insert(message, at: 0)

        // Keep only last 50 messages
        if simulatedMessages.count > 50 {
            simulatedMessages = Array(simulatedMessages.prefix(50))
        }
    }

    private func createMessage(type: MessageType, from sender: SimulatedPeer) -> MeshMessage {
        var data = MessageData()
        data.latitude = sender.location.latitude
        data.longitude = sender.location.longitude

        switch type {
        case .sos:
            let emergencies = ["Medical emergency - need assistance", "Trapped in building", "Injured, need evacuation", "Lost, need directions", "Vehicle accident"]
            data.description = emergencies.randomElement()!
            data.batteryLevel = sender.batteryLevel
        case .triage:
            let conditions = ["green", "yellow", "red", "black"]
            let injuryList = ["Minor cuts", "Broken arm", "Smoke inhalation", "Dehydration", "Head injury"]
            data.patientName = "Patient P-\(Int.random(in: 100...999))"
            data.condition = conditions.randomElement()!
            data.injuries = injuryList.randomElement()!
        case .shelter:
            let shelterNames = ["Community Center", "High School Gym", "Church Hall", "Fire Station", "Library"]
            data.shelterName = shelterNames.randomElement()!
            data.capacity = Int.random(in: 20...200)
            data.currentOccupancy = Int.random(in: 0...150)
        case .missingPerson:
            let names = ["John Doe", "Jane Smith", "Mike Johnson", "Sarah Williams", "Tom Brown"]
            let descriptions = ["Male, 30s, blue jacket", "Female, 20s, red hat", "Child, 10, green backpack", "Elderly man, gray hair", "Teen girl, blonde"]
            data.personName = names.randomElement()!
            data.lastSeenLocation = "Near \(["park", "school", "hospital", "mall", "station"].randomElement()!)"
            data.physicalDescription = descriptions.randomElement()!
        case .broadcast:
            let broadcasts = [
                "Water distribution at main square in 1 hour",
                "Road blocked on Main St, use alternate route",
                "Power restored in sector 5",
                "Medical team arriving at north entrance",
                "Evacuation bus departing in 30 minutes",
                "Cell towers back online in downtown area",
                "Food supplies available at community center"
            ]
            data.content = broadcasts.randomElement()!
        default:
            data.content = "Test message"
        }

        return MeshMessage(
            type: type,
            data: data,
            senderId: sender.id,
            senderName: sender.name
        )
    }
}

// MARK: - Simulation Scenarios

enum SimulationScenario: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case disaster = "Disaster Response"
    case dense = "Dense Urban"
    case sparse = "Rural/Sparse"
    case noInternet = "No Internet"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .normal:
            return "8 peers, 2 gateways, regular activity"
        case .disaster:
            return "15 peers, 1 gateway, high SOS/triage activity"
        case .dense:
            return "25 peers, 5 gateways, frequent messages"
        case .sparse:
            return "4 peers, 1 gateway, spread out"
        case .noInternet:
            return "10 peers, no gateways, seeking help"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "person.3"
        case .disaster: return "exclamationmark.triangle"
        case .dense: return "building.2"
        case .sparse: return "leaf"
        case .noInternet: return "wifi.slash"
        }
    }
}
