#!/usr/bin/env python3
"""Fine-tune DistilBERT for interaction sentiment classification.

Usage:
  python training/finetune.py \
    --train-file data/train.jsonl \
    --valid-file data/valid.jsonl \
    --output-dir artifacts/distilbert-anchor
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Dict

from datasets import load_dataset
from transformers import (
    AutoModelForSequenceClassification,
    AutoTokenizer,
    DataCollatorWithPadding,
    Trainer,
    TrainingArguments,
)

LABELS = ["anxious", "secure", "avoidant", "positive", "negative", "neutral"]
LABEL_TO_ID: Dict[str, int] = {name: idx for idx, name in enumerate(LABELS)}


@dataclass
class Config:
    train_file: str
    valid_file: str
    output_dir: str
    model_name: str
    lr: float
    epochs: int
    batch_size: int
    max_length: int


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="Fine-tune DistilBERT for Anchor sentiment")
    parser.add_argument("--train-file", required=True)
    parser.add_argument("--valid-file", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--model-name", default="distilbert-base-uncased")
    parser.add_argument("--lr", type=float, default=2e-5)
    parser.add_argument("--epochs", type=int, default=4)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--max-length", type=int, default=256)
    args = parser.parse_args()
    return Config(**vars(args))


def main() -> None:
    cfg = parse_args()

    dataset = load_dataset(
        "json",
        data_files={"train": cfg.train_file, "validation": cfg.valid_file},
    )

    tokenizer = AutoTokenizer.from_pretrained(cfg.model_name)

    def preprocess(batch):
        encoded = tokenizer(
            batch["text"],
            truncation=True,
            padding=False,
            max_length=cfg.max_length,
        )
        encoded["label"] = [LABEL_TO_ID[label] for label in batch["label"]]
        return encoded

    tokenized = dataset.map(preprocess, batched=True, remove_columns=dataset["train"].column_names)

    model = AutoModelForSequenceClassification.from_pretrained(
        cfg.model_name,
        num_labels=len(LABELS),
        id2label={idx: name for name, idx in LABEL_TO_ID.items()},
        label2id=LABEL_TO_ID,
    )

    training_args = TrainingArguments(
        output_dir=cfg.output_dir,
        learning_rate=cfg.lr,
        per_device_train_batch_size=cfg.batch_size,
        per_device_eval_batch_size=cfg.batch_size,
        num_train_epochs=cfg.epochs,
        weight_decay=0.01,
        logging_steps=20,
        evaluation_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        report_to="none",
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized["train"],
        eval_dataset=tokenized["validation"],
        tokenizer=tokenizer,
        data_collator=DataCollatorWithPadding(tokenizer=tokenizer),
    )

    trainer.train()
    metrics = trainer.evaluate()
    trainer.save_model(cfg.output_dir)
    tokenizer.save_pretrained(cfg.output_dir)

    print("\nTraining complete")
    for key, value in metrics.items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
