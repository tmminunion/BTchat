import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';

class AiReplyResult {
  final String text;
  final int latencyMs;
  final List<String> suggestedActions;
  final String? copilotConversationId;
  final String? copilotWatermark;

  const AiReplyResult({
    required this.text,
    required this.latencyMs,
    this.suggestedActions = const [],
    this.copilotConversationId,
    this.copilotWatermark,
  });
}

class AiChatService {
  final http.Client _client;

  AiChatService({http.Client? client}) : _client = client ?? http.Client();

  Future<AiReplyResult> sendMessage({
    required AiProviderConfig config,
    required List<ChatMessage> history,
    required String userPrompt,
    String? copilotConversationId,
    String? copilotWatermark,
  }) async {
    if (config.activeProvider == AiProviderType.geminiStudio) {
      return _sendGeminiMessage(
        config: config,
        history: history,
        userPrompt: userPrompt,
      );
    } else {
      return _sendCopilotMessage(
        config: config,
        history: history,
        userPrompt: userPrompt,
        existingConversationId: copilotConversationId,
        existingWatermark: copilotWatermark,
      );
    }
  }

  Future<String> testConnection(AiProviderConfig config) async {
    if (config.activeProvider == AiProviderType.geminiStudio) {
      if (!config.isGeminiConfigured) {
        throw Exception('API Key Gemini AI Studio belum diisi.');
      }
      final res = await _sendGeminiMessage(
        config: config,
        history: const [],
        userPrompt: 'Balas singkat dalam 1 kalimat: Status koneksi Gemini AI Studio aktif.',
      );
      return 'Gemini AI Studio (${config.geminiModel}) terhubung (${res.latencyMs} ms):\n${res.text}';
    } else {
      if (!config.isCopilotConfigured) {
        throw Exception('Kredensial / Endpoint Microsoft Copilot Studio belum diisi.');
      }
      final res = await _sendCopilotMessage(
        config: config,
        history: const [],
        userPrompt: 'hello',
      );
      return 'Copilot Studio (${config.copilotBotName}) terhubung (${res.latencyMs} ms):\n${res.text}';
    }
  }

  Future<AiReplyResult> _sendGeminiMessage({
    required AiProviderConfig config,
    required List<ChatMessage> history,
    required String userPrompt,
  }) async {
    final apiKey = config.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API Key belum dikonfigurasi. Buka menu Pengaturan AI (ikon gear di kanan atas) untuk memasukkan API Key dari Google AI Studio.',
      );
    }

    final sw = Stopwatch()..start();
    final baseUrl = config.geminiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final model = config.geminiModel.trim().isEmpty ? 'gemini-2.5-flash' : config.geminiModel.trim();
    final uri = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');

    final contents = <Map<String, dynamic>>[];
    final recentHistory = history.where((m) => !m.isError && m.content.trim().isNotEmpty).toList();
    final startIdx = recentHistory.length > 24 ? recentHistory.length - 24 : 0;

    for (var i = startIdx; i < recentHistory.length; i++) {
      final msg = recentHistory[i];
      if (msg.role == MessageRole.system) continue;
      contents.add({
        'role': msg.role == MessageRole.user ? 'user' : 'model',
        'parts': [
          {'text': msg.content}
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': userPrompt}
      ],
    });

    final payload = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': config.temperature,
        'maxOutputTokens': config.maxOutputTokens,
      },
    };

    if (config.systemInstruction.trim().isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [
          {'text': config.systemInstruction.trim()}
        ],
      };
    }

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));

    sw.stop();

    Map<String, dynamic> bodyMap = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        bodyMap = decoded;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errObj = bodyMap['error'];
      final errMsg = errObj is Map
          ? (errObj['message'] ?? 'HTTP ${response.statusCode}').toString()
          : 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Gagal menghubungi Gemini API'}';
      throw Exception('Gemini API Error: $errMsg');
    }

    final candidates = bodyMap['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map) {
        final content = first['content'];
        if (content is Map && content['parts'] is List) {
          final parts = content['parts'] as List;
          final buffer = StringBuffer();
          for (final p in parts) {
            if (p is Map && p['text'] != null) {
              buffer.write(p['text'].toString());
            }
          }
          final text = buffer.toString().trim();
          if (text.isNotEmpty) {
            return AiReplyResult(
              text: text,
              latencyMs: sw.elapsedMilliseconds,
            );
          }
        }
      }
    }

    throw Exception('Respons Gemini kosong atau diblokir oleh filter keamanan.');
  }

  Future<AiReplyResult> _sendCopilotMessage({
    required AiProviderConfig config,
    required List<ChatMessage> history,
    required String userPrompt,
    String? existingConversationId,
    String? existingWatermark,
  }) async {
    final sw = Stopwatch()..start();

    if (config.copilotMode == CopilotConnectionMode.customWebhook) {
      return _sendCopilotWebhook(
        config: config,
        history: history,
        userPrompt: userPrompt,
        existingConversationId: existingConversationId,
        sw: sw,
      );
    }

    // Direct Line v3 Mode (via Secret or Token Endpoint)
    String bearerToken = '';
    String? tokenConversationId;

    if (config.copilotMode == CopilotConnectionMode.tokenEndpoint) {
      final endpoint = config.copilotTokenEndpoint.trim();
      if (endpoint.isEmpty) {
        throw Exception('Copilot Studio Token Endpoint URL belum diisi di Pengaturan AI.');
      }
      final tokResp = await _client
          .get(Uri.parse(endpoint), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));

      if (tokResp.statusCode < 200 || tokResp.statusCode >= 300) {
        throw Exception(
          'Gagal mengambil token dari Copilot Token Endpoint (HTTP ${tokResp.statusCode}).',
        );
      }
      final tokJson = jsonDecode(utf8.decode(tokResp.bodyBytes));
      if (tokJson is Map) {
        bearerToken = (tokJson['token'] ?? '').toString().trim();
        tokenConversationId = tokJson['conversationId']?.toString();
      }
      if (bearerToken.isEmpty) {
        throw Exception('Respons Token Endpoint Copilot Studio tidak berisi field "token".');
      }
    } else {
      bearerToken = config.copilotDirectLineSecret.trim();
      if (bearerToken.isEmpty) {
        throw Exception(
          'Direct Line Secret / Token Copilot Studio belum dikonfigurasi. Buka Pengaturan AI untuk mengisinya.',
        );
      }
    }

    const dlBase = 'https://directline.botframework.com/v3/directline';
    final authHeaders = {
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };

    var convId = (existingConversationId ?? tokenConversationId ?? '').trim();
    var watermark = existingWatermark;

    if (convId.isEmpty) {
      final startResp = await _client
          .post(Uri.parse('$dlBase/conversations'), headers: authHeaders)
          .timeout(const Duration(seconds: 25));

      if (startResp.statusCode < 200 || startResp.statusCode >= 300) {
        throw Exception(
          'Gagal memulai sesi Direct Line Copilot Studio (HTTP ${startResp.statusCode}). Pastikan Direct Line Secret valid.',
        );
      }
      final startJson = jsonDecode(utf8.decode(startResp.bodyBytes));
      if (startJson is Map) {
        convId = (startJson['conversationId'] ?? '').toString();
        final refreshedToken = (startJson['token'] ?? '').toString();
        if (refreshedToken.isNotEmpty) {
          authHeaders['Authorization'] = 'Bearer $refreshedToken';
        }
      }
    }

    if (convId.isEmpty) {
      throw Exception('Copilot Studio tidak mengembalikan conversationId.');
    }

    final userId = config.copilotUserId.trim().isEmpty ? 'btchat-user' : config.copilotUserId.trim();
    final userName =
        config.copilotUserName.trim().isEmpty ? 'Developer' : config.copilotUserName.trim();

    final activityPayload = {
      'type': 'message',
      'from': {
        'id': userId,
        'name': userName,
      },
      'text': userPrompt,
      'locale': 'id-ID',
    };

    final postActResp = await _client
        .post(
          Uri.parse('$dlBase/conversations/$convId/activities'),
          headers: authHeaders,
          body: jsonEncode(activityPayload),
        )
        .timeout(const Duration(seconds: 25));

    if (postActResp.statusCode < 200 || postActResp.statusCode >= 300) {
      throw Exception(
        'Gagal mengirim pesan ke Copilot Studio (HTTP ${postActResp.statusCode}).',
      );
    }

    String sentActivityId = '';
    try {
      final actJson = jsonDecode(utf8.decode(postActResp.bodyBytes));
      if (actJson is Map) {
        sentActivityId = (actJson['id'] ?? '').toString();
      }
    } catch (_) {}

    // Poll for bot replies (up to ~18 seconds)
    final botTexts = <String>[];
    final suggestions = <String>[];

    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 700 : 1100));
      final wmQuery = (watermark != null && watermark.isNotEmpty) ? '?watermark=$watermark' : '';
      final getResp = await _client
          .get(
            Uri.parse('$dlBase/conversations/$convId/activities$wmQuery'),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 20));

      if (getResp.statusCode < 200 || getResp.statusCode >= 300) {
        continue;
      }

      final data = jsonDecode(utf8.decode(getResp.bodyBytes));
      if (data is! Map) continue;

      final newWatermark = data['watermark']?.toString();
      if (newWatermark != null && newWatermark.isNotEmpty) {
        watermark = newWatermark;
      }

      final activities = data['activities'];
      if (activities is List) {
        for (final act in activities) {
          if (act is! Map) continue;
          final actId = (act['id'] ?? '').toString();
          if (actId == sentActivityId) continue;

          final from = act['from'];
          final fromId = from is Map ? (from['id'] ?? '').toString() : '';
          final fromRole = from is Map ? (from['role'] ?? '').toString().toLowerCase() : '';
          if (fromId == userId || fromRole == 'user') continue;

          final actType = (act['type'] ?? '').toString();
          if (actType != 'message') continue;

          final text = (act['text'] ?? '').toString().trim();
          if (text.isNotEmpty && !botTexts.contains(text)) {
            botTexts.add(text);
          }

          // Parse Adaptive Card / Hero Card text if text is empty
          final attachments = act['attachments'];
          if (attachments is List) {
            for (final att in attachments) {
              if (att is Map && att['content'] is Map) {
                final cardText = _extractCardSummary(Map<String, dynamic>.from(att['content']));
                if (cardText.isNotEmpty && !botTexts.contains(cardText)) {
                  botTexts.add(cardText);
                }
              }
            }
          }

          // Parse suggestedActions
          final sug = act['suggestedActions'];
          if (sug is Map && sug['actions'] is List) {
            for (final a in (sug['actions'] as List)) {
              if (a is Map) {
                final title = (a['title'] ?? a['value'] ?? '').toString().trim();
                if (title.isNotEmpty && !suggestions.contains(title)) {
                  suggestions.add(title);
                }
              }
            }
          }
        }
      }

      if (botTexts.isNotEmpty) {
        break;
      }
    }

    sw.stop();

    if (botTexts.isEmpty) {
      throw Exception(
        'Copilot Studio menerima pesan tetapi belum mengirimkan balasan. Pastikan agent Copilot sudah di-Publish dan topik pemicu aktif.',
      );
    }

    return AiReplyResult(
      text: botTexts.join('\n\n'),
      latencyMs: sw.elapsedMilliseconds,
      suggestedActions: suggestions,
      copilotConversationId: convId,
      copilotWatermark: watermark,
    );
  }

  Future<AiReplyResult> _sendCopilotWebhook({
    required AiProviderConfig config,
    required List<ChatMessage> history,
    required String userPrompt,
    required String? existingConversationId,
    required Stopwatch sw,
  }) async {
    final url = config.copilotWebhookUrl.trim();
    if (url.isEmpty) {
      throw Exception('URL Custom Webhook Copilot Studio belum diisi di Pengaturan AI.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (config.copilotWebhookAuthHeader.trim().isNotEmpty) {
      final rawAuth = config.copilotWebhookAuthHeader.trim();
      if (rawAuth.contains(':')) {
        final idx = rawAuth.indexOf(':');
        headers[rawAuth.substring(0, idx).trim()] = rawAuth.substring(idx + 1).trim();
      } else {
        headers['Authorization'] = rawAuth.startsWith('Bearer ') ? rawAuth : 'Bearer $rawAuth';
      }
    }

    final payload = {
      'message': userPrompt,
      'prompt': userPrompt,
      'text': userPrompt,
      'conversationId': existingConversationId ?? '',
      'userId': config.copilotUserId,
      'userName': config.copilotUserName,
      'history': history
          .where((m) => !m.isError)
          .map((m) => {'role': m.role.name, 'content': m.content})
          .toList(),
    };

    final resp = await _client
        .post(Uri.parse(url), headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 60));

    sw.stop();

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Webhook Copilot Error (HTTP ${resp.statusCode}): ${resp.body}');
    }

    final rawBody = utf8.decode(resp.bodyBytes).trim();
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map) {
        final reply = (decoded['reply'] ??
                decoded['text'] ??
                decoded['message'] ??
                decoded['output'] ??
                decoded['answer'] ??
                decoded['response'] ??
                '')
            .toString()
            .trim();
        final convId = decoded['conversationId']?.toString() ?? existingConversationId;
        if (reply.isNotEmpty) {
          return AiReplyResult(
            text: reply,
            latencyMs: sw.elapsedMilliseconds,
            copilotConversationId: convId,
          );
        }
      }
    } catch (_) {}

    if (rawBody.isNotEmpty) {
      return AiReplyResult(
        text: rawBody,
        latencyMs: sw.elapsedMilliseconds,
        copilotConversationId: existingConversationId,
      );
    }

    throw Exception('Respons Webhook Copilot kosong.');
  }

  String _extractCardSummary(Map<String, dynamic> content) {
    final lines = <String>[];
    final title = (content['title'] ?? '').toString().trim();
    final subtitle = (content['subtitle'] ?? '').toString().trim();
    final text = (content['text'] ?? '').toString().trim();
    if (title.isNotEmpty) lines.add('**$title**');
    if (subtitle.isNotEmpty) lines.add('_${subtitle}_');
    if (text.isNotEmpty) lines.add(text);

    final body = content['body'];
    if (body is List) {
      for (final item in body) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().trim();
          if (t.isNotEmpty) lines.add(t);
        }
      }
    }
    return lines.join('\n');
  }
}
