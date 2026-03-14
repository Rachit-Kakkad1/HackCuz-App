import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // User will start it manually
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Cognitive Memory Tracker',
      initialNotificationContent: 'Tracking active app...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), // Not used as requested Android-only
  );
}

/// Background isolate entry point.
///
/// IMPORTANT: Do NOT call UI-only plugins here (usage_stats, speech_to_text,
/// camera, etc.). They depend on the main isolate's BinaryMessenger which is
/// not available in background isolates.
///
/// Instead, this function asks the main isolate to fetch usage data via the
/// service messaging bridge (`service.invoke('fetchUsage')`).
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ── Listen for usage data sent back from the main isolate ──────────────
  service.on('usageData').listen((event) async {
    if (event == null) return;

    try {
      final String? foregroundApp = event['foregroundApp'] as String?;

      if (foregroundApp != null &&
          foregroundApp.isNotEmpty &&
          foregroundApp != 'com.example.cognitive_memory_tracker') {
        final db = DatabaseHelper();
        final now = DateTime.now();
        String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);

        await db.insertEvent({
          'app_name': foregroundApp,
          'timestamp': formattedDate,
          'duration': 20, // Estimated duration in seconds since last check
          'date': DateFormat('yyyy-MM-dd').format(now),
        });

        print('Saved event for: $foregroundApp');

        // Notify the UI (if alive) to refresh
        service.invoke('update');
      }
    } catch (e) {
      print('Error saving usage data: $e');
    }
  });

  // ── Periodically request usage data from the main isolate ──────────────
  Timer.periodic(const Duration(seconds: 20), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    print('Background service: Requesting usage data from main isolate...');

    // Ask the main isolate to fetch usage stats (it has access to the plugin)
    service.invoke('fetchUsage');
  });
}
