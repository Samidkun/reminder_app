import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar/isar.dart';
import 'isar_service.dart';
import '../features/alarm/data/models/alarm_model.dart';

class AlarmService {
  static const String _isolateName = 'alarm_isolate';
  
  /// Global instances for the background isolate
  static AudioPlayer? _backgroundAudioPlayer;
  static FlutterLocalNotificationsPlugin? _backgroundNotifications;

  /// Initialize the alarm manager in the main isolate
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();
  }

  /// Request necessary permissions for Android 12+ and 13+
  static Future<bool> requestPermissions() async {
    final notificationStatus = await Permission.notification.request();
    final alarmStatus = await Permission.scheduleExactAlarm.request();

    return notificationStatus.isGranted && alarmStatus.isGranted;
  }

  /// Entry point for the background isolate
  /// [id] is the alarm ID passed from scheduleAlarm
  @pragma('vm:entry-point')
  static Future<void> callback(int id) async {
    print('Alarm triggered for ID: $id at ${DateTime.now()}');
    
    // 1. Initialize logic INSIDE the background isolate
    _backgroundNotifications ??= FlutterLocalNotificationsPlugin();
    _backgroundAudioPlayer ??= AudioPlayer();

    // 2. Fetch alarm details from Isar
    final isar = await IsarService.getInstance();
    final alarm = await isar.alarmModels.get(id);
    
    if (alarm == null) {
      print('Alarm with ID $id not found in Isar.');
      return;
    }

    // 3. Show Full-Screen Intent Notification with challengeType
    await _showAlarmNotification(_backgroundNotifications!, alarm);

    // 4. Start Looping Audio on Alarm Stream
    await _playAlarmSound(_backgroundAudioPlayer!, alarm.audioPath);
    
    // Communicate with the main isolate if needed
    final SendPort? send = IsolateNameServer.lookupPortByName(_isolateName);
    send?.send(id);
  }

  /// Schedule an exact alarm with anti-kill parameters
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

  /// Cancel a scheduled alarm
  static Future<void> cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
  }

  static Future<void> _showAlarmNotification(
      FlutterLocalNotificationsPlugin notifications, AlarmModel alarm) async {
    
    final androidDetails = AndroidNotificationDetails(
      'high_reliability_alarm_channel',
      'Alarms',
      channelDescription: 'Channel for critical alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      // Provide custom actions or payload to distinguish challenge type
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await notifications.show(
      alarm.id,
      alarm.title,
      'Alarm is ringing! Challenge: ${alarm.challengeType.toUpperCase()}',
      notificationDetails,
      payload: 'alarm_id=${alarm.id}&challenge=${alarm.challengeType}',
    );
  }

  static Future<void> _playAlarmSound(AudioPlayer player, String? audioPath) async {
    try {
      await player.setAndroidAudioAttributes(const AndroidAudioAttributes(
        usage: AndroidAudioUsage.alarm,
        contentType: AndroidAudioContentType.music,
      ));

      if (audioPath != null && audioPath.isNotEmpty) {
        // Handle custom file path or asset
        if (audioPath.startsWith('assets/')) {
          await player.setAudioSource(AudioSource.asset(audioPath));
        } else {
          await player.setAudioSource(AudioSource.file(audioPath));
        }
      } else {
        // Fallback to default
        await player.setAudioSource(AudioSource.asset('assets/audio/alarm.mp3'));
      }

      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);
      await player.play();
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
  }

  static Future<void> stopAlarm() async {
    await _backgroundAudioPlayer?.stop();
    // In a real app, you'd need the ID to cancel the specific notification
    await _backgroundNotifications?.cancelAll();
  }
}
