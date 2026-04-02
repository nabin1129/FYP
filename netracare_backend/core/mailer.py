"""Email delivery helpers."""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


SMTP_EMAIL = os.getenv("SMTP_EMAIL", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587


def send_otp_email(to_email: str, otp_code: str) -> bool:
    """Send a password-reset OTP email. Returns True on success."""
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        print(f"[DEV] OTP for {to_email}: {otp_code}")
        return True

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "NetraCare – Password Reset Code"
    msg["From"] = f"NetraCare <{SMTP_EMAIL}>"
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
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.sendmail(SMTP_EMAIL, to_email, msg.as_string())
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send OTP to {to_email}: {e}")
        return False
