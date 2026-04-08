#!/usr/bin/env python3
"""Convert a fine-tuned HF transformer to Core ML format.

Usage:
  python training/convert_coreml.py --model-dir artifacts/distilbert-anchor --output AnchorSentiment.mlpackage
"""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert HF DistilBERT classifier to Core ML")
    parser.add_argument("--model-dir", required=True, help="Directory containing HF model artifacts")
    parser.add_argument(
        "--torchscript-model",
        required=True,
        help="Path to a traced TorchScript model (.pt) prepared from the fine-tuned classifier",
    )
    parser.add_argument("--output", required=True, help="Output Core ML package path")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model_dir = Path(args.model_dir)
    torchscript_path = Path(args.torchscript_model)
    output_path = Path(args.output)

    if not model_dir.exists():
        raise FileNotFoundError(f"Model directory does not exist: {model_dir}")
    if not torchscript_path.exists():
        raise FileNotFoundError(f"TorchScript model does not exist: {torchscript_path}")

    # Lazy import keeps this script importable even without coremltools installed.
    import coremltools as ct
    import torch

    traced_model = torch.jit.load(str(torchscript_path))
    traced_model.eval()

    mlmodel = ct.convert(
        traced_model,
        source="pytorch",
        convert_to="mlprogram",
    )
    mlmodel.save(str(output_path))
    print(f"Core ML artifact written to: {output_path}")


if __name__ == "__main__":
    main()
