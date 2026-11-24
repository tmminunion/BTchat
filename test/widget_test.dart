import 'package:btchat/core/chat_theme.dart';
import 'package:btchat/models/chat_models.dart';
import 'package:btchat/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AiProviderConfig serializes and deserializes Gemini & Copilot settings safely', () {
    const config = AiProviderConfig(
      activeProvider: AiProviderType.copilotStudio,
      visualStyle: BtVisualStyle.claude,
      geminiApiKey: 'AIzaTestKey123',
      geminiModel: 'gemini-3.6-flash',
      copilotMode: CopilotConnectionMode.directLineSecret,
      copilotDirectLineSecret: 'dl_secret_xyz',
      copilotBotName: 'Bungtemin Copilot Dev',
    );

    final raw = config.toRawJson();
    final parsed = AiProviderConfig.fromRawJson(raw);

    expect(parsed.activeProvider, AiProviderType.copilotStudio);
    expect(parsed.visualStyle, BtVisualStyle.claude);
    expect(parsed.geminiApiKey, 'AIzaTestKey123');
    expect(parsed.geminiModel, 'gemini-3.6-flash');
    expect(parsed.copilotDirectLineSecret, 'dl_secret_xyz');
    expect(parsed.copilotBotName, 'Bungtemin Copilot Dev');
    expect(parsed.isGeminiConfigured, isTrue);
    expect(parsed.isCopilotConfigured, isTrue);
    expect(parsed.isActiveProviderReady, isTrue);
  });

  test('ChatMessage extracts fenced code artifacts accurately', () {
    final msg = ChatMessage(
      id: 'm1',
      role: MessageRole.assistant,
      content: 'Berikut contoh kode:\n```dart\nvoid main() {\n  print("BTchat");\n}\n```\nDan SQL:\n```sql\nSELECT * FROM users;\n```',
      createdAt: DateTime.parse('2026-11-24T09:00:00Z'),
      provider: AiProviderType.geminiStudio,
      modelName: 'gemini-2.5-flash',
    );

    final artifacts = msg.extractCodeArtifacts();
    expect(artifacts.length, 2);
    expect(artifacts[0].language, 'dart');
    expect(artifacts[0].code.contains('BTchat'), isTrue);
    expect(artifacts[1].language, 'sql');
    expect(artifacts[1].code, 'SELECT * FROM users;');
  });

  test('QuickPromptTemplate defaults provide 4 development templates', () {
    expect(QuickPromptTemplate.defaults.length, 4);
  });

  test('parseWebhookResponse extracts reply cleanly from Power Automate JSON with raw newlines', () {
    const rawPowerAutomateResponse = '''{
  "status": "success",
  "reply": "Saya adalah asisten virtual berbasis AI. Saya dapat membantu Anda dengan:

- **Informasi Bungtemin:** mencari berita dan informasi dari situs bungtemin.net/news.
- **Pesan:** "Update Aplikasi Tersedia."

Silakan sampaikan apa yang Anda butuhkan, Nunu.",
  "conversationId": ""
}''';

    final parsed = AiChatService.parseWebhookResponse(rawPowerAutomateResponse);
    expect(parsed.reply.startsWith('Saya adalah asisten virtual berbasis AI.'), isTrue);
    expect(parsed.reply.contains('- **Informasi Bungtemin:**'), isTrue);
    expect(parsed.reply.endsWith('Nunu.'), isTrue);
    expect(parsed.reply.contains('"status"'), isFalse);
  });
}
