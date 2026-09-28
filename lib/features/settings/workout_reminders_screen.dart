import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';
import '../../core/notifications/workout_reminder_service.dart';

class WorkoutRemindersScreen extends StatefulWidget {
  const WorkoutRemindersScreen({super.key});

  @override
  State<WorkoutRemindersScreen> createState() => _WorkoutRemindersScreenState();
}

class _WorkoutRemindersScreenState extends State<WorkoutRemindersScreen> {
  final repo = WorkoutRepository();
  final reminder = WorkoutReminderService.instance;

  static const weekdays = <int, String>{
    1: 'دوشنبه',
    2: 'سه‌شنبه',
    3: 'چهارشنبه',
    4: 'پنجشنبه',
    5: 'جمعه',
    6: 'شنبه',
    7: 'یکشنبه',
  };

  Future<void> _configure(Map<String, Object?> plan) async {
    final planId = plan['id'] as int;
    final weekday = plan['weekday'] as int?;
    if (weekday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اول برای این برنامه روز هفته مشخص کن.')),
      );
      return;
    }

    final pref = await reminder.preferenceFor(planId);
    if (!mounted) return;

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: pref.hour, minute: pref.minute),
      helpText: 'ساعت یادآوری تمرین',
      cancelText: 'لغو',
      confirmText: 'ذخیره',
    );
    if (selected == null) return;

    await reminder.scheduleWeekly(
      planId: planId,
      planName: plan['name'] as String,
      weekday: weekday,
      hour: selected.hour,
      minute: selected.minute,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('یادآوری تمرین')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: repo.getPlans(),
          builder: (context, snapshot) {
            final plans = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (plans.isEmpty) {
              return const Center(child: Text('هنوز برنامه تمرینی ساخته نشده است.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = plans[index];
                final planId = plan['id'] as int;
                final weekday = plan['weekday'] as int?;

                return FutureBuilder<WorkoutReminderPreference>(
                  future: reminder.preferenceFor(planId),
                  builder: (context, prefSnapshot) {
                    final pref = prefSnapshot.data ?? const WorkoutReminderPreference(enabled: false, hour: 18, minute: 0);
                    final time = '${pref.hour.toString().padLeft(2, '0')}:${pref.minute.toString().padLeft(2, '0')}';
                    return Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: pref.enabled,
                            title: Text(plan['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(weekday == null
                                ? 'روز هفته مشخص نشده'
                                : '${weekdays[weekday]} • $time'),
                            onChanged: (enabled) async {
                              if (!enabled) {
                                await reminder.cancel(planId);
                                if (mounted) setState(() {});
                              } else {
                                await _configure(plan);
                              }
                            },
                          ),
                          if (pref.enabled)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _configure(plan),
                                icon: const Icon(Icons.schedule_rounded),
                                label: const Text('تغییر ساعت'),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
