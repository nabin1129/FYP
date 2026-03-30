"""
simulator.py — Synthetic data generation.

Used when trained models or labelled datasets are not yet available.
All ranges are derived from real clinical / literature values for EAR,
blink rate, saccade velocity, pupil size, and fixation duration.

simulate_cnn_data          : synthetic BGR images labelled drowsy / notdrowsy
simulate_feature_data      : structured feature matrix (EAR, blink, …)
build_dummy_feature_model  : quick RandomForest trained on simulated data
"""

from __future__ import annotations

from typing import List, Tuple

import numpy as np

from .config import (
    CNN_IMG_HEIGHT,
    CNN_IMG_WIDTH,
    SIM_IMAGE_COUNT,
    SIM_N_SAMPLES,
    SIM_RANDOM_SEED,
)


def simulate_cnn_data(
    n_images: int = SIM_IMAGE_COUNT,
    seed: int = SIM_RANDOM_SEED,
) -> Tuple[List[np.ndarray], List[int]]:
    """
    Generate synthetic eye images with brightness-based drowsiness proxy.

    Drowsy eyes (half-closed) → darker mean pixel value  (~80)
    Alert  eyes (open)        → brighter mean pixel value (~160)

    Returns
    -------
    images : list of np.ndarray  shape (H, W, 3)  dtype uint8  BGR
    labels : list of int         0 = drowsy, 1 = notdrowsy
    """
    rng = np.random.default_rng(seed)
    images: List[np.ndarray] = []
    labels: List[int] = []
    half = n_images // 2

    for i in range(n_images):
        is_drowsy = i < half
        centre = 80 if is_drowsy else 160
        lo, hi = max(0, centre - 45), min(255, centre + 45)
        img = rng.integers(lo, hi, size=(CNN_IMG_HEIGHT, CNN_IMG_WIDTH, 3), dtype=np.uint8)
        images.append(img)
        labels.append(0 if is_drowsy else 1)

    return images, labels


def simulate_feature_data(
    n_samples: int = SIM_N_SAMPLES,
    seed: int = SIM_RANDOM_SEED,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Generate structured feature vectors that mirror MediaPipe / OpenCV output.

    Column order matches ``config.FEATURE_COLUMNS``:
      ear_left, ear_right, ear_avg, blink_rate,
      saccade_velocity, pupil_size_left, pupil_size_right, fixation_duration

    Clinical feature ranges
    -----------------------
    normal (label 0):
      EAR              0.28 – 0.38  (healthy open eyes)
      blink_rate        8  – 15 blinks / min
      saccade_velocity 150 – 400 °/s
      pupil_size        3  – 5 mm
      fixation_duration 150 – 300 ms

    fatigue (label 1):
      EAR              0.15 – 0.27  (drooping lids)
      blink_rate       18  – 35 blinks / min
      saccade_velocity  50 – 149 °/s   (slower pursuit)
      pupil_size        2  – 3.5 mm    (constriction under fatigue)
      fixation_duration 300 – 600 ms   (longer dwell time)

    Returns
    -------
    X : np.ndarray  shape (n_samples, 8)  dtype float64
    y : np.ndarray  shape (n_samples,)    dtype int32
    """
    rng = np.random.default_rng(seed)
    half = n_samples // 2
    rows: list = []
    labels: List[int] = []

    for i in range(n_samples):
        fatigue = i >= half

        ear_l = rng.uniform(0.15, 0.27) if fatigue else rng.uniform(0.28, 0.38)
        ear_r = float(np.clip(ear_l + rng.uniform(-0.02, 0.02), 0.10, 0.45))
        ear_avg = (ear_l + ear_r) / 2.0

        blink  = rng.uniform(18.0, 35.0) if fatigue else rng.uniform(8.0, 15.0)
        sacc   = rng.uniform(50.0, 149.0) if fatigue else rng.uniform(150.0, 400.0)

        p_l = rng.uniform(2.0, 3.5) if fatigue else rng.uniform(3.0, 5.0)
        p_r = float(np.clip(p_l + rng.uniform(-0.25, 0.25), 1.5, 6.0))

        fix = rng.uniform(300.0, 600.0) if fatigue else rng.uniform(150.0, 300.0)

        rows.append([ear_l, ear_r, ear_avg, blink, sacc, p_l, p_r, fix])
        labels.append(1 if fatigue else 0)

    X = np.array(rows, dtype=np.float64)
    y = np.array(labels, dtype=np.int32)
    return X, y


def build_dummy_feature_model(X_train: np.ndarray, y_train: np.ndarray):
    """
    Train a lightweight RandomForest on the supplied data and return it.

    Called by runner.py when no saved joblib model exists, ensuring the
    verification pipeline can always run end-to-end even without pre-trained
    feature models.
    """
    from sklearn.ensemble import RandomForestClassifier

    clf = RandomForestClassifier(
        n_estimators=50,
        random_state=SIM_RANDOM_SEED,
        n_jobs=-1,
    )
    clf.fit(X_train, y_train)
    print(f"[simulator] Dummy RandomForest trained on {len(y_train)} samples.")
    return clf
