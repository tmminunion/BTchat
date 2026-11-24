import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/chat_theme.dart';
import '../../models/chat_models.dart';

class _ContentSegment {
  final bool isCode;
  final String language;
  final String text;

  const _ContentSegment({
    required this.isCode,
    required this.language,
    required this.text,
  });
}

class MarkdownMessageView extends StatelessWidget {
  final String content;
  final BtThemePalette palette;
  final ValueChanged<ChatCodeArtifact>? onOpenArtifact;

  const MarkdownMessageView({
    super.key,
    required this.content,
    required this.palette,
    this.onOpenArtifact,
  });

  List<_ContentSegment> _parseSegments(String raw) {
    final regex = RegExp(r'```([a-zA-Z0-9_+-]*)\n?([\s\S]*?)```', multiLine: true);
    final matches = regex.allMatches(raw);
    if (matches.isEmpty) {
      return [_ContentSegment(isCode: false, language: '', text: raw)];
    }

    final segments = <_ContentSegment>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final before = raw.substring(cursor, m.start);
        if (before.trim().isNotEmpty) {
          segments.add(_ContentSegment(isCode: false, language: '', text: before.trim()));
        }
      }
      final lang = (m.group(1) ?? '').trim();
      final code = (m.group(2) ?? '').trimRight();
      segments.add(_ContentSegment(
        isCode: true,
        language: lang.isEmpty ? 'code' : lang,
        text: code,
      ));
      cursor = m.end;
    }

    if (cursor < raw.length) {
      final after = raw.substring(cursor);
      if (after.trim().isNotEmpty) {
        segments.add(_ContentSegment(isCode: false, language: '', text: after.trim()));
      }
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(content);
    var codeIndex = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          if (segments[i].isCode)
            _CodeArtifactBlock(
              artifact: ChatCodeArtifact(
                language: segments[i].language,
                code: segments[i].text,
                title: '${segments[i].language.toUpperCase()} Artifact #${codeIndex++}',
              ),
              palette: palette,
              onOpenArtifact: onOpenArtifact,
            )
          else
            _RichTextParagraphs(
              text: segments[i].text,
              palette: palette,
            ),
        ],
      ],
    );
  }
}

class _CodeArtifactBlock extends StatefulWidget {
  final ChatCodeArtifact artifact;
  final BtThemePalette palette;
  final ValueChanged<ChatCodeArtifact>? onOpenArtifact;

  const _CodeArtifactBlock({
    required this.artifact,
    required this.palette,
    this.onOpenArtifact,
  });

  @override
  State<_CodeArtifactBlock> createState() => _CodeArtifactBlockState();
}

class _CodeArtifactBlockState extends State<_CodeArtifactBlock> {
  bool _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.artifact.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final lineCount = widget.artifact.code.split('\n').length;

    return Container(
      decoration: BoxDecoration(
        color: p.codeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.codeHeaderBg,
              border: Border(bottom: BorderSide(color: p.border, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 15, color: p.accent),
                const SizedBox(width: 7),
                Text(
                  widget.artifact.language.toUpperCase(),
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$lineCount baris',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onOpenArtifact != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onOpenArtifact!(widget.artifact),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full_rounded, size: 13, color: p.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Artifact',
                            style: TextStyle(
                              color: p.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _copyCode,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 13.5,
                          color: _copied ? p.success : p.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Disalin' : 'Salin',
                          style: TextStyle(
                            color: _copied ? p.success : p.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              widget.artifact.code,
              style: TextStyle(
                fontFamily: 'monospace',
                color: p.textPrimary,
                fontSize: 12.8,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RichTextParagraphs extends StatelessWidget {
  final String text;
  final BtThemePalette palette;

  const _RichTextParagraphs({
    required this.text,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildLine(lines[i]),
        ],
      ],
    );
  }

  Widget _buildLine(String rawLine) {
    final line = rawLine.trimRight();
    if (line.isEmpty) {
      return const SizedBox(height: 4);
    }

    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(
          line.substring(4),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          line.substring(3),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          line.substring(2),
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final bulletMatch = RegExp(r'^(\s*)([-*•]|\d+\.)\s+(.*)$').firstMatch(line);
    if (bulletMatch != null) {
      final indent = (bulletMatch.group(1) ?? '').length * 8.0;
      final marker = bulletMatch.group(2) ?? '•';
      final content = bulletMatch.group(3) ?? '';
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marker == '-' || marker == '*' ? '•  ' : '$marker ',
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            Expanded(
              child: SelectableText.rich(
                TextSpan(children: _parseInlineSpans(content)),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.2,
                  height: 1.52,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: _parseInlineSpans(line)),
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 14.3,
        height: 1.54,
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String input) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');
    var cursor = 0;

    for (final m in tokenRegex.allMatches(input)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, m.start)));
      }
      final token = m.group(0) ?? '';
      if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: palette.codeHeaderBg,
              color: palette.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }
      cursor = m.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    return spans;
  }
}
