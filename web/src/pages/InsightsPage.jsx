export default function InsightsPage({ insights, digests, onGenerateDigest, loading }) {
  return (
    <div className="stack-lg">
      <section className="panel">
        <div className="row-between">
          <h3>Weekly Digests</h3>
          <button onClick={onGenerateDigest} disabled={loading}>{loading ? 'Generating...' : 'Generate This Week'}</button>
        </div>
        <div className="list-grid">
          {digests.map((digest) => (
            <article key={digest.id} className="list-card">
              <p className="list-title">Week of {digest.week_start_date}</p>
              <p>{digest.narrative}</p>
            </article>
          ))}
          {!digests.length && <p>No weekly digests yet.</p>}
        </div>
      </section>

      <section className="panel">
        <h3>Pattern Insights</h3>
        <div className="list-grid">
          {insights.map((insight) => (
            <article key={insight.id} className="list-card">
              <p className="list-title">{insight.person_name ?? 'General insight'}</p>
              <p>{insight.content}</p>
              <p className="list-meta">{insight.severity ?? 'n/a'} · {insight.pattern_type ?? 'general'}</p>
            </article>
          ))}
          {!insights.length && <p>No insights approved yet.</p>}
        </div>
      </section>
    </div>
  );
}
