import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// DBService — wraps all SQLite operations for the 'memory' table.
/// If the database is empty, it returns a set of dummy records
/// so the hackathon demo never shows a blank screen.
class DBService {
  static final DBService _instance = DBService._internal();
  static Database? _db;

  factory DBService() => _instance;
  DBService._internal();

  // ─── Singleton DB initializer ────────────────────────────────────────────
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'memory.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create the table if it doesn't exist yet.
        // Your teammate's code may have already done this — openDatabase
        // only calls onCreate if the file is brand-new.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS memory (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name  TEXT,
            timestamp TEXT,
            duration  TEXT,
            date      TEXT
          )
        ''');

        // Seed dummy data so the demo is never empty on a fresh device.
        await _seedDummyData(db);
      },
    );
  }

  // ─── Seed dummy records for demo ─────────────────────────────────────────
  Future<void> _seedDummyData(Database db) async {
    final today = _todayString();
    final yesterday = _yesterdayString();

    final List<Map<String, String>> dummies = [
      {'app_name': 'Gmail',      'timestamp': '9:00 AM',  'duration': '10 min', 'date': today},
      {'app_name': 'WhatsApp',   'timestamp': '10:30 AM', 'duration': '20 min', 'date': today},
      {'app_name': 'YouTube',    'timestamp': '1:00 PM',  'duration': '45 min', 'date': today},
      {'app_name': 'Chrome',     'timestamp': '3:15 PM',  'duration': '15 min', 'date': today},
      {'app_name': 'Gmail',      'timestamp': '8:00 AM',  'duration': '5 min',  'date': yesterday},
      {'app_name': 'WhatsApp',   'timestamp': '11:00 AM', 'duration': '30 min', 'date': yesterday},
      {'app_name': 'Instagram',  'timestamp': '7:00 PM',  'duration': '25 min', 'date': yesterday},
    ];

    for (final record in dummies) {
      await db.insert('memory', record, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ─── Public query methods ─────────────────────────────────────────────────

  /// Returns all records, newest first.
  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final db = await database;
    return await db.query('memory', orderBy: 'id DESC');
  }

  /// Returns records for a specific date string (e.g. "Mar 13").
  Future<List<Map<String, dynamic>>> getByDate(String dateStr) async {
    final db = await database;
    return await db.query(
      'memory',
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: 'id DESC',
    );
  }

  /// Returns records whose app_name contains [appName] (case-insensitive).
  Future<List<Map<String, dynamic>>> getByApp(String appName) async {
    final db = await database;
    return await db.query(
      'memory',
      where: 'LOWER(app_name) LIKE ?',
      whereArgs: ['%${appName.toLowerCase()}%'],
      orderBy: 'id DESC',
    );
  }

  /// Returns the single most recent record.
  Future<Map<String, dynamic>?> getLatestRecord() async {
    final db = await database;
    final results = await db.query('memory', orderBy: 'id DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  /// Returns all records, grouped and summed by app_name.
  /// Each item has: { 'app_name': String, 'total_minutes': int }
  Future<List<Map<String, dynamic>>> getStatsGroupedByApp() async {
    final db = await database;
    final raw = await db.rawQuery('SELECT app_name, duration FROM memory');

    // Parse "XX min" strings and accumulate per-app totals in Dart.
    final Map<String, int> totals = {};
    for (final row in raw) {
      final app = (row['app_name'] as String?) ?? 'Unknown';
      final durStr = (row['duration'] as String?) ?? '0 min';
      final minutes = _parseDurationMinutes(durStr);
      totals[app] = (totals[app] ?? 0) + minutes;
    }

    // Convert to a sorted list (highest usage first).
    final result = totals.entries
        .map((e) => {'app_name': e.key, 'total_minutes': e.value})
        .toList();
    result.sort((a, b) =>
        (b['total_minutes'] as int).compareTo(a['total_minutes'] as int));
    return result;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Parses "10 min" → 10, "1 hr 30 min" → 90, etc.
  int _parseDurationMinutes(String dur) {
    int total = 0;
    final hrMatch = RegExp(r'(\d+)\s*hr').firstMatch(dur);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(dur);
    if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    return total;
  }

  String _todayString() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _yesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _formatDate(yesterday);
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }
}
