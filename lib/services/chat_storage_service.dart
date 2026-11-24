import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class ChatStorageService {
  static const String _configKey = 'btchat_ai_config_v1';
  static const String _threadsKey = 'btchat_threads_v1';
  static const String _activeThreadIdKey = 'btchat_active_thread_id_v1';

  Future<AiProviderConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return const AiProviderConfig();
    }
    return AiProviderConfig.fromRawJson(raw);
  }

  Future<void> saveConfig(AiProviderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, config.toRawJson());
  }

  Future<List<ChatThread>> loadThreads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_threadsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveThreads(List<ChatThread> threads) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(threads.map((t) => t.toJson()).toList());
    await prefs.setString(_threadsKey, encoded);
  }

  Future<String?> loadActiveThreadId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeThreadIdKey);
  }

  Future<void> saveActiveThreadId(String? threadId) async {
    final prefs = await SharedPreferences.getInstance();
    if (threadId == null || threadId.isEmpty) {
      await prefs.remove(_activeThreadIdKey);
    } else {
      await prefs.setString(_activeThreadIdKey, threadId);
    }
  }
}
