import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Content
            Group {
                switch selectedTab {
                case 0:
                    MessagesView()
                case 1:
                    NetworkMapView()
                case 2:
                    SOSView()
                case 3:
                    ActionsView()
                case 4:
                    SettingsView()
                default:
                    MessagesView()
                }
            }

            // Floating Tab Bar
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String, isEmergency: Bool)] = [
        ("message.fill", "Messages", false),
        ("point.3.connected.trianglepath.dotted", "Map", false),
        ("sos", "SOS", true),
        ("square.grid.2x2.fill", "Actions", false),
        ("gearshape.fill", "Settings", false)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    isEmergency: tabs[index].isEmergency
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .padding(.horizontal, 24)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isEmergency: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Selection indicator
                    if isSelected {
                        Capsule()
                            .fill(isEmergency ? Color.red.opacity(0.2) : Color.white.opacity(0.15))
                            .frame(width: 56, height: 32)
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 18 : 16, weight: .medium))
                        .foregroundColor(iconColor)
                }
                .frame(height: 32)

                if isSelected {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isEmergency ? .red : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(TabButtonStyle())
    }

    private var iconColor: Color {
        if isSelected {
            return isEmergency ? .red : .white
        } else {
            return isEmergency ? .red.opacity(0.6) : .white.opacity(0.5)
        }
    }
}

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
