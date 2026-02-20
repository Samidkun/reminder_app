import '../../../../core/services/isar_service.dart';
import '../../../../core/services/alarm_service.dart';
import '../models/alarm_model.dart';
import 'package:isar/isar.dart';

class AlarmRepository {
  Future<void> saveAlarm(AlarmModel alarm) async {
    final isar = await IsarService.getInstance();

    await isar.writeTxn(() async {
      await isar.alarmModels.put(alarm);
    });

    if (alarm.isActive) {
      await AlarmService.scheduleAlarm(alarm.id, alarm.time);
    }
  }

  Future<void> deleteAlarm(int id) async {
    final isar = await IsarService.getInstance();

    await isar.writeTxn(() async {
      await isar.alarmModels.delete(id);
    });

    await AlarmService.cancelAlarm(id);
  }

  Future<void> toggleAlarm(int id, bool isActive) async {
    final isar = await IsarService.getInstance();
    final alarm = await isar.alarmModels.get(id);

    if (alarm != null) {
      alarm.isActive = isActive;
      await isar.writeTxn(() async {
        await isar.alarmModels.put(alarm);
      });

      if (isActive) {
        await AlarmService.scheduleAlarm(alarm.id, alarm.time);
      } else {
        await AlarmService.cancelAlarm(alarm.id);
      }
    }
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    final isar = await IsarService.getInstance();
    return await isar.alarmModels.where().findAll();
  }
}
