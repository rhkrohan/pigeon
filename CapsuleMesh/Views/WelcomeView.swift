import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var userName = ""
    @State private var currentPage = 0
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentPage) {
                    welcomePage
                        .tag(0)

                    featuresPage
                        .tag(1)

                    namePage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom section
                bottomSection
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo animation
            VStack(spacing: 24) {
                ZStack {
                    // Outer rings
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        .frame(width: 200, height: 200)

                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        .frame(width: 160, height: 160)

                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    // Logo
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)

                        Image(systemName: "bird.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text("Pigeon")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    Text("Mesh communication for emergencies")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Tagline
            VStack(spacing: 8) {
                Text("Stay connected when it matters most")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("Communicate with nearby devices without\ninternet or cellular connection")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How it works")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            VStack(spacing: 20) {
                FeatureRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Mesh Network",
                    description: "Connect directly with nearby devices using Bluetooth and WiFi"
                )

                FeatureRow(
                    icon: "arrow.triangle.branch",
                    title: "Message Relay",
                    description: "Messages hop through the network to reach distant devices"
                )

                FeatureRow(
                    icon: "sos",
                    title: "Emergency Alerts",
                    description: "Send SOS broadcasts to everyone on the network"
                )

                FeatureRow(
                    icon: "shield.checkered",
                    title: "No Internet Required",
                    description: "Works completely offline in disaster scenarios"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Name Page

    private var namePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("What's your name?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("This will be shown to others on the network")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            // Name input
            VStack(spacing: 12) {
                TextField("Enter your name", text: $userName)
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .focused($isNameFieldFocused)

                Text("You can change this later in Settings")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.black : Color.black.opacity(0.2))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Button
            Button {
                if currentPage < 2 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(buttonText)
                        .font(.system(size: 17, weight: .semibold))

                    if currentPage < 2 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canContinue ? Color.black : Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)

            // Skip button (only on first two pages)
            if currentPage < 2 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage = 2
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                // Spacer to maintain layout
                Text(" ")
                    .font(.system(size: 15))
            }
        }
        .padding(.bottom, 40)
    }

    private var buttonText: String {
        switch currentPage {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return userName.isEmpty ? "Enter your name" : "Start using Pigeon"
        default: return "Continue"
        }
    }

    private var canContinue: Bool {
        if currentPage == 2 {
            return !userName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func completeOnboarding() {
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            DeviceIdentity.shared.deviceName = trimmedName
        }
        DeviceIdentity.shared.hasCompletedOnboarding = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
