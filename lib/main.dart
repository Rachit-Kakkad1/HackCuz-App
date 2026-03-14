import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:usage_stats/usage_stats.dart';
import 'database_helper.dart';
import 'background_service.dart';
import 'services/usage_service.dart';

// New screens
import 'screens/ask_memory_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/focus_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't await — let runApp() render the first frame while
  // the background service configures itself asynchronously.
  initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Memory Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── HomeScreen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    // Defer heavy async work until after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServiceStatus();
      _setupUsageBridge();
    });
  }

  /// Sets up the messaging bridge between the background service and the
  /// main isolate. When the background service requests usage data via
  /// 'fetchUsage', the main isolate fetches it (since usage_stats only
  /// works here) and sends it back via 'usageData'.
  void _setupUsageBridge() {
    final service = FlutterBackgroundService();

    service.on('fetchUsage').listen((event) async {
      try {
        final foregroundApp = await UsageService.getMostRecentForegroundApp(
          lookback: const Duration(seconds: 30),
        );

        service.invoke('usageData', {
          'foregroundApp': foregroundApp ?? '',
        });
      } catch (e) {
        print('Error fetching usage in main isolate: $e');
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    setState(() => _isServiceRunning = running);
  }

  Future<void> _requestUsagePermission() async {
    // Usage permission check — uses the usage_stats plugin which is
    // safe here in the main isolate.
    try {
      final isGranted = await UsageStats.checkUsagePermission();
      if (isGranted == null || !isGranted) {
        await UsageStats.grantUsagePermission();
      }
    } catch (e) {
      print('Error checking usage permission: $e');
    }
  }

  Future<void> _toggleService() async {
    await _requestUsagePermission();
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke("stopService");
    } else {
      await service.startService();
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  void _navigate(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Memory Tracker'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── App icon + status ──────────────────────────────────────────
            Icon(Icons.memory, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              _isServiceRunning ? '🟢 Tracking Active' : '🔴 Tracking Stopped',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // ── Start / Stop tracking ──────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _toggleService,
              icon: Icon(_isServiceRunning ? Icons.stop : Icons.play_arrow),
              label:
                  Text(_isServiceRunning ? 'Stop Tracking' : 'Start Tracking'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Features', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),

            // ── Feature nav grid ───────────────────────────────────────────
            _NavTile(
              icon: Icons.history,
              label: 'Memory Timeline',
              subtitle: 'View all recorded events',
              onTap: () => _navigate(const TimelineScreen()),
            ),
            const SizedBox(height: 10),
            _NavTile(
              icon: Icons.question_answer_outlined,
              label: 'Ask Your Memory',
              subtitle: 'Query by voice or text',
              onTap: () => _navigate(const AskMemoryScreen()),
            ),
            const SizedBox(height: 10),
            _NavTile(
              icon: Icons.bar_chart_outlined,
              label: 'Screen Time Stats',
              subtitle: 'See usage by app',
              onTap: () => _navigate(const StatsScreen()),
            ),
            const SizedBox(height: 10),
            _NavTile(
              icon: Icons.timer_outlined,
              label: 'Focus Mode',
              subtitle: '25-min Pomodoro timer',
              onTap: () => _navigate(const FocusScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable nav tile ────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ─── TimelineScreen (unchanged from original, kept here) ─────────────────────

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    FlutterBackgroundService().on('update').listen((event) {
      if (mounted) _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    final events = await DatabaseHelper().getEvents();
    setState(() => _events = events);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Timeline'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
        ],
      ),
      body: _events.isEmpty
          ? const Center(child: Text('No memory events yet.'))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(event['app_name'] ?? 'Unknown App'),
                    subtitle: Text(event['duration'] != null
                        ? '${event['duration']} duration'
                        : 'App Opened'),
                    trailing: Text(
                      event['timestamp'] ?? '',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
