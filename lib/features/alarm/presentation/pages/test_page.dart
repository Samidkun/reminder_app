import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/alarm_service.dart';
import '../../data/models/alarm_model.dart';
import '../../data/repositories/alarm_repository_impl.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Reliability Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final alarm = AlarmModel()
                  ..title = 'Stress Test Alarm'
                  ..time = DateTime.now().add(const Duration(minutes: 1))
                  ..isActive = true
                  ..challengeType = 'math';
                
                await AlarmRepository().saveAlarm(alarm);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alarm set for 1 minute from now')),
                  );
                }
              },
              child: const Text('Set Alarm (1 min)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await AlarmService.cancelAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All Alarms Cancelled')),
                  );
                }
              },
              child: const Text('Cancel All'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final exactStatus = await Permission.scheduleExactAlarm.status;
                final notifyStatus = await Permission.notification.status;
                
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Permission Check'),
                      content: Text(
                        'Exact Alarm: ${exactStatus.isGranted ? '✅' : '❌'}\n'
                        'Notifications: ${notifyStatus.isGranted ? '✅' : '❌'}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                }
              },
              child: const Text('Check Perms'),
            ),
          ],
        ),
      ),
    );
  }
}
