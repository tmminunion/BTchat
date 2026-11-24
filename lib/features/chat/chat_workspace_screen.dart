import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/chat_theme.dart';
import '../../models/chat_models.dart';
import '../../services/ai_chat_service.dart';
import '../settings/ai_settings_sheet.dart';
import 'markdown_message_view.dart';

class ChatWorkspaceScreen extends StatefulWidget {
  final AiProviderConfig config;
  final List<ChatThread> initialThreads;
  final String? initialActiveThreadId;
  final ValueChanged<AiProviderConfig> onConfigChanged;
  final ValueChanged<List<ChatThread>> onThreadsChanged;
  final ValueChanged<String?> onActiveThreadChanged;

  const ChatWorkspaceScreen({
    super.key,
    required this.config,
    required this.initialThreads,
    required this.initialActiveThreadId,
    required this.onConfigChanged,
    required this.onThreadsChanged,
    required this.onActiveThreadChanged,
  });

  @override
  State<ChatWorkspaceScreen> createState() => _ChatWorkspaceScreenState();
}

class _ChatWorkspaceScreenState extends State<ChatWorkspaceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _promptFocus = FocusNode();
  final AiChatService _chatService = AiChatService();

  late List<ChatThread> _threads;
  String? _activeThreadId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _threads = List<ChatThread>.from(widget.initialThreads);
    _activeThreadId = widget.initialActiveThreadId;
    if (_activeThreadId == null && _threads.isNotEmpty) {
      _activeThreadId = _threads.first.id;
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  ChatThread? get _activeThread {
    if (_activeThreadId == null) return null;
    for (final t in _threads) {
      if (t.id == _activeThreadId) return t;
    }
    return null;
  }

  BtThemePalette get _palette => BtThemePalette.of(widget.config.visualStyle);

  void _createNewThread() {
    final now = DateTime.now();
    final newThread = ChatThread(
      id: 'thread_${now.millisecondsSinceEpoch}',
      title: 'Percakapan Baru',
      createdAt: now,
      updatedAt: now,
      provider: widget.config.activeProvider,
      modelName: widget.config.activeModelDisplay,
      messages: const [],
    );
    setState(() {
      _threads = [newThread, ..._threads];
      _activeThreadId = newThread.id;
    });
    widget.onThreadsChanged(_threads);
    widget.onActiveThreadChanged(_activeThreadId);
  }

  void _selectThread(String id) {
    setState(() => _activeThreadId = id);
    widget.onActiveThreadChanged(id);
    _scrollToBottom();
  }

  void _deleteThread(String id) {
    setState(() {
      _threads.removeWhere((t) => t.id == id);
      if (_activeThreadId == id) {
        _activeThreadId = _threads.isNotEmpty ? _threads.first.id : null;
      }
    });
    widget.onThreadsChanged(_threads);
    widget.onActiveThreadChanged(_activeThreadId);
  }

  void _toggleVisualStyle() {
    final nextStyle = widget.config.visualStyle == BtVisualStyle.gemini
        ? BtVisualStyle.claude
        : BtVisualStyle.gemini;
    widget.onConfigChanged(widget.config.copyWith(visualStyle: nextStyle));
  }

  void _switchProvider(AiProviderType provider) {
    widget.onConfigChanged(widget.config.copyWith(activeProvider: provider));
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiSettingsSheet(
        initialConfig: widget.config,
        chatService: _chatService,
        onSave: widget.onConfigChanged,
      ),
    );
  }

  void _openArtifactModal(ChatCodeArtifact artifact) {
    final p = _palette;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: p.codeBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: p.codeHeaderBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: p.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.code_rounded, color: p.accent, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artifact.title,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Claude / Gemini Code Artifact Preview (${artifact.language.toUpperCase()})',
                            style: TextStyle(color: p.textSecondary, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: artifact.code));
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Kode Artifact berhasil disalin!')),
                        );
                      },
                      icon: Icon(Icons.copy_rounded, size: 15, color: p.accent),
                      label: Text(
                        'Salin Semua',
                        style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      artifact.code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: p.textPrimary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final prompt = (overrideText ?? _promptCtrl.text).trim();
    if (prompt.isEmpty || _sending) return;

    if (overrideText == null) {
      _promptCtrl.clear();
    }

    final now = DateTime.now();
    ChatThread current = _activeThread ??
        ChatThread(
          id: 'thread_${now.millisecondsSinceEpoch}',
          title: _generateThreadTitle(prompt),
          createdAt: now,
          updatedAt: now,
          provider: widget.config.activeProvider,
          modelName: widget.config.activeModelDisplay,
          messages: const [],
        );

    final priorMessages = List<ChatMessage>.from(current.messages);
    final userMsg = ChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}_u',
      role: MessageRole.user,
      content: prompt,
      createdAt: now,
      provider: widget.config.activeProvider,
      modelName: widget.config.activeModelDisplay,
    );

    final updatedTitle =
        current.messages.isEmpty ? _generateThreadTitle(prompt) : current.title;

    current = current.copyWith(
      title: updatedTitle,
      updatedAt: now,
      provider: widget.config.activeProvider,
      modelName: widget.config.activeModelDisplay,
      messages: [...priorMessages, userMsg],
    );

    setState(() {
      _sending = true;
      _activeThreadId = current.id;
      final idx = _threads.indexWhere((t) => t.id == current.id);
      if (idx >= 0) {
        _threads[idx] = current;
      } else {
        _threads = [current, ..._threads];
      }
    });
    widget.onThreadsChanged(_threads);
    widget.onActiveThreadChanged(_activeThreadId);
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(
        config: widget.config,
        history: priorMessages,
        userPrompt: prompt,
        copilotConversationId: current.copilotConversationId,
        copilotWatermark: current.copilotWatermark,
      );

      final aiMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_a',
        role: MessageRole.assistant,
        content: reply.text,
        createdAt: DateTime.now(),
        provider: widget.config.activeProvider,
        modelName: widget.config.activeModelDisplay,
        latencyMs: reply.latencyMs,
        suggestedActions: reply.suggestedActions,
      );

      final completedThread = current.copyWith(
        updatedAt: DateTime.now(),
        messages: [...current.messages, aiMsg],
        copilotConversationId: reply.copilotConversationId ?? current.copilotConversationId,
        copilotWatermark: reply.copilotWatermark ?? current.copilotWatermark,
      );

      if (!mounted) return;
      setState(() {
        _sending = false;
        _updateThreadInList(completedThread);
      });
      widget.onThreadsChanged(_threads);
      _scrollToBottom();
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '');
      final errMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_e',
        role: MessageRole.assistant,
        content:
            '⚠️ **Gagal memproses permintaan (${widget.config.activeProviderLabel}):**\n$errText',
        createdAt: DateTime.now(),
        provider: widget.config.activeProvider,
        modelName: widget.config.activeModelDisplay,
        isError: true,
      );

      final failedThread = current.copyWith(
        updatedAt: DateTime.now(),
        messages: [...current.messages, errMsg],
      );

      if (!mounted) return;
      setState(() {
        _sending = false;
        _updateThreadInList(failedThread);
      });
      widget.onThreadsChanged(_threads);
      _scrollToBottom();
    }
  }

  void _updateThreadInList(ChatThread thread) {
    final idx = _threads.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      _threads[idx] = thread;
    } else {
      _threads = [thread, ..._threads];
    }
    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _generateThreadTitle(String prompt) {
    final clean = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 38) return clean;
    return '${clean.substring(0, 38)}...';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final thread = _activeThread;
    final messages = thread?.messages ?? const [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.bg,
      drawer: _buildSidebarDrawer(p),
      appBar: _buildTopBar(p),
      body: Column(
        children: [
          if (!widget.config.isActiveProviderReady) _buildConfigBanner(p),
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyStateWelcome(p)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= messages.length) {
                        return _buildTypingIndicator(p);
                      }
                      final msg = messages[index];
                      return _MessageBubbleItem(
                        message: msg,
                        palette: p,
                        visualStyle: widget.config.visualStyle,
                        onOpenArtifact: _openArtifactModal,
                        onTapSuggestion: (s) => _sendMessage(s),
                        onRetry: msg.isError && index > 0
                            ? () {
                                final prevUser = messages[index - 1];
                                if (prevUser.role == MessageRole.user) {
                                  _sendMessage(prevUser.content);
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
          _buildBottomComposer(p),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(BtThemePalette p) {
    final isGemini = widget.config.activeProvider == AiProviderType.geminiStudio;
    final isClaudeStyle = widget.config.visualStyle == BtVisualStyle.claude;

    return AppBar(
      backgroundColor: p.bg,
      leading: IconButton(
        tooltip: 'Riwayat & Workspace',
        icon: Icon(Icons.notes_rounded, color: p.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      titleSpacing: 0,
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSettingsSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: p.brandGradient,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isGemini ? Icons.auto_awesome_rounded : Icons.hub_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'BTchat',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: p.accent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isClaudeStyle ? 'CLAUDE UI' : 'GEMINI UI',
                            style: TextStyle(
                              color: p.accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.config.isActiveProviderReady ? p.success : p.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${widget.config.activeProviderLabel} • ${widget.config.activeModelDisplay}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 15, color: p.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Ganti Tema Gemini / Claude',
          onPressed: _toggleVisualStyle,
          icon: Icon(
            isClaudeStyle ? Icons.auto_awesome_rounded : Icons.palette_outlined,
            color: p.accent,
            size: 20,
          ),
        ),
        IconButton(
          tooltip: 'Percakapan Baru',
          onPressed: _createNewThread,
          icon: Icon(Icons.add_comment_outlined, color: p.textPrimary, size: 20),
        ),
        IconButton(
          tooltip: 'Pengaturan AI & Copilot Studio',
          onPressed: _openSettingsSheet,
          icon: Icon(Icons.tune_rounded, color: p.textPrimary, size: 20),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildConfigBanner(BtThemePalette p) {
    final isGemini = widget.config.activeProvider == AiProviderType.geminiStudio;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: p.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isGemini
                  ? 'API Key Gemini AI Studio belum diset. Ketuk untuk menghubungkan.'
                  : 'Kredensial Microsoft Copilot Studio belum diset. Ketuk untuk mengatur.',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 12.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _openSettingsSheet,
            child: Text(
              'Atur API',
              style: TextStyle(
                color: p.accent,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWelcome(BtThemePalette p) {
    final isClaude = widget.config.visualStyle == BtVisualStyle.claude;
    final isGeminiProvider = widget.config.activeProvider == AiProviderType.geminiStudio;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: p.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: p.accent.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      isClaude ? Icons.terminal_rounded : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => p.brandGradient.createShader(bounds),
                          child: Text(
                            isClaude
                                ? 'Halo Developer, siap merancang kode hari ini?'
                                : 'Halo Developer, mau ngoding apa kita hari ini?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BTchat Development AI • Terhubung ke Gemini AI Studio & Microsoft Copilot Studio',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Quick Engine Switcher Pill Bar
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProviderSwitchButton(
                        selected: isGeminiProvider,
                        label: 'Gemini AI Studio',
                        sublabel: widget.config.geminiModel,
                        icon: Icons.auto_awesome_rounded,
                        palette: p,
                        onTap: () => _switchProvider(AiProviderType.geminiStudio),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ProviderSwitchButton(
                        selected: !isGeminiProvider,
                        label: 'Copilot Studio',
                        sublabel: widget.config.copilotBotName,
                        icon: Icons.hub_rounded,
                        palette: p,
                        onTap: () => _switchProvider(AiProviderType.copilotStudio),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'PROMPT DEVELOPMENT CEPAT',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: QuickPromptTemplate.defaults.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.32,
                ),
                itemBuilder: (context, index) {
                  final tpl = QuickPromptTemplate.defaults[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _promptCtrl.text = tpl.prompt;
                      _promptCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _promptCtrl.text.length),
                      );
                      _promptFocus.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tpl.badge,
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tpl.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 13.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              tpl.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11.4,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BtThemePalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: p.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.aiBubble,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              '${widget.config.activeProviderLabel} sedang menyusun jawaban...',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer(BtThemePalette p) {
    final isClaude = widget.config.visualStyle == BtVisualStyle.claude;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: p.bg,
          border: Border(top: BorderSide(color: p.border.withValues(alpha: 0.6))),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(isClaude ? 18 : 26),
              border: Border.all(color: p.border, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptCtrl,
                        focusNode: _promptFocus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 14.2,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          hintText: isClaude
                              ? 'Tanyakan ke ${widget.config.activeModelDisplay} atau tempel kode...'
                              : 'Tanya Gemini / Copilot Studio...',
                          hintStyle: TextStyle(color: p.textSecondary, fontSize: 13.8),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Kirim Pesan',
                      onPressed: _sending ? null : () => _sendMessage(),
                      style: IconButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: p.border,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2, right: 6),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final nextProvider =
                              widget.config.activeProvider == AiProviderType.geminiStudio
                                  ? AiProviderType.copilotStudio
                                  : AiProviderType.geminiStudio;
                          _switchProvider(nextProvider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.config.activeProvider == AiProviderType.geminiStudio
                                    ? Icons.auto_awesome_rounded
                                    : Icons.hub_rounded,
                                size: 13,
                                color: p.accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.config.activeModelDisplay,
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.swap_horiz_rounded, size: 13, color: p.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _promptCtrl.text = '${_promptCtrl.text}\n```\n\n```';
                          _promptFocus.requestFocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Row(
                            children: [
                              Icon(Icons.code_rounded, size: 14, color: p.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Code Block',
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDrawer(BtThemePalette p) {
    return Drawer(
      backgroundColor: p.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: p.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BTchat Studio',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Gemini & Copilot Workspace',
                          style: TextStyle(color: p.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleVisualStyle,
                    tooltip: 'Switch Gemini / Claude Theme',
                    icon: Icon(Icons.cached_rounded, color: p.accent, size: 19),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _createNewThread();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text(
                  'Chat Development Baru',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'RIWAYAT PERCAKAPAN (${_threads.length})',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            Expanded(
              child: _threads.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat chat.',
                        style: TextStyle(color: p.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: _threads.length,
                      itemBuilder: (context, idx) {
                        final item = _threads[idx];
                        final selected = item.id == _activeThreadId;
                        final isGem = item.provider == AiProviderType.geminiStudio;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: selected ? p.accent.withValues(alpha: 0.16) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(color: p.accent.withValues(alpha: 0.4))
                                : null,
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              isGem ? Icons.auto_awesome_rounded : Icons.hub_rounded,
                              size: 17,
                              color: selected ? p.accent : p.textSecondary,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${item.modelName} • ${item.messages.length} pesan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.textSecondary, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 17, color: p.textSecondary),
                              onPressed: () => _deleteThread(item.id),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _selectThread(item.id);
                            },
                          ),
                        );
                      },
                    ),
            ),
            Divider(color: p.border, height: 1),
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                _openSettingsSheet();
              },
              leading: Icon(Icons.tune_rounded, color: p.accent, size: 20),
              title: Text(
                'Pengaturan AI & Copilot Studio',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                widget.config.activeProviderLabel,
                style: TextStyle(color: p.textSecondary, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSwitchButton extends StatelessWidget {
  final bool selected;
  final String label;
  final String sublabel;
  final IconData icon;
  final BtThemePalette palette;
  final VoidCallback onTap;

  const _ProviderSwitchButton({
    required this.selected,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: palette.accent, width: 1.2) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: selected ? palette.accent : palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubbleItem extends StatelessWidget {
  final ChatMessage message;
  final BtThemePalette palette;
  final BtVisualStyle visualStyle;
  final ValueChanged<ChatCodeArtifact> onOpenArtifact;
  final ValueChanged<String> onTapSuggestion;
  final VoidCallback? onRetry;

  const _MessageBubbleItem({
    required this.message,
    required this.palette,
    required this.visualStyle,
    required this.onOpenArtifact,
    required this.onTapSuggestion,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final artifacts = isUser ? const <ChatCodeArtifact>[] : message.extractCodeArtifacts();

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 36),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: palette.userBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(color: palette.border),
            ),
            child: SelectableText(
              message.content,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14.3,
                height: 1.48,
              ),
            ),
          ),
        ),
      );
    }

    final isGemini = message.provider == AiProviderType.geminiStudio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: palette.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGemini ? Icons.auto_awesome_rounded : Icons.hub_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.modelName,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        isGemini ? 'Gemini Studio' : 'Copilot Studio',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (message.latencyMs != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${(message.latencyMs! / 1000).toStringAsFixed(1)}s',
                        style: TextStyle(color: palette.textSecondary, fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Salin Jawaban',
                      icon: Icon(Icons.copy_rounded, size: 15, color: palette.textSecondary),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: message.content));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Jawaban AI berhasil disalin')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: visualStyle == BtVisualStyle.claude
                      ? const EdgeInsets.all(15)
                      : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: visualStyle == BtVisualStyle.claude
                      ? BoxDecoration(
                          color: palette.aiBubble,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: message.isError
                                ? palette.danger.withValues(alpha: 0.5)
                                : palette.border,
                          ),
                        )
                      : null,
                  child: MarkdownMessageView(
                    content: message.content,
                    palette: palette,
                    onOpenArtifact: onOpenArtifact,
                  ),
                ),
                if (artifacts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final art in artifacts)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onOpenArtifact(art),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: palette.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.layers_rounded, size: 15, color: palette.accent),
                                const SizedBox(width: 7),
                                Text(
                                  'Buka ${art.title}',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (message.suggestedActions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sug in message.suggestedActions)
                        ActionChip(
                          label: Text(sug),
                          backgroundColor: palette.surface,
                          side: BorderSide(color: palette.accent.withValues(alpha: 0.4)),
                          labelStyle: TextStyle(
                            color: palette.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          onPressed: () => onTapSuggestion(sug),
                        ),
                    ],
                  ),
                ],
                if (message.isError && onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh_rounded, size: 16, color: palette.accent),
                    label: Text(
                      'Coba Kirim Ulang',
                      style: TextStyle(color: palette.accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
