const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// In-memory storage for messages
let allMessages = [];
let connectedDevices = new Map(); // deviceId -> { name, lastSeen }
let stats = {
    totalMessages: 0,
    sosAlerts: 0,
    triageReports: 0,
    shelterUpdates: 0,
    missingPersons: 0,
    broadcasts: 0
};

// API endpoint to receive gateway syncs from iOS app
app.post('/api/messages', (req, res) => {
    const { deviceId, deviceName, timestamp, messages } = req.body;

    console.log(`\n📡 Received sync from ${deviceName} (${deviceId.substring(0, 8)}...)`);
    console.log(`   Messages: ${messages?.length || 0}`);

    // Update connected device info
    connectedDevices.set(deviceId, {
        name: deviceName,
        lastSeen: new Date(timestamp)
    });

    // Process messages
    if (messages && Array.isArray(messages)) {
        let newCount = 0;

        messages.forEach(msg => {
            // Check if message already exists (by ID)
            const exists = allMessages.some(m => m.id === msg.id);

            if (!exists) {
                allMessages.push({
                    ...msg,
                    receivedAt: new Date(),
                    gatewayDevice: deviceName
                });
                newCount++;

                // Update stats
                stats.totalMessages++;
                switch (msg.type) {
                    case 'sos': stats.sosAlerts++; break;
                    case 'triage': stats.triageReports++; break;
                    case 'shelter': stats.shelterUpdates++; break;
                    case 'missingPerson': stats.missingPersons++; break;
                    case 'broadcast': stats.broadcasts++; break;
                }
            }
        });

        console.log(`   New messages added: ${newCount}`);
    }

    res.json({
        success: true,
        message: `Received ${messages?.length || 0} messages`,
        totalStored: allMessages.length
    });
});

// API endpoint to get all messages
app.get('/api/messages', (req, res) => {
    const { type, limit = 100 } = req.query;

    let filtered = allMessages;

    if (type && type !== 'all') {
        filtered = allMessages.filter(m => m.type === type);
    }

    // Sort by timestamp descending (newest first)
    filtered.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    // Limit results
    filtered = filtered.slice(0, parseInt(limit));

    res.json(filtered);
});

// API endpoint to get stats
app.get('/api/stats', (req, res) => {
    res.json({
        ...stats,
        connectedDevices: connectedDevices.size,
        devices: Array.from(connectedDevices.entries()).map(([id, info]) => ({
            id: id.substring(0, 8) + '...',
            name: info.name,
            lastSeen: info.lastSeen
        }))
    });
});

// API endpoint to get messages with location data (for map)
app.get('/api/map-data', (req, res) => {
    // Filter messages that have location data
    const mapMessages = allMessages.filter(m =>
        m.data?.location || m.data?.lastSeenLocation
    ).map(m => ({
        id: m.id,
        type: m.type,
        location: m.data?.location || m.data?.lastSeenLocation,
        senderName: m.senderName,
        timestamp: m.timestamp,
        data: m.data
    }));

    res.json(mapMessages);
});

// Serve dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start server (for local development)
if (require.main === module) {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     🕊️  PIGEON DASHBOARD SERVER                           ║
║                                                           ║
║     Dashboard:  http://localhost:${PORT}                    ║
║     API:        http://localhost:${PORT}/api/messages       ║
║                                                           ║
║     Waiting for gateway syncs from Pigeon app...          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
        `);
    });
}

// Export for Vercel
module.exports = app;
