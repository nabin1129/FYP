"""Web routes not managed by Flask-RestX namespaces."""

from __future__ import annotations

import os
from pathlib import Path

from flask import send_from_directory


def register_web_routes(app) -> None:
    """Register non-API routes for static assets and homepage."""

    backend_dir = Path(__file__).resolve().parents[1]
    workspace_dir = backend_dir.parent

    @app.route("/static/ishihara/<path:filename>")
    def serve_ishihara_image(filename):
        """Serve Ishihara plate images from the dataset."""
        dataset_path = workspace_dir / "ishihara_data_set"
        if not dataset_path.exists():
            alt_dataset_path = workspace_dir / "FYP" / "ishihara_data_set"
            dataset_path = alt_dataset_path

        if dataset_path.exists():
            return send_from_directory(str(dataset_path), filename)
        return {"error": "Dataset not found"}, 404

    @app.route("/uploads/medical_records/<path:filename>")
    def serve_medical_record_file(filename):
        """Serve uploaded medical record files."""
        upload_dir = backend_dir / "uploads" / "medical_records"
        if not upload_dir.exists():
            return {"error": "Upload directory not found"}, 404
        return send_from_directory(str(upload_dir), filename)

    @app.route("/")
    def home():
        """Home page placeholder."""
        return """
    <!DOCTYPE html>
    <html lang=\"en\">
    <head>
        <meta charset=\"UTF-8\">
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
        <title>NetraCare API - Home</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                justify-content: center;
                align-items: center;
                padding: 20px;
            }
            .container {
                background: white;
                border-radius: 20px;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
                padding: 60px 40px;
                max-width: 600px;
                width: 100%;
                text-align: center;
            }
            h1 {
                color: #333;
                font-size: 2.5em;
                margin-bottom: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
            }
            p {
                color: #666;
                font-size: 1.1em;
                line-height: 1.6;
                margin-bottom: 30px;
            }
            .links {
                display: flex;
                flex-direction: column;
                gap: 15px;
                margin-top: 30px;
            }
            a {
                display: inline-block;
                padding: 12px 30px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                text-decoration: none;
                border-radius: 25px;
                font-weight: 600;
                transition: transform 0.2s, box-shadow 0.2s;
            }
            a:hover {
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
            }
            .api-info {
                margin-top: 40px;
                padding-top: 30px;
                border-top: 2px solid #f0f0f0;
            }
            .api-info h2 {
                color: #333;
                font-size: 1.5em;
                margin-bottom: 15px;
            }
            .api-info ul {
                list-style: none;
                text-align: left;
                display: inline-block;
            }
            .api-info li {
                color: #666;
                margin: 8px 0;
                padding-left: 20px;
                position: relative;
            }
            .api-info li:before {
                content: \"→\";
                position: absolute;
                left: 0;
                color: #667eea;
            }
        </style>
    </head>
    <body>
        <div class=\"container\">
            <h1>NetraCare API</h1>
            <p>Welcome to the NetraCare Backend API</p>
            <p>This is a RESTful API service for managing eye care data and user authentication.</p>

            <div class=\"links\">
                <a href=\"/docs\">API Documentation</a>
            </div>

            <div class=\"api-info\">
                <h2>Available Endpoints</h2>
                <ul>
                    <li><strong>/auth</strong> - Authentication (Login & Signup)</li>
                    <li><strong>/user</strong> - User Profile Management</li>
                    <li><strong>/tests</strong> - Eye Test Uploads</li>
                    <li><strong>/camera-eye-tracking</strong> - Camera Eye Tracking Sessions</li>
                    <li><strong>/docs</strong> - Interactive API Documentation</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    """
