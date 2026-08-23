import os
import logging
from pathlib import Path
from typing import List, Optional, Dict, Any
from dotenv import load_dotenv

# Charge le fichier .env si présent (Dev local)
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
if ENV_FILE.exists():
    load_dotenv(ENV_FILE)
else:
    load_dotenv()

logger = logging.getLogger("AppConfig")


class Settings:
    """
    Configuration centralisée pour les environnements de développement et de production.
    
    Stratégie de résolution des secrets :
    1. En local (ENV=development) : Chargement depuis .env / variables d'environnement.
    2. En production (ENV=production & USE_GCP_SECRET_MANAGER=true) :
       - Tente de charger les secrets sensibles depuis Google Cloud Secret Manager.
       - Priorité : GCP Secret Manager > Variables d'environnement.
    3. Validation stricte :
       - JWT_SECRET_KEY obligatoire (>= 32 caractères, non-par défaut).
       - DATABASE_URL obligatoire (PostgreSQL/MySQL, rejet absolu de SQLite).
       - REDIS_URL obligatoire (store distribué anti-bruteforce multi-instance).
    """

    def __init__(self, **overrides):
        self.ENV: str = overrides.get("ENV", os.getenv("ENV", "development")).lower().strip()
        self.DEBUG: bool = overrides.get("DEBUG", os.getenv("DEBUG", "true" if self.ENV == "development" else "false").lower() == "true")
        self.DOCS_ENABLED: bool = overrides.get("DOCS_ENABLED", os.getenv("DOCS_ENABLED", "true" if self.ENV == "development" else "false").lower() == "true")

        # GCP Project Config
        self.GOOGLE_CLOUD_PROJECT: str = overrides.get("GOOGLE_CLOUD_PROJECT", os.getenv("GOOGLE_CLOUD_PROJECT", "sika-all-things-agentic"))
        self.GOOGLE_CLOUD_LOCATION: str = overrides.get("GOOGLE_CLOUD_LOCATION", os.getenv("GOOGLE_CLOUD_LOCATION", "global"))
        self.GEMINI_MODEL: str = overrides.get("GEMINI_MODEL", os.getenv("GEMINI_MODEL", "gemini-2.5-flash"))

        # Secret Manager Flag
        self.USE_GCP_SECRET_MANAGER: bool = overrides.get(
            "USE_GCP_SECRET_MANAGER",
            os.getenv("USE_GCP_SECRET_MANAGER", "true" if self.ENV == "production" else "false").lower() == "true"
        )

        # Résolution des secrets (Secret Manager ou Env Vars)
        resolved_secrets = self._resolve_secrets(overrides)

        # Database
        self.DATABASE_URL: str = resolved_secrets.get(
            "DATABASE_URL",
            overrides.get("DATABASE_URL", os.getenv("DATABASE_URL", "postgresql+psycopg2://sika_user:sika_pass@127.0.0.1:5433/sika_db"))
        )

        # Redis (Multi-Instance Distributed Store)
        self.REDIS_URL: Optional[str] = resolved_secrets.get(
            "REDIS_URL",
            overrides.get("REDIS_URL", os.getenv("REDIS_URL", None))
        )

        # JWT & Auth
        self.JWT_SECRET_KEY: str = resolved_secrets.get(
            "JWT_SECRET_KEY",
            overrides.get("JWT_SECRET_KEY", os.getenv("JWT_SECRET_KEY", "sika_default_jwt_secret_dev_key_only_change_in_prod_32_chars"))
        )
        self.JWT_ALGORITHM: str = "HS256"
        self.JWT_EXPIRE_HOURS: int = int(overrides.get("JWT_EXPIRE_HOURS", os.getenv("JWT_EXPIRE_HOURS", "72")))

        # Google OAuth Client ID
        self.GOOGLE_CLIENT_ID: Optional[str] = resolved_secrets.get(
            "GOOGLE_CLIENT_ID",
            overrides.get("GOOGLE_CLIENT_ID", os.getenv("GOOGLE_CLIENT_ID", None))
        )

        # CORS
        raw_origins = overrides.get("ALLOWED_ORIGINS", os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080"))
        if isinstance(raw_origins, list):
            self.ALLOWED_ORIGINS = raw_origins
        else:
            self.ALLOWED_ORIGINS = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]

        # Security limits
        self.MAX_REQUEST_BODY_SIZE: int = int(overrides.get("MAX_REQUEST_BODY_SIZE", os.getenv("MAX_REQUEST_BODY_SIZE", str(1024 * 1024))))  # 1MB
        self.MAX_FINANCIAL_AMOUNT: float = float(overrides.get("MAX_FINANCIAL_AMOUNT", os.getenv("MAX_FINANCIAL_AMOUNT", "50000000.0")))  # 50M FCFA

        self._validate_production_constraints()

    def _resolve_secrets(self, overrides: Dict[str, Any]) -> Dict[str, str]:
        """Tente de récupérer les secrets depuis Google Secret Manager si activé."""
        secrets: Dict[str, str] = {}
        if not self.USE_GCP_SECRET_MANAGER:
            return secrets

        target_secrets = ["JWT_SECRET_KEY", "DATABASE_URL", "REDIS_URL", "GOOGLE_CLIENT_ID"]
        try:
            # pyrefly: ignore [missing-import]
            from google.cloud import secretmanager
            client = secretmanager.SecretManagerServiceClient()
            for key in target_secrets:
                if key in overrides:
                    secrets[key] = overrides[key]
                    continue
                secret_name = f"projects/{self.GOOGLE_CLOUD_PROJECT}/secrets/{key}/versions/latest"
                try:
                    response = client.access_secret_version(name=secret_name)
                    secret_val = response.payload.data.decode("UTF-8").strip()
                    if secret_val:
                        secrets[key] = secret_val
                        logger.info(f"[GCP SECRET MANAGER] Secret '{key}' chargé avec succès depuis Secret Manager.")
                except Exception as e:
                    logger.debug(f"[GCP SECRET MANAGER] Secret '{key}' non trouvé ou inaccessible ({e}).")
        except ImportError:
            logger.warning("[GCP SECRET MANAGER] google-cloud-secret-manager non disponible.")
        except Exception as e:
            logger.warning(f"[GCP SECRET MANAGER] Erreur lors de l'accès à Secret Manager: {e}")

        return secrets

    def _validate_production_constraints(self):
        """Valide que la configuration en production respecte les normes de sécurité strictes."""
        if self.ENV == "production":
            # 1. Vérification de la robustesse du secret JWT
            insecure_defaults = [
                "sika_default_jwt_secret_dev_key_only_change_in_prod_32_chars",
                "default_secret",
                "secret",
                "changeme",
                "12345678"
            ]
            if not self.JWT_SECRET_KEY or self.JWT_SECRET_KEY in insecure_defaults or len(self.JWT_SECRET_KEY) < 32:
                raise ValueError(
                    "[SECURITY FATAL] En production (ENV=production), JWT_SECRET_KEY doit être défini "
                    "avec une clé cryptographique forte d'au moins 32 caractères."
                )

            # 2. Rejet de SQLite en production
            if not self.DATABASE_URL or "sqlite" in self.DATABASE_URL.lower():
                raise ValueError("[SECURITY FATAL] SQLite est interdit en production. DATABASE_URL doit pointer vers PostgreSQL.")

            # 3. Exigence stricte de Redis en production
            if not self.REDIS_URL or not self.REDIS_URL.strip():
                raise ValueError(
                    "[SECURITY FATAL] En production (ENV=production), REDIS_URL est obligatoire "
                    "pour garantir le stockage distribué multi-instances des révocations et rate limits."
                )


settings = Settings()
