import { useEffect, useMemo, useState } from 'react';
import AuthGate from './components/AuthGate.jsx';
import { api, getToken, setToken } from './api.js';
import OverviewPage from './pages/OverviewPage.jsx';
import InsightsPage from './pages/InsightsPage.jsx';
import PeoplePage from './pages/PeoplePage.jsx';
import DigestPage from './pages/DigestPage.jsx';
import GraphPage from './pages/GraphPage.jsx';

const TABS = ['overview', 'insights', 'people', 'graph', 'digests'];

export default function App() {
  const [user, setUser] = useState(null);
  const [tab, setTab] = useState('overview');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [people, setPeople] = useState([]);
  const [interactions, setInteractions] = useState([]);
  const [network, setNetwork] = useState(null);
  const [insights, setInsights] = useState([]);
  const [digests, setDigests] = useState([]);

  useEffect(() => {
    bootstrap();
  }, []);

  async function bootstrap() {
    if (!getToken()) return;
    try {
      const me = await api.auth.me();
      setUser(me);
      await refresh();
    } catch {
      setToken('');
      setUser(null);
    }
  }

  async function refresh() {
    setError('');
    const [peopleData, interactionData, networkData, insightData, digestData] = await Promise.all([
      api.persons.list(),
      api.interactions.list({ limit: 50 }),
      api.persons.network(),
      api.insights.list(),
      api.digest.list(),
    ]);

    setPeople(peopleData);
    setInteractions(interactionData);
    setNetwork(networkData);
    setInsights(insightData);
    setDigests(digestData);
  }

  async function handleCreateInteraction(payload) {
    setLoading(true);
    setError('');
    try {
      await api.interactions.create(payload);
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleCreatePerson(payload) {
    setLoading(true);
    setError('');
    try {
      await api.persons.create(payload);
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleGenerateDigest() {
    setLoading(true);
    setError('');
    try {
      await api.digest.generate({});
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const data = useMemo(() => ({ people, interactions, network }), [people, interactions, network]);

  if (!user) {
    return <AuthGate onAuthenticated={(nextUser) => { setUser(nextUser); refresh().catch(() => {}); }} />;
  }

  return (
    <div className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow">Anchor Relationship Dashboard</p>
          <h1>Perception vs Reality</h1>
          <p>Welcome back{user.display_name ? `, ${user.display_name}` : ''}.</p>
        </div>
        <div className="header-actions">
          {TABS.map((candidate) => (
            <button
              key={candidate}
              className={candidate === tab ? 'tab-btn active' : 'tab-btn'}
              onClick={() => setTab(candidate)}
            >
              {candidate}
            </button>
          ))}
          <button className="ghost-btn" onClick={() => { setToken(''); setUser(null); }}>Sign out</button>
        </div>
      </header>

      {error ? <p className="error-text">{error}</p> : null}

      {tab === 'overview' && (
        <OverviewPage
          data={data}
          onCreateInteraction={handleCreateInteraction}
          onCreatePerson={handleCreatePerson}
          loading={loading}
        />
      )}
      {tab === 'insights' && (
        <InsightsPage insights={insights} digests={digests} onGenerateDigest={handleGenerateDigest} loading={loading} />
      )}
      {tab === 'people' && <PeoplePage />}
      {tab === 'graph' && <GraphPage network={network} />}
      {tab === 'digests' && <DigestPage digests={digests} onGenerateDigest={handleGenerateDigest} loading={loading} />}
    </div>
  );
}
