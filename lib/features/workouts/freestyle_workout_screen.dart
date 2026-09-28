import 'package:flutter/material.dart';

import '../../core/database/advanced_workout_repository.dart';
import '../../core/database/workout_repository.dart';
import 'workout_session_screen.dart';

class FreestyleWorkoutScreen extends StatefulWidget {
  const FreestyleWorkoutScreen({super.key});

  @override
  State<FreestyleWorkoutScreen> createState() => _FreestyleWorkoutScreenState();
}

class _FreestyleWorkoutScreenState extends State<FreestyleWorkoutScreen> {
  final repo = WorkoutRepository();
  final advanced = AdvancedWorkoutRepository();
  final selected = <int>{};
  String query = '';
  bool starting = false;

  Future<void> _start(List<Map<String, Object?>> all) async {
    if (selected.isEmpty || starting) return;
    setState(() => starting = true);
    try {
      final plan = await advanced.createFreestylePlan(selected.toList());
      final planId = plan['id'] as int;
      final exercises = await repo.getPlanExercises(planId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(plan: plan, exercises: exercises),
        ),
      );
      await advanced.cleanupFreestylePlan(planId);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تمرین آزاد')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: repo.getExercises(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? const [];
            final items = all.where((e) {
              final name = (e['name'] as String).toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'هر حرکتی که امروز می‌خواهی انتخاب کن',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'بدون ساخت برنامه ثابت؛ مقادیر جلسه قبلی هر حرکت همچنان پیشنهاد می‌شوند.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) => setState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'جستجوی حرکت',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      if (selected.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('${selected.length} حرکت انتخاب شده', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? const Center(child: Text('حرکتی برای انتخاب وجود ندارد.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final id = item['id'] as int;
                                final checked = selected.contains(id);
                                final mode = item['exercise_mode'] == 'timed' ? 'زمانی' : 'تکراری';
                                return Card(
                                  child: CheckboxListTile(
                                    value: checked,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selected.add(id);
                                        } else {
                                          selected.remove(id);
                                        }
                                      });
                                    },
                                    title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text([
                                      mode,
                                      if (item['muscle_group'] != null) '${item['muscle_group']}',
                                      if (item['is_bodyweight'] == 1) 'وزن بدن',
                                      if (item['per_side'] == 1) 'هر سمت',
                                    ].join(' • ')),
                                    secondary: Icon(item['is_favorite'] == 1 ? Icons.star_rounded : Icons.fitness_center_rounded),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: repo.getExercises(),
            builder: (context, snapshot) => FilledButton.icon(
              onPressed: selected.isEmpty || starting || snapshot.data == null ? null : () => _start(snapshot.data!),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(starting ? 'در حال شروع...' : 'شروع تمرین آزاد'),
            ),
          ),
        ),
      ),
    );
  }
}
