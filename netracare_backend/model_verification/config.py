"""
config.py — Single source of truth for paths, label maps, and constants.

All other modules import from here so nothing is hardcoded in logic files.
"""

from pathlib import Path

# ── Repository root ────────────────────────────────────────────────────────
_BACKEND: Path = Path(__file__).resolve().parent.parent

# ── CNN  (BlinkFatigueModel — TensorFlow/Keras) ────────────────────────────
CNN_MODEL_PATH: Path = _BACKEND / "models" / "blink_fatigue_model.keras"
CNN_IMG_HEIGHT: int = 224   # MobileNetV2 native size (updated from 145)
CNN_IMG_WIDTH: int = 224
CNN_LABELS: list[str] = ["drowsy", "notdrowsy"]
CNN_DROWSY_THRESHOLD: float = 0.6   # mirrors BlinkFatigueModel.DROWSY_LABEL_THRESHOLD

# ── Feature models  (scikit-learn / XGBoost — joblib serialised) ───────────
FEATURE_MODEL_PATHS: dict[str, Path] = {
    "rf":  _BACKEND / "models" / "rf_eye.joblib",
    "xgb": _BACKEND / "models" / "xgb_eye.joblib",
    "svm": _BACKEND / "models" / "svm_eye.joblib",
}

# Column order the feature vector must follow (matches EyeTrackingDataPoint fields)
FEATURE_COLUMNS: list[str] = [
    "ear_left",
    "ear_right",
    "ear_avg",
    "blink_rate",
    "saccade_velocity",
    "pupil_size_left",
    "pupil_size_right",
    "fixation_duration",
]

FEATURE_LABELS: list[str] = ["normal", "fatigue"]

# ── Simulation defaults ────────────────────────────────────────────────────
SIM_N_SAMPLES: int = 200     # synthetic feature samples (100 per class)
SIM_IMAGE_COUNT: int = 40    # synthetic images (20 per class)
SIM_RANDOM_SEED: int = 42
