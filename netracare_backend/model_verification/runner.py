"""
runner.py — Verification orchestrators.

Each function handles one complete pipeline:
  load model  →  prepare data  →  predict  →  evaluate

run_cnn_verification      : CNN (BlinkFatigueModel)
run_feature_verification  : RF / XGB / SVM feature models
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

import numpy as np

from .config import (
    CNN_MODEL_PATH,
    CNN_LABELS,
    FEATURE_MODEL_PATHS,
    FEATURE_LABELS,
    SIM_IMAGE_COUNT,
    SIM_N_SAMPLES,
)
from .evaluator import evaluate
from .loaders import load_tf_cnn, load_joblib_model
from .predictors import batch_predict_images, batch_predict_features
from .simulator import simulate_cnn_data, simulate_feature_data, build_dummy_feature_model

# Train / test split ratio used when a dummy feature model is built on simulated data
_TRAIN_RATIO = 0.70


def run_cnn_verification(
    model_path: Optional[str | Path] = None,
    images: Optional[list] = None,
    true_labels: Optional[List[int]] = None,
    simulate: bool = False,
    save_plot: Optional[str] = None,
) -> dict:
    """
    Verify the CNN (BlinkFatigueModel) end-to-end.

    Parameters
    ----------
    model_path  : path to .keras / .h5 / SavedModel dir; defaults to config.CNN_MODEL_PATH
    images      : list of images (file paths, bytes, or ndarrays)
    true_labels : integer labels aligned with *images*
    simulate    : if True, always use synthetic data and a dummy network
    save_plot   : optional file path to save the confusion-matrix PNG

    Returns
    -------
    dict — keys: accuracy, precision, recall, f1, confusion_matrix
    """
    path = Path(model_path) if model_path else CNN_MODEL_PATH
    use_simulation = simulate or not path.exists()

    # ── Model ────────────────────────────────────────────────────────────
    if use_simulation:
        if not simulate:
            print(f"[runner] CNN model not found at '{path}' — falling back to simulation.")
        model = _build_dummy_cnn()
    else:
        model = load_tf_cnn(path)

    # ── Data ─────────────────────────────────────────────────────────────
    if use_simulation or images is None:
        images, true_labels = simulate_cnn_data(n_images=SIM_IMAGE_COUNT)
        print(f"[runner] Using {len(images)} simulated images "
              f"({sum(1 for l in true_labels if l == 0)} drowsy, "
              f"{sum(1 for l in true_labels if l == 1)} notdrowsy).")
    elif true_labels is None:
        raise ValueError("'true_labels' must be supplied alongside 'images'.")

    # ── Predict ───────────────────────────────────────────────────────────
    pred_labels, _ = batch_predict_images(model, images, CNN_LABELS)
    y_pred = [CNN_LABELS.index(lbl) for lbl in pred_labels]
    y_true = list(true_labels)

    # ── Evaluate ──────────────────────────────────────────────────────────
    tag = "CNN — Blink/Fatigue Detection"
    if use_simulation:
        tag += " [SIMULATED]"
    return evaluate(y_true, y_pred, CNN_LABELS, title=tag, save_plot=save_plot)


def run_feature_verification(
    model_key: str = "rf",
    model_path: Optional[str | Path] = None,
    X: Optional[np.ndarray] = None,
    y: Optional[np.ndarray] = None,
    labels: Optional[List[str]] = None,
    simulate: bool = False,
    save_plot: Optional[str] = None,
) -> dict:
    """
    Verify a feature-based model (rf / xgb / svm).

    Parameters
    ----------
    model_key   : one of 'rf', 'xgb', 'svm'
    model_path  : override FEATURE_MODEL_PATHS[model_key]
    X           : (n_samples, n_features) feature matrix
    y           : (n_samples,) integer label array
    labels      : class names; defaults to config.FEATURE_LABELS
    simulate    : force synthetic data + dummy RandomForest
    save_plot   : optional file path to save the confusion-matrix PNG

    Returns
    -------
    dict — keys: accuracy, precision, recall, f1, confusion_matrix
    """
    if model_key not in FEATURE_MODEL_PATHS:
        raise ValueError(
            f"Unknown model_key '{model_key}'. "
            f"Choose from: {list(FEATURE_MODEL_PATHS)}"
        )

    path = Path(model_path) if model_path else FEATURE_MODEL_PATHS[model_key]
    label_names = labels or FEATURE_LABELS
    use_sim_data = simulate or X is None
    use_sim_model = simulate or not path.exists()

    # ── Data ─────────────────────────────────────────────────────────────
    if use_sim_data:
        X_all, y_all = simulate_feature_data(n_samples=SIM_N_SAMPLES)
        print(f"[runner] Using {len(X_all)} simulated feature samples.")
    else:
        X_all, y_all = X, y

    # ── Model ─────────────────────────────────────────────────────────────
    if use_sim_model:
        if not simulate:
            print(f"[runner] {model_key.upper()} model not found at '{path}' "
                  "— training dummy RandomForest on simulated data.")
        # Stratified 70/30 split so both classes appear in train and test sets
        from sklearn.model_selection import train_test_split
        X_train, X_eval, y_train, y_eval = train_test_split(
            X_all, y_all,
            test_size=1.0 - _TRAIN_RATIO,
            stratify=y_all,
            random_state=42,
        )
        model = build_dummy_feature_model(X_train, y_train)
    else:
        model = load_joblib_model(path)
        X_eval, y_eval = X_all, y_all

    # ── Predict ───────────────────────────────────────────────────────────
    pred_labels, _ = batch_predict_features(model, X_eval, label_names)
    y_pred = [label_names.index(lbl) for lbl in pred_labels]
    y_true = list(y_eval)

    # ── Evaluate ──────────────────────────────────────────────────────────
    tag = f"{model_key.upper()} — Eye Movement / Pupil Reflex"
    if use_sim_model or use_sim_data:
        tag += " [SIMULATED]"
    return evaluate(y_true, y_pred, label_names, title=tag, save_plot=save_plot)


# ── Internal ─────────────────────────────────────────────────────────────────

def _build_dummy_cnn():
    """
    Minimal Keras CNN that mirrors the BlinkFatigueModel input shape.
    Used only in simulate mode — weights are random so accuracy will be ~50 %.
    """
    from tensorflow import keras
    from tensorflow.keras import layers

    from .config import CNN_IMG_HEIGHT, CNN_IMG_WIDTH

    model = keras.Sequential(
        [
            layers.Input(shape=(CNN_IMG_HEIGHT, CNN_IMG_WIDTH, 3)),
            layers.Conv2D(16, (3, 3), activation="relu"),
            layers.MaxPooling2D((4, 4)),
            layers.Flatten(),
            layers.Dense(32, activation="relu"),
            layers.Dense(2, activation="softmax"),
        ],
        name="dummy_cnn",
    )
    model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])
    print("[runner] Dummy CNN built (random weights — simulation only).")
    return model
