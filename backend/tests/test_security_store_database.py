"""Store de sécurité en base (remplace Redis) : partagé entre instances, expirations, OTP, rate limit."""

from datetime import datetime, timedelta

import pytest
from sqlalchemy.orm import Session

from app.config import Settings
from app.database import Base, engine
from app.models.security_entry import SecurityEntryModel
from app.services.security_rate_limiter import SecurityRateLimiter
from app.services.security_store import DatabaseSecurityStore, create_security_store


@pytest.fixture(autouse=True)
def clean():
    Base.metadata.create_all(bind=engine)
    DatabaseSecurityStore().clear()
    yield


def _expire_all():
    with Session(engine) as db:
        db.query(SecurityEntryModel).update({"expires_at": datetime.utcnow() - timedelta(seconds=1)})
        db.commit()


def test_two_instances_share_revocations_failures_and_limits():
    # Deux instances Cloud Run = deux objets store sur la même base
    a, b = SecurityRateLimiter(store=DatabaseSecurityStore()), SecurityRateLimiter(store=DatabaseSecurityStore())
    a.revoke_token("jwt-token-value", jti="jti-1")
    assert b.is_token_revoked("jwt-token-value", jti="jti-1")
    assert not b.is_token_revoked("other-token", jti="jti-2")

    sa, sb = DatabaseSecurityStore(), DatabaseSecurityStore()
    assert sa.record_failure("login:a@b.c") == 1
    assert sb.record_failure("login:a@b.c") == 2
    assert sa.get_failures("login:a@b.c") == 2
    sb.reset_failures("login:a@b.c")
    assert sa.get_failures("login:a@b.c") == 0

    assert all(sa.check_rate_limit("confirm:42", 3, 60) for _ in range(2))
    assert sb.check_rate_limit("confirm:42", 3, 60)
    assert not sa.check_rate_limit("confirm:42", 3, 60)


def test_entries_expire():
    store = DatabaseSecurityStore()
    store.add_revoked_token("t1", expire_seconds=60)
    store.record_failure("k")
    store.check_rate_limit("r", 1, 60)
    _expire_all()
    assert not store.is_token_revoked("t1")
    assert store.get_failures("k") == 0
    assert store.check_rate_limit("r", 1, 60)  # nouvelle fenêtre


def test_otp_is_hashed_single_value_and_expires():
    store = DatabaseSecurityStore()
    store.store_otp("jane@sika.test", "123456")
    assert store.verify_otp("jane@sika.test", "123456")
    assert not store.verify_otp("jane@sika.test", "654321")
    with Session(engine) as db:
        stored = [r.value for r in db.query(SecurityEntryModel).all()]
        keys = [r.key for r in db.query(SecurityEntryModel).all()]
    assert "123456" not in stored and not any("jane" in k for k in keys)  # ni OTP ni e-mail en clair
    store.store_otp("jane@sika.test", "999999")  # un nouveau code remplace l'ancien
    assert not store.verify_otp("jane@sika.test", "123456") and store.verify_otp("jane@sika.test", "999999")
    store.clear_otp("jane@sika.test")
    assert not store.verify_otp("jane@sika.test", "999999")
    store.store_otp("jane@sika.test", "111111")
    _expire_all()
    assert not store.verify_otp("jane@sika.test", "111111")


def test_production_accepts_the_database_store_instead_of_redis(monkeypatch):
    monkeypatch.delenv("REDIS_URL", raising=False)
    s = Settings(ENV="production", JWT_SECRET_KEY="k" * 40, DATABASE_URL="postgresql+psycopg2://u:p@h:5432/db",
                 REDIS_URL=None, SECURITY_STORE="database")
    assert s.SECURITY_STORE == "database"
    with pytest.raises(ValueError, match="REDIS_URL est obligatoire"):
        Settings(ENV="production", JWT_SECRET_KEY="k" * 40, DATABASE_URL="postgresql+psycopg2://u:p@h:5432/db",
                 REDIS_URL=None)
    assert isinstance(create_security_store(env="production", redis_url=None, store_kind="database"), DatabaseSecurityStore)
