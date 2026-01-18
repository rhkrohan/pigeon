import Foundation
import MultipeerConnectivity
import Combine
import os.log

class MeshNetworkService: NSObject, ObservableObject {
    static let shared = MeshNetworkService()

    // MARK: - Published Properties
    @Published private(set) var isAdvertising = false
    @Published private(set) var isBrowsing = false
    @Published private(set) var connectedPeers: [Peer] = []
    @Published private(set) var discoveredPeers: [Peer] = []
    @Published private(set) var knownDevices: [String: Int] = [:] // deviceId: hopDistance
    @Published private(set) var networkStatus: NetworkStatus = .offline

    enum NetworkStatus {
        case offline
        case connecting
        case online
    }

    // MARK: - Private Properties
    private let serviceType = MeshConstants.serviceType
    private let myPeerId: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private let logger = Logger(subsystem: "CapsuleMesh", category: "MeshNetwork")
    private var cancellables = Set<AnyCancellable>()

    private let messageStore = MessageStore.shared
    private let identity = DeviceIdentity.shared

    // Pending receipts
    private var pendingReceipts: [UUID: (targetId: String, timestamp: Date)] = [:]

    // MARK: - Initialization
    private override init() {
        self.myPeerId = MCPeerID(displayName: DeviceIdentity.shared.deviceName)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(
            peer: myPeerId,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self

        // Discovery info includes device ID for mesh routing
        let discoveryInfo = ["deviceId": identity.deviceId]

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        browser.delegate = self
    }

    // MARK: - Public Methods
    func start() {
        startAdvertising()
        startBrowsing()
        networkStatus = .connecting
        logger.info("Mesh network started")
    }

    func stop() {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        networkStatus = .offline
        logger.info("Mesh network stopped")
    }

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        logger.info("Started advertising")
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        logger.info("Stopped advertising")
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
        isBrowsing = true
        logger.info("Started browsing")
    }

    func stopBrowsing() {
        browser.stopBrowsingForPeers()
        isBrowsing = false
        logger.info("Stopped browsing")
    }

    // MARK: - Message Sending
    func sendMessage(_ message: MeshMessage) {
        guard !session.connectedPeers.isEmpty else {
            logger.warning("No connected peers to send message")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)

            // Store own message
            _ = messageStore.addMessage(message)

            // Track for delivery receipt if direct message
            if message.type == .direct, let targetId = message.targetDeviceId {
                pendingReceipts[message.id] = (targetId, Date())
            }

            logger.info("Sent message: \(message.type.rawValue)")
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
        }
    }

    func sendSOS(location: String, description: String, urgency: String = "high") {
        let data = MessageData(
            location: location,
            description: description,
            urgency: urgency
        )
        let message = MeshMessage(
            type: .sos,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func sendTriage(
        patientName: String,
        age: Int,
        condition: String,
        injuries: String,
        conscious: Bool,
        breathing: Bool
    ) {
        let data = MessageData(
            patientName: patientName,
            age: age,
            condition: condition,
            injuries: injuries,
            conscious: conscious,
            breathing: breathing
        )
        let message = MeshMessage(
            type: .triage,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func sendShelterStatus(
        name: String,
        capacity: Int,
        currentOccupancy: Int,
        supplies: [String],
        acceptingMore: Bool
    ) {
        let data = MessageData(
            shelterName: name,
            capacity: capacity,
            currentOccupancy: currentOccupancy,
            supplies: supplies,
            acceptingMore: acceptingMore
        )
        let message = MeshMessage(
            type: .shelter,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func sendMissingPerson(
        name: String,
        lastSeenLocation: String,
        lastSeenTime: String,
        description: String,
        contactInfo: String
    ) {
        let data = MessageData(
            personName: name,
            lastSeenLocation: lastSeenLocation,
            lastSeenTime: lastSeenTime,
            physicalDescription: description,
            contactInfo: contactInfo
        )
        let message = MeshMessage(
            type: .missingPerson,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func sendBroadcast(title: String, message: String, priority: String = "normal") {
        let data = MessageData(
            title: title,
            message: message,
            priority: priority
        )
        let msg = MeshMessage(
            type: .broadcast,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(msg)
    }

    func sendDirectMessage(to targetDeviceId: String, content: String) {
        let data = MessageData(content: content)
        let message = MeshMessage(
            type: .direct,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            targetDeviceId: targetDeviceId
        )
        sendMessage(message)
    }

    func sendPing() {
        let data = MessageData(
            originalSenderId: identity.deviceId,
            originalTimestamp: Date()
        )
        let message = MeshMessage(
            type: .ping,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    func discoverNetwork() {
        let data = MessageData(
            connectedPeers: session.connectedPeers.map { $0.displayName },
            requestId: UUID().uuidString
        )
        let message = MeshMessage(
            type: .discovery,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(message)
    }

    // MARK: - Message Handling
    private func handleReceivedMessage(_ message: MeshMessage, from peerID: MCPeerID) {
        // Deduplication
        guard !messageStore.hasSeenMessage(message.id) else {
            logger.debug("Ignoring duplicate message: \(message.id)")
            return
        }

        // TTL check
        guard message.hopCount < MeshConstants.maxHops else {
            logger.debug("Message exceeded max hops: \(message.id)")
            return
        }

        // Process message
        switch message.type {
        case .direct:
            handleDirectMessage(message)
        case .ping:
            handlePing(message)
        case .pong:
            handlePong(message)
        case .discovery:
            handleDiscovery(message)
        case .discoveryReply:
            handleDiscoveryReply(message)
        case .deliveryReceipt:
            handleDeliveryReceipt(message)
        default:
            // Store and forward all other types
            _ = messageStore.addMessage(message)
        }

        // Forward to other peers (mesh relay)
        forwardMessage(message, excludingPeer: peerID)
    }

    private func handleDirectMessage(_ message: MeshMessage) {
        if message.targetDeviceId == identity.deviceId {
            // Message is for us
            _ = messageStore.addMessage(message)
            sendDeliveryReceipt(for: message)
        }
        // Forward even if not for us (mesh relay)
    }

    private func handlePing(_ message: MeshMessage) {
        // Respond with pong
        let data = MessageData(
            originalSenderId: message.data.originalSenderId,
            originalTimestamp: message.data.originalTimestamp
        )
        let pong = MeshMessage(
            type: .pong,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(pong)
    }

    private func handlePong(_ message: MeshMessage) {
        _ = messageStore.addMessage(message)

        // Update known devices with hop distance
        if let originalSender = message.data.originalSenderId {
            knownDevices[originalSender] = message.hopCount
        }
    }

    private func handleDiscovery(_ message: MeshMessage) {
        // Reply with our connected peers
        let data = MessageData(
            connectedPeers: session.connectedPeers.map { $0.displayName },
            requestId: message.data.requestId
        )
        let reply = MeshMessage(
            type: .discoveryReply,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName
        )
        sendMessage(reply)
    }

    private func handleDiscoveryReply(_ message: MeshMessage) {
        // Update network topology
        knownDevices[message.senderId] = message.hopCount

        if let peers = message.data.connectedPeers {
            for peer in peers {
                if knownDevices[peer] == nil {
                    knownDevices[peer] = message.hopCount + 1
                }
            }
        }

        _ = messageStore.addMessage(message)
    }

    private func handleDeliveryReceipt(_ message: MeshMessage) {
        if let originalId = message.data.originalMessageId,
           let uuid = UUID(uuidString: originalId) {
            pendingReceipts.removeValue(forKey: uuid)
        }
        _ = messageStore.addMessage(message)
    }

    private func sendDeliveryReceipt(for originalMessage: MeshMessage) {
        let data = MessageData(
            originalMessageId: originalMessage.id.uuidString,
            deliveredAt: Date()
        )
        let receipt = MeshMessage(
            type: .deliveryReceipt,
            data: data,
            senderId: identity.deviceId,
            senderName: identity.deviceName,
            targetDeviceId: originalMessage.senderId
        )
        sendMessage(receipt)
    }

    private func forwardMessage(_ message: MeshMessage, excludingPeer: MCPeerID) {
        var forwardedMessage = message
        forwardedMessage.addHop(deviceId: identity.deviceId)

        let peersToForward = session.connectedPeers.filter { $0 != excludingPeer }

        guard !peersToForward.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(forwardedMessage)
            try session.send(data, toPeers: peersToForward, with: .reliable)
            logger.debug("Forwarded message to \(peersToForward.count) peers")
        } catch {
            logger.error("Failed to forward message: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate
extension MeshNetworkService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.logger.info("Peer connected: \(peerID.displayName)")
                let peer = Peer(peerID: peerID, isConnected: true)
                if !self.connectedPeers.contains(where: { $0.id == peerID }) {
                    self.connectedPeers.append(peer)
                }
                self.discoveredPeers.removeAll { $0.id == peerID }
                self.networkStatus = .online

            case .connecting:
                self.logger.info("Peer connecting: \(peerID.displayName)")

            case .notConnected:
                self.logger.info("Peer disconnected: \(peerID.displayName)")
                self.connectedPeers.removeAll { $0.id == peerID }
                if self.connectedPeers.isEmpty {
                    self.networkStatus = self.discoveredPeers.isEmpty ? .offline : .connecting
                }

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(MeshMessage.self, from: data)
            DispatchQueue.main.async {
                self.handleReceivedMessage(message, from: peerID)
            }
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MeshNetworkService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept all invitations for mesh
        logger.info("Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isAdvertising = false
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MeshNetworkService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.info("Found peer: \(peerID.displayName)")

        DispatchQueue.main.async {
            // Add to discovered if not already connected
            if !self.connectedPeers.contains(where: { $0.id == peerID }) &&
               !self.discoveredPeers.contains(where: { $0.id == peerID }) {
                let peer = Peer(peerID: peerID, isConnected: false)
                self.discoveredPeers.append(peer)
            }
        }

        // Auto-invite for mesh network
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.id == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isBrowsing = false
        }
    }
}
