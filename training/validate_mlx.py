#!/usr/bin/env python3
"""Validate sentiment model behavior on Apple Silicon with MLX.

This script runs a lightweight validation pass after HF training and before Core ML conversion.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Anchor sentiment model via MLX")
    parser.add_argument("--model-dir", required=True, help="Path to HF model directory")
    parser.add_argument("--samples", required=True, help="JSONL with fields: text,label")
    parser.add_argument("--output", default="mlx_validation_report.json")
    return parser.parse_args()


def load_samples(path: Path):
    rows = []
    for line in path.read_text().splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def main() -> None:
    args = parse_args()
    model_dir = Path(args.model_dir)
    sample_path = Path(args.samples)

    if not model_dir.exists():
        raise FileNotFoundError(f"Model directory not found: {model_dir}")
    if not sample_path.exists():
        raise FileNotFoundError(f"Samples file not found: {sample_path}")

    # Placeholder scoring path: wire this to your MLX runtime model implementation.
    # Keeping this script explicit makes the handoff from HF -> MLX -> Core ML reproducible.
    samples = load_samples(sample_path)
    report = {
      "model_dir": str(model_dir),
      "sample_count": len(samples),
      "status": "ready_for_mlx_runtime_integration",
      "notes": [
        "Attach MLX tokenizer/model loading here.",
        "Compute per-label precision/recall before conversion.",
      ],
    }

    Path(args.output).write_text(json.dumps(report, indent=2))
    print(f"Wrote validation report: {args.output}")


if __name__ == "__main__":
    main()
