// lib/features/tracking/widgets/voice_input_widget.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputWidget extends StatefulWidget {
  final Function(String) onTextReceived;
  final Color? iconColor;
  final double? iconSize;

  const VoiceInputWidget({
    Key? key,
    required this.onTextReceived,
    this.iconColor,
    this.iconSize = 40,
  }) : super(key: key);

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _hasPermission = false;
  String _recognizedText = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _checkPermissionAndInitialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }

  // Check microphone permission and initialize speech recognition
  Future<void> _checkPermissionAndInitialize() async {
    final status = await Permission.microphone.status;
    
    setState(() {
      _hasPermission = status.isGranted;
    });

    if (_hasPermission) {
      await _initializeSpeech();
    }
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          setState(() {
            _isListening = false;
          });
          _showErrorSnackBar('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      
      setState(() {});
      
      if (!_speechAvailable) {
        _showErrorSnackBar('Speech recognition not available on this device');
      }
    } catch (e) {
      print('Error initializing speech: $e');
      _showErrorSnackBar('Failed to initialize speech recognition');
    }
  }

  // Request microphone permission
  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    
    setState(() {
      _hasPermission = status.isGranted;
    });

    if (status.isGranted) {
      await _initializeSpeech();
      _showSuccessSnackBar('Microphone permission granted!');
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    } else {
      _showErrorSnackBar('Microphone permission denied');
    }
  }

  // Show permission dialog for permanently denied
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Microphone Permission'),
          ],
        ),
        content: const Text(
          'Microphone permission is required for voice input. '
          'Please enable it in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Start listening
  Future<void> _startListening() async {
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }

    if (!_speechAvailable) {
      _showErrorSnackBar('Speech recognition not available');
      return;
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          
          if (result.finalResult) {
            widget.onTextReceived(_recognizedText);
            _stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      );
    } catch (e) {
      print('Error starting listening: $e');
      setState(() {
        _isListening = false;
      });
      _showErrorSnackBar('Failed to start listening');
    }
  }

  // Stop listening
  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _startListening,
      onLongPress: _stopListening,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _scaleAnimation.value : 1.0,
            child: Container(
              width: widget.iconSize,
              height: widget.iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.red.withOpacity(0.2)
                    : (_hasPermission 
                        ? Colors.blue.withOpacity(0.1) 
                        : Colors.grey.withOpacity(0.1)),
                border: Border.all(
                  color: _isListening
                      ? Colors.red
                      : (_hasPermission ? Colors.blue : Colors.grey),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _isListening
                        ? Icons.mic
                        : (_hasPermission ? Icons.mic_none : Icons.mic_off),
                    color: _isListening
                        ? Colors.red
                        : (_hasPermission 
                            ? (widget.iconColor ?? Colors.blue) 
                            : Colors.grey),
                    size: (widget.iconSize ?? 40) * 0.5,
                  ),
                  if (!_hasPermission)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}