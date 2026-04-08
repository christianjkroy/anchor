import NetworkGraph from '../components/NetworkGraph.jsx';

export default function GraphPage({ network }) {
  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Relationship Graph</h1>
      </div>

      <NetworkGraph network={network} />
    </div>
  );
}
