# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Header, Depends, Request, WebSocket
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.user import UserModel
from typing import Dict, Any, Optional
from ..schemas.sika_dto import (
    SikaQueryDTO, SikaResponseDTO,
    AuthLoginRequest, AuthRegisterRequest, AuthGoogleRequest, AuthPayPalRequest,
    AuthForgotPasswordRequest, AuthResetPasswordRequest,
    TTSRequest, AgentProcessRequest
)
from ..services.sika_ai import SikaAI
from ..services.sika_nlp import SikaNLP
from ..services.user_learning_service import user_learning_service
from ..services.backup_service import backup_service
from ..services.auth_service import oauth2_auth_service
from ..services.security_rate_limiter import security_rate_limiter
import re
from ..agent.orchestrator import sika_orchestrator

def strip_markdown(text: str) -> str:
    if not text:
        return ""
    # Remove markdown bold / italic markers (**bold**, *italic*, __bold__, _italic_)
    text = re.sub(r'[*_]{1,3}([^*_]+)[*_]{1,3}', r'\1', text)
    # Remove any leftover stray asterisks
    text = re.sub(r'\*{1,2}', '', text)
    # Remove markdown headers
    text = re.sub(r'#+\s?', '', text)
    # Remove markdown links [text](url) -> text
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    # Remove code backticks
    text = re.sub(r'`+', '', text)
    # Remove markdown bullet points
    text = re.sub(r'^\s*[-*+]\s+', '', text, flags=re.MULTILINE)
    # Clean up double spaces
    text = re.sub(r'[ \t]+', ' ', text)
    return text.strip()

router = APIRouter(prefix="/api/v1/sika", tags=["sika"])
sika_ai = SikaAI()
sika_nlp = SikaNLP()

@router.get("/health", summary="Health Check", description="Vérifie si le service est actif.")
def sika_health_check():
    """Route technique pour le monitoring SIKA AI"""
    return {
        "status": "ready",
        "service": "Sika AI Standalone API",
        "provider": sika_ai.provider.upper(),
        "model": sika_ai.model
    }

# ============================================================================
# ENDPOINTS OAUTH2 BEARER JWT AUTHENTICATION
# ============================================================================

@router.post("/auth/login", summary="Login via Email/Password", description="Connexion OAuth2 avec génération de jeton Bearer JWT.")
def auth_login(data: AuthLoginRequest):
    """Connexion OAuth2 avec génération de jeton Bearer JWT."""
    if not data.email or not data.password:
        raise HTTPException(status_code=400, detail="Email et mot de passe requis.")
    return oauth2_auth_service.login(data.email, data.password)

@router.post("/auth/register", summary="Register Account", description="Inscription d'un nouvel utilisateur avec jeton OAuth2.")
def auth_register(data: AuthRegisterRequest):
    """Inscription d'un nouvel utilisateur avec jeton OAuth2."""
    if not data.name or not data.email or not data.password:
        raise HTTPException(status_code=400, detail="Tous les champs sont requis.")
    return oauth2_auth_service.register(data.name, data.email, data.password)

@router.post("/auth/google", summary="Login via Google", description="Authentification OAuth2 via Google Sign-In.")
def auth_google(data: AuthGoogleRequest):
    """Authentification OAuth2 via Google Sign-In officiel."""
    name = data.name or "Utilisateur Google"
    if not data.email and not data.id_token:
        raise HTTPException(status_code=400, detail="Adresse email ou id_token Google requis.")
    return oauth2_auth_service.google_login(email=data.email, name=name, id_token=data.id_token)

@router.get("/auth/paypal/start", summary="Start Log in with PayPal",
            description="Renvoie l'URL d'autorisation PayPal (sandbox) et un state signé valable 10 minutes.")
def auth_paypal_start():
    from ..services.paypal_identity_service import paypal_identity_service
    return paypal_identity_service.start()


@router.post("/auth/paypal", summary="Complete Log in with PayPal",
             description="Échange le code PayPal côté serveur, lit le profil PayPal vérifié et ouvre la session SIKA.")
def auth_paypal(data: AuthPayPalRequest):
    from ..services.paypal_identity_service import paypal_identity_service
    return paypal_identity_service.complete(data.code, data.state)


@router.get("/auth/paypal/return", summary="Log in with PayPal return page", include_in_schema=False)
def auth_paypal_return(request: Request):
    """URL de retour web déclarée chez PayPal : renvoie code/state (ou l'erreur) à l'application mobile.

    Le code n'est pas échangé ici : l'app le transmet à POST /auth/paypal avec le state signé.
    """
    import html
    from urllib.parse import urlencode
    from fastapi.responses import HTMLResponse
    from ..config import settings

    params = {k: request.query_params[k] for k in ("code", "state", "error") if k in request.query_params}
    if not params:
        params = {"error": "missing_code"}
    target = html.escape(f"{settings.PAYPAL_LOGIN_APP_REDIRECT}?{urlencode(params)}", quote=True)
    page = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><meta http-equiv="refresh" content="0;url={target}">
<title>SIKA Pay</title></head>
<body style="font-family:sans-serif;text-align:center;padding:48px 20px;color:#0D1B3E">
<p>Retour vers SIKA Pay…</p>
<p><a href="{target}" style="display:inline-block;padding:14px 22px;border-radius:14px;background:#1463FF;color:#fff;text-decoration:none">Ouvrir SIKA Pay</a></p>
</body></html>"""
    return HTMLResponse(page, headers={"Cache-Control": "no-store"})


@router.get("/auth/me", summary="Get current user", description="Route protégée vérifiant le jeton OAuth2 Bearer.")
def auth_me(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    """Route protégée vérifiant le jeton OAuth2 Bearer."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Jeton Authorization Bearer manquant.")
    token = authorization.split(" ")[1]
    payload = oauth2_auth_service.verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Jeton invalide ou expiré.")
    
    # Fetch latest user state from DB
    user_id = payload.get("user_id")
    if user_id:
        user = db.query(UserModel).filter(UserModel.id == user_id).first()
        if user:
            from ..services.user_profile import profile_status
            payload["full_name"] = user.full_name
            payload["phone"] = user.phone
            payload["country"] = user.country
            payload["is_kyc_verified"] = user.kyc_status == "paypal"
            payload["profile"] = profile_status(user)

    return {
        "status": "AUTHENTICATED",
        "user": payload
    }


@router.post("/auth/logout")
def auth_logout(authorization: Optional[str] = Header(None)):
    """Invalide et révoque le jeton Bearer JWT actif de l'utilisateur."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Jeton Authorization Bearer manquant.")
    token = authorization.split(" ")[1]
    security_rate_limiter.revoke_token(token)
    return {
        "success": True,
        "status": "LOGGED_OUT",
        "message": "Déconnexion réussie et jeton révoqué côté serveur."
    }

@router.post("/auth/forgot-password", summary="Forgot Password", description="Demande de réinitialisation de mot de passe (génère un OTP).")
def auth_forgot_password(data: AuthForgotPasswordRequest):
    """Demande de réinitialisation de mot de passe (génère un OTP)."""
    if not data.email:
        raise HTTPException(status_code=400, detail="L'adresse email est requise.")
    return oauth2_auth_service.generate_password_reset_otp(data.email)

@router.post("/auth/reset-password", summary="Reset Password", description="Réinitialise le mot de passe avec un OTP valide.")
def auth_reset_password(data: AuthResetPasswordRequest):
    """Réinitialise le mot de passe avec un OTP valide."""
    if not data.email or not data.otp or not data.new_password:
        raise HTTPException(status_code=400, detail="Tous les champs (email, otp, new_password) sont requis.")
    return oauth2_auth_service.reset_password_with_otp(data.email, data.otp, data.new_password)

# ============================================================================
# ENDPOINTS SIKA CHAT & AGENT
# ============================================================================

@router.post("/chat", response_model=SikaResponseDTO)
async def sika_chat(data: SikaQueryDTO, request: Request, authorization: Optional[str] = Header(None)):
    """Endpoint principal SIKA AI."""
    # Authentification stricte obligatoire
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    
    # Protection Rate Limiting pour l'IA
    security_rate_limiter.check_ai_rate_limit(str(user_id))
        
    ctx_dict = data.context if isinstance(data.context, dict) else (data.context.dict() if data.context else {})
    # Le prénom vient du compte authentifié ; celui envoyé par l'app ne sert que s'il n'y en a pas
    from ..services.user_profile import account_first_name
    firstname = account_first_name(user_id) or str(ctx_dict.get("user_firstname") or "").strip()[:40]


    from ..agent.session_manager import sika_session_manager
    session = sika_session_manager.get_user_session(str(user_id))
    history = session.get("history", [])

    result = await sika_ai.chat(
        user_message=data.query,
        financial_context=ctx_dict,
        conversation_history=history,
        user_firstname=firstname,
        user_id=str(user_id)
    )

    history.append({"role": "user", "content": data.query})
    history.append({"role": "model", "content": result.get("response", "")})
    session["history"] = history[-10:]
    sika_session_manager.save_user_session(str(user_id), session)

    raw_response = result.get("response", result.get("message", ""))
    cleaned_message = strip_markdown(raw_response)

    detected_language = result.get("language") or sika_ai.detect_language(data.query)

    raw_speech = strip_markdown(result.get("speech_text", raw_response))
    # Transformation des nombres avec espaces (ex: "1 800 000" -> "1800000") pour un rendu vocal fluide
    cleaned_speech = re.sub(r'(\d)\s+(?=\d)', r'\1', raw_speech)
    curr_code = str(ctx_dict.get("currency_code", "")).upper()
    curr_sym = str(ctx_dict.get("currency_symbol", "")).upper()
    if detected_language == "fr" and (curr_code in ["XOF", "FCFA"] or curr_sym == "FCFA"):
        cleaned_speech = cleaned_speech.replace("FCFA", "francs CFA")

    return SikaResponseDTO(
        query=data.query,
        message=cleaned_message,
        intent=result.get("intent", result.get("action", "chat")),
        sentiment=result.get("sentiment", "positive"),
        suggestions=result.get("suggestions", []),
        provider=result.get("provider", sika_ai.provider.upper()),
        status=result.get("status", "PROCESSED"),
        action_id=result.get("action_id"),
        requires_confirmation=result.get("requires_confirmation", False),
        requires_biometric=result.get("requires_biometric", result.get("requires_confirmation", False)),
        requires_security_validation=result.get("requires_security_validation", result.get("requires_confirmation", False)),
        should_speak=result.get("should_speak", True),
        speech_text=cleaned_speech,
        language=detected_language,
        action_data=result.get("action_data"),
        agent_steps=result.get("agent_steps", []),
    )

from ..services.gcp_tts_service import gcp_tts_service


@router.post("/tts", summary="Generate TTS", description="Génère la synthèse vocale MP3 haute fidélité via Google Cloud Text-to-Speech (GCP TTS).")
def sika_text_to_speech(data: TTSRequest, authorization: Optional[str] = Header(None)):
    """Génère la synthèse vocale MP3 (Google Cloud TTS). Réservé aux utilisateurs connectés : chaque appel est facturé."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    security_rate_limiter.check_ai_rate_limit(f"tts_{user_id}", max_requests=40)
    text = (data.text or data.speech_text or "")[:2000]
    voice_name = data.voice_name
    language_code = data.language_code
    speaking_rate = float(data.speaking_rate)

    if not text:
        raise HTTPException(status_code=400, detail="Le champ 'text' est obligatoire.")

    res = gcp_tts_service.synthesize_speech(
        text=text,
        voice_name=voice_name,
        language_code=language_code,
        speaking_rate=speaking_rate
    )
    if not res.get("success"):
        raise HTTPException(status_code=500, detail=res.get("error", "Échec GCP TTS"))

    return res


@router.websocket("/voice/live")
async def sika_voice_live(websocket: WebSocket):
    """Assistant vocal en langage naturel (Gemini Live). Authentifié par le premier message, jamais par l'URL."""
    from ..services.sika_voice_live import handle_voice_socket
    await handle_voice_socket(websocket)


@router.get("/tts/voices", summary="List TTS Voices", description="Liste les voix françaises de haute qualité disponibles sur Google Cloud Text-to-Speech.")
def sika_list_tts_voices():
    """Liste les voix françaises de haute qualité disponibles sur Google Cloud Text-to-Speech."""
    return gcp_tts_service.list_french_voices()


@router.post("/agent/process", summary="Agent Process", description="Endpoint principal de traitement de la boucle Agent Taskmaster (Exige JWT).")
async def sika_agent_process(data: AgentProcessRequest, authorization: Optional[str] = Header(None)):
    """Endpoint principal de traitement de la boucle Agent Taskmaster (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    security_rate_limiter.check_ai_rate_limit(str(user_id))
    query = data.query
    return await sika_orchestrator.process_user_request(user_id=user_id, query=query)


