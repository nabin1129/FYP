"""Email delivery helpers."""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def _first_non_empty(*values: str) -> str:
    for value in values:
        if value and value.strip():
            return value.strip()
    return ""


def _smtp_settings() -> tuple[str, str, str, int]:
    """Resolve SMTP settings from environment at call time."""
    smtp_email = _first_non_empty(
        os.getenv("SMTP_EMAIL", ""),
        os.getenv("MAIL_USERNAME", ""),
        os.getenv("MAIL_USER", ""),
    )
    smtp_password = _first_non_empty(
        os.getenv("SMTP_PASSWORD", ""),
        os.getenv("MAIL_PASSWORD", ""),
        os.getenv("MAIL_PASS", ""),
    )
    smtp_host = _first_non_empty(
        os.getenv("SMTP_HOST", ""),
        os.getenv("MAIL_SERVER", ""),
        "smtp.gmail.com",
    )
    smtp_port_raw = _first_non_empty(
        os.getenv("SMTP_PORT", ""),
        os.getenv("MAIL_PORT", ""),
        "587",
    )
    try:
        smtp_port = int(smtp_port_raw)
    except ValueError:
        smtp_port = 587
    return smtp_email, smtp_password, smtp_host, smtp_port


def send_otp_email(to_email: str, otp_code: str) -> bool:
    """Send a password-reset OTP email. Returns True on success."""
    smtp_email, smtp_password, smtp_host, smtp_port = _smtp_settings()

    if not smtp_email or not smtp_password:
        print(
            "[EMAIL ERROR] SMTP not configured. "
            "Set SMTP_EMAIL and SMTP_PASSWORD to enable OTP delivery."
        )
        return False

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "NetraCare – Password Reset Code"
    msg["From"] = f"NetraCare <{smtp_email}>"
    msg["To"] = to_email

    plain = (
        f"Your NetraCare password reset code is: {otp_code}\n\n"
        "This code expires in 15 minutes.\n"
        "If you did not request this, please ignore this email."
    )

    html = f"""\
    <div style=\"font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;\">
      <h2 style=\"color:#4F46E5;\">NetraCare</h2>
      <p>You requested a password reset. Use the code below:</p>
      <div style=\"background:#F4F6FA;border-radius:8px;padding:20px;text-align:center;margin:20px 0;\">
        <span style=\"font-size:32px;font-weight:bold;letter-spacing:6px;color:#4F46E5;\">{otp_code}</span>
      </div>
      <p style=\"color:#6B7280;font-size:14px;\">
        This code expires in <b>15 minutes</b>.<br>
        If you didn't request this, you can safely ignore this email.
      </p>
    </div>
    """

    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_email, smtp_password)
            server.sendmail(smtp_email, to_email, msg.as_string())
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send OTP to {to_email}: {e}")
        return False
