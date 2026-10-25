"""Models package.
Re-exports all models from the root models.py for backward compatibility,
while allowing submodule imports like `from models.admin_models import ...`.
"""
import sys
import importlib.util
from pathlib import Path

_models_py = Path(__file__).resolve().parent.parent / "models.py"
if _models_py.exists():
    _spec = importlib.util.spec_from_file_location("_models_root", _models_py)
    _mod = importlib.util.module_from_spec(_spec)
    sys.modules["_models_root"] = _mod
    _spec.loader.exec_module(_mod)
    for _k, _v in _mod.__dict__.items():
        if not _k.startswith("__"):
            globals()[_k] = _v
