import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Map<String, Object?> session;

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository();
    final sessionId = session['id'] as int;
    final started = DateTime.tryParse(session['started_at'] as String? ?? '');
    final finished = DateTime.tryParse(session['finished_at'] as String? ?? '');
    final duration = started != null && finished != null ? finished.difference(started) : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جزئیات تمرین')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: repo.getSessionSets(sessionId),
          builder: (context, snapshot) {
            final sets = snapshot.data ?? const [];
            final grouped = <String, List<Map<String, Object?>>>{};
            for (final set in sets) {
              final name = (set['exercise_name'] as String?) ?? 'حرکت';
              grouped.putIfAbsent(name, () => []).add(set);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  (session['plan_name'] as String?) ?? 'تمرین',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Metric(icon: Icons.check_circle_outline_rounded, label: '${sets.length} ست'),
                    if (duration != null) _Metric(icon: Icons.timer_outlined, label: '${duration.inMinutes} دقیقه'),
                    _Metric(icon: Icons.monitor_weight_outlined, label: '${_formatNumber(session['volume'])} kg حجم'),
                  ],
                ),
                const SizedBox(height: 24),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (grouped.isEmpty)
                  const Center(child: Text('هیچ ستی در این جلسه ثبت نشده است.'))
                else
                  ...grouped.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 10),
                              ...entry.value.map(
                                (set) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 15, child: Text('${set['set_number']}')),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text('${set['reps'] ?? '—'} تکرار × ${set['weight'] ?? '—'} kg')),
                                      if (set['rpe'] != null) Text('RPE ${set['rpe']}'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatNumber(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return number.toStringAsFixed(number % 1 == 0 ? 0 : 1);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
