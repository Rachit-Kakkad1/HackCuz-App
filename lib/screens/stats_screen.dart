import 'package:flutter/material.dart';
import '../services/db_service.dart';

/// StatsScreen — Task 6 (Part 1)
/// Fetches all records from SQLite, groups them by app_name,
/// sums the durations, and shows a sorted leaderboard list.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DBService _db = DBService();
  List<Map<String, dynamic>> _stats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final data = await _db.getStatsGroupedByApp();
    // Guard: widget may have been disposed while the async DB call was in-flight.
    if (!mounted) return;
    setState(() {
      _stats = data;
      _isLoading = false;
    });
  }

  // Format minutes → "1 hr 5 min" or "45 min"
  String _fmtMins(int mins) {
    if (mins >= 60) {
      final hr = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '$hr hr $m min' : '$hr hr';
    }
    return '$mins min';
  }

  // Pick an icon for well-known apps
  IconData _iconFor(String app) {
    final a = app.toLowerCase();
    if (a.contains('gmail') || a.contains('mail')) return Icons.email_outlined;
    if (a.contains('whatsapp')) return Icons.chat_bubble_outline;
    if (a.contains('youtube')) return Icons.play_circle_outlined;
    if (a.contains('chrome')) return Icons.language_outlined;
    if (a.contains('instagram')) return Icons.camera_alt_outlined;
    if (a.contains('facebook')) return Icons.thumb_up_alt_outlined;
    if (a.contains('twitter')) return Icons.tag;
    if (a.contains('spotify')) return Icons.music_note_outlined;
    if (a.contains('maps')) return Icons.map_outlined;
    if (a.contains('netflix')) return Icons.movie_outlined;
    return Icons.phone_android_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time Stats'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('No data yet.\nStart tracking to see stats.',
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Summary banner ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Apps tracked',
                              style: theme.textTheme.labelLarge),
                          Text('${_stats.length}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),

                    // ── Stats list ─────────────────────────────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _stats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = _stats[i];
                          final app = item['app_name'] as String;
                          final mins = item['total_minutes'] as int;
                          // Compute width ratio relative to max usage
                          final maxMins =
                              (_stats.first['total_minutes'] as int).toDouble();
                          final ratio = maxMins > 0 ? mins / maxMins : 0.0;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // App name row
                                  Row(
                                    children: [
                                      Icon(_iconFor(app),
                                          size: 22,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(app,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ),
                                      Text(_fmtMins(mins),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                  color: theme
                                                      .colorScheme.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: theme
                                          .colorScheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
