import 'package:flutter/material.dart';

import '../../core/database/exercise_history_repository.dart';

class ExerciseHistoryScreen extends StatelessWidget {
  const ExerciseHistoryScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context) {
    final repo = ExerciseHistoryRepository();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تاریخچه حرکت')),
        body: FutureBuilder<List<Object?>>(
          future: Future.wait<Object?>([
            repo.exercise(exerciseId),
            repo.sessions(exerciseId),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final exercise = snapshot.data?[0] as Map<String, Object?>?;
            final sessions = snapshot.data?[1] as List<Map<String, Object?>>? ?? const [];
            final tracking = exercise?['tracking_type'] as String? ?? 'strength';
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  exercise?['name'] as String? ?? 'حرکت',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    exercise?['muscle_group'] as String?,
                    exercise?['equipment'] as String?,
                  ].whereType<String>().where((e) => e.isNotEmpty).join(' • '),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                if (sessions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('هنوز جلسه‌ای برای این حرکت ثبت نشده است.'),
                    ),
                  )
                else ...[
                  _ProgressLine(items: sessions, tracking: tracking),
                  const SizedBox(height: 18),
                  Text('جلسه‌های اخیر', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ...sessions.map((session) {
                    final date = DateTime.tryParse(session['started_at'] as String? ?? '');
                    final value = tracking == 'cardio'
                        ? '${_number(session['distance_km'])} km'
                        : tracking == 'timed'
                            ? '${session['timed_seconds'] ?? 0} ثانیه'
                            : '${_number(session['estimated_1rm'])} kg 1RM تخمینی';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(session['plan_name'] as String? ?? 'تمرین آزاد'),
                        subtitle: Text(
                          date == null
                              ? '${session['set_count'] ?? 0} ست'
                              : '${date.year}/${date.month}/${date.day} • ${session['set_count'] ?? 0} ست',
                        ),
                        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _number(Object? value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return n.toStringAsFixed(n % 1 == 0 ? 0 : 1);
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.items, required this.tracking});
  final List<Map<String, Object?>> items;
  final String tracking;

  @override
  Widget build(BuildContext context) {
    final chronological = items.reversed.take(12).toList();
    final values = chronological.map((e) {
      if (tracking == 'cardio') return (e['distance_km'] as num?)?.toDouble() ?? 0;
      if (tracking == 'timed') return (e['timed_seconds'] as num?)?.toDouble() ?? 0;
      return (e['estimated_1rm'] as num?)?.toDouble() ?? 0;
    }).toList();
    final maxValue = values.fold<double>(0, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('روند ثبت‌شده', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) {
                final ratio = maxValue <= 0 ? .04 : (values[index] / maxValue).clamp(.04, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}
