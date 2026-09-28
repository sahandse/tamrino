import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';
import 'workout_session_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final repo = WorkoutRepository();

  Future<void> _createPlan() async {
    final name = TextEditingController();
    final notes = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('برنامه جدید', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'نام برنامه *')),
              const SizedBox(height: 12),
              TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await repo.createPlan(name: name.text, notes: notes.text);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('ساخت برنامه'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (created == true && mounted) setState(() {});
  }

  Future<void> _managePlan(Map<String, Object?> plan) async {
    final planId = plan['id'] as int;
    final exercises = await repo.getExercises();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, localSetState) => FutureBuilder<List<Map<String, Object?>>>(
            future: repo.getPlanExercises(planId),
            builder: (context, snapshot) {
              final selected = snapshot.data ?? const [];
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: .72,
                maxChildSize: .92,
                builder: (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(plan['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    if (selected.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('هنوز حرکتی به این برنامه اضافه نشده است.', textAlign: TextAlign.center),
                      )
                    else
                      ...selected.map((e) => Card(
                            child: ListTile(
                              title: Text(e['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text('${e['target_sets'] ?? '—'} ست • ${e['target_reps'] ?? '—'} تکرار'),
                            ),
                          )),
                    const SizedBox(height: 16),
                    Text('افزودن حرکت', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (exercises.isEmpty)
                      const Text('ابتدا از تب حرکات، یک حرکت واقعی اضافه کن.')
                    else
                      ...exercises.map((exercise) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
                            title: Text(exercise['name'] as String),
                            onTap: () async {
                              await repo.addExerciseToPlan(
                                planId: planId,
                                exerciseId: exercise['id'] as int,
                                targetSets: 3,
                                targetReps: '8-12',
                              );
                              localSetState(() {});
                              if (mounted) setState(() {});
                            },
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getPlans(),
      builder: (context, snapshot) {
        final plans = snapshot.data ?? const [];
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('برنامه‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton.filledTonal(onPressed: _createPlan, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : plans.isEmpty
                          ? const Center(child: Text('هنوز برنامه تمرینی ساخته نشده است.'))
                          : ListView.separated(
                              itemCount: plans.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final plan = plans[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(plan['name'] as String, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text('${plan['exercise_count'] ?? 0} حرکت'),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _managePlan(plan),
                                                icon: const Icon(Icons.edit_outlined),
                                                label: const Text('ویرایش'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () async {
                                                  final exercises = await repo.getPlanExercises(plan['id'] as int);
                                                  if (!mounted) return;
                                                  if (exercises.isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ابتدا به برنامه حرکت اضافه کن.')));
                                                    return;
                                                  }
                                                  Navigator.of(context).push(MaterialPageRoute(
                                                    builder: (_) => WorkoutSessionScreen(plan: plan, exercises: exercises),
                                                  ));
                                                },
                                                icon: const Icon(Icons.play_arrow_rounded),
                                                label: const Text('شروع'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('برنامه جدید'),
          ),
        );
      },
    );
  }
}
