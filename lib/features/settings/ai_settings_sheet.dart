import 'package:flutter/material.dart';
import '../../core/chat_theme.dart';
import '../../models/chat_models.dart';
import '../../services/ai_chat_service.dart';

class AiSettingsSheet extends StatefulWidget {
  final AiProviderConfig initialConfig;
  final AiChatService chatService;
  final ValueChanged<AiProviderConfig> onSave;

  const AiSettingsSheet({
    super.key,
    required this.initialConfig,
    required this.chatService,
    required this.onSave,
  });

  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  late AiProviderType _activeProvider;
  late BtVisualStyle _visualStyle;

  // Gemini controllers
  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _geminiModelCtrl;
  late final TextEditingController _geminiBaseUrlCtrl;
  late final TextEditingController _sysInstructionCtrl;
  late double _temperature;
  late int _maxTokens;

  // Copilot controllers
  late CopilotConnectionMode _copilotMode;
  late final TextEditingController _copilotSecretCtrl;
  late final TextEditingController _copilotTokenEndpointCtrl;
  late final TextEditingController _copilotWebhookUrlCtrl;
  late final TextEditingController _copilotWebhookAuthCtrl;
  late final TextEditingController _copilotBotNameCtrl;
  late final TextEditingController _copilotUserIdCtrl;
  late final TextEditingController _copilotUserNameCtrl;

  bool _obscureGeminiKey = true;
  bool _obscureCopilotSecret = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _activeProvider = c.activeProvider;
    _visualStyle = c.visualStyle;

    _geminiKeyCtrl = TextEditingController(text: c.geminiApiKey);
    _geminiModelCtrl = TextEditingController(text: c.geminiModel);
    _geminiBaseUrlCtrl = TextEditingController(text: c.geminiBaseUrl);
    _sysInstructionCtrl = TextEditingController(text: c.systemInstruction);
    _temperature = c.temperature;
    _maxTokens = c.maxOutputTokens;

    _copilotMode = c.copilotMode;
    _copilotSecretCtrl = TextEditingController(text: c.copilotDirectLineSecret);
    _copilotTokenEndpointCtrl = TextEditingController(text: c.copilotTokenEndpoint);
    _copilotWebhookUrlCtrl = TextEditingController(text: c.copilotWebhookUrl);
    _copilotWebhookAuthCtrl = TextEditingController(text: c.copilotWebhookAuthHeader);
    _copilotBotNameCtrl = TextEditingController(text: c.copilotBotName);
    _copilotUserIdCtrl = TextEditingController(text: c.copilotUserId);
    _copilotUserNameCtrl = TextEditingController(text: c.copilotUserName);
  }

  @override
  void dispose() {
    _geminiKeyCtrl.dispose();
    _geminiModelCtrl.dispose();
    _geminiBaseUrlCtrl.dispose();
    _sysInstructionCtrl.dispose();
    _copilotSecretCtrl.dispose();
    _copilotTokenEndpointCtrl.dispose();
    _copilotWebhookUrlCtrl.dispose();
    _copilotWebhookAuthCtrl.dispose();
    _copilotBotNameCtrl.dispose();
    _copilotUserIdCtrl.dispose();
    _copilotUserNameCtrl.dispose();
    super.dispose();
  }

  AiProviderConfig _buildCurrentConfig() {
    return widget.initialConfig.copyWith(
      activeProvider: _activeProvider,
      visualStyle: _visualStyle,
      geminiApiKey: _geminiKeyCtrl.text.trim(),
      geminiModel: _geminiModelCtrl.text.trim().isEmpty
          ? 'gemini-3-flash-preview'
          : _geminiModelCtrl.text.trim(),
      geminiBaseUrl: _geminiBaseUrlCtrl.text.trim().isEmpty
          ? 'https://generativelanguage.googleapis.com/v1beta'
          : _geminiBaseUrlCtrl.text.trim(),
      temperature: _temperature,
      maxOutputTokens: _maxTokens,
      systemInstruction: _sysInstructionCtrl.text.trim(),
      copilotMode: _copilotMode,
      copilotDirectLineSecret: _copilotSecretCtrl.text.trim(),
      copilotTokenEndpoint: _copilotTokenEndpointCtrl.text.trim(),
      copilotWebhookUrl: _copilotWebhookUrlCtrl.text.trim(),
      copilotWebhookAuthHeader: _copilotWebhookAuthCtrl.text.trim(),
      copilotBotName: _copilotBotNameCtrl.text.trim().isEmpty
          ? 'Copilot Studio Agent'
          : _copilotBotNameCtrl.text.trim(),
      copilotUserId: _copilotUserIdCtrl.text.trim().isEmpty
          ? 'btchat-dev-user'
          : _copilotUserIdCtrl.text.trim(),
      copilotUserName: _copilotUserNameCtrl.text.trim().isEmpty
          ? 'Developer'
          : _copilotUserNameCtrl.text.trim(),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final cfg = _buildCurrentConfig();
      final msg = await widget.chatService.testConnection(cfg);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testSuccess = true;
        _testResult = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testSuccess = false;
        _testResult = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _saveAndClose() {
    final cfg = _buildCurrentConfig();
    widget.onSave(cfg);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = BtThemePalette.of(_visualStyle);

    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.border),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: p.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurasi AI & Studio',
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Hubungkan ke Gemini AI Studio atau Microsoft Copilot Studio',
                            style: TextStyle(color: p.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(color: p.border, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionTitle('1. Tema Antarmuka (Gemini / Claude)', p),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceCard(
                            selected: _visualStyle == BtVisualStyle.gemini,
                            title: 'Gemini Mode',
                            subtitle: 'Dark Nebula & Blue-Violet Sparkle',
                            icon: Icons.auto_awesome_rounded,
                            accentColor: BtThemePalette.gemini.accent,
                            palette: p,
                            onTap: () => setState(() => _visualStyle = BtVisualStyle.gemini),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceCard(
                            selected: _visualStyle == BtVisualStyle.claude,
                            title: 'Claude Mode',
                            subtitle: 'Warm Studio & Code Artifact Card',
                            icon: Icons.terminal_rounded,
                            accentColor: BtThemePalette.claude.accent,
                            palette: p,
                            onTap: () => setState(() => _visualStyle = BtVisualStyle.claude),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildSectionTitle('2. Engine AI Aktif', p),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceCard(
                            selected: _activeProvider == AiProviderType.geminiStudio,
                            title: 'Gemini AI Studio',
                            subtitle: 'Google Generative AI API (v1beta)',
                            icon: Icons.bolt_rounded,
                            accentColor: p.accent,
                            palette: p,
                            onTap: () =>
                                setState(() => _activeProvider = AiProviderType.geminiStudio),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceCard(
                            selected: _activeProvider == AiProviderType.copilotStudio,
                            title: 'Copilot Studio',
                            subtitle: 'Microsoft Direct Line v3 / Webhook',
                            icon: Icons.hub_rounded,
                            accentColor: p.accentSecondary,
                            palette: p,
                            onTap: () =>
                                setState(() => _activeProvider = AiProviderType.copilotStudio),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_activeProvider == AiProviderType.geminiStudio)
                      _buildGeminiSettings(p)
                    else
                      _buildCopilotSettings(p),
                    const SizedBox(height: 18),
                    if (_testResult != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_testSuccess ? p.success : p.danger).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (_testSuccess ? p.success : p.danger).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _testSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                              color: _testSuccess ? p.success : p.danger,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SelectableText(
                                _testResult!,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 12.8,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _runTest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.textPrimary,
                              side: BorderSide(color: p.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _testing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: p.accent,
                                    ),
                                  )
                                : Icon(Icons.wifi_tethering_rounded, size: 18, color: p.accent),
                            label: Text(
                              _testing ? 'Menguji...' : 'Tes Koneksi AI',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveAndClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text(
                              'Simpan Konfigurasi',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, BtThemePalette p) {
    return Text(
      title,
      style: TextStyle(
        color: p.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildGeminiSettings(BtThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: p.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pengaturan Google Gemini AI Studio',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _geminiKeyCtrl,
            obscureText: _obscureGeminiKey,
            style: TextStyle(color: p.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Gemini AI Studio API Key (AIza...)',
              hintText: 'Masukkan API Key dari aistudio.google.com',
              prefixIcon: Icon(Icons.key_rounded, color: p.accent, size: 19),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureGeminiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: p.textSecondary,
                  size: 19,
                ),
                onPressed: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pilih Preset Model atau Ketik Model Kustom:',
            style: TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in AiProviderConfig.geminiModels)
                ChoiceChip(
                  label: Text(m),
                  selected: _geminiModelCtrl.text.trim() == m,
                  selectedColor: p.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: _geminiModelCtrl.text.trim() == m ? p.accent : p.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _geminiModelCtrl.text = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiModelCtrl,
            style: TextStyle(color: p.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Model ID',
              hintText: 'gemini-2.5-flash',
              prefixIcon: Icon(Icons.memory_rounded, color: p.accent, size: 19),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sysInstructionCtrl,
            maxLines: 3,
            style: TextStyle(color: p.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'System Instruction (Persona & Aturan Developer AI)',
              hintText: 'Instruksi sistem untuk mengarahkan gaya jawaban AI...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temperature: ${_temperature.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 1.5,
                      divisions: 15,
                      activeColor: p.accent,
                      onChanged: (v) => setState(() => _temperature = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: [2048, 4096, 8192, 16384].contains(_maxTokens) ? _maxTokens : 8192,
                dropdownColor: p.cardElevated,
                style: TextStyle(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                items: const [
                  DropdownMenuItem(value: 2048, child: Text('2048 Tokens')),
                  DropdownMenuItem(value: 4096, child: Text('4096 Tokens')),
                  DropdownMenuItem(value: 8192, child: Text('8192 Tokens')),
                  DropdownMenuItem(value: 16384, child: Text('16384 Tokens')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _maxTokens = v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCopilotSettings(BtThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, color: p.accentSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pengaturan Microsoft Copilot Studio',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Metode Koneksi Copilot Studio:',
            style: TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Direct Line Secret'),
                selected: _copilotMode == CopilotConnectionMode.directLineSecret,
                selectedColor: p.accent.withValues(alpha: 0.25),
                onSelected: (_) =>
                    setState(() => _copilotMode = CopilotConnectionMode.directLineSecret),
              ),
              ChoiceChip(
                label: const Text('Token Endpoint URL'),
                selected: _copilotMode == CopilotConnectionMode.tokenEndpoint,
                selectedColor: p.accent.withValues(alpha: 0.25),
                onSelected: (_) =>
                    setState(() => _copilotMode = CopilotConnectionMode.tokenEndpoint),
              ),
              ChoiceChip(
                label: const Text('Custom Webhook / Proxy'),
                selected: _copilotMode == CopilotConnectionMode.customWebhook,
                selectedColor: p.accent.withValues(alpha: 0.25),
                onSelected: (_) =>
                    setState(() => _copilotMode = CopilotConnectionMode.customWebhook),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _copilotBotNameCtrl,
            style: TextStyle(color: p.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Nama Agent / Bot Copilot Studio',
              hintText: 'Copilot Studio Agent',
              prefixIcon: Icon(Icons.smart_toy_rounded, color: p.accent, size: 19),
            ),
          ),
          const SizedBox(height: 12),
          if (_copilotMode == CopilotConnectionMode.directLineSecret)
            TextField(
              controller: _copilotSecretCtrl,
              obscureText: _obscureCopilotSecret,
              style: TextStyle(color: p.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Direct Line Secret / Bearer Token',
                hintText: 'Settings -> Channels -> Mobile App / Direct Line Secret',
                prefixIcon: Icon(Icons.vpn_key_rounded, color: p.accent, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCopilotSecret
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: p.textSecondary,
                    size: 19,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCopilotSecret = !_obscureCopilotSecret),
                ),
              ),
            )
          else if (_copilotMode == CopilotConnectionMode.tokenEndpoint)
            TextField(
              controller: _copilotTokenEndpointCtrl,
              style: TextStyle(color: p.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Copilot Studio Token Endpoint URL',
                hintText:
                    'https://...environment.api.powerplatform.com/powervirtualagents/botsbyschema/.../directline/token?api-version=2022-03-01-preview',
                prefixIcon: Icon(Icons.link_rounded, color: p.accent, size: 19),
              ),
            )
          else ...[
            TextField(
              controller: _copilotWebhookUrlCtrl,
              style: TextStyle(color: p.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Custom Webhook / Copilot Bridge URL',
                hintText: 'https://api.example.com/copilot/chat',
                prefixIcon: Icon(Icons.webhook_rounded, color: p.accent, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _copilotWebhookAuthCtrl,
              style: TextStyle(color: p.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Authorization Header / API Key (Opsional)',
                hintText: 'Bearer xxx atau x-api-key: xxx',
                prefixIcon: Icon(Icons.security_rounded, color: p.accent, size: 19),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _copilotUserIdCtrl,
                  style: TextStyle(color: p.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: 'btchat-dev-user',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _copilotUserNameCtrl,
                  style: TextStyle(color: p.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'Developer',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final BtThemePalette palette;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.14) : palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : palette.border,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? accentColor : palette.textSecondary, size: 18),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accentColor, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.2,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
