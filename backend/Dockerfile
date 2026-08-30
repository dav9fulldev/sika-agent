# 1. OS (SYSTÈME D'EXPLOITATION) 
# Note: On utilise l'image officielle python:3.11-slim-bookworm (plus sécurisée et récente)
FROM python:3.11-slim-bookworm

# OPTIMISATION SÉCURITÉ: Création d'un utilisateur non-root
RUN useradd -m -u 1000 appuser

# 2. Mettre à jour le repo apt, appliquer les correctifs de sécurité (upgrade), et installer des dépendances système
RUN apt-get update && apt-get upgrade -y && \
    apt-get -y install libpq-dev gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Définir le dossier de travail
WORKDIR /opt/code-source

# OPTIMISATION CACHE: Copier UNIQUEMENT requirements.txt en premier
COPY requirements.txt .

# 4. Installer et mettre à jour les outils de base Python pour éviter les CVEs de pip/setuptools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# 5. Installer les dépendances Python du projet
RUN pip install --no-cache-dir -r requirements.txt
# 5. Copier le reste du code source
COPY --chown=appuser:appuser . .

# Basculer vers l'utilisateur sécurisé
USER appuser

EXPOSE 8080

# 6. Exécuter le serveur web
ENTRYPOINT ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
