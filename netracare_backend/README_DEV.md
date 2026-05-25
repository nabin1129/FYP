Developer guide — setup, migrations, and tests
=============================================

Quick start (local development):

1. Create and activate your virtualenv (recommended):

   Windows PowerShell:

       python -m venv .venv
       .\.venv\Scripts\Activate.ps1

2. Install project dependencies (runtime + dev):

       python -m pip install --upgrade pip
       python -m pip install -r netracare_backend/requirements.txt -r netracare_backend/requirements-dev.txt

3. Copy environment example and update secrets locally (never commit real secrets):

       copy netracare_backend\.env.example .env

4. Run Alembic migrations (development):

       alembic -c netracare_backend/alembic.ini upgrade head

5. Run tests:

       pytest -q netracare_backend/tests

6. Run pre-commit hooks (recommended):

       pre-commit install
       pre-commit run --all-files

Notes
- Use `SQLALCHEMY_DATABASE_URI` env var to point migrations/tests at a different DB.
- CI runs linting, dependency audits, and migration checks.
