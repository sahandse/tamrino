import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';
import '../../core/settings/app_preferences.dart';

class TrainingCalendarScreen extends StatefulWidget {
  const TrainingCalendarScreen({super.key});

  @override
  State<TrainingCalendarScreen> createState() => _TrainingCalendarScreenState();
}

class _TrainingCalendarScreenState extends State<TrainingCalendarScreen> {
  final repo = WorkoutRepository();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int weekStart = DateTime.saturday;

  @override
  void initState() {
    super.initState();
    AppPreferences.instance.weekStart().then((value) {
      if (mounted) setState(() => weekStart = value);
    });
  }

  void _changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تقویم و عضلات')),
        body: FutureBuilder<List<Object>>(
          future: Future.wait([
            repo.getSessionsForMonth(month),
            repo.getMuscleVolume(days: 30),
          ]),
          builder: (context, snapshot) {
            final sessions = snapshot.hasData
                ? snapshot.data![0] as List<Map<String, Object?>>
                : const <Map<String, Object?>>[];
            final muscles = snapshot.hasData
                ? snapshot.data![1] as List<Map<String, Object?>>
                : const <Map<String, Object?>>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${month.year}/${month.month.toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ]),
                const SizedBox(height: 12),
                _MonthGrid(month: month, sessions: sessions, weekStart: weekStart),
                const SizedBox(height: 24),
                Text(
                  'درگیری عضلات • ۳۰ روز اخیر',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (muscles.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('هنوز داده‌ای برای نمایش عضلات وجود ندارد.'),
                    ),
                  )
                else
                  ...muscles.map((m) {
                    final volume = (m['volume'] as num?)?.toDouble() ?? 0;
                    final maxVolume = muscles
                        .map((e) => (e['volume'] as num?)?.toDouble() ?? 0)
                        .fold<double>(0, (a, b) => b > a ? b : a);
                    final ratio = maxVolume <= 0 ? 0.0 : volume / maxVolume;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    m['muscle'] as String? ?? 'نامشخص',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Text('${m['set_count'] ?? 0} ست'),
                              ]),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: ratio.clamp(0, 1),
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${volume.toStringAsFixed(volume % 1 == 0 ? 0 : 1)} kg حجم تمرین',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.sessions, required this.weekStart});

  final DateTime month;
  final List<Map<String, Object?>> sessions;
  final int weekStart;

  static const _labels = <int, String>{
    DateTime.monday: 'د',
    DateTime.tuesday: 'س',
    DateTime.wednesday: 'چ',
    DateTime.thursday: 'پ',
    DateTime.friday: 'ج',
    DateTime.saturday: 'ش',
    DateTime.sunday: 'ی',
  };

  List<int> get _weekdays => List.generate(7, (index) => ((weekStart - 1 + index) % 7) + 1);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = (first.weekday - weekStart + 7) % 7;
    final activeDays = <int, int>{};

    for (final session in sessions) {
      final date = DateTime.tryParse(session['started_at'] as String? ?? '');
      if (date != null) {
        activeDays[date.day] = (activeDays[date.day] ?? 0) + 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: _weekdays
                  .map(
                    (day) => Expanded(
                      child: Text(
                        _labels[day] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: startOffset + days,
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox.shrink();
                final day = index - startOffset + 1;
                final count = activeDays[day] ?? 0;
                return Container(
                  decoration: BoxDecoration(
                    color: count > 0
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: count > 0 ? FontWeight.w900 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          left: 5,
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
