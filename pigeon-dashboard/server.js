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

// Prediction markets storage (Polymarket-style)
let predictionMarkets = [
    {
        id: 'market-1',
        question: 'Will power be restored in Downtown Pittsburgh by Friday?',
        category: 'infrastructure',
        createdAt: new Date(Date.now() - 86400000),
        endDate: new Date(Date.now() + 172800000),
        yesVotes: 67,
        noVotes: 33,
        totalVolume: 1250,
        status: 'active'
    },
    {
        id: 'market-2',
        question: 'Will evacuation orders for South Side be lifted this week?',
        category: 'evacuation',
        createdAt: new Date(Date.now() - 43200000),
        endDate: new Date(Date.now() + 432000000),
        yesVotes: 45,
        noVotes: 55,
        totalVolume: 890,
        status: 'active'
    },
    {
        id: 'market-3',
        question: 'Will flood waters recede below warning level by tomorrow?',
        category: 'weather',
        createdAt: new Date(Date.now() - 21600000),
        endDate: new Date(Date.now() + 86400000),
        yesVotes: 23,
        noVotes: 77,
        totalVolume: 2100,
        status: 'active'
    }
];

// API endpoint to receive gateway syncs from iOS app
app.post('/api/messages', (req, res) => {
    const { deviceId, deviceName, timestamp, messages } = req.body;

    console.log(`\n📡 Received sync from ${deviceName} (${deviceId?.substring(0, 8) || 'unknown'}...)`);
    console.log(`   Messages: ${messages?.length || 0}`);

    // Debug: Log location data for first few messages
    if (messages && messages.length > 0) {
        messages.slice(0, 3).forEach((m, i) => {
            console.log(`   [${i}] Type: ${m.type}, Lat: ${m.data?.latitude}, Lng: ${m.data?.longitude}`);
        });
    }

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

// API endpoint to clear all messages
app.delete('/api/messages', (req, res) => {
    const count = allMessages.length;
    allMessages = [];
    connectedDevices.clear();
    stats = {
        totalMessages: 0,
        sosAlerts: 0,
        triageReports: 0,
        shelterUpdates: 0,
        missingPersons: 0,
        broadcasts: 0
    };

    console.log(`\n🗑️  Cleared ${count} messages`);

    res.json({
        success: true,
        message: `Cleared ${count} messages`,
        totalStored: 0
    });
});

// API endpoint to get messages with location data (for map)
app.get('/api/map-data', (req, res) => {
    // Filter messages that have GPS coordinates or location text
    const mapMessages = allMessages.filter(m =>
        (m.data?.latitude && m.data?.longitude) || m.data?.location || m.data?.lastSeenLocation
    ).map(m => ({
        id: m.id,
        type: m.type,
        latitude: m.data?.latitude,
        longitude: m.data?.longitude,
        location: m.data?.location || m.data?.lastSeenLocation,
        senderName: m.senderName,
        timestamp: m.timestamp,
        batteryLevel: m.data?.batteryLevel,
        photoBase64: m.data?.photoBase64,
        data: m.data
    }));

    res.json(mapMessages);
});

// ==========================================
// PREDICTION MARKETS API (Polymarket-style)
// ==========================================

// Get all prediction markets
app.get('/api/markets', (req, res) => {
    const { status, category } = req.query;

    let filtered = predictionMarkets;

    if (status) {
        filtered = filtered.filter(m => m.status === status);
    }
    if (category) {
        filtered = filtered.filter(m => m.category === category);
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json(filtered);
});

// Create a new prediction market
app.post('/api/markets', (req, res) => {
    const { question, category, endDate } = req.body;

    if (!question) {
        return res.status(400).json({ error: 'Question is required' });
    }

    const market = {
        id: `market-${Date.now()}`,
        question,
        category: category || 'general',
        createdAt: new Date(),
        endDate: endDate ? new Date(endDate) : new Date(Date.now() + 604800000), // Default 1 week
        yesVotes: 0,
        noVotes: 0,
        totalVolume: 0,
        status: 'active'
    };

    predictionMarkets.push(market);

    console.log(`\n🎯 New prediction market created: "${question.substring(0, 50)}..."`);

    res.json({
        success: true,
        market
    });
});

// Vote on a prediction market
app.post('/api/markets/:id/vote', (req, res) => {
    const { id } = req.params;
    const { vote, amount = 10 } = req.body; // vote: 'yes' or 'no'

    const market = predictionMarkets.find(m => m.id === id);

    if (!market) {
        return res.status(404).json({ error: 'Market not found' });
    }

    if (market.status !== 'active') {
        return res.status(400).json({ error: 'Market is not active' });
    }

    if (vote === 'yes') {
        market.yesVotes += amount;
    } else if (vote === 'no') {
        market.noVotes += amount;
    } else {
        return res.status(400).json({ error: 'Vote must be "yes" or "no"' });
    }

    market.totalVolume += amount;

    console.log(`\n🎯 Vote recorded: ${vote.toUpperCase()} on "${market.question.substring(0, 30)}..."`);

    res.json({
        success: true,
        market
    });
});

// Resolve a prediction market
app.post('/api/markets/:id/resolve', (req, res) => {
    const { id } = req.params;
    const { outcome } = req.body; // outcome: 'yes' or 'no'

    const market = predictionMarkets.find(m => m.id === id);

    if (!market) {
        return res.status(404).json({ error: 'Market not found' });
    }

    if (outcome !== 'yes' && outcome !== 'no') {
        return res.status(400).json({ error: 'Outcome must be "yes" or "no"' });
    }

    market.status = 'resolved';
    market.outcome = outcome;
    market.resolvedAt = new Date();

    console.log(`\n🎯 Market resolved: "${market.question.substring(0, 30)}..." → ${outcome.toUpperCase()}`);

    res.json({
        success: true,
        market
    });
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
