import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.plan,
    required this.exercises,
  });

  final Map<String, Object?> plan;
  final List<Map<String, Object?>> exercises;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final repo = WorkoutRepository();
  final stopwatch = Stopwatch();
  Timer? timer;
  int? sessionId;
  bool loading = true;
  bool finishing = false;
  final Map<int, int> setCounters = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final id = await repo.startSession(widget.plan['id'] as int);
    stopwatch.start();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (!mounted) return;
    setState(() {
      sessionId = id;
      loading = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String get elapsed {
    final d = stopwatch.elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _addSet(Map<String, Object?> exercise) async {
    if (sessionId == null) return;

    final reps = TextEditingController();
    final weight = TextEditingController();
    final rpe = TextEditingController();
    final exerciseId = exercise['exercise_id'] as int;
    final nextSet = (setCounters[exerciseId] ?? 0) + 1;

    final saved = await showModalBottomSheet<bool>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exercise['name'] as String,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text('ست $nextSet'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: reps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'تکرار'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'وزنه (kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rpe,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'RPE (اختیاری)'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final repValue = int.tryParse(reps.text.trim());
                  final weightValue = double.tryParse(weight.text.trim());
                  final rpeValue = double.tryParse(rpe.text.trim());
                  if (repValue == null && weightValue == null) return;

                  await repo.addSet(
                    sessionId: sessionId!,
                    exerciseId: exerciseId,
                    setNumber: nextSet,
                    reps: repValue,
                    weight: weightValue,
                    rpe: rpeValue,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('ثبت ست'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() => setCounters[exerciseId] = nextSet);
    }
  }

  Future<void> _finish() async {
    if (sessionId == null || finishing) return;
    setState(() => finishing = true);
    await repo.finishSession(sessionId!);
    stopwatch.stop();
    timer?.cancel();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan['name'] as String),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  elapsed,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: widget.exercises.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final exercise = widget.exercises[index];
                  final exerciseId = exercise['exercise_id'] as int;
                  final completed = setCounters[exerciseId] ?? 0;
                  final targetSets = exercise['target_sets'] as int?;
                  final targetReps = exercise['target_reps'] as String?;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise['name'] as String,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${targetSets ?? '—'} ست • ${targetReps ?? '—'} تکرار',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$completed/${targetSets ?? '—'}',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: () => _addSet(exercise),
                            icon: const Icon(Icons.add_rounded),
                            label: Text('ثبت ست ${completed + 1}'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: finishing ? null : _finish,
            icon: const Icon(Icons.flag_rounded),
            label: Text(finishing ? 'در حال ذخیره...' : 'پایان تمرین'),
          ),
        ),
      ),
    );
  }
}
