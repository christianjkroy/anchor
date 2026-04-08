import 'dotenv/config';
import { pool } from './pool.js';

const migrations = [
  `CREATE EXTENSION IF NOT EXISTS "pgcrypto"`,
  `CREATE EXTENSION IF NOT EXISTS "vector"`,

  `CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  )`,

  `CREATE TABLE IF NOT EXISTS persons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    photo_url TEXT,
    relationship_type TEXT DEFAULT 'friend',
    initiation_ratio FLOAT,
    consistency_score FLOAT,
    perception_score FLOAT,
    reality_score FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  )`,

  `CREATE INDEX IF NOT EXISTS persons_user_idx ON persons(user_id)`,
  `CREATE INDEX IF NOT EXISTS persons_user_name_idx ON persons(user_id, name)`,
  `CREATE INDEX IF NOT EXISTS persons_created_idx ON persons(created_at DESC)`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'persons_perception_score_range_chk'
      ) THEN
        ALTER TABLE persons
          ADD CONSTRAINT persons_perception_score_range_chk
          CHECK (perception_score IS NULL OR (perception_score >= 1 AND perception_score <= 5));
      END IF;
    END
  $$`,

  `CREATE TABLE IF NOT EXISTS interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    initiated_by TEXT NOT NULL,
    feeling_before TEXT,
    feeling_during TEXT,
    feeling_after TEXT,
    location_context TEXT,
    duration_minutes INT,
    energy_rating FLOAT,
    vibe_rating FLOAT,
    note TEXT DEFAULT '',
    sentiment TEXT,
    sentiment_confidence FLOAT,
    embedding VECTOR(384),
    created_at TIMESTAMPTZ DEFAULT NOW()
  )`,

  `CREATE INDEX IF NOT EXISTS interactions_person_idx ON interactions(person_id)`,
  `CREATE INDEX IF NOT EXISTS interactions_user_idx ON interactions(user_id)`,
  `CREATE INDEX IF NOT EXISTS interactions_user_person_created_idx ON interactions(user_id, person_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS interactions_created_idx ON interactions(created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS interactions_embedding_cosine_idx
    ON interactions USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interactions_type_valid_chk'
      ) THEN
        ALTER TABLE interactions
          ADD CONSTRAINT interactions_type_valid_chk
          CHECK (type IN ('text', 'hangout', 'call', 'group'));
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interactions_initiated_by_valid_chk'
      ) THEN
        ALTER TABLE interactions
          ADD CONSTRAINT interactions_initiated_by_valid_chk
          CHECK (initiated_by IN ('user', 'them', 'unclear'));
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interactions_energy_rating_range_chk'
      ) THEN
        ALTER TABLE interactions
          ADD CONSTRAINT interactions_energy_rating_range_chk
          CHECK (energy_rating IS NULL OR (energy_rating >= -1 AND energy_rating <= 1));
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interactions_vibe_rating_range_chk'
      ) THEN
        ALTER TABLE interactions
          ADD CONSTRAINT interactions_vibe_rating_range_chk
          CHECK (vibe_rating IS NULL OR (vibe_rating >= -1 AND vibe_rating <= 1));
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interactions_sentiment_confidence_range_chk'
      ) THEN
        ALTER TABLE interactions
          ADD CONSTRAINT interactions_sentiment_confidence_range_chk
          CHECK (sentiment_confidence IS NULL OR (sentiment_confidence >= 0 AND sentiment_confidence <= 1));
      END IF;
    END
  $$`,

  `CREATE TABLE IF NOT EXISTS insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id UUID REFERENCES persons(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    pattern_type TEXT,
    severity TEXT,
    supporting_interaction_ids UUID[],
    generated_at TIMESTAMPTZ DEFAULT NOW()
  )`,

  `CREATE INDEX IF NOT EXISTS insights_user_idx ON insights(user_id)`,
  `CREATE INDEX IF NOT EXISTS insights_generated_idx ON insights(generated_at DESC)`,

  `CREATE TABLE IF NOT EXISTS perception_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    perceived_score FLOAT NOT NULL,
    reality_score FLOAT,
    divergence FLOAT,
    direction TEXT,
    flagged BOOLEAN DEFAULT FALSE,
    checked_at TIMESTAMPTZ DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS perception_checks_user_person_checked_idx
    ON perception_checks(user_id, person_id, checked_at DESC)`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'perception_checks_perceived_score_range_chk'
      ) THEN
        ALTER TABLE perception_checks
          ADD CONSTRAINT perception_checks_perceived_score_range_chk
          CHECK (perceived_score >= 1 AND perceived_score <= 5);
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'perception_checks_reality_score_range_chk'
      ) THEN
        ALTER TABLE perception_checks
          ADD CONSTRAINT perception_checks_reality_score_range_chk
          CHECK (reality_score IS NULL OR (reality_score >= 1 AND reality_score <= 5));
      END IF;
    END
  $$`,
  `DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'perception_checks_divergence_nonnegative_chk'
      ) THEN
        ALTER TABLE perception_checks
          ADD CONSTRAINT perception_checks_divergence_nonnegative_chk
          CHECK (divergence IS NULL OR divergence >= 0);
      END IF;
    END
  $$`,

  `CREATE TABLE IF NOT EXISTS weekly_digests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    narrative TEXT,
    initiation_changes JSONB,
    patterns JSONB,
    generated_at TIMESTAMPTZ DEFAULT NOW()
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS weekly_digests_user_week_uidx
    ON weekly_digests(user_id, week_start_date)`,
];

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const sql of migrations) {
      await client.query(sql);
      console.log('✓', sql.slice(0, 60).replace(/\s+/g, ' ').trim());
    }
    await client.query('COMMIT');
    console.log('\nMigrations complete.');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch(err => { console.error(err); process.exit(1); });
