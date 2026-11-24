import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/chat_theme.dart';
import '../../models/chat_models.dart';

class BtSplashScreen extends StatefulWidget {
  final BtVisualStyle visualStyle;
  final AiProviderType activeProvider;
  final String activeModel;

  const BtSplashScreen({
    super.key,
    required this.visualStyle,
    required this.activeProvider,
    required this.activeModel,
  });

  @override
  State<BtSplashScreen> createState() => _BtSplashScreenState();
}

class _BtSplashScreenState extends State<BtSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BtThemePalette.of(widget.visualStyle);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Nebula Orbit Aura
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _NebulaSplashPainter(
                  progress: _ctrl.value,
                  accent: p.accent,
                  secondary: p.accentSecondary,
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // Animated Central BTchat AI Logo
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      final pulse = 1.0 + 0.035 * math.sin(_ctrl.value * 2 * math.pi);
                      return Transform.scale(
                        scale: pulse,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 122,
                      height: 122,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: p.brandGradient,
                        boxShadow: [
                          BoxShadow(
                            color: p.accent.withValues(alpha: 0.42),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: p.accentSecondary.withValues(alpha: 0.25),
                            blurRadius: 56,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1322),
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/img/appicon.png',
                                width: 108,
                                height: 108,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.auto_awesome_rounded,
                                  color: p.accent,
                                  size: 54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Brand Title
                  ShaderMask(
                    shaderCallback: (bounds) => p.brandGradient.createShader(bounds),
                    child: const Text(
                      'BTchat Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI DEVELOPMENT & COPILOT WORKSPACE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Dual Engine Pill Badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _EngineBadge(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Gemini 3.x Studio',
                        color: const Color(0xFF38BDF8),
                        palette: p,
                      ),
                      _EngineBadge(
                        icon: Icons.hub_rounded,
                        label: 'Copilot Studio v3',
                        color: const Color(0xFFA855F7),
                        palette: p,
                      ),
                      _EngineBadge(
                        icon: Icons.terminal_rounded,
                        label: 'Claude Artifact UI',
                        color: const Color(0xFFD97757),
                        palette: p,
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  // Loading bar & engine status
                  Container(
                    constraints: const BoxConstraints(maxWidth: 290),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: p.card.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: p.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Menyiapkan ${widget.activeProvider == AiProviderType.geminiStudio ? 'Gemini AI Studio' : 'Copilot Studio'} (${widget.activeModel})...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: p.bgSecondary,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Bungtemin AI Engineering Suite • v1.0.2',
                    style: TextStyle(
                      color: p.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final BtThemePalette palette;

  const _EngineBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NebulaSplashPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color secondary;

  const _NebulaSplashPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final angle = progress * 2 * math.pi;

    // Soft glowing nebula orbs
    final orb1 = Offset(
      center.dx + math.cos(angle) * 65,
      center.dy + math.sin(angle) * 45,
    );
    final orb2 = Offset(
      center.dx + math.cos(angle + math.pi) * 75,
      center.dy + math.sin(angle + math.pi) * 55,
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.22),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb1, radius: 210));
    canvas.drawCircle(orb1, 210, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondary.withValues(alpha: 0.18),
          secondary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb2, radius: 190));
    canvas.drawCircle(orb2, 190, paint2);

    // Subtle concentric tech rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accent.withValues(alpha: 0.12);
    canvas.drawCircle(center, 115, ringPaint);
    canvas.drawCircle(center, 165, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _NebulaSplashPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
