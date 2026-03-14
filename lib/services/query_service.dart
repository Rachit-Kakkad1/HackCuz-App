import 'db_service.dart';

/// QueryService — pure keyword-based query engine.
/// No AI, no ML, no APIs. Only simple string matching.
class QueryService {
  final DBService _db;

  QueryService({DBService? dbService}) : _db = dbService ?? DBService();

  // ─── Main entry point ─────────────────────────────────────────────────────

  /// Parse [question] and return a natural-language answer string.
  Future<String> ask(String question) async {
    final q = question.toLowerCase().trim();

    // Guard: empty question
    if (q.isEmpty) return 'Please type or speak a question.';

    // ── Step 1: Detect a date keyword ──────────────────────────────────────
    String? dateFilter;
    if (q.contains('today')) {
      dateFilter = _todayString();
    } else if (q.contains('yesterday')) {
      dateFilter = _yesterdayString();
    }

    // ── Step 2: Detect an app keyword ──────────────────────────────────────
    final String? appFilter = _detectApp(q);

    // ── Step 3: Detect "last" / "latest" ───────────────────────────────────
    final bool wantsLatest = q.contains('last') || q.contains('latest');

    // ── Step 4: Query the database ─────────────────────────────────────────
    List<Map<String, dynamic>> records;

    if (wantsLatest && appFilter == null && dateFilter == null) {
      // "What was the last app I used?"
      final single = await _db.getLatestRecord();
      records = single != null ? [single] : [];
    } else if (appFilter != null && dateFilter != null) {
      // Combo: "Did I use Gmail today?"
      final byApp = await _db.getByApp(appFilter);
      records = byApp
          .where((r) => (r['date'] as String?) == dateFilter)
          .toList();
    } else if (appFilter != null) {
      // "How long did I use WhatsApp?"
      records = await _db.getByApp(appFilter);
    } else if (dateFilter != null) {
      // "What did I use today?"
      records = await _db.getByDate(dateFilter);
    } else {
      // Fallback: return the most recent record
      final single = await _db.getLatestRecord();
      records = single != null ? [single] : [];
    }

    // ── Step 5: Build a natural-language response ──────────────────────────
    return _buildAnswer(records, appFilter, dateFilter, wantsLatest);
  }

  // ─── Response builder ────────────────────────────────────────────────────

  String _buildAnswer(
    List<Map<String, dynamic>> records,
    String? appFilter,
    String? dateFilter,
    bool wantsLatest,
  ) {
    if (records.isEmpty) {
      if (appFilter != null && dateFilter != null) {
        return 'No usage data found for $appFilter on $dateFilter.';
      } else if (appFilter != null) {
        return 'No records found for $appFilter.';
      } else if (dateFilter != null) {
        return 'No usage data found for $dateFilter.';
      }
      return 'No records found. Start tracking to see your memory data.';
    }

    // If a single specific record is expected, show it in detail.
    if (wantsLatest || records.length == 1) {
      final r = records.first;
      return _formatSingle(r);
    }

    // Multiple records: show the most used (longest duration) one + count.
    // ⚠️ SQLite returns a read-only list — copy it before sorting.
    final sorted = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => _parseMins(b['duration']) - _parseMins(a['duration']));
    final top = sorted.first;
    final totalMins = sorted.fold<int>(0, (sum, r) => sum + _parseMins(r['duration']));
    final answer = _formatSingle(top);
    return '$answer\n(${records.length} sessions found, $totalMins min total)';
  }

  String _formatSingle(Map<String, dynamic> r) {
    final app = r['app_name'] ?? 'an app';
    final dur = r['duration'] ?? 'some time';
    final time = r['timestamp'] ?? '';
    final date = r['date'] ?? '';
    final when = [if (date.isNotEmpty) date, if (time.isNotEmpty) time].join(' at ');
    return 'You used $app for $dur${when.isNotEmpty ? " ($when)" : ""}.';
  }

  // ─── Keyword helpers ──────────────────────────────────────────────────────

  // Map common spoken app names → search terms.
  static const Map<String, String> _appKeywords = {
    'gmail'      : 'gmail',
    'mail'       : 'gmail',
    'email'      : 'gmail',
    'whatsapp'   : 'whatsapp',
    'whats app'  : 'whatsapp',
    'youtube'    : 'youtube',
    'yt'         : 'youtube',
    'chrome'     : 'chrome',
    'instagram'  : 'instagram',
    'insta'      : 'instagram',
    'facebook'   : 'facebook',
    'fb'         : 'facebook',
    'twitter'    : 'twitter',
    'spotify'    : 'spotify',
    'maps'       : 'maps',
    'google maps': 'maps',
    'netflix'    : 'netflix',
  };

  String? _detectApp(String q) {
    for (final entry in _appKeywords.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ─── Date helpers ─────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return _fmtDate(now);
  }

  String _yesterdayString() {
    return _fmtDate(DateTime.now().subtract(const Duration(days: 1)));
  }

  String _fmtDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }

  int _parseMins(dynamic durRaw) {
    final dur = (durRaw as String?) ?? '';
    int total = 0;
    final hrM = RegExp(r'(\d+)\s*hr').firstMatch(dur);
    final minM = RegExp(r'(\d+)\s*min').firstMatch(dur);
    if (hrM != null) total += int.parse(hrM.group(1)!) * 60;
    if (minM != null) total += int.parse(minM.group(1)!);
    return total;
  }
}
