const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Conectare la MongoDB
// Asigură-te că ai un string valid în fișierul .env din acest folder
mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/guessr_timi')
    .then(() => console.log('✅ Conectat la MongoDB'))
    .catch(err => console.error('❌ Eroare conectare MongoDB:', err));

const scoreSchema = new mongoose.Schema({
    playerName: String,
    totalScore: Number,
    timestamp: { type: Date, default: Date.now },
    rounds: [Number]
});

const Score = mongoose.model('Score', scoreSchema);

// Endpoint pentru a lua scorurile
app.get('/api/highscores', async (req, res) => {
    try {
        const scores = await Score.find().sort({ totalScore: -1 }).limit(5);
        res.json(scores);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Endpoint pentru a salva un scor nou
app.post('/api/highscores', async (req, res) => {
    try {
        const newScore = new Score(req.body);
        await newScore.save();
        res.status(201).json(newScore);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`🚀 Serverul rulează pe http://localhost:${PORT}`);
});