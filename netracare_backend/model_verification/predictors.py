"""
predictors.py — Prediction helpers (single-sample and batch).

predict_cnn             : one image  → (label, prob_array)
predict_feature_model   : one vector → (label, prob_array)
batch_predict_images    : list of images  → (label_list, prob_matrix)
batch_predict_features  : 2-D array      → (label_list, prob_matrix)
"""

from __future__ import annotations

from typing import List, Tuple

import numpy as np

from .config import CNN_LABELS, CNN_DROWSY_THRESHOLD, FEATURE_LABELS
from .preprocessing import preprocess_image, preprocess_features


def predict_cnn(
    model,
    image_input,
    labels: List[str] = CNN_LABELS,
    drowsy_threshold: float = CNN_DROWSY_THRESHOLD,
) -> Tuple[str, np.ndarray]:
    """
    Run the CNN on a single image.

    Returns
    -------
    (predicted_label, probability_array)
        probability_array has shape (n_classes,)
    """
    processed = preprocess_image(image_input)
    probs: np.ndarray = model.predict(processed, verbose=0)[0]

    # Apply the same threshold logic as BlinkFatigueModel.predict()
    pred_idx = 0 if probs[0] >= drowsy_threshold else int(np.argmax(probs))
    return labels[pred_idx], probs


def predict_feature_model(
    model,
    feature_input,
    labels: List[str] = FEATURE_LABELS,
) -> Tuple[str, np.ndarray]:
    """
    Run a feature-based model on a single sample.

    Uses predict_proba when available (RF, XGB, SVM with probability=True),
    otherwise falls back to predict() and builds a one-hot probability array.

    Returns
    -------
    (predicted_label, probability_array)
    """
    vec = preprocess_features(feature_input).reshape(1, -1)

    if hasattr(model, "predict_proba"):
        probs = model.predict_proba(vec)[0]
    else:
        raw = int(model.predict(vec)[0])
        probs = np.zeros(len(labels), dtype=np.float64)
        probs[raw] = 1.0

    pred_idx = int(np.argmax(probs))
    return labels[pred_idx], probs


def batch_predict_images(
    model,
    images: list,
    labels: List[str] = CNN_LABELS,
    drowsy_threshold: float = CNN_DROWSY_THRESHOLD,
) -> Tuple[List[str], np.ndarray]:
    """
    Predict over a list of images.

    Returns
    -------
    (label_list, prob_matrix)
        prob_matrix shape: (n_images, n_classes)
    """
    pred_labels, prob_rows = [], []
    for img in images:
        lbl, pr = predict_cnn(model, img, labels, drowsy_threshold)
        pred_labels.append(lbl)
        prob_rows.append(pr)
    return pred_labels, np.array(prob_rows)


def batch_predict_features(
    model,
    X: np.ndarray,
    labels: List[str] = FEATURE_LABELS,
) -> Tuple[List[str], np.ndarray]:
    """
    Predict over a 2-D feature matrix.

    Returns
    -------
    (label_list, prob_matrix)
        prob_matrix shape: (n_samples, n_classes)
    """
    pred_labels, prob_rows = [], []
    for row in X:
        lbl, pr = predict_feature_model(model, row, labels)
        pred_labels.append(lbl)
        prob_rows.append(pr)
    return pred_labels, np.array(prob_rows)
