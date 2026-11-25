import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _channelId = 'medicine_reminders';
  static const String _channelName = 'Medicine reminders';
  static const String _channelDescription =
      'Reminders for scheduled medicine doses.';

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return false;

    return await android.requestNotificationsPermission() ?? true;
  }

  static int frequencyCount(Map<String, dynamic> medicine) {
    final value = (medicine['frequency'] ?? '').toString().toLowerCase();

    if (value.contains('3') || value.contains('three')) return 3;
    if (value.contains('2') || value.contains('twice')) return 2;

    return 1;
  }

  static List<({int hour, int minute})> _times(
    Map<String, dynamic> medicine,
  ) {
    final instruction =
        (medicine['instruction'] ?? '').toString().toLowerCase();
    final timing = (medicine['timing'] ?? '').toString().toLowerCase();
    final frequency = frequencyCount(medicine);

    if ((instruction.contains('morning') &&
            instruction.contains('night')) ||
        (timing.contains('morning') && timing.contains('night'))) {
      return [(hour: 8, minute: 0), (hour: 20, minute: 0)];
    }

    if (instruction.contains('before breakfast') ||
        timing.contains('before breakfast')) {
      return [(hour: 7, minute: 30)];
    }

    if (frequency == 3) {
      return [
        (hour: 8, minute: 0),
        (hour: 14, minute: 0),
        (hour: 20, minute: 0),
      ];
    }

    if (frequency == 2) {
      return [
        (hour: 8, minute: 0),
        (hour: 20, minute: 0),
      ];
    }

    return [(hour: 8, minute: 0)];
  }

  static int _durationDays(Map<String, dynamic> medicine) {
    final value = (medicine['duration'] ?? '').toString().toLowerCase();
    final match = RegExp(r'(\d+)').firstMatch(value);
    final days = int.tryParse(match?.group(1) ?? '');
    return days != null && days > 0 ? days : 1;
  }

  static String _dosage(Map<String, dynamic> medicine) =>
      (medicine['dosage'] ?? '').toString();

  static String _timing(Map<String, dynamic> medicine) =>
      (medicine['timing'] ?? '').toString();

  static String _name(Map<String, dynamic> medicine) =>
      (medicine['name'] ?? 'Medicine').toString();

  static Future<void> scheduleMedicines(
    List<Map<String, dynamic>> medicines,
  ) async {
    await initialize();
    await _plugin.cancelAll();

    if (medicines.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: '@mipmap/ic_launcher',
      ),
    );

    for (var medicineIndex = 0;
        medicineIndex < medicines.length;
        medicineIndex++) {
      final medicine = medicines[medicineIndex];
      final name = _name(medicine);
      final dosage = _dosage(medicine);
      final timing = _timing(medicine);
      final duration = _durationDays(medicine);
      final times = _times(medicine);

      for (var day = 0; day < duration; day++) {
        for (var slot = 0; slot < times.length; slot++) {
          final time = times[slot];

          final scheduled =
              tz.TZDateTime(tz.local, now.year, now.month, now.day + day,
                  time.hour, time.minute);

          if (scheduled.isBefore(now)) continue;

          final id = (medicineIndex * 100000) + (day * 100) + slot + 1;

          final instruction =
              (medicine['instruction'] ?? '').toString();

          final bodyParts = <String>[
            if (dosage.isNotEmpty) dosage,
            if (timing.isNotEmpty) timing,
            if (instruction.isNotEmpty) instruction,
          ];

          await _plugin.zonedSchedule(
            id: id,
            title: 'Time to take $name',
            body: bodyParts.isEmpty
                ? 'Your scheduled medicine dose is due now.'
                : bodyParts.join(' • '),
            scheduledDate: scheduled,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: name,
          );
        }
      }
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static Future<void> showTestNotification() async {
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      id: 999999,
      title: 'MediScan Lite reminder',
      body: 'Notifications are working correctly on this device.',
      notificationDetails: details,
    );
  }
}
