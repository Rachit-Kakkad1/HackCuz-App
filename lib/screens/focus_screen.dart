import 'dart:async';
import 'package:flutter/material.dart';

/// FocusScreen — Task 6 (Part 2)
/// 25-minute Pomodoro-style countdown timer.
/// Start / Pause / Reset controls + circular progress indicator.
/// No app-blocking required.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  // ─── Constants ────────────────────────────────────────────────────────────
  static const int _totalSeconds = 25 * 60; // 25 minutes

  // ─── State ────────────────────────────────────────────────────────────────
  int _remaining = _totalSeconds;
  bool _isRunning = false;
  Timer? _timer;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Timer controls ───────────────────────────────────────────────────────

  void _start() {
    if (_remaining == 0) return;
    setState(() => _isRunning = true);
    _pulseCtrl.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
        _pulseCtrl.stop();
        setState(() => _isRunning = false);
        _showDoneDialog();
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _pulseCtrl.stop(canceled: false);
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    _pulseCtrl.stop(canceled: false);
    setState(() {
      _isRunning = false;
      _remaining = _totalSeconds;
    });
  }

  // ─── Completion dialog ────────────────────────────────────────────────────

  void _showDoneDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Focus Complete!'),
        ]),
        content:
            const Text('Great work! You completed a 25-minute focus session.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reset();
            },
            child: const Text('Start Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      1.0 - (_remaining / _totalSeconds);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = _remaining == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Instructional label ────────────────────────────────────
              Text(
                _isRunning
                    ? '🧠 Stay focused…'
                    : isDone
                        ? '✅ Session complete!'
                        : '🎯 Ready to focus?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 36),

              // ── Circular progress + time label ─────────────────────────
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  final scale = _isRunning
                      ? 1.0 + _pulseCtrl.value * 0.02
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      // Progress arc
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          color: isDone
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                      ),
                      // Time label
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _timeLabel,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Text('remaining',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Control buttons ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(110, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Start / Pause
                  ElevatedButton.icon(
                    onPressed: isDone
                        ? null
                        : (_isRunning ? _pause : _start),
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? 'Pause' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Mini tip
              Text(
                '25 min focus + 5 min break = Pomodoro ✅',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
