"""Production WSGI entrypoint for NetraCare backend."""

from backend_app.factory import create_app

app = create_app()
