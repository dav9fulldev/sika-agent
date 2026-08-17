import pytest
from app.services.user_learning_service import user_learning_service
from app.services.backup_service import backup_service
from app.agent.tool_registry import tool_registry

def test_user_learning_service():
    profile = user_learning_service.get_user_profile("default_user")
    assert profile["name"] == "David YAO"
    assert "habits" in profile

    updated = user_learning_service.update_user_habit("default_user", "Restauration", 5000.0)
    assert updated["category"] == "Restauration"
    assert updated["average_spent"] > 0

def test_backup_service():
    snapshot = backup_service.create_backup_snapshot("default_user")
    assert snapshot["status"] == "COMPLETED"
    assert "snapshot_id" in snapshot
    assert snapshot["user_id"] == "default_user"

def test_learning_tools():
    res_habits = tool_registry.execute("get_user_habits", {"user_id": "default_user"})
    assert res_habits.success is True
    assert "habits" in res_habits.data

    res_backup = tool_registry.execute("create_backup_snapshot", {"user_id": "default_user"})
    assert res_backup.success is True
    assert res_backup.data["status"] == "COMPLETED"
