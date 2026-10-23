"""
Configuration pytest partagée.

Sécurité : certaines suites exécutent Base.metadata.drop_all(). Les tests utilisent TOUJOURS une
base SQLite jetable, jamais le DATABASE_URL de backend/.env (qui peut pointer vers un proxy Cloud SQL).
Aucun appel réseau réel vers PayPal n'est effectué par pytest : le client PayPal est remplacé par
tests/paypal_fakes.FakePayPalAPI ou par une session HTTP simulée.
"""

import os
import secrets

os.environ["DATABASE_URL"] = "sqlite:///./sika_test.db"
os.environ["ENV"] = "development"
# Identifiants factices générés à chaque exécution (aucune valeur d'identifiant en dur dans le dépôt)
os.environ["PAYPAL_CLIENT_ID"] = f"dummy-{secrets.token_hex(8)}"
os.environ["PAYPAL_CLIENT_SECRET"] = f"dummy-{secrets.token_hex(8)}"
