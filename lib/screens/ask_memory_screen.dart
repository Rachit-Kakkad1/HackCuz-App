import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/query_service.dart';
import '../widgets/answer_card.dart';

/// AskMemoryScreen — Task 4 + Task 5
/// • TextField for question input
/// • Mic button for voice input (speech_to_text)
/// • Ask button to run keyword-based query
/// • AnswerCard to display the result
class AskMemoryScreen extends StatefulWidget {
  const AskMemoryScreen({super.key});

  @override
  State<AskMemoryScreen> createState() => _AskMemoryScreenState();
}

class _AskMemoryScreenState extends State<AskMemoryScreen> {
  final TextEditingController _questionCtrl = TextEditingController();
  final QueryService _queryService = QueryService();

  // speech_to_text state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // query state
  String? _answer;
  bool _isLoading = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  // ─── Speech Helpers ───────────────────────────────────────────────────────

  /// Initialise the speech recogniser once on startup.
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        // Auto-stop listening UI when the engine goes idle
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          // Auto-run the query if the text field has content
          if (_questionCtrl.text.trim().isNotEmpty) {
            _runQuery();
          }
        }
      },
    );
    setState(() {});
  }

  /// Toggle microphone listening.
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnack('Microphone permission is not available.');
      return;
    }

    if (_isListening) {
      // Stop listening
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      // Start listening
      setState(() {
        _isListening = true;
        _answer = null;
      });

      await _speech.listen(
        onResult: (result) {
          // Update the text field in real-time as speech is recognised
          setState(() {
            _questionCtrl.text = result.recognizedWords;
            _questionCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _questionCtrl.text.length),
            );
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
        // Listen until we get a final result and auto-stop
        partialResults: true,
      );
    }
  }

  // ─── Query Helpers ────────────────────────────────────────────────────────

  Future<void> _runQuery() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      _showSnack('Please type or speak a question first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _answer = null;
    });

    final result = await _queryService.ask(question);

    setState(() {
      _answer = result;
      _isLoading = false;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Your Memory'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header label ──────────────────────────────────────────────
              Text(
                'What would you like to know?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ── Question input row ────────────────────────────────────────
              Row(
                children: [
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _questionCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runQuery(),
                      decoration: InputDecoration(
                        hintText: 'e.g. "How long did I use Gmail today?"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Mic button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.redAccent
                          : theme.colorScheme.primaryContainer,
                    ),
                    child: IconButton(
                      tooltip: _isListening ? 'Stop listening' : 'Speak',
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Ask button ────────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runQuery,
                icon: const Icon(Icons.search),
                label: const Text('Ask'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Show "Listening…" indicator
              if (_isListening) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('Listening…',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.redAccent)),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // ── Answer card ───────────────────────────────────────────────
              Expanded(
                child: AnswerCard(answer: _answer, isLoading: _isLoading),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
