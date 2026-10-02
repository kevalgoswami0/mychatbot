import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../history/providers/history_provider.dart';
import '../providers/chat_providers.dart';
import 'services/voice_audio_player_service.dart';
import 'widgets/voice_ai_orb.dart';
import 'widgets/voice_mic_button.dart';

/// Clean, minimalist White Live Voice Call Screen.
/// Supports hands-free voice conversation and centered text input popup.
/// Seamlessly uses the existing WebSocket chat and TTS WAV audio.
class LiveVoiceChatScreen extends ConsumerStatefulWidget {
  const LiveVoiceChatScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<LiveVoiceChatScreen> createState() =>
      _LiveVoiceChatScreenState();
}

class _LiveVoiceChatScreenState extends ConsumerState<LiveVoiceChatScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final VoiceAudioPlayerService _audioService =
      VoiceAudioPlayerService.instance;

  VoiceCallState _callState = VoiceCallState.idle;
  String _statusTitle = 'Voice Ready';
  String _statusSubtitle = 'Tap microphone or type to speak';
  String _lastRecognizedWords = '';
  String _currentLocaleId = '';
  double _soundLevel = 0.0;
  bool _isSpeechInitialized = false;
  bool _isMuted = false;

  StreamSubscription<bool>? _speakingSub;
  StreamSubscription<void>? _playbackCompleteSub;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();

    // Enable voice session audio playback exclusively for this screen
    _audioService.setVoiceSessionActive(true);

    // Set clean light status bar / system navigation bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _listenToAudioService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVoiceSession();
    });
  }

  void _listenToAudioService() {
    // When audio playback begins (AI speaking)
    _speakingSub = _audioService.isSpeakingStream.listen((speaking) {
      if (!mounted) return;
      if (speaking) {
        _cancelSilenceTimer();
        setState(() {
          _callState = VoiceCallState.speaking;
          _statusTitle = 'AI Speaking';
          _statusSubtitle = 'Tap mic or Stop anytime';
        });
      }
    });

    // When the queued WAV audio finishes playing completely
    _playbackCompleteSub = _audioService.playbackCompleteStream.listen((_) {
      if (!mounted) return;
      AppLogger.info('Voice playback completed. AI finished speaking.');
      setState(() {
        _callState = VoiceCallState.idle;
        _statusTitle = 'Voice Ready';
        _statusSubtitle = 'Tap microphone or type to speak';
      });
    });
  }

  Future<void> _initVoiceSession() async {
    // 1. Ensure conversation ID is set
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      ref
          .read(activeConversationIdProvider.notifier)
          .setActiveId(widget.conversationId);
    }

    // 2. Initialize Speech-To-Text
    try {
      final available = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: true,
      );

      if (!mounted) return;

      if (available) {
        try {
          final systemLocale = await _speechToText.systemLocale();
          _currentLocaleId = systemLocale?.localeId ?? 'en_US';
        } catch (_) {}

        setState(() {
          _isSpeechInitialized = true;
          _callState = VoiceCallState.idle;
          _statusTitle = 'Voice Ready';
          _statusSubtitle = 'Tap microphone or type to speak';
        });
      } else {
        setState(() {
          _isSpeechInitialized = false;
          _callState = VoiceCallState.idle;
          _statusTitle = 'Voice Ready';
          _statusSubtitle = 'Tap microphone or type to speak';
        });
      }
    } catch (e) {
      AppLogger.warning('Speech initialize failed: $e');
      if (mounted) {
        setState(() {
          _callState = VoiceCallState.idle;
          _statusTitle = 'Voice Ready';
          _statusSubtitle = 'Tap microphone or type to speak';
        });
      }
    }
  }

  void _handleSpeechStatus(String status) {
    AppLogger.info('STT status changed: $status');
    if (!mounted) return;

    if (status == 'notListening' && _callState == VoiceCallState.listening) {
      _onSpeechFinished();
    }
  }

  void _handleSpeechError(SpeechRecognitionError errorNotification) {
    AppLogger.warning('STT error: ${errorNotification.errorMsg}');
    if (!mounted) return;

    // If we already captured speech, finalize it despite error
    if (_lastRecognizedWords.trim().isNotEmpty &&
        _callState == VoiceCallState.listening) {
      _onSpeechFinished();
      return;
    }

    if (_callState != VoiceCallState.speaking &&
        _callState != VoiceCallState.processing) {
      setState(() {
        _callState = VoiceCallState.idle;
        _statusTitle = 'Voice Ready';
        _statusSubtitle = 'Tap microphone or type to speak';
      });
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;

    final userSub = ref.read(userSubscriptionProvider).value;
    final isSubscribed =
        userSub != null &&
        (userSub.hasSubscription || userSub.isSubscribedAndValid);
    final isLimitReached = !isSubscribed && (userSub?.limitReached == true);
    if (isLimitReached) {
      setState(() {
        _callState = VoiceCallState.error;
        _statusTitle = 'Limit Reached';
        _statusSubtitle = 'Daily limit reached. Upgrade to continue.';
      });
      return;
    }

    // Ensure speech is initialized
    if (!_isSpeechInitialized) {
      final available = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: true,
      );
      if (!available) {
        setState(() {
          _callState = VoiceCallState.error;
          _statusTitle = 'Mic Access Denied';
          _statusSubtitle = 'Tap "Type" or enable mic in settings.';
        });
        return;
      }
      _isSpeechInitialized = true;
      try {
        final systemLocale = await _speechToText.systemLocale();
        _currentLocaleId = systemLocale?.localeId ?? 'en_US';
      } catch (_) {}
    }

    // Stop current audio before listening
    await _audioService.stop();

    _lastRecognizedWords = '';
    _cancelSilenceTimer();

    setState(() {
      _callState = VoiceCallState.listening;
      _statusTitle = 'Listening...';
      _statusSubtitle = 'Speak now into microphone';
      _soundLevel = 0.0;
    });

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: (level) {
          if (!mounted) return;
          final normalized = ((level + 5.0) / 15.0).clamp(0.0, 1.0);
          setState(() {
            _soundLevel = normalized;
          });
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
          autoPunctuation: true,
          localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : null,
        ),
      );
    } catch (e) {
      AppLogger.warning('Error starting STT listen: $e');
      if (mounted) {
        setState(() {
          _callState = VoiceCallState.idle;
          _statusTitle = 'Voice Ready';
          _statusSubtitle = 'Tap microphone or type to speak';
        });
      }
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    _lastRecognizedWords = words;

    // Show captured words in real-time in status caption
    if (words.isNotEmpty && _callState == VoiceCallState.listening) {
      setState(() {
        _statusTitle = 'Listening...';
        _statusSubtitle = '"$words"';
      });
    }

    _cancelSilenceTimer();

    if (result.finalResult) {
      _onSpeechFinished();
    } else {
      // Auto-send after 2 seconds of silence
      _silenceTimer = Timer(const Duration(milliseconds: 2000), () {
        if (_callState == VoiceCallState.listening &&
            _lastRecognizedWords.trim().isNotEmpty) {
          _onSpeechFinished();
        }
      });
    }
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  Future<void> _onSpeechFinished() async {
    _cancelSilenceTimer();
    final text = _lastRecognizedWords.trim();

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    if (!mounted) return;

    if (text.isEmpty) {
      setState(() {
        _callState = VoiceCallState.idle;
        _statusTitle = 'Voice Ready';
        _statusSubtitle = 'Tap microphone or type to speak';
        _soundLevel = 0.0;
      });
      return;
    }

    await _submitText(text);
  }

  Future<void> _submitText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _cancelSilenceTimer();
    _lastRecognizedWords = '';
    FocusScope.of(context).unfocus();

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    await _sendSpokenQuery(trimmed);
  }

  Future<void> _sendSpokenQuery(String query) async {
    setState(() {
      _callState = VoiceCallState.processing;
      _statusTitle = 'Thinking...';
      _statusSubtitle = 'Generating response';
      _soundLevel = 0.0;
    });

    try {
      // Sends message through the existing chat repository over WebSocket.
      // Generates assistant reply, saves conversation history, and plays TTS WAV audio.
      await ref.read(messagesProvider.notifier).sendMessage(query);
    } catch (e) {
      AppLogger.error('Failed to send message: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final isLimit =
            errStr.contains('free chat limit') ||
            errStr.contains('daily limit') ||
            errStr.contains('2 min') ||
            errStr.contains('limit_exceeded');

        setState(() {
          _callState = VoiceCallState.error;
          _statusTitle = isLimit ? 'Limit Reached' : 'Connection Error';
          _statusSubtitle = isLimit
              ? 'Daily limit reached. Upgrade to continue.'
              : 'Connection interrupted. Tap mic or try again.';
        });
      }
    }
  }

  /// Opens the clean centered textfield popup dialog.
  void _openTextInputDialog() {
    // Stop listening or current audio before showing the dialog
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _cancelSilenceTimer();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _VoiceTextInputDialog(
        initialText: _lastRecognizedWords,
        onSubmit: (text) {
          Navigator.of(dialogContext).pop();
          _submitText(text);
        },
        onMicTap: () {
          Navigator.of(dialogContext).pop();
          _startListening();
        },
      ),
    );
  }

  void _handleMicTap() {
    switch (_callState) {
      case VoiceCallState.listening:
        // Tapping while listening forces immediate dispatch
        _onSpeechFinished();
        break;

      case VoiceCallState.speaking:
        // Tapping while AI speaks interrupts AI and starts listening
        _audioService.stop();
        _startListening();
        break;

      case VoiceCallState.processing:
        // Tapping while processing cancels generation
        ref.read(messagesProvider.notifier).stopGeneration();
        setState(() {
          _callState = VoiceCallState.idle;
          _statusTitle = 'Cancelled';
          _statusSubtitle = 'Tap microphone to speak or type';
        });
        break;

      case VoiceCallState.idle:
      case VoiceCallState.error:
        _startListening();
        break;
    }
  }

  /// Stops voice/audio and speech recognition without closing the screen.
  void _handleStopVoice() {
    _cancelSilenceTimer();
    _speechToText.stop();
    _audioService.stop();
    ref.read(messagesProvider.notifier).stopGeneration();
    if (mounted) {
      setState(() {
        _callState = VoiceCallState.idle;
        _statusTitle = 'Voice Stopped';
        _statusSubtitle = 'Tap microphone to speak or type';
        _soundLevel = 0.0;
      });
    }
  }

  Future<void> _handleMuteToggle() async {
    final nextMute = !_isMuted;
    await _audioService.setMuted(nextMute);
    if (mounted) {
      setState(() {
        _isMuted = nextMute;
      });
    }
  }

  /// Exits the screen back to chat when user taps top back arrow.
  void _handleExitScreen() {
    _cleanupVoiceResources();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _cleanupVoiceResources() {
    _cancelSilenceTimer();
    _speechToText.stop();
    _speechToText.cancel();
    _audioService.setVoiceSessionActive(false);
    _audioService.stop();
    _speakingSub?.cancel();
    _playbackCompleteSub?.cancel();
  }

  @override
  void dispose() {
    _cleanupVoiceResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Colors.white;
    const surfaceColor = Color(0xFFF8FAFC);
    const borderColor = Color(0xFFE2E8F0);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // Generous, balanced orb sizing for clean minimalism
    final orbSize = (screenWidth * 0.52).clamp(180.0, 230.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),

              // 1. Clean Top Bar (Back button, "Voice Assistant" title, Speaker toggle)
              _buildTopBar(
                textPrimary,
                textSecondary,
                surfaceColor,
                borderColor,
              ),

              // 2. Central AI Stage with perfect vertical balance
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Central Animated AI Orb
                    VoiceAiOrb(
                      state: _callState,
                      soundLevel: _soundLevel,
                      size: orbSize,
                    ),

                    const SizedBox(height: 32),

                    // Beautiful "Voice Ready" Status Bar with proper arrangement
                    _buildVoiceReadyBar(
                      textPrimary,
                      textSecondary,
                      surfaceColor,
                      borderColor,
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),

              // 3. Bottom Controls Row (Type popup button, Center Big Mic, Stop button)
              _buildBottomControls(surfaceColor, borderColor, textSecondary),

              SizedBox(
                height: mediaQuery.padding.bottom > 0
                    ? AppSpacing.sm
                    : AppSpacing.md,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Button (Exits screen)
        Material(
          color: surfaceColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _handleExitScreen,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1E293B),
                  size: 16,
                ),
              ),
            ),
          ),
        ),

        // Screen Title: Clean "Voice Assistant" (No connected badge)
        Text(
          'Voice Assistant',
          style: AppTextStyles.titleMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontSize: 18,
          ),
        ),

        // Mute / Speaker Quick Action
        Material(
          color: _isMuted ? const Color(0xFFFEE2E2) : surfaceColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _handleMuteToggle,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isMuted ? const Color(0xFFFECDD3) : borderColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _isMuted
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF475569),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Properly arranged, elegant "Voice Ready" status capsule bar.
  Widget _buildVoiceReadyBar(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    final isError = _callState == VoiceCallState.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('$_statusTitle-$_statusSubtitle'),
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 330),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFEF2F2) : surfaceColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isError ? const Color(0xFFFECDD3) : borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // State-specific Icon Badge
            _buildStatusIconBadge(),
            const SizedBox(width: 12),

            // Two-tier Structured Text (Title + Subtitle)
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isError ? const Color(0xFFDC2626) : textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _statusSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: isError ? const Color(0xFFEF4444) : textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatusIconBadge() {
    switch (_callState) {
      case VoiceCallState.listening:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 16,
              color: Color(0xFF10B981),
            ),
          ),
        );

      case VoiceCallState.processing:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ),
        );

      case VoiceCallState.speaking:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.volume_up_rounded,
              size: 16,
              color: Color(0xFF2563EB),
            ),
          ),
        );

      case VoiceCallState.error:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: Color(0xFFDC2626),
            ),
          ),
        );

      case VoiceCallState.idle:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.mic_none_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ),
        );
    }
  }

  Widget _buildBottomControls(
    Color surfaceColor,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Type Button (opens center popup dialog)
          _buildSecondaryButton(
            icon: Icons.keyboard_rounded,
            label: 'Type',
            isActive: false,
            onTap: _openTextInputDialog,
            surfaceColor: Colors.white,
            borderColor: borderColor,
            iconColor: const Color(0xFF2563EB),
            labelColor: textSecondary,
          ),

          // Center: Large Animated Microphone Button
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VoiceMicButton(
                state: _callState,
                soundLevel: _soundLevel,
                onTap: _handleMicTap,
                size: 76,
              ),
              const SizedBox(height: 8),
              Text(
                _callState == VoiceCallState.listening
                    ? 'Listening...'
                    : (_callState == VoiceCallState.speaking
                          ? 'Tap to interrupt'
                          : 'Microphone'),
                style: AppTextStyles.caption.copyWith(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Right: Stop Button (Stops voice/audio, does NOT close screen)
          _buildStopButton(textSecondary),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color borderColor,
    required Color iconColor,
    required Color labelColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: surfaceColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: Icon(icon, size: 22, color: iconColor)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Stop Button: Stops ongoing speech/voice without closing the screen.
  Widget _buildStopButton(Color labelColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFFEF4444),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _handleStopVoice,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.stop_rounded, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Stop',
          style: AppTextStyles.caption.copyWith(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Clean, simple popup dialog using native Flutter components without extra wrapper containers.
class _VoiceTextInputDialog extends StatefulWidget {
  const _VoiceTextInputDialog({
    required this.onSubmit,
    this.onMicTap,
    this.initialText = '',
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback? onMicTap;
  final String initialText;

  @override
  State<_VoiceTextInputDialog> createState() => _VoiceTextInputDialogState();
}

class _VoiceTextInputDialogState extends State<_VoiceTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      title: Text(
        'Type to AI',
        style: AppTextStyles.titleLarge.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
          fontSize: 25,
          letterSpacing: -0.3,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _handleSend(),
        cursorColor: const Color(0xFF3B82F6),
        style: AppTextStyles.bodyMedium.copyWith(
          color: const Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'e.g. "What time is it?" or...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: const Color(0xFF94A3B8),
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: widget.onMicTap != null
              ? IconButton(
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    size: 24,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: widget.onMicTap,
                  splashRadius: 20,
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2.0),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            foregroundColor: const Color(0xFF0F172A),
          ),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyLarge.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _handleSend,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Send',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
