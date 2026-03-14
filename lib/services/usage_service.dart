import 'package:usage_stats/usage_stats.dart';

/// UsageService — wraps usage_stats plugin calls.
///
/// IMPORTANT: This service must ONLY be called from the main (UI) isolate.
/// The usage_stats plugin relies on Flutter platform channels, which are
/// unavailable in background isolates.
class UsageService {
  /// Returns a list of maps with package names from recent foreground events.
  /// Each map contains: { 'packageName': String, 'eventType': String }
  static Future<List<Map<String, String>>> fetchRecentUsage({
    Duration lookback = const Duration(seconds: 30),
  }) async {
    final now = DateTime.now();
    final start = now.subtract(lookback);

    final List<EventUsageInfo> events =
        await UsageStats.queryEvents(start, now);

    // Sort descending by timestamp
    events.sort((a, b) => (b.timeStamp ?? '').compareTo(a.timeStamp ?? ''));

    return events
        .where((e) => e.packageName != null)
        .map((e) => {
              'packageName': e.packageName ?? '',
              'eventType': e.eventType ?? '',
            })
        .toList();
  }

  /// Returns the package name of the most recently foregrounded app,
  /// or null if no foreground event was found.
  static Future<String?> getMostRecentForegroundApp({
    Duration lookback = const Duration(seconds: 30),
  }) async {
    final events = await fetchRecentUsage(lookback: lookback);

    // Look for MOVE_TO_FOREGROUND event (type '1')
    for (final event in events) {
      if (event['eventType'] == '1') {
        return event['packageName'];
      }
    }

    // Fallback to the latest event of any type
    return events.isNotEmpty ? events.first['packageName'] : null;
  }
}
