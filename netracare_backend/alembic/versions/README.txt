This directory will contain Alembic revision scripts.

Run in development (with alembic installed):

    alembic -c alembic.ini revision --autogenerate -m "initial"
    alembic -c alembic.ini upgrade head

In CI, run the same commands to verify migrations apply cleanly.
