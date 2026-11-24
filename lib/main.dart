import 'package:flutter/material.dart';
import 'core/chat_theme.dart';
import 'features/chat/chat_workspace_screen.dart';
import 'models/chat_models.dart';
import 'services/chat_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BtChatApp());
}

class BtChatApp extends StatefulWidget {
  const BtChatApp({super.key});

  @override
  State<BtChatApp> createState() => _BtChatAppState();
}

class _BtChatAppState extends State<BtChatApp> {
  final ChatStorageService _storage = ChatStorageService();
  AiProviderConfig _config = const AiProviderConfig();
  List<ChatThread> _threads = const [];
  String? _activeThreadId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cfg = await _storage.loadConfig();
    final threads = await _storage.loadThreads();
    final activeId = await _storage.loadActiveThreadId();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _threads = threads;
      _activeThreadId = activeId;
      _ready = true;
    });
  }

  Future<void> _handleConfigChanged(AiProviderConfig newConfig) async {
    setState(() => _config = newConfig);
    await _storage.saveConfig(newConfig);
  }

  Future<void> _handleThreadsChanged(List<ChatThread> newThreads) async {
    setState(() => _threads = newThreads);
    await _storage.saveThreads(newThreads);
  }

  Future<void> _handleActiveThreadChanged(String? threadId) async {
    setState(() => _activeThreadId = threadId);
    await _storage.saveActiveThreadId(threadId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BtThemePalette.of(_config.visualStyle);
    return MaterialApp(
      title: 'BTchat',
      debugShowCheckedModeBanner: false,
      theme: buildBtChatTheme(_config.visualStyle),
      home: !_ready
          ? Scaffold(
              backgroundColor: palette.bg,
              body: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            )
          : ChatWorkspaceScreen(
              config: _config,
              initialThreads: _threads,
              initialActiveThreadId: _activeThreadId,
              onConfigChanged: _handleConfigChanged,
              onThreadsChanged: _handleThreadsChanged,
              onActiveThreadChanged: _handleActiveThreadChanged,
            ),
    );
  }
}
