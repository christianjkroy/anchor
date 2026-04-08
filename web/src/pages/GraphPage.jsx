import React, { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import { api } from '../api';

export default function GraphPage() {
  const svgRef = useRef(null);
  const [graph, setGraph] = useState(null);
  const [selected, setSelected] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api.persons.list().then(persons => {
      // Build a star graph: user node in center, person nodes around it
      const nodes = [
        { id: 'self', name: 'You', isSelf: true, interactionCount: 0, avgEnergy: 0 },
        ...persons.map(p => ({
          id: p.id,
          name: p.name,
          isSelf: false,
          interactionCount: p.total_interactions ?? 0,
          avgEnergy: 0,
          initiationRatio: p.initiation_ratio,
        })),
      ];
      const links = persons.map(p => ({
        source: 'self',
        target: p.id,
        weight: Math.min(1, Math.max(0.1, (p.total_interactions ?? 1) / 20)),
      }));
      setGraph({ nodes, links });
    }).catch(err => setError(err.message));
  }, []);

  useEffect(() => {
    if (!graph || !svgRef.current) return;
    renderGraph(svgRef.current, graph, setSelected);
    return () => d3.select(svgRef.current).selectAll('*').remove();
  }, [graph]);

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Relationship Graph</h1>
      </div>

      {error && <p style={{ color: 'var(--color-anxious)' }}>{error}</p>}

      <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative' }}>
        <svg ref={svgRef} style={{ width: '100%', height: 520, display: 'block' }} />

        {selected && (
          <div style={{
            position: 'absolute', top: 16, right: 16, background: 'white',
            border: '1px solid var(--color-border)', borderRadius: 10,
            padding: '12px 16px', minWidth: 200, boxShadow: 'var(--shadow)',
          }}>
            <strong>{selected.name}</strong>
            <p style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginTop: 4 }}>
              {selected.interactionCount} interaction{selected.interactionCount !== 1 ? 's' : ''}
            </p>
            {selected.initiationRatio !== undefined && (
              <p style={{ fontSize: '0.8rem', color: 'var(--color-muted)' }}>
                You initiate {Math.round((selected.initiationRatio ?? 0.5) * 100)}%
              </p>
            )}
            <button onClick={() => setSelected(null)} style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginTop: 8 }}>
              Dismiss
            </button>
          </div>
        )}
      </div>

      <p style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginTop: 12 }}>
        Node size reflects interaction count. Edge weight reflects frequency.
      </p>
    </div>
  );
}

function nodeColor(d) {
  if (d.isSelf) return '#007aff';
  const ratio = d.initiationRatio ?? 0.5;
  if (ratio > 0.7) return '#ff9500'; // you chase — orange
  if (ratio < 0.3) return '#34c759'; // they reach out — green
  return '#5856d6'; // balanced — purple
}

function renderGraph(svgEl, { nodes, links }, onSelect) {
  const width = svgEl.clientWidth || 800;
  const height = 520;
  const svg = d3.select(svgEl)
    .attr('viewBox', `0 0 ${width} ${height}`)
    .call(d3.zoom().scaleExtent([0.3, 3]).on('zoom', e => g.attr('transform', e.transform)));

  const g = svg.append('g');

  const simulation = d3.forceSimulation(nodes)
    .force('link', d3.forceLink(links).id(d => d.id).distance(d => 140 - d.weight * 60))
    .force('charge', d3.forceManyBody().strength(-300))
    .force('center', d3.forceCenter(width / 2, height / 2))
    .force('collision', d3.forceCollide(40));

  const link = g.append('g')
    .selectAll('line')
    .data(links)
    .join('line')
    .attr('stroke', '#d1d5db')
    .attr('stroke-width', d => 1 + d.weight * 3)
    .attr('stroke-opacity', 0.6);

  const node = g.append('g')
    .selectAll('g')
    .data(nodes)
    .join('g')
    .style('cursor', 'pointer')
    .on('click', (_, d) => !d.isSelf && onSelect(d))
    .call(d3.drag()
      .on('start', (e, d) => { if (!e.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
      .on('drag', (e, d) => { d.fx = e.x; d.fy = e.y; })
      .on('end', (e, d) => { if (!e.active) simulation.alphaTarget(0); d.fx = null; d.fy = null; })
    );

  node.append('circle')
    .attr('r', d => d.isSelf ? 22 : 14 + Math.min(d.interactionCount, 10))
    .attr('fill', nodeColor)
    .attr('stroke', '#fff')
    .attr('stroke-width', 2);

  node.append('text')
    .text(d => d.name)
    .attr('text-anchor', 'middle')
    .attr('dy', d => (d.isSelf ? 22 : 14 + Math.min(d.interactionCount, 10)) + 16)
    .attr('font-size', 12)
    .attr('fill', '#374151');

  simulation.on('tick', () => {
    link
      .attr('x1', d => d.source.x).attr('y1', d => d.source.y)
      .attr('x2', d => d.target.x).attr('y2', d => d.target.y);
    node.attr('transform', d => `translate(${d.x},${d.y})`);
  });
}
