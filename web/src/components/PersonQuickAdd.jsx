import { useState } from 'react';

export default function PersonQuickAdd({ onCreate, loading }) {
  const [name, setName] = useState('');

  async function submit(event) {
    event.preventDefault();
    if (!name.trim()) return;
    await onCreate({ name: name.trim() });
    setName('');
  }

  return (
    <form className="panel" onSubmit={submit}>
      <h3>Add Person</h3>
      <label>
        Name
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Maya" required />
      </label>
      <button type="submit" disabled={loading}>{loading ? 'Adding...' : 'Add person'}</button>
    </form>
  );
}
