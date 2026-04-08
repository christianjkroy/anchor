import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';

import { authRouter } from './routes/auth.js';
import { personsRouter } from './routes/persons.js';
import { interactionsRouter } from './routes/interactions.js';
import { insightsRouter } from './routes/insights.js';
import { perceptionRouter } from './routes/perception.js';
import { digestRouter } from './routes/digest.js';
import { authenticate } from './middleware/auth.js';

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webDistPath = path.resolve(__dirname, '../web/dist');

app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Public
app.use('/api/auth', authRouter);

// Protected
app.use('/api/persons', authenticate, personsRouter);
app.use('/api/interactions', authenticate, interactionsRouter);
app.use('/api/insights', authenticate, insightsRouter);
app.use('/api/perception', authenticate, perceptionRouter);
app.use('/api/digest', authenticate, digestRouter);

app.get('/health', (_req, res) => res.json({ ok: true }));

// Serve React dashboard build when present
app.use(express.static(webDistPath));
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api/')) return next();
  res.sendFile(path.join(webDistPath, 'index.html'), (err) => {
    if (err) next();
  });
});

// Last-mile error guard for unhandled async errors bubbling into Express
app.use((err, _req, res, _next) => {
  console.error('[api] Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Anchor API running on :${PORT}`));
