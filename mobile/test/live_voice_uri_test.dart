import 'package:flutter_test/flutter_test.dart';
import 'package:sika_assistant_mobile/core/config/app_config.dart';
import 'package:sika_assistant_mobile/features/ai_assistant/services/sika_live_voice.dart';

void main() {
  test('la conversation vocale utilise le même serveur que l\'API, en WebSocket', () {
    final uri = SikaLiveVoice.socketUri();
    final base = Uri.parse(AppConfig.baseUrl);
    expect(uri.host, base.host);
    expect(uri.scheme, base.scheme == 'https' ? 'wss' : 'ws');
    expect(uri.path, '/api/v1/sika/voice/live');
    expect(uri.query, isEmpty, reason: 'le jeton ne passe jamais dans l\'URL');
  });
}
