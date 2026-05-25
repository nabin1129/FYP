from contextlib import contextmanager
from typing import Iterator

from db_model import db


@contextmanager
def transactional_session() -> Iterator:
    """Context manager for a transactional DB session.

    Usage:
        with transactional_session() as session:
            session.add(obj)
            ...
    The session is committed on success and rolled back on exception.
    """
    session = db.session
    try:
        with session.begin():
            yield session
    except Exception:
        session.rollback()
        raise
