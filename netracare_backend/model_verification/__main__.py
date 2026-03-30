"""
__main__.py — CLI entry point.

Usage
-----
# Simulate all four models (no trained weights required)
python -m model_verification --simulate

# Verify real CNN model
python -m model_verification --model cnn --model-path ./models/blink_fatigue_model.keras

# Verify RF with a CSV dataset  (last column = label)
python -m model_verification --model rf --model-path ./models/rf_eye.joblib \\
       --data ./data/features.csv

# Verify all models, save confusion-matrix plots
python -m model_verification --simulate --save-plots

Options
-------
--model        cnn | rf | xgb | svm | all   (default: all)
--model-path   override the default model file path
--data         CSV path for feature models (last column treated as label)
--simulate     use synthetic data instead of real models / datasets
--save-plots   write each confusion matrix to <model>_cm.png
"""

from __future__ import annotations

import argparse
import os
import sys


# ── Argument parser ───────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="python -m model_verification",
        description="Netracare ML model verification suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument(
        "--model",
        choices=["cnn", "rf", "xgb", "svm", "all"],
        default="all",
        metavar="MODEL",
        help="Model(s) to verify: cnn | rf | xgb | svm | all  (default: all)",
    )
    p.add_argument(
        "--model-path",
        default=None,
        metavar="PATH",
        help="Override the default model file / directory path",
    )
    p.add_argument(
        "--data",
        default=None,
        metavar="CSV",
        help="Path to a CSV for feature models; last column is treated as the label",
    )
    p.add_argument(
        "--simulate",
        action="store_true",
        help="Use fully synthetic data (no trained model or dataset required)",
    )
    p.add_argument(
        "--save-plots",
        action="store_true",
        help="Save each confusion-matrix figure to <model>_cm.png",
    )
    return p


# ── CSV loader ────────────────────────────────────────────────────────────────

def _load_feature_csv(csv_path: str):
    """Parse CSV: all columns except the last are features; last column = label."""
    import numpy as np
    import pandas as pd

    df = pd.read_csv(csv_path)
    if df.shape[1] < 2:
        sys.exit(f"[error] CSV must have at least 2 columns (features + label): {csv_path}")

    X = df.iloc[:, :-1].values.astype(np.float64)
    raw_y = df.iloc[:, -1].tolist()

    # Build a stable label → index mapping
    unique_labels = sorted(set(str(v) for v in raw_y))
    lmap = {lbl: i for i, lbl in enumerate(unique_labels)}
    y = np.array([lmap[str(v)] for v in raw_y], dtype=np.int32)
    return X, y, unique_labels


# ── Main ──────────────────────────────────────────────────────────────────────

def main(argv=None) -> None:
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")   # suppress TF CUDA noise

    args = _build_parser().parse_args(argv)

    from .runner import run_cnn_verification, run_feature_verification

    targets: list[str] = (
        ["cnn", "rf", "xgb", "svm"] if args.model == "all" else [args.model]
    )

    # Pre-load CSV feature data if provided (shared across feature models)
    feature_kwargs: dict = {}
    csv_labels: list[str] | None = None
    if args.data:
        X_csv, y_csv, csv_labels = _load_feature_csv(args.data)
        feature_kwargs = {"X": X_csv, "y": y_csv, "labels": csv_labels}
        print(f"[cli] Loaded {len(y_csv)} samples from '{args.data}'  "
              f"(labels: {csv_labels})")

    results: dict[str, dict] = {}

    for target in targets:
        print(f"\n{'─' * 62}")
        print(f"  Verifying: {target.upper()}")
        print(f"{'─' * 62}")

        save_plot = f"{target}_cm.png" if args.save_plots else None

        try:
            if target == "cnn":
                results["cnn"] = run_cnn_verification(
                    model_path=args.model_path if args.model != "all" else None,
                    simulate=args.simulate,
                    save_plot=save_plot,
                )
            else:
                mp = args.model_path if args.model != "all" else None
                results[target] = run_feature_verification(
                    model_key=target,
                    model_path=mp,
                    simulate=args.simulate,
                    save_plot=save_plot,
                    **feature_kwargs,
                )
        except Exception as exc:
            print(f"\n[ERROR] {target.upper()} verification failed: {exc}")
            if not args.simulate:
                print("  Tip: run with --simulate to verify the pipeline without trained models.")

    # ── Summary table ────────────────────────────────────────────────────
    if results:
        print("\n" + "=" * 62)
        print("  VERIFICATION SUMMARY")
        print("=" * 62)
        header = f"  {'Model':<10} {'Accuracy':>10} {'Precision':>10} {'Recall':>10} {'F1':>10}"
        print(header)
        print("  " + "-" * 46)
        for key, res in results.items():
            print(
                f"  {key.upper():<10} "
                f"{res['accuracy']:>10.4f} "
                f"{res['precision']:>10.4f} "
                f"{res['recall']:>10.4f} "
                f"{res['f1']:>10.4f}"
            )
        print()


if __name__ == "__main__":
    main()
