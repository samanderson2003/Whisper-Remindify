import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'history.dart';

class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({Key? key}) : super(key: key);

  @override
  _SpeechToTextPageState createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _status = 'Ready';
  List<String> _recognizedSentences = [];
  bool _isListening = false;
  String _currentWords = '';
  bool _isEmulator = false;
  double _soundLevel = 0.0;

  // Animation controllers for waveform
  late AnimationController _waveAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  // Timer for recording duration
  int _recordingDuration = 0;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _detectEmulator();
    _initSpeech();
    _initAnimations();
  }

  void _initAnimations() {
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimationController.repeat(reverse: true);
  }

  /// Detect if running on emulator
  void _detectEmulator() {
    _isEmulator =
        Platform.isAndroid &&
        (Platform.environment['ANDROID_EMULATOR'] == 'true' ||
            Platform.environment.containsKey('ANDROID_AVD_HOME'));
  }

  /// Check if permissions are available
  Future<bool> _checkPermissions() async {
    try {
      bool available = await _speechToText.initialize();
      return available;
    } catch (e) {
      return false;
    }
  }

  /// Check available locales
  Future<void> _checkLocales() async {
    if (_speechEnabled) {
      var locales = await _speechToText.locales();
      print(
        'Available locales: ${locales.map((l) => '${l.localeId} - ${l.name}').join(', ')}',
      );
    }
  }

  /// Initialize speech recognition
  void _initSpeech() async {
    try {
      print('Attempting to initialize speech recognition...');
      _speechEnabled = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      print('Speech recognition initialization result: $_speechEnabled');
      if (_speechEnabled) {
        _checkLocales();
      }
      setState(() {
        if (_speechEnabled) {
          _status = 'Ready';
        } else {
          _status =
              'Speech recognition not available. Please check microphone permissions.';
        }
      });
    } catch (e) {
      print('Error during speech initialization: $e');
      setState(() {
        _status =
            'Error initializing speech recognition: $e\nPlease check microphone permissions in device settings.';
        _speechEnabled = false;
      });
    }
  }

  /// Handle speech status changes
  void _onSpeechStatus(String status) {
    print('Speech status changed: $status');
    setState(() {
      if (status == 'listening') {
        _status = 'Listening...';
        _isListening = true;
        _waveAnimationController.repeat();
        _recordingStartTime = DateTime.now();
        _updateRecordingDuration();
      } else if (status == 'notListening') {
        _status = 'Stopped listening';
        _isListening = false;
        _soundLevel = 0.0;
        _waveAnimationController.stop();
        _recordingStartTime = null;
      } else if (status == 'done') {
        _status = 'Recording session ended';
        _isListening = false;
        _soundLevel = 0.0;
        _waveAnimationController.stop();
        _recordingStartTime = null;
      } else {
        _status = status;
        _isListening = status == 'listening';
        if (!_isListening) {
          _soundLevel = 0.0;
          _waveAnimationController.stop();
          _recordingStartTime = null;
        }
      }
    });
  }

  void _updateRecordingDuration() {
    if (_recordingStartTime != null && _isListening) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isListening && _recordingStartTime != null) {
          setState(() {
            _recordingDuration = DateTime.now()
                .difference(_recordingStartTime!)
                .inSeconds;
          });
          _updateRecordingDuration();
        }
      });
    }
  }

  /// Handle speech errors
  void _onSpeechError(dynamic error) {
    print('Speech error occurred: ${error.errorMsg}');
    setState(() {
      String errorMsg = error.errorMsg ?? 'Unknown error';
      if (errorMsg.contains('timeout') ||
          errorMsg.contains('error_speech_timeout')) {
        _status =
            'Speech timeout - This often happens on emulators. Try on a real device.';
      } else if (errorMsg.contains('network') ||
          errorMsg.contains('connection')) {
        _status = 'Network error. Check your internet connection.';
      } else if (errorMsg.contains('permission') ||
          errorMsg.contains('denied')) {
        _status = 'Microphone permission denied. Please enable it in settings.';
      } else if (errorMsg.contains('recognizer_busy')) {
        _status = 'Speech recognizer is busy. Please try again.';
      } else if (errorMsg.contains('no_match')) {
        _status =
            'No speech detected. Please speak louder or closer to the microphone.';
      } else if (errorMsg.contains('error_audio')) {
        _status =
            'Audio error - Make sure microphone is working (emulators may not support this).';
      } else {
        _status = 'Error: $errorMsg';
      }
      _isListening = false;
      _waveAnimationController.stop();
      _recordingStartTime = null;
    });
  }

  /// Start listening for speech
  void _startListening() async {
    if (!_speechEnabled) return;

    try {
      print('Starting to listen...');
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(hours: 24),
        pauseFor: const Duration(hours: 24),
        localeId: 'en_US',
        partialResults: true,
        onSoundLevelChange: (level) {
          setState(() {
            _soundLevel = level;
          });
        },
      );
      setState(() {
        _status = 'Listening...';
        _currentWords = '';
      });
    } catch (e) {
      print('Error starting listening: $e');
      setState(() {
        _status = 'Error starting: $e';
      });
    }
  }

  /// Stop listening for speech
  void _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() {
        _status = 'Manually stopped by user';
        _isListening = false;
        _soundLevel = 0.0;
        _recordingDuration = 0;
        if (_currentWords.isNotEmpty) {
          _recognizedSentences.add(_currentWords);
          _currentWords = '';
        }
      });
      print('Speech recognition stopped manually');
    } catch (e) {
      setState(() {
        _status = 'Error stopping: $e';
        _isListening = false;
        _soundLevel = 0.0;
        _recordingDuration = 0;
      });
    }
  }

  /// Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    print(
      'Speech result: ${result.recognizedWords}, confidence: ${result.confidence}, final: ${result.finalResult}',
    );
    setState(() {
      _currentWords = result.recognizedWords;

      if (_isListening && result.recognizedWords.isNotEmpty) {
        _status = 'Recording... (active speech detected)';
      } else if (_isListening) {
        _status = 'Listening...';
      }

      if (result.finalResult && _currentWords.isNotEmpty) {
        _recognizedSentences.add(_currentWords);
        _currentWords = '';
        if (_isListening) {
          _status = 'Listening...';
        }
      }
    });
  }

  /// Clear all recognized text
  void _clearText() {
    setState(() {
      _recognizedSentences.clear();
      _currentWords = '';
    });
  }

  /// Save current text to history
  void _saveToHistory() {
    final textToSave = _allText;
    if (textToSave.isNotEmpty) {
      HistoryManager.addHistoryItem(textToSave);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text saved to history'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text to save'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Get all text (previous sentences + current words)
  String get _allText {
    String allText = _recognizedSentences.join(' ');
    if (_currentWords.isNotEmpty) {
      allText += (allText.isEmpty ? '' : ' ') + _currentWords;
    }
    return allText;
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Converter',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.black),
            onPressed: _allText.isNotEmpty ? _saveToHistory : null,
            tooltip: 'Save to History',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _allText.isEmpty
                                ? (_speechEnabled
                                      ? 'Start speaking to see text here...'
                                      : 'Speech recognition not available')
                                : _allText,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.5,
                              color: _allText.isEmpty
                                  ? Colors.grey
                                  : Colors.black87,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (_allText.isNotEmpty && _currentWords.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _currentWords.split(' ').last,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isListening) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimationController,
                          builder: (context, child) {
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(
                                      _pulseAnimation.value - 0.8,
                                    ),
                                    spreadRadius: _pulseAnimation.value * 4,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Listening...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: AnimatedBuilder(
                        animation: _waveAnimationController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: EnhancedWaveformPainter(
                              animationValue: _waveAnimationController.value,
                              soundLevel: _soundLevel,
                            ),
                            size: Size(double.infinity, 60),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _speechEnabled && !_isListening
                              ? _startListening
                              : _isListening
                              ? _stopListening
                              : null,
                          icon: Icon(
                            _isListening ? Icons.pause : Icons.play_arrow,
                            size: 28,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red
                                    : Colors.black87,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (_isListening) ...[
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      spreadRadius: _pulseAnimation.value * 8,
                                      blurRadius: 12,
                                    ),
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.2),
                                      spreadRadius: _pulseAnimation.value * 16,
                                      blurRadius: 20,
                                    ),
                                  ] else ...[
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ],
                              ),
                              child: IconButton(
                                onPressed: _speechEnabled
                                    ? (_isListening
                                          ? _stopListening
                                          : _startListening)
                                    : null,
                                icon: Icon(
                                  _isListening ? Icons.stop : Icons.mic,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _clearText,
                          icon: const Icon(
                            Icons.refresh,
                            size: 28,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_speechEnabled || _isEmulator) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          if (_isEmulator)
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Running on emulator - Speech recognition may not work properly.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (!_speechEnabled)
                            Column(
                              children: [
                                if (_isEmulator) const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _status,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    bool hasPermission =
                                        await _checkPermissions();
                                    if (hasPermission) {
                                      _initSpeech();
                                    } else {
                                      setState(() {
                                        _status =
                                            'Microphone permission denied. Please enable it in device settings.';
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Check Permissions'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _waveAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final double soundLevel;

  WaveformPainter({required this.animationValue, required this.soundLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final barWidth = 3.0;
    final barSpacing = 5.0;
    final numberOfBars = (size.width / (barWidth + barSpacing)).floor();

    for (int i = 0; i < numberOfBars; i++) {
      final x = i * (barWidth + barSpacing);

      final baseHeight = 4.0;
      final animationOffset = (animationValue + i * 0.1) % 1.0;
      final waveHeight =
          baseHeight +
          (math.sin(animationOffset * 2 * math.pi) * 15 * (soundLevel + 0.3)) +
          (math.sin((animationOffset + 0.3) * 4 * math.pi) *
              8 *
              (soundLevel + 0.2));

      final height = math.max(baseHeight, waveHeight.abs());

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class EnhancedWaveformPainter extends CustomPainter {
  final double animationValue;
  final double soundLevel;

  EnhancedWaveformPainter({
    required this.animationValue,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barWidth = 2.0;
    final barSpacing = 1.5;
    final numberOfBars = (size.width / (barWidth + barSpacing)).floor();

    for (int i = 0; i < numberOfBars; i++) {
      final x = (i * (barWidth + barSpacing)) + barSpacing;

      final baseHeight = 4.0;
      final progress = i / numberOfBars;

      final mainWave =
          math.sin((animationValue * 2 * math.pi) + (progress * 4 * math.pi)) *
          0.6;
      final secondaryWave =
          math.sin((animationValue * 3 * math.pi) + (progress * 6 * math.pi)) *
          0.2;

      final soundMultiplier = 1.0 + (soundLevel * 1.5);

      final waveHeight =
          baseHeight + ((mainWave + secondaryWave) * 10 * soundMultiplier);

      final height = math.max(baseHeight, waveHeight.abs());

      final paint = Paint()..style = PaintingStyle.fill;

      final intensity = ((height - baseHeight) / 20.0).clamp(0.0, 1.0);
      final opacity = (0.5 + (intensity * 0.5)).clamp(0.5, 1.0);
      paint.color = Colors.black87.withOpacity(opacity);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
        const Radius.circular(1.0),
      );

      canvas.drawRRect(rect, paint);

      if (height > 10) {
        final highlightPaint = Paint()
          ..color = Colors.black54.withOpacity(0.15)
          ..style = PaintingStyle.fill;

        final highlightRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height / 2, barWidth * 0.3, height),
          const Radius.circular(1.0),
        );

        canvas.drawRRect(highlightRect, highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
