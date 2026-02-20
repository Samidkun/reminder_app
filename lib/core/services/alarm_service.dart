import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar/isar.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'isar_service.dart';
import '../../features/alarm/data/models/alarm_model.dart';

class AlarmService {
  static const String _isolateName = 'alarm_isolate';

  static AudioPlayer? _backgroundAudioPlayer;
  static FlutterLocalNotificationsPlugin? _backgroundNotifications;

  /// Cancel a scheduled alarm
  static Future<void> cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
  }

  /// Cancel all scheduled alarms
  static Future<void> cancelAll() async {
    try {
      final isar = await IsarService.getInstance();
      final alarms = await isar.alarmModels.where().findAll();
      for (final alarm in alarms) {
        await AndroidAlarmManager.cancel(alarm.id);
      }
    } catch (e) {
      print('Error cancelling all alarms: $e');
    }
  }

  /// Initialize the alarm manager in the main isolate
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    // Reboot Recovery: Reschedule all active alarms on app start
    await rescheduleAllActiveAlarms();
  }

  /// Reboot Recovery: Reregister all isActive alarms with the System
  static Future<void> rescheduleAllActiveAlarms() async {
    try {
      final isar = await IsarService.getInstance();
      final activeAlarms =
          await isar.alarmModels.filter().isActiveEqualTo(true).findAll();

      for (final alarm in activeAlarms) {
        if (alarm.time.isAfter(DateTime.now())) {
          await scheduleAlarm(alarm.id, alarm.time);
        } else if (alarm.repeatDays.isNotEmpty) {
          final nextTime =
              _calculateNextOccurrence(alarm.time, alarm.repeatDays);
          await scheduleAlarm(alarm.id, nextTime);
        }
      }
    } catch (e) {
      print('Error rescheduling alarms: $e');
    }
  }

  /// Request necessary permissions
  static Future<void> requestPermissions() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await checkBatteryOptimization();
  }

  static Future<void> checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.porto.reminder_app',
      );
      await intent.launch();
    }
  }

  /// Entry point for the background isolate
  @pragma('vm:entry-point')
  static Future<void> callback(int id) async {
    print('Alarm triggered for ID: $id at ${DateTime.now()}');

    VolumeController().setVolume(1.0);

    _backgroundNotifications ??= FlutterLocalNotificationsPlugin();
    _backgroundAudioPlayer ??= AudioPlayer();

    try {
      final isar = await IsarService.getInstance();
      final alarm = await isar.alarmModels.get(id);

      if (alarm == null) return;

      await _showAlarmNotification(_backgroundNotifications!, alarm);
      await _playAlarmSound(_backgroundAudioPlayer!, alarm.audioPath);
    } catch (e) {
      print('Error in background callback: $e');
    }

    final SendPort? send = IsolateNameServer.lookupPortByName(_isolateName);
    send?.send(id);
  }

  /// Schedule an exact alarm
  static Future<void> scheduleAlarm(int id, DateTime time) async {
    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      callback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  /// Handle Alarm Dismissal (Auto-Reschedule if recurring)
  static Future<void> handleAlarmDismissal(int id) async {
    try {
      final isar = await IsarService.getInstance();
      final alarm = await isar.alarmModels.get(id);

      if (alarm != null) {
        if (alarm.repeatDays.isNotEmpty) {
          final nextTime =
              _calculateNextOccurrence(alarm.time, alarm.repeatDays);
          alarm.time = nextTime;

          await isar.writeTxn(() async {
            await isar.alarmModels.put(alarm);
          });

          await scheduleAlarm(alarm.id, nextTime);
        } else {
          alarm.isActive = false;
          await isar.writeTxn(() async {
            await isar.alarmModels.put(alarm);
          });
        }
      }
    } catch (e) {
      print('Error dismissing alarm: $e');
    }

    await stopAlarm();
  }

  static DateTime _calculateNextOccurrence(
      DateTime currentTime, List<int> repeatDays) {
    if (repeatDays.isEmpty) return currentTime.add(const Duration(days: 1));

    DateTime nextDate = currentTime.add(const Duration(days: 1));
    while (!repeatDays.contains(nextDate.weekday)) {
      nextDate = nextDate.add(const Duration(days: 1));
    }
    return nextDate;
  }

  static Future<void> _showAlarmNotification(
      FlutterLocalNotificationsPlugin notifications, AlarmModel alarm) async {
    const androidDetails = AndroidNotificationDetails(
      'critical_alarm_channel',
      'Critical Alarms',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await notifications.show(
      alarm.id,
      alarm.title,
      'Challenge required: ${alarm.challengeType}',
      const NotificationDetails(android: androidDetails),
      payload: 'alarm_id=${alarm.id}',
    );
  }

  static Future<void> _playAlarmSound(
      AudioPlayer player, String? audioPath) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        androidAudioAttributes: AndroidAudioAttributes(
          usage: AndroidAudioUsage.alarm,
          contentType: AndroidAudioContentType.music,
        ),
      ));

      if (audioPath != null && audioPath.isNotEmpty) {
        if (audioPath.startsWith('assets/')) {
          await player.setAudioSource(AudioSource.asset(audioPath));
        } else {
          await player.setAudioSource(AudioSource.file(audioPath));
        }
      } else {
        await player
            .setAudioSource(AudioSource.asset('assets/audio/alarm.mp3'));
      }

      await player.setLoopMode(LoopMode.one);
      await player.play();
    } catch (e) {
      print('Audio error: $e');
    }
  }

  static Future<void> stopAlarm() async {
    await _backgroundAudioPlayer?.stop();
    await _backgroundNotifications?.cancelAll();
  }
}
