from app.agents import sika_adk_agent
from app.agents.tools import get_total_balance, get_savings_status

print("[TEST ADK TOOL 1] get_total_balance():", get_total_balance())
print("[TEST ADK TOOL 2] get_savings_status():", get_savings_status())

print("\n--- TEST SCÉNARIO 1 : CONSULTATION DU SOLDE ---")
res1 = sika_adk_agent.process_query("Sika, quel est mon solde ?", user_firstname="David")
print("Outil utilisé:", res1.get("tool_used"))
print("Réponse Vocale SIKA:", res1.get("response"))

print("\n--- TEST SCÉNARIO 2 : TRANSFERT URGENT (CONFIRMATION BIOMÉTRIQUE) ---")
res2 = sika_adk_agent.process_query("Sika, envoie 20 000 francs à Kouamé. C'est urgent.", user_firstname="David")
print("Outil utilisé:", res2.get("tool_used"))
print("Confirmation requise:", res2.get("requires_confirmation"))
print("Réponse Vocale SIKA:", res2.get("response"))

print("\n--- TEST SCÉNARIO 3 : ÉPARGNE INTELLIGENTE ---")
res3 = sika_adk_agent.process_query("Sika, est-ce que je peux mettre 10 000 francs de côté ?", user_firstname="David")
print("Outil utilisé:", res3.get("tool_used"))
print("Confirmation requise:", res3.get("requires_confirmation"))
print("Réponse Vocale SIKA:", res3.get("response"))

print("\n--- TEST SCÉNARIO 4 : CONSEILLER FINANCIER & ANALYSE DÉPENSES ---")
res4 = sika_adk_agent.process_query("Sika, analyse mes dépenses et dis-moi comment économiser ce mois-ci.", user_firstname="David")
print("Outil utilisé:", res4.get("tool_used"))
print("Réponse Vocale SIKA:", res4.get("response"))

print("\n--- TEST MAILLON FINAL : EXÉCUTION RÉELLE APRÈS BIOMÉTRIE ('Oui') ---")
import asyncio
from app.agent.orchestrator import sika_orchestrator

async def test_confirm():
    action_id = res2.get("action_id", "tx_transfer_kouame_20000")
    exec_res = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1, user_confirmed=True)
    print("Statut exécution réelle:", exec_res.get("status"))
    print("Réponse Vocale Finale TTS:", exec_res.get("message"))

asyncio.run(test_confirm())
