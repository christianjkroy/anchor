export default function StatCard({ label, value, subtext }) {
  return (
    <article className="stat-card">
      <p className="stat-label">{label}</p>
      <h3 className="stat-value">{value}</h3>
      {subtext ? <p className="stat-subtext">{subtext}</p> : null}
    </article>
  );
}
