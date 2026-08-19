from app.agents import sika_adk_agent
from app.agents.tools import get_total_balance, get_savings_status

print("[TEST ADK TOOL 1] get_total_balance():", get_total_balance())
print("[TEST ADK TOOL 2] get_savings_status():", get_savings_status())

print("\n--- TEST GOOGLE ADK AGENT REQUÊTE 1 (SOLDE) ---")
res1 = sika_adk_agent.process_query("Bonjour SIKA, quel est mon solde ?", user_firstname="David")
print("Outil utilisé:", res1.get("tool_used"))
print("Réponse Agent ADK:", res1.get("response"))

print("\n--- TEST GOOGLE ADK AGENT REQUÊTE 2 (ÉPARGNE) ---")
res2 = sika_adk_agent.process_query("Comment avance mon épargne ?", user_firstname="David")
print("Outil utilisé:", res2.get("tool_used"))
print("Réponse Agent ADK:", res2.get("response"))
