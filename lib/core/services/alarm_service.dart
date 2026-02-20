import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmService {
  static const String _isolateName = 'alarm_isolate';
  
  /// Global instance for the background isolate
  static AudioPlayer? _backgroundAudioPlayer;
  static FlutterLocalNotificationsPlugin? _backgroundNotifications;

  /// Initialize the alarm manager in the main isolate
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();
  }

  /// Request necessary permissions for Android 12+ and 13+
  static Future<bool> requestPermissions() async {
    // Android 13+ notification permission
    final status = await Permission.notification.request();
    
    // Android 12+ Exact Alarm permission
    // For SCHEDULE_EXACT_ALARM, it's often automatically granted if declared,
    // but on some devices/versions it needs explicit check/request.
    final alarmStatus = await Permission.scheduleExactAlarm.request();

    return status.isGranted && alarmStatus.isGranted;
  }

  /// Entry point for the background isolate
  @pragma('vm:entry-point')
  static Future<void> callback() async {
    print('Alarm triggered at ${DateTime.now()}');
    
    // 1. Initialize logic INSIDE the background isolate
    _backgroundNotifications ??= FlutterLocalNotificationsPlugin();
    _backgroundAudioPlayer ??= AudioPlayer();

    // 2. Show Full-Screen Intent Notification (Max Priority)
    await _showAlarmNotification(_backgroundNotifications!);

    // 3. Start Looping Audio on Alarm Stream
    await _playAlarmSound(_backgroundAudioPlayer!);
    
    // Communicate with the main isolate if needed
    final SendPort? send = IsolateNameServer.lookupPortByName(_isolateName);
    send?.send(true);
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

  static Future<void> _showAlarmNotification(
      FlutterLocalNotificationsPlugin notifications) async {
    
    const androidDetails = AndroidNotificationDetails(
      'high_reliability_alarm_channel',
      'Alarms',
      channelDescription: 'Channel for critical alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true, // Prevents swipe-to-dismiss
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await notifications.show(
      0,
      'Alarm!',
      'Time to wake up!',
      notificationDetails,
      payload: 'alarm_triggered',
    );
  }

  static Future<void> _playAlarmSound(AudioPlayer player) async {
    try {
      // Set Android Audio Attributes to use the Alarm Stream
      await player.setAndroidAudioAttributes(const AndroidAudioAttributes(
        usage: AndroidAudioUsage.alarm,
        contentType: AndroidAudioContentType.music,
      ));

      await player.setAudioSource(
        AudioSource.asset('assets/audio/alarm.mp3'),
      );
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);
      
      await player.play();
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
  }

  static Future<void> stopAlarm() async {
    await _backgroundAudioPlayer?.stop();
    // Also cancel the ongoing notification if necessary
    await _backgroundNotifications?.cancel(0);
  }
}
