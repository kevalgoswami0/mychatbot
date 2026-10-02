
import 'package:flutter/material.dart';
import 'voice_ai_orb.dart';

/// Large, interactive Microphone Call Button for live voice conversation.
/// Shows distinct animated visual states (idle, listening, processing, speaking, error)
/// with pulsing ripple waves and sound-level responsiveness.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.state,
    required this.onTap,
    this.soundLevel = 0.0,
    this.size = 76.0,
  });

  final VoiceCallState state;
  final VoidCallback onTap;
  final double soundLevel;
  final double size;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.state == VoiceCallState.listening;
    final isProcessing = widget.state == VoiceCallState.processing;
    final isSpeaking = widget.state == VoiceCallState.speaking;
    final isError = widget.state == VoiceCallState.error;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.size + 36,
            height: widget.size + 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ripple ring when listening
                if (isListening) ...[
                  _buildRippleWave(_pulseController.value),
                  _buildRippleWave((_pulseController.value + 0.5) % 1.0),
                ],

                // Rotating processing ring
                if (isProcessing)
                  SizedBox(
                    width: widget.size + 14,
                    height: widget.size + 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF38BDF8),
                      ),
                    ),
                  ),

                // Main Button Container
                AnimatedScale(
                  scale: _isPressed ? 0.92 : (isListening ? 1.0 + (widget.soundLevel * 0.08) : 1.0),
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _buildButtonGradient(
                        isListening: isListening,
                        isProcessing: isProcessing,
                        isSpeaking: isSpeaking,
                        isError: isError,
                      ),
                      border: Border.all(
                        color: _buildBorderColor(
                          isListening: isListening,
                          isProcessing: isProcessing,
                          isSpeaking: isSpeaking,
                          isError: isError,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _buildShadowColor(
                            isListening: isListening,
                            isSpeaking: isSpeaking,
                            isError: isError,
                          ),
                          blurRadius: isListening ? 24 : 12,
                          spreadRadius: isListening ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildIcon(
                        isListening: isListening,
                        isProcessing: isProcessing,
                        isSpeaking: isSpeaking,
                        isError: isError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRippleWave(double progress) {
    final waveSize = widget.size + (progress * 34.0);
    final opacity = (1.0 - progress) * 0.40;

    return Container(
      width: waveSize,
      height: waveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: (opacity * 0.35).clamp(0.0, 1.0)),
          width: 1.5,
        ),
      ),
    );
  }

  LinearGradient _buildButtonGradient({
    required bool isListening,
    required bool isProcessing,
    required bool isSpeaking,
    required bool isError,
  }) {
    if (isError) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
      );
    }
    if (isListening) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      );
    }
    if (isProcessing) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
      );
    }
    if (isSpeaking) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      );
    }
    // Idle state: Clean, crisp white with soft surface
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    );
  }

  Color _buildBorderColor({
    required bool isListening,
    required bool isProcessing,
    required bool isSpeaking,
    required bool isError,
  }) {
    if (isError) return const Color(0xFFFCA5A5);
    if (isListening) return const Color(0xFF60A5FA);
    if (isProcessing) return const Color(0xFFCBD5E1);
    if (isSpeaking) return const Color(0xFF93C5FD);
    return const Color(0xFFE2E8F0);
  }

  Color _buildShadowColor({
    required bool isListening,
    required bool isSpeaking,
    required bool isError,
  }) {
    if (isError) return const Color(0xFFEF4444).withValues(alpha: 0.30);
    if (isListening) return const Color(0xFF2563EB).withValues(alpha: 0.35);
    if (isSpeaking) return const Color(0xFF2563EB).withValues(alpha: 0.28);
    return Colors.black.withValues(alpha: 0.08);
  }

  Widget _buildIcon({
    required bool isListening,
    required bool isProcessing,
    required bool isSpeaking,
    required bool isError,
  }) {
    if (isError) {
      return const Icon(
        Icons.refresh_rounded,
        size: 32,
        color: Colors.white,
      );
    }
    if (isProcessing) {
      return const Icon(
        Icons.more_horiz_rounded,
        size: 30,
        color: Color(0xFF2563EB),
      );
    }
    if (isSpeaking) {
      return const Icon(
        Icons.graphic_eq_rounded,
        size: 32,
        color: Colors.white,
      );
    }
    if (isListening) {
      return const Icon(
        Icons.mic_rounded,
        size: 34,
        color: Colors.white,
      );
    }
    // Idle: Royal cobalt blue mic on crisp white button
    return const Icon(
      Icons.mic_rounded,
      size: 34,
      color: Color(0xFF2563EB),
    );
  }
}
