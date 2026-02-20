import 'package:isar/isar.dart';

part 'alarm_model.g.dart';

@collection
class AlarmModel {
  Id id = Isar.autoIncrement;

  late String title;
  
  late DateTime time;
  
  late List<int> daysEnabled; // 1-7 for Mon-Sun
  
  late bool isActive;
  
  late int snoozeDuration; // in minutes
  
  late bool isCloudSynced;

  AlarmModel({
    required this.title,
    required this.time,
    required this.daysEnabled,
    this.isActive = true,
    this.snoozeDuration = 5,
    this.isCloudSynced = false,
  });
}
