import { useState } from 'react';

const TYPES = ['text', 'hangout', 'call', 'group'];
const INITIATORS = ['user', 'them', 'unclear'];

export default function InteractionComposer({ people, onSubmit, loading }) {
  const [personId, setPersonId] = useState('');
  const [type, setType] = useState('text');
  const [initiatedBy, setInitiatedBy] = useState('unclear');
  const [energyRating, setEnergyRating] = useState(0);
  const [vibeRating, setVibeRating] = useState(0);
  const [note, setNote] = useState('');

  async function submit(event) {
    event.preventDefault();
    if (!personId) return;
    await onSubmit({ personId, type, initiatedBy, energyRating: Number(energyRating), vibeRating: Number(vibeRating), note });
    setNote('');
  }

  return (
    <form className="composer" onSubmit={submit}>
      <h3>Log Interaction</h3>
      <div className="composer-grid">
        <label>
          Person
          <select value={personId} onChange={(e) => setPersonId(e.target.value)} required>
            <option value="">Select...</option>
            {people.map((person) => (
              <option key={person.id} value={person.id}>{person.name}</option>
            ))}
          </select>
        </label>
        <label>
          Type
          <select value={type} onChange={(e) => setType(e.target.value)}>
            {TYPES.map((v) => <option key={v} value={v}>{v}</option>)}
          </select>
        </label>
        <label>
          Initiated By
          <select value={initiatedBy} onChange={(e) => setInitiatedBy(e.target.value)}>
            {INITIATORS.map((v) => <option key={v} value={v}>{v}</option>)}
          </select>
        </label>
        <label>
          Energy (-1 to 1)
          <input type="number" min="-1" max="1" step="0.1" value={energyRating} onChange={(e) => setEnergyRating(e.target.value)} />
        </label>
        <label>
          Vibe (-1 to 1)
          <input type="number" min="-1" max="1" step="0.1" value={vibeRating} onChange={(e) => setVibeRating(e.target.value)} />
        </label>
      </div>
      <label>
        Note
        <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Awkward lunch with Maya, felt like I talked too much..." />
      </label>
      <button type="submit" disabled={loading}>{loading ? 'Saving...' : 'Save interaction'}</button>
    </form>
  );
}
