import React, { useEffect, useState } from 'react';
import { api } from '../api';

export default function PeoplePage() {
  const [people, setPeople] = useState([]);
  const [selected, setSelected] = useState(null);
  const [stats, setStats] = useState(null);
  const [interactions, setInteractions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [perceptionScore, setPerceptionScore] = useState('');
  const [perceptionResult, setPerceptionResult] = useState(null);
  const [submittingPerception, setSubmittingPerception] = useState(false);

  useEffect(() => {
    api.persons.list().then(p => { setPeople(p); setLoading(false); });
  }, []);

  const selectPerson = async (person) => {
    setSelected(person);
    setStats(null);
    setInteractions([]);
    setPerceptionResult(null);
    setPerceptionScore('');
    const [s, i] = await Promise.all([
      api.persons.stats(person.id),
      api.interactions.list({ personId: person.id, limit: 30 }),
    ]);
    setStats(s);
    setInteractions(i);
  };

  const submitPerception = async () => {
    if (!selected || !perceptionScore) return;
    setSubmittingPerception(true);
    try {
      const result = await api.perception.submit(selected.id, Number(perceptionScore));
      setPerceptionResult(result);
    } catch (err) {
      alert(err.message);
    } finally {
      setSubmittingPerception(false);
    }
  };

  if (loading) return <div className="loading">Loading…</div>;

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '260px 1fr', gap: 24 }}>
      {/* People list */}
      <div>
        <div className="page-header" style={{ marginBottom: 16 }}>
          <h1 className="page-title">People</h1>
        </div>
        <div className="card" style={{ padding: 0 }}>
          {people.length === 0 && <p className="empty-state">No people yet. Add some via the iOS app.</p>}
          {people.map(p => (
            <div key={p.id}
              onClick={() => selectPerson(p)}
              style={{
                padding: '12px 16px', cursor: 'pointer', borderBottom: '1px solid var(--color-border)',
                background: selected?.id === p.id ? 'var(--color-bg)' : 'transparent',
                transition: 'background .1s',
              }}
            >
              <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>{p.name}</div>
              <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>
                {p.total_interactions ?? 0} interaction{p.total_interactions !== 1 ? 's' : ''}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Person detail */}
      <div>
        {!selected && (
          <div className="empty-state" style={{ paddingTop: 80 }}>Select a person to see their data.</div>
        )}
        {selected && (
          <div>
            <div className="page-header">
              <h2 className="page-title">{selected.name}</h2>
              <span className="badge" style={{ background: '#e0e7ff', color: '#3730a3' }}>
                {selected.relationship_type}
              </span>
            </div>

            {/* Stats */}
            {stats && (
              <div className="card" style={{ marginBottom: 16 }}>
                <h3 style={{ fontWeight: 600, marginBottom: 12, fontSize: '0.9rem' }}>Stats</h3>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
                  <Stat label="Total interactions" value={stats.totalInteractions} />
                  <Stat label="You initiate" value={`${Math.round((stats.initiationRatio ?? 0.5) * 100)}%`} />
                  <Stat label="Consistency" value={stats.consistencyScore != null ? stats.consistencyScore.toFixed(2) : '—'} />
                </div>
                <InitiationBar ratio={stats.initiationRatio ?? 0.5} />
                <SentimentBar dist={stats.sentimentDistribution} />
              </div>
            )}

            {/* Perception check */}
            <div className="card" style={{ marginBottom: 16 }}>
              <h3 style={{ fontWeight: 600, marginBottom: 12, fontSize: '0.9rem' }}>Perception Check</h3>
              <p style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginBottom: 12 }}>
                How do you feel about this relationship? (1 = very uncertain, 5 = very confident)
              </p>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                {[1,2,3,4,5].map(n => (
                  <button key={n}
                    onClick={() => setPerceptionScore(String(n))}
                    style={{
                      width: 36, height: 36, borderRadius: '50%',
                      background: perceptionScore === String(n) ? 'var(--color-accent)' : 'var(--color-bg)',
                      color: perceptionScore === String(n) ? '#fff' : 'var(--color-text)',
                      border: '1px solid var(--color-border)', fontWeight: 600, fontSize: '0.9rem',
                    }}
                  >{n}</button>
                ))}
                <button className="btn btn--primary" onClick={submitPerception} disabled={!perceptionScore || submittingPerception}>
                  {submittingPerception ? '…' : 'Submit'}
                </button>
              </div>

              {perceptionResult && (
                <div style={{ marginTop: 16, padding: 12, background: perceptionResult.flagged ? '#fee2e2' : '#dcfce7', borderRadius: 8 }}>
                  <strong style={{ fontSize: '0.875rem' }}>
                    {perceptionResult.flagged ? 'Divergence flagged' : 'Aligned'}
                  </strong>
                  <p style={{ fontSize: '0.8rem', marginTop: 4 }}>
                    You rated: {perceptionResult.perceived_score} &nbsp;|&nbsp; Reality score: {perceptionResult.reality_score?.toFixed(1)} &nbsp;|&nbsp;
                    You're <em>{perceptionResult.direction}</em> by {perceptionResult.divergence?.toFixed(1)} points
                  </p>
                </div>
              )}
            </div>

            {/* Interactions */}
            <div className="card">
              <h3 style={{ fontWeight: 600, marginBottom: 12, fontSize: '0.9rem' }}>Recent Interactions</h3>
              {interactions.length === 0 && <p className="empty-state">No interactions logged yet.</p>}
              {interactions.map(i => (
                <div key={i.id} style={{ borderBottom: '1px solid var(--color-border)', padding: '10px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <div style={{ fontWeight: 500, fontSize: '0.875rem', textTransform: 'capitalize' }}>{i.type}</div>
                    {i.note && <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginTop: 2 }}>{i.note}</div>}
                    <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginTop: 4 }}>
                      Initiated by: {i.initiated_by} &nbsp;·&nbsp; {i.feeling_before} → {i.feeling_during} → {i.feeling_after}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0, marginLeft: 12 }}>
                    {i.sentiment && <span className={`badge badge--${i.sentiment}`}>{i.sentiment}</span>}
                    <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginTop: 4 }}>
                      {new Date(i.created_at).toLocaleDateString()}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }) {
  return (
    <div>
      <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', marginBottom: 2 }}>{label}</div>
      <div style={{ fontWeight: 700, fontSize: '1.1rem' }}>{value}</div>
    </div>
  );
}

function InitiationBar({ ratio }) {
  const you = Math.round(ratio * 100);
  const them = 100 - you;
  return (
    <div style={{ marginTop: 16 }}>
      <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', marginBottom: 4 }}>Initiation</div>
      <div style={{ display: 'flex', height: 8, borderRadius: 4, overflow: 'hidden', gap: 2 }}>
        <div style={{ flex: you, background: '#ff9500', borderRadius: 4 }} title={`You: ${you}%`} />
        <div style={{ flex: them, background: '#34c759', borderRadius: 4 }} title={`Them: ${them}%`} />
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--color-muted)', marginTop: 4 }}>
        <span>You {you}%</span><span>Them {them}%</span>
      </div>
    </div>
  );
}

function SentimentBar({ dist }) {
  if (!dist) return null;
  const total = dist.anxious + dist.secure + dist.avoidant;
  if (!total) return null;
  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', marginBottom: 4 }}>Sentiment</div>
      <div style={{ display: 'flex', height: 8, borderRadius: 4, overflow: 'hidden', gap: 2 }}>
        <div style={{ flex: dist.anxious, background: 'var(--color-anxious)' }} />
        <div style={{ flex: dist.secure,  background: 'var(--color-secure)'  }} />
        <div style={{ flex: dist.avoidant, background: 'var(--color-avoidant)' }} />
      </div>
    </div>
  );
}
