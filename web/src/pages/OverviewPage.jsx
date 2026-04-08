import StatCard from '../components/StatCard.jsx';
import InteractionComposer from '../components/InteractionComposer.jsx';
import NetworkGraph from '../components/NetworkGraph.jsx';
import PersonQuickAdd from '../components/PersonQuickAdd.jsx';

export default function OverviewPage({ data, onCreateInteraction, onCreatePerson, loading }) {
  const totalInteractions = data.interactions.length;
  const theyInitiated = data.interactions.filter((i) => i.initiated_by === 'them').length;
  const avgEnergy = totalInteractions
    ? data.interactions.reduce((sum, i) => sum + (i.energy_rating ?? 0), 0) / totalInteractions
    : 0;

  return (
    <div className="stack-lg">
      <section className="stats-grid">
        <StatCard label="Interactions Logged" value={String(totalInteractions)} subtext="Last 50 interactions" />
        <StatCard
          label="They Initiated"
          value={`${totalInteractions ? Math.round((theyInitiated / totalInteractions) * 100) : 0}%`}
          subtext={`${theyInitiated}/${totalInteractions || 0} interactions`}
        />
        <StatCard label="Average Energy" value={avgEnergy.toFixed(2)} subtext="-1 drained to +1 energized" />
        <StatCard label="People Tracked" value={String(data.people.length)} subtext="Active relationship profiles" />
      </section>

      <div className="layout-two">
        <div className="stack-lg">
          <PersonQuickAdd onCreate={onCreatePerson} loading={loading} />
          <InteractionComposer people={data.people} onSubmit={onCreateInteraction} loading={loading} />
        </div>
        <NetworkGraph network={data.network} />
      </div>

      <section className="panel">
        <h3>Recent Interactions</h3>
        <div className="list-grid">
          {data.interactions.map((interaction) => (
            <article key={interaction.id} className="list-card">
              <p className="list-title">{interaction.person_name}</p>
              <p className="list-meta">{interaction.type} · initiated by {interaction.initiated_by}</p>
              <p>{interaction.note || 'No note provided.'}</p>
              <p className="list-meta">Energy {interaction.energy_rating ?? 0} · Vibe {interaction.vibe_rating ?? 0}</p>
            </article>
          ))}
          {!data.interactions.length && <p>No interactions yet.</p>}
        </div>
      </section>
    </div>
  );
}
