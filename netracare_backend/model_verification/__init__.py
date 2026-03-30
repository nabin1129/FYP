"""
model_verification
==================
Modular verification suite for the Netracare ML models.

Package layout
--------------
config          paths, label maps, simulation constants
preprocessing   image preprocessing (preprocess_image) and
                feature vector preparation (preprocess_features)
loaders         load_tf_cnn, load_joblib_model
predictors      predict_cnn, predict_feature_model, and batch variants
evaluator       evaluate() — sklearn metrics + seaborn confusion matrix
simulator       synthetic data & dummy model for offline/CI use
runner          orchestrates each model's full verify pipeline
__main__        CLI  →  python -m model_verification [options]

Quick-start (simulate everything, no trained models required)
-------------------------------------------------------------
  cd netracare_backend
  python -m model_verification --simulate
"""

from .runner import run_cnn_verification, run_feature_verification

__all__ = [
    "run_cnn_verification",
    "run_feature_verification",
]
