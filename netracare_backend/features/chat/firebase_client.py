"""Firebase Admin bootstrap for chat persistence and custom token minting."""

from __future__ import annotations

import json
import logging
import os
import threading
from typing import Optional

LOGGER = logging.getLogger(__name__)

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.auth.exceptions import DefaultCredentialsError


_INIT_LOCK = threading.Lock()
_APP: Optional[firebase_admin.App] = None
_ADC_WARNING_LOGGED = False


def _build_credentials() -> credentials.Base:
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()

    if service_account_json:
        return credentials.Certificate(json.loads(service_account_json))

    if service_account_path:
        return credentials.Certificate(service_account_path)

    # Fallback to Application Default Credentials for hosted environments.
    return credentials.ApplicationDefault()


def get_firebase_app() -> Optional[firebase_admin.App]:
    """Return a configured Firebase Admin app, or None when unavailable."""
    global _APP

    if _APP is not None:
        return _APP

    with _INIT_LOCK:
        if _APP is not None:
            return _APP

        try:
            project_id = os.getenv("FIREBASE_PROJECT_ID", "").strip() or None
            options = {"projectId": project_id} if project_id else None
            _APP = firebase_admin.initialize_app(_build_credentials(), options=options)
        except Exception:
            _APP = None

    return _APP


def get_firestore_client() -> Optional[firestore.Client]:
    """Return Firestore client when Firebase is configured, else None."""
    app = get_firebase_app()
    if app is None:
        return None
    try:
        return firestore.client(app)
    except Exception:
        LOGGER.debug(
            "Firestore client unavailable – set FIREBASE_SERVICE_ACCOUNT_PATH or "
            "FIREBASE_SERVICE_ACCOUNT_JSON in .env to enable chat history persistence"
        )
        return None


def create_custom_token(uid: str, claims: dict) -> Optional[str]:
    """Create a Firebase custom token for a chat participant.

    Returns None when Firebase is not configured or the service account lacks
    the iam.serviceAccountTokenCreator permission (common with ADC in dev).
    In that case the chat REST API returns 503 and Flutter skips Firestore history
    gracefully.
    """
    app = get_firebase_app()
    if app is None:
        return None

    global _ADC_WARNING_LOGGED

    try:
        encoded = auth.create_custom_token(uid, developer_claims=claims, app=app)
        if isinstance(encoded, bytes):
            return encoded.decode("utf-8")
        return str(encoded)
    except DefaultCredentialsError:
        if not _ADC_WARNING_LOGGED:
            LOGGER.warning(
                "Firebase custom token unavailable (missing ADC/service account). "
                "Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON."
            )
            _ADC_WARNING_LOGGED = True
        return None
    except Exception as exc:
        # Keep this non-fatal: chat continues using REST/socket paths without Firebase.
        LOGGER.warning(
            "Failed to create Firebase custom token for uid=%s: %s",
            uid,
            str(exc),
        )
        return None
