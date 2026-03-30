"""
evaluator.py — Metrics computation and confusion-matrix visualisation.

evaluate  : compute + print all metrics, then show confusion matrix
plot_cm   : standalone seaborn heatmap helper
"""

from __future__ import annotations

from typing import List

import numpy as np

# Use a non-interactive backend that works in VS Code terminals and notebooks
import matplotlib
matplotlib.use("Agg")        # renders to file / inline; switch to TkAgg if a window is wanted
import matplotlib.pyplot as plt

import seaborn as sns
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)


def evaluate(
    y_true: list | np.ndarray,
    y_pred: list | np.ndarray,
    label_names: List[str],
    title: str = "Model Evaluation",
    save_plot: str | None = None,
) -> dict:
    """
    Print a full classification report + summary table, display confusion matrix.

    Parameters
    ----------
    y_true      : ground-truth integer labels
    y_pred      : predicted integer labels
    label_names : class names aligned with label indices
    title       : heading used in printout and plot title
    save_plot   : if given, save the confusion-matrix figure to this path

    Returns
    -------
    dict with keys: accuracy, precision, recall, f1, confusion_matrix
    """
    y_true = np.asarray(y_true)
    y_pred = np.asarray(y_pred)

    all_indices = list(range(len(label_names)))

    acc  = accuracy_score(y_true, y_pred)
    prec = precision_score(y_true, y_pred, average="weighted", labels=all_indices, zero_division=0)
    rec  = recall_score(y_true, y_pred, average="weighted", labels=all_indices, zero_division=0)
    f1   = f1_score(y_true, y_pred, average="weighted", labels=all_indices, zero_division=0)
    cm   = confusion_matrix(y_true, y_pred, labels=all_indices)

    _print_banner(title)
    print(classification_report(y_true, y_pred, labels=all_indices, target_names=label_names, zero_division=0))
    _print_summary(acc, prec, rec, f1)
    plot_cm(cm, label_names, title=f"Confusion Matrix — {title}", save_path=save_plot)

    return {
        "accuracy":         acc,
        "precision":        prec,
        "recall":           rec,
        "f1":               f1,
        "confusion_matrix": cm,
    }


def plot_cm(
    cm: np.ndarray,
    labels: List[str],
    title: str = "Confusion Matrix",
    save_path: str | None = None,
) -> None:
    """Render a seaborn confusion-matrix heatmap and show / save it."""
    n = len(labels)
    fig, ax = plt.subplots(figsize=(max(5, n + 1), max(4, n)))

    sns.heatmap(
        cm,
        annot=True,
        fmt="d",
        cmap="Blues",
        xticklabels=labels,
        yticklabels=labels,
        linewidths=0.5,
        ax=ax,
    )
    ax.set_xlabel("Predicted", fontsize=12)
    ax.set_ylabel("True", fontsize=12)
    ax.set_title(title, fontsize=13, fontweight="bold")
    plt.tight_layout()

    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
        print(f"[evaluator] Confusion matrix saved → {save_path}")
    else:
        # Show interactively when a display is available; otherwise save to PNG
        backend = matplotlib.get_backend().lower()
        if "agg" in backend:
            fallback = title.replace(" ", "_").replace("—", "").replace("/", "-").strip() + ".png"
            fig.savefig(fallback, dpi=150, bbox_inches="tight")
            print(f"[evaluator] Confusion matrix saved → {fallback}")
        else:
            try:
                plt.show()
            except Exception:
                fallback = title.replace(" ", "_").replace("—", "").replace("/", "-").strip() + ".png"
                fig.savefig(fallback, dpi=150, bbox_inches="tight")
                print(f"[evaluator] No display available — saved → {fallback}")

    plt.close(fig)


# ── Internal formatting helpers ───────────────────────────────────────────────

def _print_banner(title: str) -> None:
    line = "=" * 62
    print(f"\n{line}")
    print(f"  {title}")
    print(line)


def _print_summary(acc: float, prec: float, rec: float, f1: float) -> None:
    print(f"\n  {'Metric':<18} {'Value':>7}   Bar")
    print("  " + "-" * 44)
    for name, val in [
        ("Accuracy",  acc),
        ("Precision", prec),
        ("Recall",    rec),
        ("F1-Score",  f1),
    ]:
        bar = _mini_bar(val)
        print(f"  {name:<18} {val:>7.4f}   {bar}")
    print()


def _mini_bar(value: float, width: int = 20) -> str:
    filled = round(value * width)
    return "[" + "█" * filled + "░" * (width - filled) + f"] {value * 100:.1f}%"
