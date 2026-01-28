# Pigeon - Emergency Mesh Network Communication

<p align="center">
  <img src="https://github.com/user-attachments/assets/d988d185-0586-4d02-ae11-16327e86c39d" alt="Pigeon Logo" width="120"/>
</p>

**Pigeon** is a decentralized, peer-to-peer mesh networking application designed for crisis communication when traditional infrastructure fails. Built for iOS using Apple's Multipeer Connectivity framework, it enables offline communication during natural disasters, emergencies, and infrastructure outages.

## The Problem

During natural disasters and emergencies:
- Cell towers become overloaded or destroyed
- Internet connectivity fails
- Traditional communication breaks down
- Emergency responders can't coordinate effectively
- Families can't locate missing loved ones

## Our Solution

Pigeon creates a resilient mesh network using Bluetooth and WiFi Direct, allowing devices to relay critical emergency information even without internet access. When any device in the mesh gains internet connectivity, it automatically becomes a "gateway" and syncs all collected data to a central command dashboard.

## Key Features

### Mobile App (iOS)

#### Emergency Communication Types
- **SOS Alerts** - Send distress signals with GPS location and battery status
- **Medical Triage** - Report patient conditions for emergency responders
- **Shelter Updates** - Share shelter locations, capacity, and available supplies
- **Missing Persons** - Post reports with photos and last-seen information
- **Broadcasts** - Send area-wide announcements and updates

#### Mesh Networking
- **Peer-to-Peer Communication** - Direct device-to-device messaging via Bluetooth/WiFi
- **Multi-Hop Routing** - Messages automatically relay through multiple devices
- **Store-and-Forward** - Messages persist until delivery is confirmed
- **Gateway Detection** - Automatic identification of internet-connected devices
- **Network Visualization** - Real-time graph showing all connected peers

#### Additional Features
- **GPS Integration** - Automatic location tagging on all messages
- **Battery Monitoring** - Track device battery levels across the network
- **Offline-First Design** - Full functionality without internet
- **Simulation Mode** - Test the app with virtual peers and messages

### Web Dashboard

#### Live Command Center
- **Real-Time Map** - View all emergency reports on an interactive map
- **Pulsing Markers** - Color-coded, animated pins for different emergency types
- **Mesh Visualization** - Toggle mesh network connections between nodes
- **Live Feed** - Scrolling feed of incoming emergency reports
- **Statistics Bar** - At-a-glance counts for all message types

#### Features
- **Filtering** - Filter by message type (SOS, Triage, Shelter, Missing, Broadcast)
- **Simulation Mode** - Generate test data focused on Pittsburgh area
- **Clear All** - Reset dashboard data for new scenarios
- **Auto-Refresh** - Real-time updates every 3 seconds

## Technical Architecture

### iOS App Stack

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  (SOSView, TriageView, ShelterView, MissingPersonView...)  │
├─────────────────────────────────────────────────────────────┤
│                     View Models                             │
│                    (MeshViewModel)                          │
├─────────────────────────────────────────────────────────────┤
│                      Services                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │   Mesh      │ │   Gateway   │ │    Location         │   │
│  │  Network    │ │   Service   │ │    Service          │   │
│  │  Service    │ │             │ │                     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  Message    │ │  Device     │ │    Simulation       │   │
│  │   Store     │ │  Identity   │ │    Service          │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│              Apple Multipeer Connectivity                   │
│                 (Bluetooth + WiFi Direct)                   │
└─────────────────────────────────────────────────────────────┘
```

### Dashboard Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (HTML/CSS/JS)                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  Leaflet.js │ │   Glass UI  │ │   Real-time         │   │
│  │    Maps     │ │  Components │ │   Updates           │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   Express.js Backend                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  REST API   │ │  In-Memory  │ │   CORS Enabled      │   │
│  │  Endpoints  │ │   Storage   │ │   for Mobile        │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Vercel Deployment                        │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────┐    Bluetooth/WiFi    ┌──────────┐
│  Device  │◄────────────────────►│  Device  │
│    A     │                      │    B     │
└────┬─────┘                      └────┬─────┘
     │                                 │
     │         Multi-hop relay         │
     │                                 │
     ▼                                 ▼
┌──────────┐    Bluetooth/WiFi    ┌──────────┐
│  Device  │◄────────────────────►│  Device  │
│    C     │                      │    D     │
└──────────┘                      └────┬─────┘
                                       │
                                       │ Internet (when available)
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  Pigeon Dashboard │
                              │   (Vercel Cloud)  │
                              └──────────────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  Command Center   │
                              │   (Web Browser)   │
                              └──────────────────┘
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/messages` | Receive gateway syncs from iOS app |
| `GET` | `/api/messages` | Retrieve all messages (with optional filters) |
| `GET` | `/api/stats` | Get message statistics and connected devices |
| `GET` | `/api/map-data` | Get messages with location data for map |
| `DELETE` | `/api/messages` | Clear all stored messages |

## Message Types & Data Structure

### SOS Alert
```json
{
  "type": "sos",
  "data": {
    "urgency": "Critical",
    "description": "Trapped under debris",
    "location": "Downtown Pittsburgh",
    "latitude": 40.4406,
    "longitude": -79.9959,
    "batteryLevel": 42
  }
}
```

### Medical Triage
```json
{
  "type": "triage",
  "data": {
    "patientName": "John Doe",
    "age": 45,
    "condition": "Critical",
    "injuries": "Head trauma",
    "conscious": true,
    "breathing": true,
    "location": "Oakland"
  }
}
```

### Shelter Update
```json
{
  "type": "shelter",
  "data": {
    "shelterName": "Convention Center",
    "capacity": 500,
    "currentOccupancy": 234,
    "acceptingMore": true,
    "supplies": ["Water", "Food", "Medical", "Blankets"]
  }
}
```

### Missing Person
```json
{
  "type": "missingPerson",
  "data": {
    "personName": "Jane Smith",
    "age": 8,
    "physicalDescription": "Child, red jacket",
    "lastSeenLocation": "Squirrel Hill",
    "lastSeenTime": "2 hours ago",
    "contactInfo": "412-555-1234",
    "photoBase64": "..."
  }
}
```

## Project Structure

```
swift-ui-app/
├── CapsuleMesh/                    # iOS App
│   ├── CapsuleMeshApp.swift        # App entry point
│   ├── Models/
│   │   ├── MeshMessage.swift       # Message data model
│   │   ├── MessageType.swift       # Message type enum
│   │   └── Peer.swift              # Peer device model
│   ├── Services/
│   │   ├── MeshNetworkService.swift    # Multipeer connectivity
│   │   ├── GatewayService.swift        # Internet sync service
│   │   ├── LocationService.swift       # GPS location
│   │   ├── MessageStore.swift          # Message persistence
│   │   ├── DeviceIdentity.swift        # Device identification
│   │   └── SimulationService.swift     # Testing simulation
│   ├── Views/
│   │   ├── MainTabView.swift           # Tab navigation
│   │   ├── SOSView.swift               # SOS alert screen
│   │   ├── TriageView.swift            # Triage form
│   │   ├── ShelterView.swift           # Shelter updates
│   │   ├── MissingPersonView.swift     # Missing person reports
│   │   ├── BroadcastView.swift         # Broadcast messages
│   │   ├── MessagesView.swift          # Message feed
│   │   ├── NetworkMapView.swift        # Network visualization
│   │   ├── PeersView.swift             # Connected peers list
│   │   └── SettingsView.swift          # App settings
│   ├── ViewModels/
│   │   └── MeshViewModel.swift         # Main view model
│   └── Utilities/
│       ├── Theme.swift                 # UI theming
│       └── Constants.swift             # App constants
│
├── pigeon-dashboard/               # Web Dashboard
│   ├── server.js                   # Express.js backend
│   ├── public/
│   │   └── index.html              # Dashboard UI
│   ├── package.json
│   └── vercel.json                 # Deployment config
│
└── README.md
```

## Setup & Installation

### iOS App

1. **Requirements**
   - Xcode 15+
   - iOS 17+
   - Physical iOS device (Multipeer requires real hardware)

2. **Build**
   ```bash
   cd CapsuleMesh
   open CapsuleMesh.xcodeproj
   # Select your device and build (Cmd+R)
   ```

3. **Permissions**
   The app requires:
   - Bluetooth
   - Local Network
   - Location Services
   - Camera (for missing person photos)

### Web Dashboard

1. **Local Development**
   ```bash
   cd pigeon-dashboard
   npm install
   node server.js
   # Dashboard available at http://localhost:3000
   ```

2. **Deploy to Vercel**
   ```bash
   vercel --prod
   ```

## Live Demo

- **Dashboard**: [https://pigeon-dashboard.vercel.app](https://pigeon-dashboard.vercel.app)
- **TestFlight**: Available on request

## Simulation Mode

Both the iOS app and web dashboard include simulation modes for testing:

### iOS App
1. Go to Settings tab
2. Enable "Simulation Mode"
3. Select a scenario (Normal, Disaster, Dense, Sparse)
4. Virtual peers and messages will appear on the network map

### Web Dashboard
1. Click "Simulate" button in top bar
2. Dashboard pans to Pittsburgh area
3. Simulated emergency data generates every 3 seconds
4. Click "Mesh" to visualize network connections
5. Click "Stop" to return to live mode

## Design Decisions

### Why Multipeer Connectivity?
- Native iOS framework with no server dependency
- Automatic peer discovery
- Bluetooth + WiFi for maximum range
- Encrypted communication built-in

### Why Store-and-Forward?
- Messages persist even if devices disconnect
- Multi-hop routing extends network range
- No single point of failure
- Works in sparse network conditions

### Why Gateway Architecture?
- Leverages any available internet connection
- Automatic failover between gateways
- Centralized view for emergency coordinators
- Real-time sync when connectivity returns

## Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| Limited Bluetooth range | Multi-hop message relay through intermediate devices |
| Device discovery latency | Continuous background advertising and browsing |
| Message deduplication | UUID-based message tracking across all devices |
| Battery optimization | Intelligent sync intervals and background modes |
| Offline map display | Caching and graceful degradation |

## Future Roadmap

- [ ] Android version using Nearby Connections API
- [ ] Offline map tile caching
- [ ] End-to-end encryption for sensitive data
- [ ] Voice message support
- [ ] Integration with official emergency systems
- [ ] Cross-platform mesh (iOS to Android)

## Team

Built with love for the hackathon by the Pigeon team.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>When the network fails, the mesh prevails.</strong>
</p>
