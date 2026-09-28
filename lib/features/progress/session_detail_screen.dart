import 'package:flutter/material.dart';

import '../../core/database/advanced_workout_repository.dart';
import '../../core/database/workout_repository.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Map<String, Object?> session;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final repo = WorkoutRepository();
  final advanced = AdvancedWorkoutRepository();
  late DateTime? started;
  late DateTime? finished;

  int get sessionId => widget.session['id'] as int;

  @override
  void initState() {
    super.initState();
    started = DateTime.tryParse(widget.session['started_at'] as String? ?? '');
    finished = DateTime.tryParse(widget.session['finished_at'] as String? ?? '');
  }

  Duration? get duration => started != null && finished != null ? finished!.difference(started!) : null;

  Future<void> _editTime() async {
    if (started == null) return;
    var date = DateTime(started!.year, started!.month, started!.day);
    var time = TimeOfDay.fromDateTime(started!);
    final minutes = TextEditingController(text: '${duration?.inMinutes ?? 60}');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, localSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('زمان جلسه', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) localSetState(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text('${date.year}/${date.month}/${date.day}'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: time);
                      if (picked != null) localSetState(() => time = picked);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(time.format(context)),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت جلسه (دقیقه)')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final durationMinutes = int.tryParse(minutes.text.trim()) ?? 60;
                    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    await advanced.updateSessionTime(sessionId: sessionId, startedAt: value, duration: Duration(minutes: durationMinutes.clamp(1, 1440)));
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('ذخیره زمان'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      final durationMinutes = int.tryParse(minutes.text.trim()) ?? 60;
      setState(() {
        started = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        finished = started!.add(Duration(minutes: durationMinutes.clamp(1, 1440)));
      });
    }
  }

  Future<void> _editSet(Map<String, Object?> set) async {
    final reps = TextEditingController(text: '${set['reps'] ?? ''}');
    final weight = TextEditingController(text: '${set['weight'] ?? ''}');
    final rpe = TextEditingController(text: '${set['rpe'] ?? ''}');
    final durationSeconds = TextEditingController(text: '${set['duration_seconds'] ?? ''}');
    var setType = set['set_type'] as String? ?? 'normal';

    await showModalBottomSheet<void>(
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
                  Text('ویرایش ست', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: setType,
                    decoration: const InputDecoration(labelText: 'نوع ست'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('معمولی')),
                      DropdownMenuItem(value: 'warmup', child: Text('گرم‌کردن')),
                      DropdownMenuItem(value: 'drop', child: Text('دراپ‌ست')),
                      DropdownMenuItem(value: 'failure', child: Text('تا ناتوانی')),
                      DropdownMenuItem(value: 'rest_pause', child: Text('Rest-Pause')),
                    ],
                    onChanged: (value) {
                      if (value != null) localSetState(() => setType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تکرار'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزنه kg'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: durationSeconds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت (ثانیه)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE'))),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await repo.updateSet(
                        setId: set['id'] as int,
                        reps: int.tryParse(reps.text.trim()),
                        weight: double.tryParse(weight.text.trim()),
                        durationSeconds: int.tryParse(durationSeconds.text.trim()),
                        rpe: double.tryParse(rpe.text.trim()),
                        setType: setType,
                        supersetGroup: set['superset_group'] as String?,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('ذخیره تغییرات'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await repo.deleteSet(set['id'] as int);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف ست'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addSetForExercise(List<Map<String, Object?>> existing) async {
    if (existing.isEmpty) return;
    final sample = existing.first;
    final reps = TextEditingController();
    final weight = TextEditingController();
    final durationSeconds = TextEditingController();
    final rpe = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ست جدید', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تکرار'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزنه kg'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: durationSeconds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت (ثانیه)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE'))),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await repo.addSet(
                    sessionId: sessionId,
                    exerciseId: sample['exercise_id'] as int,
                    setNumber: existing.length + 1,
                    reps: int.tryParse(reps.text.trim()),
                    weight: double.tryParse(weight.text.trim()),
                    durationSeconds: int.tryParse(durationSeconds.text.trim()),
                    rpe: double.tryParse(rpe.text.trim()),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('افزودن ست'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جزئیات تمرین'),
          actions: [IconButton(onPressed: _editTime, icon: const Icon(Icons.edit_calendar_rounded), tooltip: 'ویرایش زمان')],
        ),
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
                Text((widget.session['plan_name'] as String?) ?? 'تمرین آزاد', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _Metric(icon: Icons.check_circle_outline_rounded, label: '${sets.length} ست'),
                  if (duration != null) _Metric(icon: Icons.timer_outlined, label: '${duration!.inMinutes} دقیقه'),
                  _Metric(icon: Icons.monitor_weight_outlined, label: '${_formatNumber(widget.session['volume'])} kg حجم'),
                ]),
                if (started != null) ...[
                  const SizedBox(height: 10),
                  Text('شروع: ${started!.year}/${started!.month}/${started!.day} • ${started!.hour.toString().padLeft(2, '0')}:${started!.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 24),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (grouped.isEmpty)
                  const Center(child: Text('هیچ ستی در این جلسه ثبت نشده است.'))
                else
                  ...grouped.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                                IconButton(onPressed: () => _addSetForExercise(entry.value), icon: const Icon(Icons.add_rounded), tooltip: 'افزودن ست'),
                              ]),
                              const SizedBox(height: 6),
                              ...entry.value.map((set) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(radius: 16, child: Text('${set['set_number']}')),
                                    title: Text(set['duration_seconds'] != null
                                        ? '${set['duration_seconds']} ثانیه${set['weight'] != null ? ' • ${set['weight']} kg' : ''}'
                                        : '${set['reps'] ?? '—'} تکرار × ${set['weight'] ?? '—'} kg'),
                                    subtitle: set['rpe'] != null ? Text('RPE ${set['rpe']}') : null,
                                    trailing: const Icon(Icons.edit_outlined),
                                    onTap: () => _editSet(set),
                                  )),
                            ]),
                          ),
                        ),
                      )),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
