import Foundation
import Network
import Combine

class GatewayService: ObservableObject {
    static let shared = GatewayService()

    // MARK: - Published Properties
    @Published var isOnline = false
    @Published var isGatewayActive = false
    @Published var syncedMessageCount = 0
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle

    // MARK: - Configuration
    // Vercel deployed Pigeon dashboard (use stable alias URL, not deployment-specific URL)
    var apiEndpoint = "https://pigeon-dashboard.vercel.app/api/messages"

    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var syncedMessageIds: Set<UUID> = []
    private let syncedIdsKey = "GatewayService.SyncedMessageIds"
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success(count: Int)
        case failed(error: String)
    }

    private init() {
        loadSyncedIds()
        startMonitoring()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied

                // Check if we just came online
                if self?.isOnline == true && !wasOnline {
                    self?.activateGateway()
                } else if self?.isOnline == false {
                    self?.deactivateGateway()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Gateway Activation

    private func activateGateway() {
        isGatewayActive = true
        print("📡 Gateway activated - device has internet access")

        // Start periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.syncMessages()
        }

        // Immediate sync
        syncMessages()
    }

    private func deactivateGateway() {
        isGatewayActive = false
        syncTimer?.invalidate()
        syncTimer = nil
        print("📡 Gateway deactivated - no internet access")
    }

    // MARK: - Message Syncing

    func syncMessages() {
        guard isOnline else {
            syncStatus = .failed(error: "No internet connection")
            return
        }

        let messageStore = MessageStore.shared
        let unsyncedMessages = messageStore.messages.filter { !syncedMessageIds.contains($0.id) }

        guard !unsyncedMessages.isEmpty else {
            print("📡 No new messages to sync")
            return
        }

        syncStatus = .syncing
        print("📡 Syncing \(unsyncedMessages.count) messages...")

        // Prepare payload
        let payload = GatewayPayload(
            deviceId: DeviceIdentity.shared.deviceId,
            deviceName: DeviceIdentity.shared.deviceName,
            timestamp: Date(),
            messages: unsyncedMessages.map { MessagePayload(message: $0) }
        )

        // Send to API
        sendToAPI(payload: payload) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Mark messages as synced
                    for message in unsyncedMessages {
                        self?.syncedMessageIds.insert(message.id)
                    }
                    self?.saveSyncedIds()
                    self?.syncedMessageCount = self?.syncedMessageIds.count ?? 0
                    self?.lastSyncTime = Date()
                    self?.syncStatus = .success(count: unsyncedMessages.count)
                    print("📡 Successfully synced \(unsyncedMessages.count) messages")
                } else {
                    self?.syncStatus = .failed(error: "API request failed")
                    print("📡 Failed to sync messages")
                }
            }
        }
    }

    // Force sync all messages (even previously synced)
    func forceSyncAll() {
        syncedMessageIds.removeAll()
        saveSyncedIds()
        syncMessages()
    }

    // MARK: - API Communication

    private func sendToAPI(payload: GatewayPayload, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: apiEndpoint) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceIdentity.shared.deviceId, forHTTPHeaderField: "X-Device-ID")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(payload)
        } catch {
            print("📡 Failed to encode payload: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("📡 API error: \(error.localizedDescription)")
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                if !success {
                    print("📡 API returned status: \(httpResponse.statusCode)")
                }
                completion(success)
            } else {
                completion(false)
            }
        }.resume()
    }

    // MARK: - Persistence

    private func loadSyncedIds() {
        if let data = UserDefaults.standard.data(forKey: syncedIdsKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            syncedMessageIds = ids
            syncedMessageCount = ids.count
        }
    }

    private func saveSyncedIds() {
        if let data = try? JSONEncoder().encode(syncedMessageIds) {
            UserDefaults.standard.set(data, forKey: syncedIdsKey)
        }
    }

    // MARK: - Configuration

    func setAPIEndpoint(_ endpoint: String) {
        apiEndpoint = endpoint
        UserDefaults.standard.set(endpoint, forKey: "GatewayService.APIEndpoint")
    }

    func loadSavedEndpoint() {
        if let saved = UserDefaults.standard.string(forKey: "GatewayService.APIEndpoint") {
            apiEndpoint = saved
        }
    }
}

// MARK: - Payload Models

struct GatewayPayload: Codable {
    let deviceId: String
    let deviceName: String
    let timestamp: Date
    let messages: [MessagePayload]
}

struct MessagePayload: Codable {
    let id: UUID
    let type: String
    let senderId: String
    let senderName: String
    let timestamp: Date
    let hopCount: Int
    let data: MessageDataPayload

    init(message: MeshMessage) {
        self.id = message.id
        self.type = message.type.rawValue
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.timestamp = message.timestamp
        self.hopCount = message.hopCount
        self.data = MessageDataPayload(data: message.data)
    }
}

struct MessageDataPayload: Codable {
    // GPS Coordinates
    let latitude: Double?
    let longitude: Double?

    // SOS
    let location: String?
    let description: String?
    let urgency: String?

    // Triage
    let patientName: String?
    let age: Int?
    let condition: String?
    let injuries: String?
    let conscious: Bool?
    let breathing: Bool?

    // Shelter
    let shelterName: String?
    let capacity: Int?
    let currentOccupancy: Int?
    let supplies: [String]?
    let acceptingMore: Bool?

    // Missing Person
    let personName: String?
    let lastSeenLocation: String?
    let lastSeenTime: String?
    let physicalDescription: String?
    let contactInfo: String?

    // Broadcast
    let title: String?
    let message: String?

    // Direct Message
    let recipientId: String?
    let content: String?

    init(data: MessageData) {
        self.latitude = data.latitude
        self.longitude = data.longitude
        self.location = data.location
        self.description = data.description
        self.urgency = data.urgency
        self.patientName = data.patientName
        self.age = data.age
        self.condition = data.condition
        self.injuries = data.injuries
        self.conscious = data.conscious
        self.breathing = data.breathing
        self.shelterName = data.shelterName
        self.capacity = data.capacity
        self.currentOccupancy = data.currentOccupancy
        self.supplies = data.supplies
        self.acceptingMore = data.acceptingMore
        self.personName = data.personName
        self.lastSeenLocation = data.lastSeenLocation
        self.lastSeenTime = data.lastSeenTime
        self.physicalDescription = data.physicalDescription
        self.contactInfo = data.contactInfo
        self.title = data.title
        self.message = data.message
        self.recipientId = nil
        self.content = data.content
    }
}
