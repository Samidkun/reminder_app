import 'package:isar/isar.dart';

part 'alarm_model.g.dart';

@collection
class AlarmModel {
  Id id = Isar.autoIncrement; // ID unik buat ngebatalin alarm

  late String title;
  late DateTime time; // Jam & menit alarm
  
  @Index()
  bool isActive = true;

  // Fitur Advanced
  List<int> repeatDays = []; // 1 untuk Senin, 7 untuk Minggu
  bool isVibrate = true;
  String? audioPath; // Path ringtone custom
  
  // Logic Challenge
  String challengeType = 'none'; // none, math, shake
  int difficultyLevel = 1; // Level soal matematika

  // Logic Snooze
  int snoozeDuration = 5; // Dalam menit
  int snoozeCount = 0;
}