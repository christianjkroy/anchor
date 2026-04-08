#!/usr/bin/env python3
"""Export Anchor interaction data from Postgres as JSONL for DistilBERT fine-tuning.

Usage:
  python training/export_data.py --db-url postgresql://user:pass@localhost/anchor \
      --output-dir data --valid-split 0.15

Output files:
  data/train.jsonl  — {"text": "...", "label": "anxious|secure|avoidant|..."}
  data/valid.jsonl

Label derivation mirrors ClaudeService.swift rule-based logic so that the
trained model converges toward (and can eventually replace) the rule-based system.
"""

from __future__ import annotations

import argparse
import json
import os
import random
from typing import Optional

import psycopg2
import psycopg2.extras

LABELS = ["anxious", "secure", "avoidant", "positive", "negative", "neutral"]

# ------------------------------------------------------------------
# Rule-based label derivation (mirrors ClaudeService.swift)
# ------------------------------------------------------------------

ANXIOUS_BEFORE  = {"anxious"}
AVOIDANT_BEFORE = {"avoidant"}
SECURE_DURING   = {"secure", "connected", "authentic"}
ANXIOUS_DURING  = {"anxious", "disconnected", "performative"}
POSITIVE_AFTER  = {"calm", "energized", "satisfied"}
NEGATIVE_AFTER  = {"drained", "regretful", "anxious"}


def derive_label(
    feeling_before: Optional[str],
    feeling_during: Optional[str],
    feeling_after: Optional[str],
    sentiment: Optional[str],
) -> str:
    """Rule-based label; falls back to DB sentiment if rules are ambiguous."""
    before = (feeling_before or "").lower()
    during = (feeling_during or "").lower()
    after  = (feeling_after or "").lower()

    score = 0

    if before in ANXIOUS_BEFORE:
        score -= 1
    if before in AVOIDANT_BEFORE:
        score -= 2

    if during in SECURE_DURING:
        score += 2
    if during in ANXIOUS_DURING:
        score -= 2

    if after in POSITIVE_AFTER:
        score += 2
    if after in NEGATIVE_AFTER:
        score -= 2

    if score >= 3:
        return "secure"
    if score <= -3:
        return "anxious" if before in ANXIOUS_BEFORE else "avoidant"
    if score >= 1:
        return "positive"
    if score <= -1:
        return "negative"

    # Ambiguous — use DB sentiment if present
    if sentiment in LABELS:
        return sentiment

    return "neutral"


def build_text(row: dict) -> str:
    """Build natural-language sentence from structured fields."""
    parts = []
    if row.get("feeling_before"):
        parts.append(f"Before: {row['feeling_before'].lower()}")
    if row.get("feeling_during"):
        parts.append(f"During: {row['feeling_during'].lower()}")
    if row.get("feeling_after"):
        parts.append(f"After: {row['feeling_after'].lower()}")
    if row.get("type"):
        parts.append(f"Type: {row['type']}")
    if row.get("initiated_by"):
        parts.append(f"Initiated by: {row['initiated_by']}")
    if row.get("note") and row["note"].strip():
        note = row["note"].strip()[:300]  # truncate long notes
        parts.append(f"Note: {note}")
    return ". ".join(parts) if parts else "No details recorded"


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db-url",      required=True,  help="PostgreSQL connection URL")
    parser.add_argument("--output-dir",  default="data", help="Output directory for JSONL files")
    parser.add_argument("--valid-split", type=float, default=0.15, help="Fraction for validation set")
    parser.add_argument("--seed",        type=int,   default=42)
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    random.seed(args.seed)

    conn = psycopg2.connect(args.db_url)
    cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    cur.execute("""
        SELECT feeling_before, feeling_during, feeling_after, type, initiated_by, note, sentiment
        FROM   interactions
        WHERE  feeling_after IS NOT NULL
    """)
    rows = cur.fetchall()
    conn.close()

    print(f"Fetched {len(rows)} interactions from DB.")

    examples = []
    for row in rows:
        text  = build_text(row)
        label = derive_label(
            row.get("feeling_before"),
            row.get("feeling_during"),
            row.get("feeling_after"),
            row.get("sentiment"),
        )
        examples.append({"text": text, "label": label})

    random.shuffle(examples)

    split_idx  = int(len(examples) * (1 - args.valid_split))
    train_data = examples[:split_idx]
    valid_data = examples[split_idx:]

    def write_jsonl(path: str, data: list[dict]) -> None:
        with open(path, "w", encoding="utf-8") as f:
            for item in data:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

    train_path = os.path.join(args.output_dir, "train.jsonl")
    valid_path = os.path.join(args.output_dir, "valid.jsonl")
    write_jsonl(train_path, train_data)
    write_jsonl(valid_path, valid_data)

    print(f"Wrote {len(train_data)} train / {len(valid_data)} valid examples.")
    print(f"  {train_path}")
    print(f"  {valid_path}")

    # Label distribution
    from collections import Counter
    dist = Counter(e["label"] for e in examples)
    print("\nLabel distribution:")
    for label in LABELS:
        print(f"  {label:12s}: {dist.get(label, 0)}")


if __name__ == "__main__":
    main()
