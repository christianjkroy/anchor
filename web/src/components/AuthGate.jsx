import { useState } from 'react';
import { api, setToken } from '../api.js';

export default function AuthGate({ onAuthenticated }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(event) {
    event.preventDefault();
    setLoading(true);
    setError('');

    try {
      const payload = { email, password, displayName };
      const data = isRegister ? await api.register(payload) : await api.login(payload);
      setToken(data.token);
      onAuthenticated(data.user);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-shell">
      <div className="auth-card">
        <h1>Anchor</h1>
        <p>Build a reality-based picture of your relationships.</p>
        <form onSubmit={submit}>
          {isRegister && (
            <label>
              Display Name
              <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Chris" />
            </label>
          )}
          <label>
            Email
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
          </label>
          <label>
            Password
            <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" />
          </label>
          {error && <p className="error-text">{error}</p>}
          <button type="submit" disabled={loading}>{loading ? 'Please wait...' : isRegister ? 'Create account' : 'Sign in'}</button>
        </form>
        <button className="ghost-btn" onClick={() => setIsRegister((v) => !v)}>
          {isRegister ? 'Already have an account? Sign in' : 'Need an account? Register'}
        </button>
      </div>
    </div>
  );
}
