export default function NetworkGraph({ network }) {
  if (!network?.nodes?.length) {
    return <section className="panel"><h3>Relationship Graph</h3><p>No graph data yet.</p></section>;
  }

  const nodes = network.nodes.filter((n) => n.id !== 'self');
  const radius = 190;
  const center = 230;

  const positioned = nodes.map((node, index) => {
    const angle = (Math.PI * 2 * index) / Math.max(nodes.length, 1);
    return {
      ...node,
      x: center + Math.cos(angle) * radius,
      y: center + Math.sin(angle) * radius,
    };
  });

  return (
    <section className="panel">
      <h3>Relationship Graph</h3>
      <svg viewBox="0 0 460 460" className="graph-svg" role="img" aria-label="Relationship graph">
        <circle cx={center} cy={center} r="24" className="self-node" />
        <text x={center} y={center + 4} textAnchor="middle" className="self-label">You</text>

        {positioned.map((node) => (
          <line key={`edge-${node.id}`} x1={center} y1={center} x2={node.x} y2={node.y} className="graph-edge" />
        ))}

        {positioned.map((node) => (
          <g key={node.id}>
            <circle cx={node.x} cy={node.y} r={Math.max(12, Math.min(22, 10 + node.interactionCount))} className={node.avgEnergy >= 0 ? 'node-positive' : 'node-negative'} />
            <text x={node.x} y={node.y + 28} textAnchor="middle" className="node-label">{node.name}</text>
          </g>
        ))}
      </svg>
    </section>
  );
}
