import os
import sys

# Ensure the package root is on sys.path so tests can import top-level modules like
# `core` and `db_model` (they rely on being able to `import core`).
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

# Tests expect to be able to create an in-memory database by setting
# `SQLALCHEMY_DATABASE_URI` prior to application creation. Set it here so
# `create_app()` will pick it up from the environment when tests call it.
os.environ.setdefault("SQLALCHEMY_DATABASE_URI", "sqlite:///:memory:")
