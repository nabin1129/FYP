"""Audit-log decorator for sensitive endpoint access."""

from functools import wraps
from flask import request
from db_model import db, AuditLog


def audit_log(action: str, resource_type: str):
    """Decorator that writes an append-only AuditLog entry after the endpoint runs.

    Usage::

        @audit_log('read', 'medical_record')
        @token_required
        def get(self, current_user, record_id):
            ...

    The decorated function must receive *current_user* as its first positional
    argument (injected by @token_required) so the actor identity is available.
    """

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            result = fn(*args, **kwargs)

            try:
                # current_user is injected by @token_required as first positional arg
                # args[0] is 'self' for Resource methods, args[1] is current_user
                current_user = None
                for arg in args:
                    if hasattr(arg, "id") and hasattr(arg, "email"):
                        current_user = arg
                        break

                resource_id = (
                    kwargs.get("record_id")
                    or kwargs.get("test_id")
                    or kwargs.get("report_id")
                )

                if current_user is not None:
                    entry = AuditLog(
                        actor_id=current_user.id,
                        actor_role=getattr(current_user, "role", "user"),
                        action=action,
                        resource_type=resource_type,
                        resource_id=resource_id,
                        ip_address=request.remote_addr,
                    )
                    db.session.add(entry)
                    db.session.commit()
            except Exception:
                db.session.rollback()

            return result

        return wrapper

    return decorator
