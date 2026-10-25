import sys
import os

_this_dir = os.path.dirname(__file__)
if _this_dir not in sys.path:
    sys.path.insert(0, _this_dir)

import database
sys.modules.setdefault("backend_research.database", database)

import models
sys.modules.setdefault("backend_research.models", models)
sys.modules.setdefault("backend_research.models.gap_analysis_models", models)
sys.modules.setdefault("models.gap_analysis_models", models)
