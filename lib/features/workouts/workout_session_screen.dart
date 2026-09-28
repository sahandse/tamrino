import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/active_session_repository.dart';
import '../../core/database/workout_repository.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.plan,
    required this.exercises,
    this.existingSessionId,
    this.existingStartedAt,
  });

  final Map<String, Object?> plan;
  final List<Map<String, Object?>> exercises;
  final int? existingSessionId;
  final DateTime? existingStartedAt;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final repo = WorkoutRepository();
  final activeRepo = ActiveSessionRepository();
  Timer? timer;
  Timer? restTimer;
  int? sessionId;
  DateTime? startedAt;
  bool loading = true;
  bool finishing = false;
  int restSeconds = 0;
  List<Map<String, Object?>> sets = [];
  final Map<int, List<Map<String, Object?>>> previousSets = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    sessionId = widget.existingSessionId ?? await activeRepo.startOrReuseSession(widget.plan['id'] as int);
    if (widget.existingStartedAt != null) {
      startedAt = widget.existingStartedAt;
    } else {
      final active = await activeRepo.getActiveSession();
      startedAt = DateTime.tryParse(active?['started_at'] as String? ?? '') ?? DateTime.now();
    }
    sets = await repo.getSessionSets(sessionId!);
    for (final exercise in widget.exercises) {
      final exerciseId = exercise['exercise_id'] as int;
      previousSets[exerciseId] = await repo.getLastExerciseSets(exerciseId);
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    restTimer?.cancel();
    super.dispose();
  }

  String get elapsed {
    final d = DateTime.now().difference(startedAt ?? DateTime.now());
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get restLabel => _durationLabel(restSeconds);

  String _durationLabel(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _reloadSets() async {
    if (sessionId == null) return;
    final data = await repo.getSessionSets(sessionId!);
    if (mounted) setState(() => sets = data);
  }

  int _completedFor(int exerciseId) => sets.where((s) => s['exercise_id'] == exerciseId).length;

  void _startRestTimer(int seconds) {
    restTimer?.cancel();
    if (seconds <= 0) {
      setState(() => restSeconds = 0);
      return;
    }
    setState(() => restSeconds = seconds);
    restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (restSeconds <= 1) {
        t.cancel();
        setState(() => restSeconds = 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('زمان استراحت تمام شد.')));
      } else {
        setState(() => restSeconds--);
      }
    });
  }

  void _skipRest() {
    restTimer?.cancel();
    setState(() => restSeconds = 0);
  }

  Future<void> _editSessionNotes() async {
    if (sessionId == null) return;
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('یادداشت تمرین', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(controller: controller, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'نکته یا یادداشت این جلسه...')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                await repo.updateSessionNotes(sessionId!, controller.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('ذخیره یادداشت'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _addSet(Map<String, Object?> exercise) async {
    if (sessionId == null) return;
    final mode = exercise['exercise_mode'] as String? ?? 'reps';
    if (mode == 'timed') {
      await _addTimedSet(exercise);
    } else {
      await _addRepSet(exercise);
    }
  }

  Future<void> _addTimedSet(Map<String, Object?> exercise) async {
    final exerciseId = exercise['exercise_id'] as int;
    final nextSet = _completedFor(exerciseId) + 1;
    final previous = previousSets[exerciseId] ?? const [];
    final suggested = previous.isEmpty ? null : previous[(nextSet - 1).clamp(0, previous.length - 1)];
    final draft = await showModalBottomSheet<_TimedSetDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TimedSetSheet(
        exerciseName: exercise['name'] as String,
        setNumber: nextSet,
        suggestedSeconds: (suggested?['duration_seconds'] as num?)?.toInt(),
        allowWeight: exercise['is_bodyweight'] != 1,
      ),
    );
    if (draft == null || draft.seconds <= 0) return;
    await repo.addSet(
      sessionId: sessionId!,
      exerciseId: exerciseId,
      setNumber: nextSet,
      durationSeconds: draft.seconds,
      weight: draft.weight,
      rpe: draft.rpe,
      setType: draft.setType,
    );
    await _reloadSets();
    _startRestTimer((exercise['rest_seconds'] as num?)?.toInt() ?? 90);
  }

  Future<void> _addRepSet(Map<String, Object?> exercise) async {
    final reps = TextEditingController();
    final weight = TextEditingController();
    final rpe = TextEditingController();
    final superset = TextEditingController();
    final exerciseId = exercise['exercise_id'] as int;
    final nextSet = _completedFor(exerciseId) + 1;
    var setType = 'normal';
    final bodyweight = exercise['is_bodyweight'] == 1;
    final perSide = exercise['per_side'] == 1;

    final previous = previousSets[exerciseId] ?? const [];
    Map<String, Object?>? suggestion;
    if (previous.isNotEmpty) {
      suggestion = previous[(nextSet - 1).clamp(0, previous.length - 1)];
      if (suggestion['reps'] != null) reps.text = '${suggestion['reps']}';
      if (suggestion['weight'] != null) weight.text = '${suggestion['weight']}';
      if (suggestion['rpe'] != null) rpe.text = '${suggestion['rpe']}';
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(exercise['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('ست $nextSet${perSide ? ' • تکرار برای هر سمت' : ''}'),
                if (suggestion != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
                    child: Text('جلسه قبل: ${suggestion['reps'] ?? '—'} تکرار${suggestion['weight'] != null ? ' • ${suggestion['weight']} kg' : ''}'),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: setType,
                  decoration: const InputDecoration(labelText: 'نوع ست'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('معمولی')),
                    DropdownMenuItem(value: 'warmup', child: Text('گرم‌کردن')),
                    DropdownMenuItem(value: 'drop', child: Text('دراپ‌ست')),
                    DropdownMenuItem(value: 'failure', child: Text('تا ناتوانی')),
                    DropdownMenuItem(value: 'rest_pause', child: Text('Rest-Pause')),
                  ],
                  onChanged: (value) {
                    if (value != null) modalSetState(() => setType = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: perSide ? 'تکرار هر سمت' : 'تکرار'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: bodyweight ? 'وزنه اضافه (kg)' : 'وزنه (kg)'),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE (اختیاری)')),
                const SizedBox(height: 12),
                TextField(controller: superset, decoration: const InputDecoration(labelText: 'گروه سوپرست (اختیاری)', hintText: 'مثلاً A')),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final repValue = int.tryParse(reps.text.trim());
                    if (repValue == null || repValue <= 0) return;
                    await repo.addSet(
                      sessionId: sessionId!,
                      exerciseId: exerciseId,
                      setNumber: nextSet,
                      reps: repValue,
                      weight: double.tryParse(weight.text.trim()),
                      rpe: double.tryParse(rpe.text.trim()),
                      setType: setType,
                      supersetGroup: superset.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ثبت ست'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      await _reloadSets();
      _startRestTimer((exercise['rest_seconds'] as num?)?.toInt() ?? 90);
    }
  }

  Future<void> _editSet(Map<String, Object?> set) async {
    final timed = set['exercise_mode'] == 'timed';
    final reps = TextEditingController(text: '${set['reps'] ?? ''}');
    final weight = TextEditingController(text: '${set['weight'] ?? ''}');
    final duration = TextEditingController(text: '${set['duration_seconds'] ?? ''}');
    final rpe = TextEditingController(text: '${set['rpe'] ?? ''}');
    var setType = set['set_type'] as String? ?? 'normal';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('ویرایش ست', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: setType,
                decoration: const InputDecoration(labelText: 'نوع ست'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('معمولی')),
                  DropdownMenuItem(value: 'warmup', child: Text('گرم‌کردن')),
                  DropdownMenuItem(value: 'drop', child: Text('دراپ‌ست')),
                  DropdownMenuItem(value: 'failure', child: Text('تا ناتوانی')),
                  DropdownMenuItem(value: 'rest_pause', child: Text('Rest-Pause')),
                ],
                onChanged: (value) {
                  if (value != null) modalSetState(() => setType = value);
                },
              ),
              const SizedBox(height: 12),
              if (timed)
                TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت (ثانیه)'))
              else
                TextField(controller: reps, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: set['per_side'] == 1 ? 'تکرار هر سمت' : 'تکرار')),
              const SizedBox(height: 12),
              TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: set['is_bodyweight'] == 1 ? 'وزنه اضافه (kg)' : 'وزنه (kg)')),
              const SizedBox(height: 12),
              TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await repo.updateSet(
                    setId: set['id'] as int,
                    reps: timed ? null : int.tryParse(reps.text.trim()),
                    weight: double.tryParse(weight.text.trim()),
                    durationSeconds: timed ? int.tryParse(duration.text.trim()) : null,
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
            ]),
          ),
        ),
      ),
    );
    await _reloadSets();
  }

  Future<void> _finish() async {
    if (sessionId == null || finishing) return;
    setState(() => finishing = true);
    restTimer?.cancel();
    await repo.finishSession(sessionId!);
    timer?.cancel();
    if (mounted) Navigator.pop(context, true);
  }

  String _setTypeLabel(String? type) {
    switch (type) {
      case 'warmup':
        return 'گرم‌کردن';
      case 'drop':
        return 'دراپ‌ست';
      case 'failure':
        return 'تا ناتوانی';
      case 'rest_pause':
        return 'Rest-Pause';
      default:
        return 'معمولی';
    }
  }

  String _setTitle(Map<String, Object?> set) {
    if (set['exercise_mode'] == 'timed') {
      final seconds = (set['duration_seconds'] as num?)?.toInt() ?? 0;
      final weight = set['weight'];
      return '${_durationLabel(seconds)}${weight != null ? ' • $weight kg' : ''}';
    }
    final reps = set['reps'] ?? '—';
    final side = set['per_side'] == 1 ? ' هر سمت' : '';
    final weight = set['weight'];
    final bodyweight = set['is_bodyweight'] == 1;
    if (bodyweight) {
      return '$reps تکرار$side${weight != null ? ' • +$weight kg' : ' • وزن بدن'}';
    }
    return '$reps تکرار$side × ${weight ?? '—'} kg';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan['name'] as String),
          actions: [
            IconButton(onPressed: _editSessionNotes, icon: const Icon(Icons.sticky_note_2_outlined), tooltip: 'یادداشت جلسه'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(elapsed, style: const TextStyle(fontWeight: FontWeight.w800))),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                if (restSeconds > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('استراحت', style: TextStyle(fontWeight: FontWeight.w800)),
                        Text(restLabel, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ])),
                      IconButton(onPressed: () => setState(() => restSeconds += 30), icon: const Icon(Icons.add_rounded)),
                      IconButton(onPressed: _skipRest, icon: const Icon(Icons.skip_next_rounded)),
                    ]),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: widget.exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exercise = widget.exercises[index];
                      final exerciseId = exercise['exercise_id'] as int;
                      final exerciseSets = sets.where((s) => s['exercise_id'] == exerciseId).toList();
                      final targetSets = exercise['target_sets'] as int?;
                      final rest = (exercise['rest_seconds'] as num?)?.toInt() ?? 90;
                      final timed = exercise['exercise_mode'] == 'timed';
                      final bodyweight = exercise['is_bodyweight'] == 1;
                      final perSide = exercise['per_side'] == 1;
                      final tags = <String>[
                        timed ? 'زمانی' : 'تکراری',
                        if (bodyweight) 'وزن بدن',
                        if (perSide) 'هر سمت',
                        'استراحت ${rest}s',
                      ];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              CircleAvatar(child: Text('${index + 1}')),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(exercise['name'] as String, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(tags.join(' • '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ])),
                              Text('${exerciseSets.length}/${targetSets ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ]),
                            if (exerciseSets.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ...exerciseSets.map((set) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(radius: 16, child: Text('${set['set_number']}')),
                                    title: Text(_setTitle(set)),
                                    subtitle: Text([
                                      _setTypeLabel(set['set_type'] as String?),
                                      if (set['rpe'] != null) 'RPE ${set['rpe']}',
                                      if (set['superset_group'] != null) 'سوپرست ${set['superset_group']}',
                                    ].join(' • ')),
                                    trailing: const Icon(Icons.edit_outlined, size: 20),
                                    onTap: () => _editSet(set),
                                  )),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _addSet(exercise),
                              icon: Icon(timed ? Icons.timer_rounded : Icons.add_rounded),
                              label: Text(timed ? 'شروع ست زمانی ${exerciseSets.length + 1}' : 'ثبت ست ${exerciseSets.length + 1}'),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
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

class _TimedSetDraft {
  const _TimedSetDraft({required this.seconds, this.weight, this.rpe, required this.setType});
  final int seconds;
  final double? weight;
  final double? rpe;
  final String setType;
}

class _TimedSetSheet extends StatefulWidget {
  const _TimedSetSheet({
    required this.exerciseName,
    required this.setNumber,
    required this.allowWeight,
    this.suggestedSeconds,
  });

  final String exerciseName;
  final int setNumber;
  final bool allowWeight;
  final int? suggestedSeconds;

  @override
  State<_TimedSetSheet> createState() => _TimedSetSheetState();
}

class _TimedSetSheetState extends State<_TimedSetSheet> {
  Timer? timer;
  int seconds = 0;
  bool running = false;
  String setType = 'normal';
  final weight = TextEditingController();
  final rpe = TextEditingController();

  @override
  void initState() {
    super.initState();
    seconds = widget.suggestedSeconds ?? 0;
  }

  @override
  void dispose() {
    timer?.cancel();
    weight.dispose();
    rpe.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  String get label {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.exerciseName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text('ست زمانی ${widget.setNumber}'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                Text(label, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(running ? 'توقف' : 'شروع تایمر'),
                ),
                if (!running && seconds > 0)
                  TextButton(onPressed: () => setState(() => seconds = 0), child: const Text('صفر کردن')),
              ]),
            ),
            if (widget.suggestedSeconds != null) ...[
              const SizedBox(height: 10),
              Text('جلسه قبل: ${widget.suggestedSeconds} ثانیه', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: setType,
              decoration: const InputDecoration(labelText: 'نوع ست'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('معمولی')),
                DropdownMenuItem(value: 'warmup', child: Text('گرم‌کردن')),
                DropdownMenuItem(value: 'failure', child: Text('تا ناتوانی')),
                DropdownMenuItem(value: 'rest_pause', child: Text('Rest-Pause')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => setType = value);
              },
            ),
            if (widget.allowWeight) ...[
              const SizedBox(height: 12),
              TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزنه (kg) - اختیاری')),
            ],
            const SizedBox(height: 12),
            TextField(controller: rpe, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'RPE - اختیاری')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: seconds <= 0
                  ? null
                  : () {
                      timer?.cancel();
                      Navigator.pop(
                        context,
                        _TimedSetDraft(
                          seconds: seconds,
                          weight: double.tryParse(weight.text.trim()),
                          rpe: double.tryParse(rpe.text.trim()),
                          setType: setType,
                        ),
                      );
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('ثبت ست زمانی'),
            ),
          ]),
        ),
      ),
    );
  }
}
