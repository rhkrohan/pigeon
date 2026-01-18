import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @State private var selectedFilter: MessageType?
    @State private var selectedMessage: MeshMessage?
    @State private var selectedQuickAction: QuickActionType?

    var filteredMessages: [MeshMessage] {
        let messages = viewModel.messageStore.messages.sorted { $0.timestamp > $1.timestamp }
        guard let filter = selectedFilter else {
            return messages
        }
        return messages.filter { $0.type == filter }
    }

    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                header
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Quick actions
                quickActionsRow
                    .padding(.bottom, 16)

                // Content
                if viewModel.messageStore.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailSheet(message: message)
        }
        .sheet(item: $selectedQuickAction) { action in
            quickActionSheet(for: action)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            // Top bar with logo
            HStack {
                // Filter button
                Menu {
                    Button {
                        selectedFilter = nil
                    } label: {
                        Label("All messages", systemImage: selectedFilter == nil ? "checkmark" : "")
                    }

                    Divider()

                    ForEach([MessageType.sos, .triage, .shelter, .missingPerson, .broadcast, .direct], id: \.self) { type in
                        Button {
                            selectedFilter = type
                        } label: {
                            Label(type.displayName, systemImage: selectedFilter == type ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: selectedFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }

                Spacer()

                // Pigeon logo
                HStack(spacing: 8) {
                    PigeonLogoCompact(size: 22)
                    Text("Messages")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }

            // Filter chip if active
            if let filter = selectedFilter {
                HStack {
                    Text("Showing: \(filter.displayName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)

                    Spacer()

                    Button {
                        withAnimation { selectedFilter = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                icon: "megaphone.fill",
                title: "Broadcast",
                color: 0.7
            ) {
                selectedQuickAction = .broadcast
            }

            QuickActionCard(
                icon: "person.fill.questionmark",
                title: "Missing",
                color: 0.8
            ) {
                selectedQuickAction = .missingPerson
            }

            QuickActionCard(
                icon: "cross.case.fill",
                title: "Triage",
                color: 0.9
            ) {
                selectedQuickAction = .triage
            }

            QuickActionCard(
                icon: "house.fill",
                title: "Shelter",
                color: 0.75
            ) {
                selectedQuickAction = .shelter
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func quickActionSheet(for action: QuickActionType) -> some View {
        switch action {
        case .broadcast:
            BroadcastSheet()
        case .missingPerson:
            MissingPersonSheet()
        case .triage:
            TriageSheet()
        case .shelter:
            ShelterSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated pigeon
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.03))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 100, height: 100)

                    Image(systemName: "bird.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.black)
                }

                VStack(spacing: 8) {
                    Text("No messages yet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)

                    Text("Messages from the Pigeon mesh\nnetwork will appear here")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Action button
            Button {
                viewModel.meshService.sendPing()
            } label: {
                Text("Send ping")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    MessageCard(message: message)
                        .onTapGesture {
                            selectedMessage = message
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private var statusColor: Color {
        switch viewModel.meshService.networkStatus {
        case .offline: return .black.opacity(0.3)
        case .connecting: return .black.opacity(0.5)
        case .online: return .black
        }
    }

    private var statusText: String {
        switch viewModel.meshService.networkStatus {
        case .offline: return "Offline"
        case .connecting: return "Connecting"
        case .online: return "\(viewModel.meshService.connectedPeers.count) peers"
        }
    }
}

// MARK: - Message Card

struct MessageCard: View {
    let message: MeshMessage

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Type icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(iconOpacity))
                    .frame(width: 44, height: 44)

                Image(systemName: message.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text(message.type.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    Text(message.timestamp, style: .relative)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Sender
                Text(message.senderName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Preview
                messagePreview
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var iconOpacity: Double {
        switch message.type {
        case .sos: return 1.0
        case .triage: return 0.85
        case .shelter: return 0.7
        case .missingPerson: return 0.75
        case .broadcast: return 0.6
        case .direct: return 0.5
        default: return 0.5
        }
    }

    @ViewBuilder
    private var messagePreview: some View {
        switch message.type {
        case .sos:
            if let location = message.data.location {
                Text(location)
            }
        case .triage:
            if let name = message.data.patientName, let condition = message.data.condition {
                Text("\(name) — \(condition.capitalized)")
            }
        case .shelter:
            if let name = message.data.shelterName {
                Text(name)
            }
        case .missingPerson:
            if let name = message.data.personName {
                Text(name)
            }
        case .broadcast:
            if let title = message.data.title {
                Text(title)
            }
        case .direct:
            if let content = message.data.content {
                Text(content)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Message Detail Sheet

struct MessageDetailSheet: View {
    let message: MeshMessage
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 64, height: 64)

                            Image(systemName: message.type.icon)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(message.type.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)

                            Text("From \(message.senderName)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Details section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            detailContent
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Metadata section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Metadata")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            DetailRowBW(label: "Received", value: message.timestamp.formatted())
                            Divider().padding(.leading, 16)
                            DetailRowBW(label: "Hops", value: "\(message.hopCount)")
                            Divider().padding(.leading, 16)
                            DetailRowBW(label: "Message ID", value: String(message.id.uuidString.prefix(12)) + "...")
                        }
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        PigeonLogoCompact(size: 18)
                        Text("Pigeon")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch message.type {
        case .sos:
            if let location = message.data.location {
                DetailRowBW(label: "Location", value: location)
                Divider().padding(.leading, 16)
            }
            if let desc = message.data.description {
                DetailRowBW(label: "Description", value: desc)
                Divider().padding(.leading, 16)
            }
            if let urgency = message.data.urgency {
                DetailRowBW(label: "Urgency", value: urgency.capitalized)
            }

        case .triage:
            if let name = message.data.patientName {
                DetailRowBW(label: "Patient", value: name)
                Divider().padding(.leading, 16)
            }
            if let age = message.data.age {
                DetailRowBW(label: "Age", value: "\(age)")
                Divider().padding(.leading, 16)
            }
            if let condition = message.data.condition {
                DetailRowBW(label: "Condition", value: condition.capitalized)
                Divider().padding(.leading, 16)
            }
            if let injuries = message.data.injuries {
                DetailRowBW(label: "Injuries", value: injuries)
            }

        case .shelter:
            if let name = message.data.shelterName {
                DetailRowBW(label: "Shelter", value: name)
                Divider().padding(.leading, 16)
            }
            if let capacity = message.data.capacity, let occupancy = message.data.currentOccupancy {
                DetailRowBW(label: "Occupancy", value: "\(occupancy) / \(capacity)")
                Divider().padding(.leading, 16)
            }
            if let accepting = message.data.acceptingMore {
                DetailRowBW(label: "Accepting", value: accepting ? "Yes" : "No")
            }

        case .missingPerson:
            if let name = message.data.personName {
                DetailRowBW(label: "Name", value: name)
                Divider().padding(.leading, 16)
            }
            if let lastSeen = message.data.lastSeenLocation {
                DetailRowBW(label: "Last seen", value: lastSeen)
                Divider().padding(.leading, 16)
            }
            if let desc = message.data.physicalDescription {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(desc)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        case .broadcast:
            if let title = message.data.title {
                DetailRowBW(label: "Title", value: title)
                Divider().padding(.leading, 16)
            }
            if let msg = message.data.message {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(msg)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        case .direct:
            if let content = message.data.content {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(content)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .padding(16)
            }

        default:
            EmptyView()
        }
    }
}

// MARK: - Detail Row

struct DetailRowBW: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }
}

// MARK: - Quick Action Type

enum QuickActionType: String, Identifiable {
    case broadcast
    case missingPerson
    case triage
    case shelter

    var id: String { rawValue }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(color))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(width: 80)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(QuickActionButtonStyle())
    }
}

struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
