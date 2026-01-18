import SwiftUI

struct NetworkMapView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @State private var animationPhase: CGFloat = 0
    @State private var selectedNode: NetworkNode? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var showingPeersList = false

    // Interactive state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var computedNodes: [NetworkNode] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()

                // Minimal grid
                MinimalGrid()
                    .scaleEffect(scale)
                    .offset(offset)

                // Main visualization
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
                    let nodes = computeNodePositions(center: center, size: size)

                    // Draw hill edges first
                    for node in nodes where node.id != "self" {
                        drawHillEdge(
                            context: &context,
                            from: center,
                            to: node.position,
                            hops: node.hops,
                            phase: animationPhase,
                            isActive: node.isConnected,
                            isSelected: selectedNode?.id == node.id
                        )
                    }

                    // Draw peer connections
                    drawPeerConnections(context: &context, nodes: nodes, phase: animationPhase)

                    // Draw nodes
                    for node in nodes {
                        drawFlatNode(
                            context: &context,
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            pulseScale: node.id == "self" ? pulseScale : 1.0
                        )
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, 0.5), 3.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Only handle as tap if no significant movement
                            if abs(value.translation.width) < 10 && abs(value.translation.height) < 10 {
                                handleTap(at: value.location, in: geometry.size)
                            }
                        }
                )

                // Selected node info card
                if let node = selectedNode {
                    VStack {
                        nodeInfoCard(for: node)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 80)
                    .padding(.horizontal)
                }

                // Stats overlay at bottom
                VStack {
                    Spacer()
                    statsOverlay
                }
                .padding()

                // Top bar
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingPeersList = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                PigeonLogoCompact(size: 22)
                                Text("Pigeon")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }

                            Button {
                                refreshNetwork()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Refresh")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black)
                                .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                selectedNode = nil
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            startAnimations()
        }
        .sheet(isPresented: $showingPeersList) {
            PeersView()
        }
    }

    private func nodeInfoCard(for node: NetworkNode) -> some View {
        HStack(spacing: 16) {
            // Node indicator
            Circle()
                .fill(Color.black.opacity(node.nodeType == .self ? 1.0 : (node.isConnected ? 0.8 : 0.4)))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(node.displayName)
                    .font(.headline)
                    .foregroundColor(.black)

                HStack(spacing: 12) {
                    Label(node.nodeType == .self ? "You" : (node.isConnected ? "Connected" : "Remote"), systemImage: node.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if node.hops > 0 {
                        Label("\(node.hops) hop\(node.hops == 1 ? "" : "s")", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.spring()) {
                    selectedNode = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }

    private var statsOverlay: some View {
        HStack(spacing: 24) {
            StatBadgeBW(value: "\(viewModel.meshService.connectedPeers.count)", label: "Connected")
            StatBadgeBW(value: "\(viewModel.meshService.knownDevices.count)", label: "In Mesh")
            StatBadgeBW(value: "\(maxHops)", label: "Hops")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black)
        .clipShape(Capsule())
    }

    private var maxHops: Int {
        viewModel.meshService.knownDevices.values.max() ?? 0
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            animationPhase = 1
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }

    private func refreshNetwork() {
        // Restart browsing and advertising to discover new devices
        viewModel.meshService.stopBrowsing()
        viewModel.meshService.stopAdvertising()

        // Brief delay then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.meshService.startBrowsing()
            viewModel.meshService.startAdvertising()

            // Reset view as well
            withAnimation(.spring()) {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
                selectedNode = nil
            }
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        let nodes = computeNodePositions(center: center, size: size)

        // Adjust tap location for scale and offset
        let adjustedLocation = CGPoint(
            x: (location.x - size.width / 2 - offset.width) / scale + size.width / 2,
            y: (location.y - size.height / 2 - offset.height) / scale + size.height / 2
        )

        // Find tapped node
        for node in nodes {
            let distance = sqrt(pow(adjustedLocation.x - node.position.x, 2) + pow(adjustedLocation.y - node.position.y, 2))
            let hitRadius: CGFloat = node.nodeType == .self ? 40 : (node.isConnected ? 30 : 25)

            if distance < hitRadius {
                withAnimation(.spring()) {
                    if selectedNode?.id == node.id {
                        selectedNode = nil
                    } else {
                        selectedNode = node
                    }
                }
                return
            }
        }

        // Tap on empty space deselects
        withAnimation(.spring()) {
            selectedNode = nil
        }
    }

    private func computeNodePositions(center: CGPoint, size: CGSize) -> [NetworkNode] {
        var result: [NetworkNode] = []

        result.append(NetworkNode(
            id: "self",
            displayName: DeviceIdentity.shared.deviceName,
            position: center,
            hops: 0,
            isConnected: true,
            nodeType: .self
        ))

        let connectedCount = viewModel.meshService.connectedPeers.count
        let innerRadius = min(size.width, size.height) * 0.2

        for (index, peer) in viewModel.meshService.connectedPeers.enumerated() {
            let angle = (2.0 * Double.pi * Double(index) / Double(max(connectedCount, 1))) - Double.pi / 2.0
            let position = CGPoint(
                x: center.x + CGFloat(innerRadius) * CGFloat(cos(angle)),
                y: center.y + CGFloat(innerRadius) * CGFloat(sin(angle)) * 0.7
            )
            result.append(NetworkNode(
                id: peer.id.displayName,
                displayName: peer.displayName,
                position: position,
                hops: 1,
                isConnected: true,
                nodeType: .peer
            ))
        }

        let connectedNames = Set(viewModel.meshService.connectedPeers.map { $0.id.displayName })
        let knownDevices = viewModel.meshService.knownDevices
            .filter { !connectedNames.contains($0.key) }
            .sorted { $0.value < $1.value }

        let groupedByHops = Dictionary(grouping: knownDevices, by: { $0.value })

        for (hops, devices) in groupedByHops.sorted(by: { $0.key < $1.key }) {
            let radius = min(size.width, size.height) * (0.2 + 0.12 * Double(hops))
            let deviceCount = devices.count

            for (index, device) in devices.enumerated() {
                let baseAngle = (2.0 * Double.pi * Double(index) / Double(max(deviceCount, 1)))
                let offset = Double(hops) * 0.3
                let angle = baseAngle + offset - Double.pi / 2.0
                let position = CGPoint(
                    x: center.x + CGFloat(radius) * CGFloat(cos(angle)),
                    y: center.y + CGFloat(radius) * CGFloat(sin(angle)) * 0.7
                )
                result.append(NetworkNode(
                    id: device.key,
                    displayName: String(device.key.prefix(6)),
                    position: position,
                    hops: hops,
                    isConnected: false,
                    nodeType: .remote
                ))
            }
        }

        return result
    }

    private func drawHillEdge(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        hops: Int,
        phase: CGFloat,
        isActive: Bool,
        isSelected: Bool
    ) {
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let hillHeight = distance * 0.4

        let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: controlPoint)

        let opacity = isSelected ? 1.0 : (isActive ? 0.8 : 0.25)
        let lineWidth: CGFloat = isSelected ? 3.0 : (isActive ? 2.0 : 1.0)

        // Shadow
        context.stroke(
            path,
            with: .color(Color.black.opacity(0.05)),
            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
        )

        // Main edge
        context.stroke(
            path,
            with: .color(Color.black.opacity(opacity)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        // Animated dot
        if isActive {
            let dotPosition = pointOnQuadCurve(from: from, to: to, control: controlPoint, t: phase)
            let shadowPath = Path(ellipseIn: CGRect(x: dotPosition.x - 6, y: dotPosition.y - 4, width: 12, height: 8))
            context.fill(shadowPath, with: .color(Color.black.opacity(0.1)))

            let dotPath = Path(ellipseIn: CGRect(x: dotPosition.x - 4, y: dotPosition.y - 4, width: 8, height: 8))
            context.fill(dotPath, with: .color(Color.black))
        }
    }

    private func drawPeerConnections(context: inout GraphicsContext, nodes: [NetworkNode], phase: CGFloat) {
        let connectedNodes = nodes.filter { $0.isConnected && $0.id != "self" }

        for i in 0..<connectedNodes.count {
            for j in (i+1)..<connectedNodes.count {
                let from = connectedNodes[i].position
                let to = connectedNodes[j].position

                let midX = (from.x + to.x) / 2
                let midY = (from.y + to.y) / 2
                let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
                let hillHeight = distance * 0.3

                let controlPoint = CGPoint(x: midX, y: midY - hillHeight)

                var path = Path()
                path.move(to: from)
                path.addQuadCurve(to: to, control: controlPoint)

                context.stroke(
                    path,
                    with: .color(Color.black.opacity(0.12)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4])
                )
            }
        }
    }

    private func drawFlatNode(
        context: inout GraphicsContext,
        node: NetworkNode,
        isSelected: Bool,
        pulseScale: CGFloat
    ) {
        let baseSize: CGFloat
        let fillOpacity: Double

        switch node.nodeType {
        case .self:
            baseSize = 36
            fillOpacity = 1.0
        case .peer:
            baseSize = 26
            fillOpacity = 0.8
        case .remote:
            baseSize = 18
            fillOpacity = 0.4
        }

        let size = baseSize * (isSelected ? 1.2 : pulseScale)
        let actualOpacity = isSelected ? 1.0 : fillOpacity

        // Shadow
        let shadowRect = CGRect(
            x: node.position.x - size * 0.5,
            y: node.position.y + size * 0.35,
            width: size,
            height: size * 0.25
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(isSelected ? 0.2 : 0.1)))

        // Selection ring
        if isSelected {
            let selectionRect = CGRect(
                x: node.position.x - size / 2 - 6,
                y: node.position.y - size / 2 - 6,
                width: size + 12,
                height: size + 12
            )
            context.stroke(
                Path(ellipseIn: selectionRect),
                with: .color(Color.black.opacity(0.3)),
                style: StrokeStyle(lineWidth: 2, dash: [4, 4])
            )
        }

        // Outer ring
        let outerRect = CGRect(
            x: node.position.x - size / 2 - 2,
            y: node.position.y - size / 2 - 2,
            width: size + 4,
            height: size + 4
        )
        context.stroke(
            Path(ellipseIn: outerRect),
            with: .color(Color.black.opacity(actualOpacity * 0.3)),
            style: StrokeStyle(lineWidth: 1)
        )

        // Main node
        let rect = CGRect(
            x: node.position.x - size / 2,
            y: node.position.y - size / 2,
            width: size,
            height: size
        )
        context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(actualOpacity)))

        // Inner dot for self
        if node.nodeType == .self {
            let innerRect = CGRect(x: node.position.x - 5, y: node.position.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: innerRect), with: .color(.white))
        }

        // Label
        if node.nodeType == .self || node.isConnected || isSelected {
            let labelPoint = CGPoint(x: node.position.x, y: node.position.y + size / 2 + 16)
            context.draw(
                Text(node.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.black),
                at: labelPoint
            )
        }
    }

    private func pointOnQuadCurve(from: CGPoint, to: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let t1 = 1 - t
        return CGPoint(
            x: t1 * t1 * from.x + 2 * t1 * t * control.x + t * t * to.x,
            y: t1 * t1 * from.y + 2 * t1 * t * control.y + t * t * to.y
        )
    }
}

// MARK: - Supporting Types

struct NetworkNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let position: CGPoint
    let hops: Int
    let isConnected: Bool
    let nodeType: NodeType

    enum NodeType {
        case `self`, peer, remote
    }

    static func == (lhs: NetworkNode, rhs: NetworkNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct StatBadgeBW: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct MinimalGrid: View {
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 50
            let lineColor = Color.black.opacity(0.04)

            var y: CGFloat = gridSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                y += gridSpacing
            }

            var x: CGFloat = gridSpacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                x += gridSpacing
            }

            let centerX = size.width / 2
            let centerY = size.height / 2 + 20

            var hLine = Path()
            hLine.move(to: CGPoint(x: centerX - 30, y: centerY))
            hLine.addLine(to: CGPoint(x: centerX + 30, y: centerY))
            context.stroke(hLine, with: .color(Color.black.opacity(0.1)), lineWidth: 1)

            var vLine = Path()
            vLine.move(to: CGPoint(x: centerX, y: centerY - 30))
            vLine.addLine(to: CGPoint(x: centerX, y: centerY + 30))
            context.stroke(vLine, with: .color(Color.black.opacity(0.1)), lineWidth: 1)
        }
    }
}
