import React, { useEffect, useState } from 'react';

export default function DigestPage({ digests = [], onGenerateDigest, loading = false }) {
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    setSelected((current) => {
      if (current && digests.some((digest) => digest.id === current.id)) {
        return current;
      }
      return digests[0] ?? null;
    });
  }, [digests]);

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr', gap: 24 }}>
      <div>
        <div className="page-header" style={{ marginBottom: 16 }}>
          <h1 className="page-title">Digests</h1>
          <button className="btn btn--primary" onClick={onGenerateDigest} disabled={loading}>
            {loading ? 'Generating…' : 'Generate latest'}
          </button>
        </div>
        <div className="card" style={{ padding: 0 }}>
          {digests.length === 0 && <p className="empty-state">No digests yet. They generate on Sundays.</p>}
          {digests.map(d => (
            <div key={d.id}
              onClick={() => setSelected(d)}
              style={{
                padding: '12px 16px', cursor: 'pointer',
                borderBottom: '1px solid var(--color-border)',
                background: selected?.id === d.id ? 'var(--color-bg)' : 'transparent',
              }}
            >
              <div style={{ fontWeight: 600, fontSize: '0.875rem' }}>
                Week of {new Date(d.week_start_date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
              </div>
              <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>
                {new Date(d.generated_at).toLocaleDateString()}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div>
        {!selected && <div className="empty-state" style={{ paddingTop: 80 }}>Select a digest.</div>}
        {selected && <DigestDetail digest={selected} />}
      </div>
    </div>
  );
}

function DigestDetail({ digest }) {
  const patterns = Array.isArray(digest.patterns)
    ? digest.patterns
    : digest.patterns?.topInsights?.map((content) => ({ summary: content, detail: '' })) ?? [];
  const changes = Array.isArray(digest.initiation_changes)
    ? digest.initiation_changes
    : digest.initiation_changes
      ? [digest.initiation_changes]
      : [];

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">
          Week of {new Date(digest.week_start_date).toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' })}
        </h2>
      </div>

      {digest.narrative && (
        <div className="card" style={{ marginBottom: 16 }}>
          <h3 style={{ fontWeight: 600, marginBottom: 10, fontSize: '0.9rem' }}>Summary</h3>
          <p style={{ lineHeight: 1.7, color: 'var(--color-text)' }}>{digest.narrative}</p>
        </div>
      )}

      {patterns.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <h3 style={{ fontWeight: 600, marginBottom: 12, fontSize: '0.9rem' }}>Patterns</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {patterns.map((p, i) => (
              <div key={i} style={{ borderLeft: `3px solid ${severityColor(p.severity)}`, paddingLeft: 12 }}>
                <div style={{ fontWeight: 600, fontSize: '0.875rem' }}>{p.summary}</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginTop: 2 }}>{p.detail}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {changes.length > 0 && (
        <div className="card">
          <h3 style={{ fontWeight: 600, marginBottom: 12, fontSize: '0.9rem' }}>Initiation Changes</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {changes.map((c, i) => {
              return (
                <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontWeight: 500, fontSize: '0.875rem' }}>{c.personName ?? 'Weekly initiation ratio'}</span>
                  <span style={{ fontSize: '0.8rem', color: 'var(--color-secure)' }}>
                    {Math.round((c.ratio ?? c.currentRatio ?? 0) * 100)}%
                    {typeof c.total === 'number' ? ` across ${c.total} interaction${c.total === 1 ? '' : 's'}` : ''}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

function severityColor(severity) {
  if (severity === 'high')   return 'var(--color-anxious)';
  if (severity === 'medium') return '#f59e0b';
  return 'var(--color-secure)';
}
