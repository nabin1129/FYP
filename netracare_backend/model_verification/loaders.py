"""
loaders.py — Model loading utilities.

load_tf_cnn       : load a Keras / TF SavedModel (.keras / .h5 / SavedModel dir)
load_joblib_model : load any joblib-serialised model (RF, XGBoost, SVM …)
"""

from __future__ import annotations

from pathlib import Path


def load_tf_cnn(model_path: str | Path):
    """
    Load a TensorFlow/Keras model from *model_path*.

    Raises
    ------
    ImportError       if TensorFlow is not installed
    FileNotFoundError if the path does not exist
    """
    try:
        from tensorflow import keras
    except ImportError as exc:
        raise ImportError(
            "TensorFlow is required for CNN verification. "
            "Install it with: pip install tensorflow"
        ) from exc

    path = Path(model_path)
    if not path.exists():
        raise FileNotFoundError(f"CNN model not found: {path}")

    model = keras.models.load_model(str(path))
    print(f"[loader] CNN loaded  →  {path.name}  ({type(model).__name__})")
    return model


def load_joblib_model(model_path: str | Path):
    """
    Load a joblib-serialised scikit-learn / XGBoost / SVM model.

    Raises
    ------
    ImportError       if joblib is not installed
    FileNotFoundError if the path does not exist
    """
    try:
        import joblib
    except ImportError as exc:
        raise ImportError(
            "joblib is required. Install it with: pip install joblib"
        ) from exc

    path = Path(model_path)
    if not path.exists():
        raise FileNotFoundError(f"Feature model not found: {path}")

    model = joblib.load(str(path))
    print(f"[loader] Feature model loaded  →  {path.name}  ({type(model).__name__})")
    return model
