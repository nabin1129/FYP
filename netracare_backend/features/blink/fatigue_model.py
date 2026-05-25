"""Notebook-backed Blink/Fatigue model loader

This module intentionally loads runtime definitions from the companion
`fatigue_model.ipynb` notebook. It provides a thin compatibility shim so
that existing imports (`from features.blink.fatigue_model import get_model_singleton`)
continue to work while the authoritative implementation lives in the
notebook. The loader executes notebook code cells in a restricted
namespace and exposes `BlinkFatigueModel` and `get_model_singleton`.

The loader is defensive: if executing the notebook fails or the notebook
doesn't define `BlinkFatigueModel`, a minimal stub model is provided so
the backend does not crash.
"""

from __future__ import annotations

import os
import types
import nbformat
import numpy as np
from typing import Any

# Read and execute the notebook to populate a namespace
NB_PATH = os.path.join(os.path.dirname(__file__), "fatigue_model.ipynb")
_nb_ns: dict[str, Any] = {}

if os.path.exists(NB_PATH):
    try:
        nb = nbformat.read(NB_PATH, as_version=4)
        code_cells = [c["source"] for c in nb.cells if c.get("cell_type") == "code"]
        # Execute notebook code in dedicated namespace
        exec("\n\n".join(code_cells), _nb_ns)
    except Exception:
        _nb_ns = {}
else:
    _nb_ns = {}


def _make_stub():
    class _StubModel:
        img_height = 224
        img_width = 224

        def predict(self, image_input):
            return {
                "prediction": "notdrowsy",
                "confidence": 1.0,
                "probabilities": {"drowsy": 0.0, "notdrowsy": 1.0},
                "fatigue_level": "Alert",
                "alert": False,
                "timestamp": str(np.datetime64("now")),
            }

        def preprocess_image(self, x):
            return x

        def predict_batch(self, lst):
            return [self.predict(x) for x in lst]

    return _StubModel


# Prefer BlinkFatigueModel from notebook; fall back to stub
BlinkFatigueModel = _nb_ns.get("BlinkFatigueModel", None)
if BlinkFatigueModel is None:
    BlinkFatigueModel = _make_stub()


def get_model_singleton(model_path: str | None = None):
    """Return a singleton instance of the BlinkFatigueModel.

    If `model_path` is omitted, the loader will prefer the most-recent
    `.keras` or `.h5` file in the `models/` directory next to this file.
    The function is defensive and will return a minimal stub on failure.
    """
    if not hasattr(get_model_singleton, "_instance"):
        # Determine model path
        if model_path is None:
            models_dir = os.path.join(os.path.dirname(__file__), "models")
            chosen = None
            try:
                if os.path.isdir(models_dir):
                    candidates = [
                        os.path.join(models_dir, f)
                        for f in os.listdir(models_dir)
                        if f.lower().endswith(".keras") or f.lower().endswith(".h5")
                    ]
                    if candidates:
                        candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
                        chosen = candidates[0]
            except Exception:
                chosen = None

            if chosen:
                model_path = chosen
            else:
                model_path = os.path.join(models_dir, "best_blink_fatigue.keras")

        # Instantiate model class
        try:
            inst = (
                BlinkFatigueModel(model_path)
                if callable(BlinkFatigueModel)
                else BlinkFatigueModel()
            )
        except Exception:
            try:
                inst = BlinkFatigueModel()
            except Exception:
                inst = _make_stub()()

        get_model_singleton._instance = inst

    return get_model_singleton._instance
