import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db/pool.js';
import { asyncHandler } from '../middleware/async_handler.js';

export const authRouter = Router();

authRouter.post('/register', asyncHandler(async (req, res) => {
  const { email, password, displayName } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  const hash = await bcrypt.hash(password, 12);
  try {
    const { rows } = await pool.query(
      'INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id, email, display_name',
      [email.toLowerCase().trim(), hash, displayName ?? null]
    );
    const token = jwt.sign({ userId: rows[0].id }, process.env.JWT_SECRET, { expiresIn: '90d' });
    res.status(201).json({ token, user: rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email already in use' });
    throw err;
  }
}));

authRouter.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '90d' });
  res.json({ token, user: { id: user.id, email: user.email, displayName: user.display_name } });
}));

authRouter.get('/me', asyncHandler(async (req, res) => {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing token' });
  try {
    const { userId } = jwt.verify(auth.slice(7), process.env.JWT_SECRET);
    const { rows } = await pool.query('SELECT id, email, display_name FROM users WHERE id = $1', [userId]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}));
