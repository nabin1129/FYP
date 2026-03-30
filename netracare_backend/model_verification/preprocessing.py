"""
preprocessing.py — Input preparation utilities.

preprocess_image    : file path | bytes | ndarray  →  (1, H, W, 3) float32
preprocess_features : dict | array-like            →  1-D float64 array
"""

from __future__ import annotations

import numpy as np
import cv2

from .config import CNN_IMG_HEIGHT, CNN_IMG_WIDTH, FEATURE_COLUMNS


def preprocess_image(
    image_input,
    img_height: int = CNN_IMG_HEIGHT,
    img_width: int = CNN_IMG_WIDTH,
) -> np.ndarray:
    """
    Decode, resize, normalise an eye image for the TF CNN.

    Parameters
    ----------
    image_input : str | bytes | np.ndarray
        • str  — filesystem path
        • bytes — raw encoded bytes (JPEG / PNG)
        • ndarray — already decoded BGR or RGB array

    Returns
    -------
    np.ndarray  shape (1, img_height, img_width, 3)  dtype float32
    """
    if isinstance(image_input, str):
        img = cv2.imread(image_input)
        if img is None:
            raise FileNotFoundError(f"Cannot read image from path: {image_input}")
    elif isinstance(image_input, bytes):
        arr = np.frombuffer(image_input, np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image bytes")
    elif isinstance(image_input, np.ndarray):
        img = image_input.copy()
    else:
        raise TypeError(
            f"Unsupported image_input type '{type(image_input).__name__}'. "
            "Expected str, bytes, or np.ndarray."
        )

    # OpenCV loads as BGR — convert to RGB (matches Keras training pipeline)
    if img.ndim == 3 and img.shape[2] == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    img = cv2.resize(img, (img_width, img_height), interpolation=cv2.INTER_AREA)
    # MobileNetV2 preprocess_input is baked into the model graph, so pass raw
    # pixel values in [0, 255] as float32 — no /255 rescaling here.
    img = img.astype("float32")
    return np.expand_dims(img, axis=0)   # (1, H, W, 3)


def preprocess_features(
    feature_input,
    columns: list[str] = FEATURE_COLUMNS,
) -> np.ndarray:
    """
    Validate and order a feature vector for scikit-learn / XGBoost / SVM models.

    Parameters
    ----------
    feature_input : dict | list | np.ndarray
        • dict      — keys must include all entries in ``columns``
        • array-like — assumed to already be in ``columns`` order

    Returns
    -------
    np.ndarray  shape (len(columns),)  dtype float64
    """
    if isinstance(feature_input, dict):
        missing = [c for c in columns if c not in feature_input]
        if missing:
            raise KeyError(f"Missing feature keys: {missing}")
        return np.array([float(feature_input[c]) for c in columns], dtype=np.float64)

    arr = np.asarray(feature_input, dtype=np.float64).ravel()
    if arr.shape[0] != len(columns):
        raise ValueError(
            f"Expected {len(columns)} features (columns: {columns}), got {arr.shape[0]}."
        )
    return arr
