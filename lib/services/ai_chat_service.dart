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
    final primaryModel =
        config.geminiModel.trim().isEmpty ? 'gemini-3-flash-preview' : config.geminiModel.trim();

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

    final candidateModels = <String>[
      primaryModel,
      for (final m in const [
        'gemini-3-flash-preview',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-3.5-flash-lite',
        'gemini-flash-lite-latest',
      ])
        if (m != primaryModel) m,
    ];

    String lastErrorMsg = 'Gagal menghubungi Gemini API';

    for (var idx = 0; idx < candidateModels.length; idx++) {
      final model = candidateModels[idx];
      final uri = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      Map<String, dynamic> bodyMap = {};
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          bodyMap = decoded;
        }
      } catch (_) {}

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errObj = bodyMap['error'];
        lastErrorMsg = errObj is Map
            ? (errObj['message'] ?? 'HTTP ${response.statusCode}').toString()
            : 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Gagal menghubungi Gemini API'}';

        // Auto-fallback jika model deprecated (404), kuota model penuh (429), atau high demand (503)
        final shouldFallback =
            response.statusCode == 404 || response.statusCode == 429 || response.statusCode == 503;
        if (shouldFallback && idx < candidateModels.length - 1) {
          continue;
        }
        sw.stop();
        throw Exception('Gemini API Error ($model): $lastErrorMsg');
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
              sw.stop();
              return AiReplyResult(
                text: text,
                latencyMs: sw.elapsedMilliseconds,
              );
            }
          }
        }
      }
    }

    sw.stop();
    throw Exception('Respons Gemini kosong atau diblokir oleh filter keamanan ($lastErrorMsg).');
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

    // Inject multi-turn context if workflow is stateless (no conversationId)
    var messageText = userPrompt;
    final cleanHistory = history.where((m) => !m.isError && m.content.trim().isNotEmpty).toList();
    if ((existingConversationId ?? '').trim().isEmpty && cleanHistory.isNotEmpty) {
      final startIdx = cleanHistory.length > 6 ? cleanHistory.length - 6 : 0;
      final histLines = <String>[];
      for (var i = startIdx; i < cleanHistory.length; i++) {
        final m = cleanHistory[i];
        final roleLabel = m.role == MessageRole.user ? config.copilotUserName : config.copilotBotName;
        final snippet = m.content.trim();
        final clipped = snippet.length > 500 ? '${snippet.substring(0, 500)}...' : snippet;
        histLines.add('$roleLabel: $clipped');
      }
      if (histLines.isNotEmpty) {
        messageText = '[Riwayat percakapan sebelumnya]\n'
            '${histLines.join('\n')}\n\n'
            '[Pesan terbaru dari ${config.copilotUserName}]\n'
            '$userPrompt';
      }
    }

    final payload = {
      'message': messageText,
      'prompt': userPrompt,
      'text': messageText,
      'conversationId': existingConversationId ?? '',
      'noreg': config.copilotUserId,
      'nama': config.copilotUserName,
      'userId': config.copilotUserId,
      'userName': config.copilotUserName,
    };

    final resp = await _client
        .post(Uri.parse(url), headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 120));

    sw.stop();

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Webhook Copilot Error (HTTP ${resp.statusCode}): ${resp.body}');
    }

    final rawBody = utf8.decode(resp.bodyBytes).trim();
    final parsed = parseWebhookResponse(rawBody, fallbackConvId: existingConversationId);
    if (parsed.reply.isNotEmpty) {
      return AiReplyResult(
        text: parsed.reply,
        latencyMs: sw.elapsedMilliseconds,
        copilotConversationId: parsed.conversationId,
      );
    }

    throw Exception('Respons Webhook Copilot kosong.');
  }

  /// Parses Power Automate / Copilot Studio webhook JSON even when the server
  /// emits unescaped literal newlines or quotes inside the "reply" string.
  static ({String reply, String? conversationId}) parseWebhookResponse(
    String rawBody, {
    String? fallbackConvId,
  }) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return (reply: '', conversationId: fallbackConvId);
    }

    // 1. Standard JSON decode
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final reply = _pickReplyFromMap(decoded);
        final convId = _pickConvIdFromMap(decoded) ?? fallbackConvId;
        if (reply.isNotEmpty) {
          return (reply: reply, conversationId: convId);
        }
      }
    } catch (_) {}

    // 2. Sanitize raw control characters (literal \r, \n, \t) inside JSON strings
    final sanitized = _escapeControlCharsInsideJsonStrings(trimmed);
    if (sanitized != trimmed) {
      try {
        final decoded = jsonDecode(sanitized);
        if (decoded is Map) {
          final reply = _pickReplyFromMap(decoded);
          final convId = _pickConvIdFromMap(decoded) ?? fallbackConvId;
          if (reply.isNotEmpty) {
            return (reply: reply, conversationId: convId);
          }
        }
      } catch (_) {}
    }

    // 3. Resilient field extractor for Power Automate malformed JSON
    //    (e.g. unescaped inner quotes like "Update Aplikasi Tersedia." + raw newlines)
    final keyMatch = RegExp(
      r'"(?:reply|text|message|output|answer|response)"\s*:\s*"',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (keyMatch != null) {
      final start = keyMatch.end;
      var end = -1;

      final nextKeyMatch = RegExp(
        r'"\s*,\s*"[a-zA-Z0-9_]+"|\s*"\s*\n?\s*\}',
      ).allMatches(trimmed, start);
      if (nextKeyMatch.isNotEmpty) {
        // Pick the last structural boundary before the closing object or next JSON field
        final convBoundary = RegExp(
          r'"\s*,\s*"conversationId"\s*:',
          caseSensitive: false,
        ).firstMatch(trimmed.substring(start));
        if (convBoundary != null) {
          end = start + convBoundary.start;
        } else {
          end = nextKeyMatch.last.start;
        }
      }

      if (end > start) {
        var extracted = trimmed.substring(start, end);
        extracted = extracted
            .replaceAll(r'\r\n', '\n')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\')
            .trim();

        String? convId = fallbackConvId;
        final convMatch = RegExp(
          r'"conversationId"\s*:\s*"([^"]*)"',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (convMatch != null) {
          final c = (convMatch.group(1) ?? '').trim();
          if (c.isNotEmpty) convId = c;
        }

        if (extracted.isNotEmpty) {
          return (reply: extracted, conversationId: convId);
        }
      }
    }

    return (reply: trimmed, conversationId: fallbackConvId);
  }

  static String _pickReplyFromMap(Map decoded) {
    return (decoded['reply'] ??
            decoded['text'] ??
            decoded['message'] ??
            decoded['output'] ??
            decoded['answer'] ??
            decoded['response'] ??
            '')
        .toString()
        .trim();
  }

  static String? _pickConvIdFromMap(Map decoded) {
    final c = (decoded['conversationId'] ?? '').toString().trim();
    return c.isEmpty ? null : c;
  }

  static String _escapeControlCharsInsideJsonStrings(String input) {
    final buf = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        buf.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        buf.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        buf.write(ch);
        continue;
      }
      if (inString) {
        if (ch == '\n') {
          buf.write(r'\n');
          continue;
        }
        if (ch == '\r') {
          buf.write(r'\r');
          continue;
        }
        if (ch == '\t') {
          buf.write(r'\t');
          continue;
        }
      }
      buf.write(ch);
    }
    return buf.toString();
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
