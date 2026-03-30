"""
Plotting utilities for blink fatigue model training results.
"""

import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec


def plot_train_test_time(history: dict, save_path: str = None) -> None:
    """
    Plot training and validation accuracy/loss over epochs from a training history dict.

    Args:
        history: dict with keys 'accuracy', 'val_accuracy', 'loss', 'val_loss'
                 (as returned by BlinkFatigueModel.train()['history'])
        save_path: optional file path to save the figure (e.g. 'results/training_curves.png')
    """
    acc = history['accuracy']
    val_acc = history['val_accuracy']
    loss = history['loss']
    val_loss = history['val_loss']

    epochs = range(1, len(acc) + 1)

    fig = plt.figure(figsize=(14, 5))
    gs = gridspec.GridSpec(1, 2, figure=fig)

    # ── Accuracy ──────────────────────────────────────────────────────────
    ax1 = fig.add_subplot(gs[0, 0])
    ax1.plot(epochs, acc, 'b-o', markersize=3, label='Train Accuracy')
    ax1.plot(epochs, val_acc, 'r-o', markersize=3, label='Test / Val Accuracy')
    ax1.set_title('Train vs Test Accuracy over Epochs')
    ax1.set_xlabel('Epoch')
    ax1.set_ylabel('Accuracy')
    ax1.legend()
    ax1.grid(True, linestyle='--', alpha=0.5)

    # ── Loss ──────────────────────────────────────────────────────────────
    ax2 = fig.add_subplot(gs[0, 1])
    ax2.plot(epochs, loss, 'b-o', markersize=3, label='Train Loss')
    ax2.plot(epochs, val_loss, 'r-o', markersize=3, label='Test / Val Loss')
    ax2.set_title('Train vs Test Loss over Epochs')
    ax2.set_xlabel('Epoch')
    ax2.set_ylabel('Loss')
    ax2.legend()
    ax2.grid(True, linestyle='--', alpha=0.5)

    plt.tight_layout()

    import os
    if save_path is None:
        save_path = os.path.join(os.path.dirname(__file__), 'assets', 'training_curves.png')

    os.makedirs(os.path.dirname(save_path) if os.path.dirname(save_path) else '.', exist_ok=True)
    plt.savefig(save_path, dpi=150)
    print(f"Plot saved to {save_path}")

    plt.show()
