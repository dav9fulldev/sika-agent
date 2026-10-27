"""La version de l'API, de l'application mobile et du CHANGELOG doivent rester alignées."""

import re
from pathlib import Path

from fastapi.testclient import TestClient

from app.config import APP_VERSION
from app.main import app

ROOT = Path(__file__).resolve().parents[2]


def test_api_reports_app_version():
    assert TestClient(app).get("/health").json()["version"] == APP_VERSION


def test_mobile_and_changelog_match_api_version():
    pubspec = (ROOT / "mobile" / "pubspec.yaml").read_text()
    mobile_version = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", pubspec, re.MULTILINE).group(1)
    assert mobile_version == APP_VERSION

    changelog = (ROOT / "CHANGELOG.md").read_text()
    latest = re.search(r"^## \[([0-9.]+)\]", changelog, re.MULTILINE).group(1)
    assert latest == APP_VERSION
