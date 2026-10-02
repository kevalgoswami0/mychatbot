import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VoiceCallState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// Premium, animated AI Voice Orb inspired by modern conversational AI interfaces.
/// Implements fluid breathing, floating elevation, dynamic sound reactivity,
/// and smooth state transitions (idle, listening, processing, speaking, error).
class VoiceAiOrb extends StatefulWidget {
  const VoiceAiOrb({
    super.key,
    required this.state,
    this.soundLevel = 0.0,
    this.size = 210.0,
  });

  final VoiceCallState state;
  final double soundLevel; // 0.0 to 1.0 (normalized volume)
  final double size;

  @override
  State<VoiceAiOrb> createState() => _VoiceAiOrbState();
}

class _VoiceAiOrbState extends State<VoiceAiOrb> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    // Subtle continuous floating
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    // Breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Processing rotation / fluid shift
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Speaking & listening ripple wave
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceAiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateSpeedsForState();
    }
  }

  void _updateSpeedsForState() {
    switch (widget.state) {
      case VoiceCallState.idle:
        _pulseController.duration = const Duration(milliseconds: 2600);
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        break;
      case VoiceCallState.listening:
        _pulseController.duration = const Duration(milliseconds: 1400);
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        break;
      case VoiceCallState.processing:
        _rotateController.duration = const Duration(milliseconds: 2200);
        if (!_rotateController.isAnimating) _rotateController.repeat();
        break;
      case VoiceCallState.speaking:
        _pulseController.duration = const Duration(milliseconds: 900);
        if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        break;
      case VoiceCallState.error:
        _pulseController.duration = const Duration(milliseconds: 2800);
        break;
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatController,
        _pulseController,
        _rotateController,
        _rippleController,
      ]),
      builder: (context, child) {
        // Floating elevation (up to 8px up and down)
        final floatOffset = math.sin(_floatController.value * math.pi * 2) * 7.0;

        // Base breathing scale
        double scale = 1.0 + (_pulseController.value * 0.05);

        // Sound level reactivity (adds subtle organic expansion)
        if (widget.state == VoiceCallState.listening) {
          scale += widget.soundLevel.clamp(0.0, 1.0) * 0.12;
        } else if (widget.state == VoiceCallState.speaking) {
          scale += math.sin(_pulseController.value * math.pi * 3).abs() * 0.08;
        }

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ripple rings when speaking or listening
                  if (widget.state == VoiceCallState.speaking ||
                      widget.state == VoiceCallState.listening)
                    _buildRippleRing(_rippleController.value),

                  // Secondary ripple ring
                  if (widget.state == VoiceCallState.speaking)
                    _buildRippleRing((_rippleController.value + 0.5) % 1.0),

                  // Soft ambient glow background
                  _buildAmbientGlow(),

                  // Core AI Orb with layered radial gradient
                  _buildOrbCore(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRippleRing(double progress) {
    final ringSize = widget.size * (1.0 + progress * 0.45);
    final opacity = (1.0 - progress) * 0.40;

    Color ringColor;
    switch (widget.state) {
      case VoiceCallState.speaking:
        ringColor = const Color(0xFF2563EB); // Royal Blue
        break;
      case VoiceCallState.listening:
        ringColor = const Color(0xFF0284C7); // Sky Blue
        break;
      case VoiceCallState.processing:
        ringColor = const Color(0xFF7C3AED); // Soft Violet
        break;
      case VoiceCallState.error:
        ringColor = const Color(0xFFE11D48); // Rose
        break;
      default:
        ringColor = const Color(0xFF3B82F6);
    }

    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor.withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    Color glowColor;
    switch (widget.state) {
      case VoiceCallState.idle:
        glowColor = const Color(0xFF2563EB).withValues(alpha: 0.16);
        break;
      case VoiceCallState.listening:
        glowColor = const Color(0xFF0284C7).withValues(alpha: 0.22);
        break;
      case VoiceCallState.processing:
        glowColor = const Color(0xFF7C3AED).withValues(alpha: 0.20);
        break;
      case VoiceCallState.speaking:
        glowColor = const Color(0xFF2563EB).withValues(alpha: 0.26);
        break;
      case VoiceCallState.error:
        glowColor = const Color(0xFFEF4444).withValues(alpha: 0.20);
        break;
    }

    return Container(
      width: widget.size * 0.95,
      height: widget.size * 0.95,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 46,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbCore() {
    List<Color> gradientColors;
    switch (widget.state) {
      case VoiceCallState.idle:
        gradientColors = const [
          Color(0xFFFFFFFF), // Crisp luminous highlight
          Color(0xFF93C5FD), // Radiant sky blue
          Color(0xFF3B82F6), // Vibrant cobalt blue
          Color(0xFF1D4ED8), // Deep rich blue
        ];
        break;
      case VoiceCallState.listening:
        gradientColors = const [
          Color(0xFFFFFFFF), // Radiant white
          Color(0xFF67E8F9), // Electric cyan
          Color(0xFF06B6D4), // Deep cyan
          Color(0xFF0284C7), // Rich ocean blue
        ];
        break;
      case VoiceCallState.processing:
        gradientColors = const [
          Color(0xFFFFFFFF), // Pure highlight
          Color(0xFFC4B5FD), // Soft lavender
          Color(0xFF8B5CF6), // Royal purple
          Color(0xFF6D28D9), // Deep violet
        ];
        break;
      case VoiceCallState.speaking:
        gradientColors = const [
          Color(0xFFFFFFFF), // Luminous white
          Color(0xFF93C5FD), // Sky blue
          Color(0xFF2563EB), // Royal cobalt blue
          Color(0xFF1E40AF), // Deep navy
        ];
        break;
      case VoiceCallState.error:
        gradientColors = const [
          Color(0xFFFFFFFF),
          Color(0xFFFDA4AF),
          Color(0xFFF43F5E),
          Color(0xFFBE123C),
        ];
        break;
    }

    final rotationAngle = widget.state == VoiceCallState.processing
        ? _rotateController.value * math.pi * 2
        : _floatController.value * 0.3;

    return Transform.rotate(
      angle: rotationAngle,
      child: Container(
        width: widget.size * 0.80,
        height: widget.size * 0.80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.25, -0.28),
            radius: 0.94,
            colors: gradientColors,
            stops: const [0.0, 0.38, 0.76, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[2].withValues(alpha: 0.30),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          // Clean subtle surface sheen
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.10),
              ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
