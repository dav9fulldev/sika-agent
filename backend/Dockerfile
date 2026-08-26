# 1. OS (SYSTÈME D'EXPLOITATION) 
# Note: On utilise l'image officielle python:3.11-slim (basée sur Debian)
FROM python:3.11-slim

# OPTIMISATION SÉCURITÉ: Création d'un utilisateur non-root
RUN useradd -m -u 1000 appuser

# 2. Mettre à jour le repo apt et installer des dépendances système
RUN apt-get update && apt-get -y install libpq-dev gcc

# Définir le dossier de travail
WORKDIR /opt/code-source

# OPTIMISATION CACHE: Copier UNIQUEMENT requirements.txt en premier
COPY requirements.txt .

# 4. Installer les dépendances Python avec pip
# (Ne sera re-téléchargé que si le fichier requirements.txt est modifié)
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copier le reste du code source
COPY --chown=appuser:appuser . .

# Basculer vers l'utilisateur sécurisé
USER appuser

# 6. Exécuter le serveur web
ENTRYPOINT ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
