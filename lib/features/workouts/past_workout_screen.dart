import 'package:flutter/material.dart';

import '../../core/database/advanced_workout_repository.dart';
import '../../core/database/workout_repository.dart';

class PastWorkoutScreen extends StatefulWidget {
  const PastWorkoutScreen({super.key});

  @override
  State<PastWorkoutScreen> createState() => _PastWorkoutScreenState();
}

class _PastWorkoutScreenState extends State<PastWorkoutScreen> {
  final repo = WorkoutRepository();
  final advanced = AdvancedWorkoutRepository();
  final notes = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  int durationMinutes = 60;
  bool saving = false;
  final drafts = <_PastSetDraft>[];

  Future<void> _addSet(List<Map<String, Object?>> exercises) async {
    int? exerciseId;
    final reps = TextEditingController();
    final weight = TextEditingController();
    final duration = TextEditingController();
    final rpe = TextEditingController();

    final result = await showModalBottomSheet<_PastSetDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, localSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('افزودن ست', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: exerciseId,
                    decoration: const InputDecoration(labelText: 'حرکت'),
                    items: exercises
                        .map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String)))
                        .toList(),
                    onChanged: (value) => localSetState(() => exerciseId = value),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تکرار'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزنه kg'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت ست (ثانیه)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE'))),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: exerciseId == null
                        ? null
                        : () {
                            final exercise = exercises.firstWhere((e) => e['id'] == exerciseId);
                            Navigator.pop(
                              context,
                              _PastSetDraft(
                                exerciseId: exerciseId!,
                                exerciseName: exercise['name'] as String,
                                reps: int.tryParse(reps.text.trim()),
                                weight: double.tryParse(weight.text.trim()),
                                durationSeconds: int.tryParse(duration.text.trim()),
                                rpe: double.tryParse(rpe.text.trim()),
                              ),
                            );
                          },
                    child: const Text('افزودن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted) setState(() => drafts.add(result));
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => selectedDate = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: selectedTime);
    if (value != null) setState(() => selectedTime = value);
  }

  Future<void> _save() async {
    if (drafts.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final startedAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final sessionId = await advanced.createPastSession(
        startedAt: startedAt,
        duration: Duration(minutes: durationMinutes),
        notes: notes.text,
      );
      final perExerciseCount = <int, int>{};
      for (final draft in drafts) {
        final next = (perExerciseCount[draft.exerciseId] ?? 0) + 1;
        perExerciseCount[draft.exerciseId] = next;
        await advanced.addPastSet(
          sessionId: sessionId,
          exerciseId: draft.exerciseId,
          setNumber: next,
          reps: draft.reps,
          weight: draft.weight,
          durationSeconds: draft.durationSeconds,
          rpe: draft.rpe,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ثبت تمرین گذشته')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: repo.getExercises(),
          builder: (context, snapshot) {
            final exercises = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('زمان تمرین', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_rounded), label: Text('${selectedDate.year}/${selectedDate.month}/${selectedDate.day}'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule_rounded), label: Text(selectedTime.format(context)))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: durationMinutes,
                  decoration: const InputDecoration(labelText: 'مدت جلسه'),
                  items: const [30, 45, 60, 75, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m دقیقه'))).toList(),
                  onChanged: (value) => setState(() => durationMinutes = value ?? 60),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت جلسه')),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text('ست‌ها', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  FilledButton.tonalIcon(onPressed: exercises.isEmpty ? null : () => _addSet(exercises), icon: const Icon(Icons.add_rounded), label: const Text('ست')),
                ]),
                const SizedBox(height: 10),
                if (drafts.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('ست‌های تمرینی که انجام دادی را اضافه کن.')))
                else
                  ...List.generate(drafts.length, (index) {
                    final d = drafts[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(d.exerciseName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text([
                          if (d.reps != null) '${d.reps} تکرار',
                          if (d.weight != null) '${d.weight} kg',
                          if (d.durationSeconds != null) '${d.durationSeconds} ثانیه',
                          if (d.rpe != null) 'RPE ${d.rpe}',
                        ].join(' • ')),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => setState(() => drafts.removeAt(index))),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: drafts.isEmpty || saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(saving ? 'در حال ذخیره...' : 'ثبت تمرین گذشته'),
          ),
        ),
      ),
    );
  }
}

class _PastSetDraft {
  _PastSetDraft({
    required this.exerciseId,
    required this.exerciseName,
    this.reps,
    this.weight,
    this.durationSeconds,
    this.rpe,
  });

  final int exerciseId;
  final String exerciseName;
  final int? reps;
  final double? weight;
  final int? durationSeconds;
  final double? rpe;
}
