/// SikaMessage — Conversational message model in SIKA Agent Hub.
class SikaMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? suggestedTransaction;
  final bool canAddTransaction;

  SikaMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.suggestedTransaction,
    this.canAddTransaction = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
