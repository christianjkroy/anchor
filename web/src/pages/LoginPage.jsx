import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../App';
import '../styles/login.css';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (mode === 'login') {
        await login(email, password);
      } else {
        const { api } = await import('../api');
        const { token } = await api.auth.register(email, password, name);
        localStorage.setItem('anchor_token', token);
        await login(email, password);
      }
      navigate('/');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1 className="login-logo">Anchor</h1>
        <p className="login-tagline">Your relationships, grounded in data.</p>

        <div className="login-tabs">
          <button className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')}>Sign in</button>
          <button className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')}>Create account</button>
        </div>

        <form onSubmit={submit} className="login-form">
          {mode === 'register' && (
            <input placeholder="Display name (optional)" value={name} onChange={e => setName(e.target.value)} />
          )}
          <input type="email" placeholder="Email" required value={email} onChange={e => setEmail(e.target.value)} />
          <input type="password" placeholder="Password" required value={password} onChange={e => setPassword(e.target.value)} />

          {error && <p className="login-error">{error}</p>}

          <button type="submit" className="btn btn--primary" style={{ width: '100%', justifyContent: 'center' }} disabled={loading}>
            {loading ? 'Loading…' : mode === 'login' ? 'Sign in' : 'Create account'}
          </button>
        </form>
      </div>
    </div>
  );
}
