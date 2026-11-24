import 'dart:convert';
import '../core/chat_theme.dart';

enum AiProviderType {
  geminiStudio,
  copilotStudio,
}

enum CopilotConnectionMode {
  directLineSecret,
  tokenEndpoint,
  customWebhook,
}

enum MessageRole {
  user,
  assistant,
  system,
}

class ChatCodeArtifact {
  final String language;
  final String code;
  final String title;

  const ChatCodeArtifact({
    required this.language,
    required this.code,
    required this.title,
  });
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final AiProviderType provider;
  final String modelName;
  final bool isError;
  final int? latencyMs;
  final List<String> suggestedActions;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.provider,
    required this.modelName,
    this.isError = false,
    this.latencyMs,
    this.suggestedActions = const [],
  });

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? createdAt,
    AiProviderType? provider,
    String? modelName,
    bool? isError,
    int? latencyMs,
    List<String>? suggestedActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      modelName: modelName ?? this.modelName,
      isError: isError ?? this.isError,
      latencyMs: latencyMs ?? this.latencyMs,
      suggestedActions: suggestedActions ?? this.suggestedActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'provider': provider.name,
      'modelName': modelName,
      'isError': isError,
      'latencyMs': latencyMs,
      'suggestedActions': suggestedActions,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] ?? 'assistant').toString();
    final provStr = (json['provider'] ?? 'geminiStudio').toString();
    final rawSuggestions = json['suggestedActions'];
    return ChatMessage(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      role: MessageRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => MessageRole.assistant,
      ),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      provider: AiProviderType.values.firstWhere(
        (e) => e.name == provStr,
        orElse: () => AiProviderType.geminiStudio,
      ),
      modelName: (json['modelName'] ?? 'gemini-2.5-flash').toString(),
      isError: json['isError'] == true,
      latencyMs: json['latencyMs'] is num ? (json['latencyMs'] as num).toInt() : null,
      suggestedActions: rawSuggestions is List
          ? rawSuggestions.map((e) => e.toString()).toList()
          : const [],
    );
  }

  List<ChatCodeArtifact> extractCodeArtifacts() {
    final regex = RegExp(r'```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```', multiLine: true);
    final matches = regex.allMatches(content);
    final list = <ChatCodeArtifact>[];
    var idx = 1;
    for (final m in matches) {
      final lang = (m.group(1) ?? '').trim();
      final code = (m.group(2) ?? '').trimRight();
      if (code.isEmpty) continue;
      list.add(
        ChatCodeArtifact(
          language: lang.isEmpty ? 'text' : lang,
          code: code,
          title: lang.isEmpty ? 'Snippet #$idx' : '${lang.toUpperCase()} Artifact #$idx',
        ),
      );
      idx++;
    }
    return list;
  }
}

class ChatThread {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AiProviderType provider;
  final String modelName;
  final List<ChatMessage> messages;
  final String? copilotConversationId;
  final String? copilotWatermark;

  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.provider,
    required this.modelName,
    required this.messages,
    this.copilotConversationId,
    this.copilotWatermark,
  });

  ChatThread copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    AiProviderType? provider,
    String? modelName,
    List<ChatMessage>? messages,
    String? copilotConversationId,
    String? copilotWatermark,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      provider: provider ?? this.provider,
      modelName: modelName ?? this.modelName,
      messages: messages ?? this.messages,
      copilotConversationId: copilotConversationId ?? this.copilotConversationId,
      copilotWatermark: copilotWatermark ?? this.copilotWatermark,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'provider': provider.name,
      'modelName': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'copilotConversationId': copilotConversationId,
      'copilotWatermark': copilotWatermark,
    };
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final provStr = (json['provider'] ?? 'geminiStudio').toString();
    final rawMsgs = json['messages'];
    return ChatThread(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      title: (json['title'] ?? 'Percakapan Baru').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      provider: AiProviderType.values.firstWhere(
        (e) => e.name == provStr,
        orElse: () => AiProviderType.geminiStudio,
      ),
      modelName: (json['modelName'] ?? 'gemini-2.5-flash').toString(),
      messages: rawMsgs is List
          ? rawMsgs
              .whereType<Map>()
              .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      copilotConversationId: json['copilotConversationId']?.toString(),
      copilotWatermark: json['copilotWatermark']?.toString(),
    );
  }
}

class AiProviderConfig {
  final AiProviderType activeProvider;
  final BtVisualStyle visualStyle;

  // Gemini AI Studio Configuration
  final String geminiApiKey;
  final String geminiModel;
  final String geminiBaseUrl;
  final double temperature;
  final int maxOutputTokens;
  final String systemInstruction;

  // Microsoft Copilot Studio Configuration
  final CopilotConnectionMode copilotMode;
  final String copilotDirectLineSecret;
  final String copilotTokenEndpoint;
  final String copilotWebhookUrl;
  final String copilotWebhookAuthHeader;
  final String copilotBotName;
  final String copilotUserId;
  final String copilotUserName;

  static const String bundledGeminiApiKey =
      String.fromEnvironment('DEFAULT_GEMINI_API_KEY', defaultValue: '');

  const AiProviderConfig({
    this.activeProvider = AiProviderType.geminiStudio,
    this.visualStyle = BtVisualStyle.gemini,
    this.geminiApiKey = bundledGeminiApiKey,
    this.geminiModel = 'gemini-3-flash-preview',
    this.geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.temperature = 0.4,
    this.maxOutputTokens = 8192,
    this.systemInstruction =
        'Kamu adalah BTchat AI Assistant, asisten AI Software Engineering & Enterprise Automation untuk developer Bungtemin. '
        'Berikan jawaban yang terstruktur, akurat, menggunakan Markdown yang rapi, dan sertakan kode siap pakai dengan best-practice.',
    this.copilotMode = CopilotConnectionMode.directLineSecret,
    this.copilotDirectLineSecret =
        const String.fromEnvironment('DEFAULT_COPILOT_SECRET', defaultValue: ''),
    this.copilotTokenEndpoint =
        const String.fromEnvironment('DEFAULT_COPILOT_TOKEN_ENDPOINT', defaultValue: ''),
    this.copilotWebhookUrl =
        const String.fromEnvironment('DEFAULT_COPILOT_WEBHOOK_URL', defaultValue: ''),
    this.copilotWebhookAuthHeader = '',
    this.copilotBotName = 'Copilot Studio Agent',
    this.copilotUserId = 'btchat-dev-user',
    this.copilotUserName = 'Developer',
  });

  static const List<String> geminiModels = [
    'gemini-3-flash-preview',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
  ];

  bool get isGeminiConfigured => geminiApiKey.trim().isNotEmpty;

  bool get isCopilotConfigured {
    switch (copilotMode) {
      case CopilotConnectionMode.directLineSecret:
        return copilotDirectLineSecret.trim().isNotEmpty;
      case CopilotConnectionMode.tokenEndpoint:
        return copilotTokenEndpoint.trim().isNotEmpty;
      case CopilotConnectionMode.customWebhook:
        return copilotWebhookUrl.trim().isNotEmpty;
    }
  }

  bool get isActiveProviderReady =>
      activeProvider == AiProviderType.geminiStudio ? isGeminiConfigured : isCopilotConfigured;

  String get activeModelDisplay {
    if (activeProvider == AiProviderType.geminiStudio) {
      return geminiModel;
    }
    return copilotBotName.trim().isEmpty ? 'Copilot Studio' : copilotBotName;
  }

  String get activeProviderLabel =>
      activeProvider == AiProviderType.geminiStudio ? 'Gemini AI Studio' : 'Copilot Studio';

  AiProviderConfig copyWith({
    AiProviderType? activeProvider,
    BtVisualStyle? visualStyle,
    String? geminiApiKey,
    String? geminiModel,
    String? geminiBaseUrl,
    double? temperature,
    int? maxOutputTokens,
    String? systemInstruction,
    CopilotConnectionMode? copilotMode,
    String? copilotDirectLineSecret,
    String? copilotTokenEndpoint,
    String? copilotWebhookUrl,
    String? copilotWebhookAuthHeader,
    String? copilotBotName,
    String? copilotUserId,
    String? copilotUserName,
  }) {
    return AiProviderConfig(
      activeProvider: activeProvider ?? this.activeProvider,
      visualStyle: visualStyle ?? this.visualStyle,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      geminiBaseUrl: geminiBaseUrl ?? this.geminiBaseUrl,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      systemInstruction: systemInstruction ?? this.systemInstruction,
      copilotMode: copilotMode ?? this.copilotMode,
      copilotDirectLineSecret: copilotDirectLineSecret ?? this.copilotDirectLineSecret,
      copilotTokenEndpoint: copilotTokenEndpoint ?? this.copilotTokenEndpoint,
      copilotWebhookUrl: copilotWebhookUrl ?? this.copilotWebhookUrl,
      copilotWebhookAuthHeader: copilotWebhookAuthHeader ?? this.copilotWebhookAuthHeader,
      copilotBotName: copilotBotName ?? this.copilotBotName,
      copilotUserId: copilotUserId ?? this.copilotUserId,
      copilotUserName: copilotUserName ?? this.copilotUserName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeProvider': activeProvider.name,
      'visualStyle': visualStyle.name,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'geminiBaseUrl': geminiBaseUrl,
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
      'systemInstruction': systemInstruction,
      'copilotMode': copilotMode.name,
      'copilotDirectLineSecret': copilotDirectLineSecret,
      'copilotTokenEndpoint': copilotTokenEndpoint,
      'copilotWebhookUrl': copilotWebhookUrl,
      'copilotWebhookAuthHeader': copilotWebhookAuthHeader,
      'copilotBotName': copilotBotName,
      'copilotUserId': copilotUserId,
      'copilotUserName': copilotUserName,
    };
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    const defaults = AiProviderConfig();
    final provStr = (json['activeProvider'] ?? defaults.activeProvider.name).toString();
    final styleStr = (json['visualStyle'] ?? defaults.visualStyle.name).toString();
    final modeStr = (json['copilotMode'] ?? defaults.copilotMode.name).toString();
    final rawSavedKey = (json['geminiApiKey'] ?? '').toString().trim();
    final rawSavedModel = (json['geminiModel'] ?? '').toString().trim();
    const deprecatedModels = {
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    };

    return AiProviderConfig(
      activeProvider: AiProviderType.values.firstWhere(
        (e) => e.name == provStr,
        orElse: () => defaults.activeProvider,
      ),
      visualStyle: BtVisualStyle.values.firstWhere(
        (e) => e.name == styleStr,
        orElse: () => defaults.visualStyle,
      ),
      geminiApiKey: rawSavedKey.isNotEmpty ? rawSavedKey : defaults.geminiApiKey,
      geminiModel: (rawSavedModel.isEmpty || deprecatedModels.contains(rawSavedModel))
          ? defaults.geminiModel
          : rawSavedModel,
      geminiBaseUrl: (json['geminiBaseUrl'] ?? defaults.geminiBaseUrl).toString(),
      temperature: json['temperature'] is num
          ? (json['temperature'] as num).toDouble().clamp(0.0, 2.0)
          : defaults.temperature,
      maxOutputTokens: json['maxOutputTokens'] is num
          ? (json['maxOutputTokens'] as num).toInt().clamp(256, 65536)
          : defaults.maxOutputTokens,
      systemInstruction: (json['systemInstruction'] ?? defaults.systemInstruction).toString(),
      copilotMode: CopilotConnectionMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => defaults.copilotMode,
      ),
      copilotDirectLineSecret:
          (json['copilotDirectLineSecret'] ?? defaults.copilotDirectLineSecret).toString(),
      copilotTokenEndpoint:
          (json['copilotTokenEndpoint'] ?? defaults.copilotTokenEndpoint).toString(),
      copilotWebhookUrl: (json['copilotWebhookUrl'] ?? defaults.copilotWebhookUrl).toString(),
      copilotWebhookAuthHeader:
          (json['copilotWebhookAuthHeader'] ?? defaults.copilotWebhookAuthHeader).toString(),
      copilotBotName: (json['copilotBotName'] ?? defaults.copilotBotName).toString(),
      copilotUserId: (json['copilotUserId'] ?? defaults.copilotUserId).toString(),
      copilotUserName: (json['copilotUserName'] ?? defaults.copilotUserName).toString(),
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory AiProviderConfig.fromRawJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AiProviderConfig.fromJson(decoded);
      }
    } catch (_) {}
    return const AiProviderConfig();
  }
}

class QuickPromptTemplate {
  final String title;
  final String subtitle;
  final String prompt;
  final String badge;

  const QuickPromptTemplate({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.badge,
  });

  static const List<QuickPromptTemplate> defaults = [
    QuickPromptTemplate(
      title: 'Arsitektur & Code Review',
      subtitle: 'Analisis kode Flutter / Node.js / PHP untuk performa & keamanan',
      badge: 'Engineering',
      prompt:
          'Tolong bantu saya melakukan code review dan optimasi arsitektur kode berikut. '
          'Jelaskan potensi bug, celah keamanan, serta berikan versi refactor yang bersih dan modular:\n\n```\n// Tempel kode di sini\n```',
    ),
    QuickPromptTemplate(
      title: 'Debug Error & Stacktrace',
      subtitle: 'Diagnosa cepat root cause dari log error atau crash',
      badge: 'Debugging',
      prompt:
          'Saya menemukan error / stacktrace berikut saat menjalankan aplikasi. '
          'Tolong jelaskan penyebab utamanya (root cause) dan langkah perbaikannya secara bertahap:\n\n```\n// Tempel log error di sini\n```',
    ),
    QuickPromptTemplate(
      title: 'Rancang Integrasi API & Webhook',
      subtitle: 'Buat endpoint REST API, payload JSON, dan error handling',
      badge: 'Backend API',
      prompt:
          'Buatkan desain dan implementasi endpoint REST API beserta validasi request, '
          'otentikasi header, dan format respons JSON standar untuk skenario berikut:\n\n- Fitur: ',
    ),
    QuickPromptTemplate(
      title: 'Copilot Studio Agent Prompt',
      subtitle: 'Uji topik, alur Power Automate, atau respons adaptive agent',
      badge: 'Copilot Studio',
      prompt:
          'Halo Copilot Agent! Tolong tampilkan daftar kapabilitas topik atau workflow otomasi yang tersedia serta contoh cara memanggilnya.',
    ),
  ];
}
