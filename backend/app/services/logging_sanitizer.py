"""
Module de Sanitisation des Logs pour SIKA.
Empêche l'affichage et l'enregistrement de secrets, tokens, mots de passe,
PINs et OTPs dans les logs de l'application.
"""

import re
import logging
from typing import Any

# Patterns regex pour identifier les données sensibles
SENSITIVE_PATTERNS = [
    # Mots de passe
    (re.compile(r'("password"|"password_hash"|password)\s*[:=]\s*["\']?([^"\'\s,]+)["\']?', re.IGNORECASE), r'\1: "[REDACTED]"'),
    # Codes PIN
    (re.compile(r'("pin"|"pin_code"|pin)\s*[:=]\s*["\']?(\d{4,8})["\']?', re.IGNORECASE), r'\1: "[REDACTED_PIN]"'),
    # Codes OTP
    (re.compile(r'("otp"|"otp_code"|otp)\s*[:=]\s*["\']?(\d{4,8})["\']?', re.IGNORECASE), r'\1: "[REDACTED_OTP]"'),
    # Tokens JWT / Bearer
    (re.compile(r'(Bearer\s+)[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*', re.IGNORECASE), r'\1[REDACTED_JWT]'),
    (re.compile(r'("token"|"access_token"|"jwt_token"|"id_token")\s*[:=]\s*["\']?([^"\'\s,]+)["\']?', re.IGNORECASE), r'\1: "[REDACTED_TOKEN]"'),
    # Clés API et Secrets
    (re.compile(r'("secret"|"api_key"|"private_key"|"client_secret")\s*[:=]\s*["\']?([^"\'\s,]+)["\']?', re.IGNORECASE), r'\1: "[REDACTED_SECRET]"'),
]


def sanitize_sensitive_data(message: str) -> str:
    """Sanitise une chaîne de caractères en masquant toutes les données sensibles identifiées."""
    if not isinstance(message, str):
        message = str(message)

    sanitized = message
    for pattern, replacement in SENSITIVE_PATTERNS:
        sanitized = pattern.sub(replacement, sanitized)

    return sanitized


class SensitiveDataFilter(logging.Filter):
    """Filtre de logging Python qui applique la sanitisation à chaque log émis."""

    def filter(self, record: logging.LogRecord) -> bool:
        if record.msg:
            record.msg = sanitize_sensitive_data(record.msg)
        if record.args:
            if isinstance(record.args, dict):
                record.args = {k: sanitize_sensitive_data(v) if isinstance(v, str) else v for k, v in record.args.items()}
            elif isinstance(record.args, (list, tuple)):
                record.args = tuple(sanitize_sensitive_data(a) if isinstance(a, str) else a for a in record.args)
        return True


def setup_secure_logging():
    """Configure la sanitisation sur le logger racine."""
    root_logger = logging.getLogger()
    for handler in root_logger.handlers:
        handler.addFilter(SensitiveDataFilter())
