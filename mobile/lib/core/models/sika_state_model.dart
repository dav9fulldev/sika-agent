/// SikaState — Execution states for the SIKA Agent.
enum SikaState {
  idle, // En attente
  listening, // Écoute vocale active
  processing, // Analyse LLM / Tool execution
  speaking, // Restitution vocale TTS
  error, // Erreur réseau / permission
}
