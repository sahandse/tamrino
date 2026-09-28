import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/branding/tamrino_logo.dart';
import '../../core/database/active_session_repository.dart';
import '../../core/database/advanced_workout_repository.dart';
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
  final advanced = AdvancedWorkoutRepository();

  Timer? timer;
  Timer? restTimer;
  int? sessionId;
  DateTime? startedAt;
  bool loading = true;
  bool finishing = false;
  int restSeconds = 0;
  List<Map<String, Object?>> sets = [];
  List<Map<String, Object?>> sessionExercises = [];
  final Map<int, List<Map<String, Object?>>> previousSets = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final planId = widget.plan['id'] as int;
    sessionId = widget.existingSessionId ?? await activeRepo.startOrReuseSession(planId);
    if (widget.existingStartedAt != null) {
      startedAt = widget.existingStartedAt;
    } else {
      final active = await activeRepo.getActiveSession();
      startedAt = DateTime.tryParse(active?['started_at'] as String? ?? '') ?? DateTime.now();
    }

    await advanced.ensureSessionExercises(sessionId: sessionId!, planId: planId);
    sessionExercises = await advanced.getSessionExercises(sessionId!);
    sets = await repo.getSessionSets(sessionId!);
    for (final exercise in sessionExercises) {
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

  Future<void> _reloadSessionExercises() async {
    if (sessionId == null) return;
    final data = await advanced.getSessionExercises(sessionId!);
    for (final exercise in data) {
      final id = exercise['exercise_id'] as int;
      previousSets[id] ??= await repo.getLastExerciseSets(id);
    }
    if (mounted) setState(() => sessionExercises = data);
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

  Future<Map<String, Object?>?> _pickExercise({int? excludingId}) async {
    final all = await repo.getExercises();
    if (!mounted) return null;
    final inSession = sessionExercises.map((e) => e['exercise_id'] as int).toSet();
    final available = all.where((e) {
      final id = e['id'] as int;
      if (id == excludingId) return false;
      return !inSession.contains(id) || excludingId != null;
    }).toList();

    return showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .72,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(children: [
                  const TamrinoLogo(size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text('انتخاب حرکت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                ]),
              ),
              Expanded(
                child: available.isEmpty
                    ? const Center(child: Text('حرکت دیگری وجود ندارد.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exercise = available[index];
                          return ListTile(
                            leading: CircleAvatar(child: Icon(exercise['is_favorite'] == 1 ? Icons.star_rounded : Icons.fitness_center_rounded)),
                            title: Text(exercise['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text([exercise['muscle_group'], exercise['equipment']].whereType<String>().where((e) => e.isNotEmpty).join(' • ')),
                            onTap: () => Navigator.pop(context, exercise),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _addExerciseMidSession() async {
    if (sessionId == null) return;
    final picked = await _pickExercise();
    if (picked == null) return;
    await advanced.addExerciseToSession(
      sessionId: sessionId!,
      exerciseId: picked['id'] as int,
      targetReps: picked['exercise_mode'] == 'timed' ? null : '8-12',
    );
    await _reloadSessionExercises();
  }

  Future<void> _swapExercise(Map<String, Object?> exercise) async {
    final oldId = exercise['exercise_id'] as int;
    final picked = await _pickExercise(excludingId: oldId);
    if (picked == null) return;
    final logged = sets.any((s) => s['exercise_id'] == oldId);
    if (logged && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعویض حرکت؟'),
          content: const Text('ست‌های ثبت‌شده قبلی با نام حرکت قبلی در تاریخچه می‌مانند و ادامه جلسه با حرکت جدید انجام می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تعویض')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await advanced.swapSessionExercise(
      sessionExerciseId: exercise['id'] as int,
      newExerciseId: picked['id'] as int,
    );
    previousSets[picked['id'] as int] = await repo.getLastExerciseSets(picked['id'] as int);
    await _reloadSessionExercises();
  }

  Future<void> _removeExercise(Map<String, Object?> exercise) async {
    if (sessionId == null) return;
    final exerciseId = exercise['exercise_id'] as int;
    final hasSets = sets.any((s) => s['exercise_id'] == exerciseId);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حرکت از این جلسه'),
        content: Text(hasSets ? 'برای ست‌هایی که قبلاً ثبت شده‌اند چه کاری انجام شود؟' : 'این حرکت فقط از همین جلسه حذف می‌شود و برنامه اصلی تغییر نمی‌کند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          if (hasSets) TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('نگه‌داشتن ست‌ها')),
          FilledButton(onPressed: () => Navigator.pop(context, hasSets ? 'delete' : 'remove'), child: Text(hasSets ? 'حذف همراه ست‌ها' : 'حذف')),
        ],
      ),
    );
    if (result == null) return;
    await advanced.removeExerciseFromSession(
      sessionExerciseId: exercise['id'] as int,
      sessionId: sessionId!,
      exerciseId: exerciseId,
      removeLoggedSets: result == 'delete',
    );
    await _reloadSets();
    await _reloadSessionExercises();
  }

  Future<void> _setBarWeight(Map<String, Object?> exercise) async {
    final controller = TextEditingController(text: exercise['bar_weight'] == null ? '20' : '${exercise['bar_weight']}');
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('وزن میله'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'کیلوگرم', hintText: 'مثلاً 20'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())), child: const Text('ذخیره')),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    await advanced.setBarWeight(exercise['id'] as int, value);
    await _reloadSessionExercises();
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
    final barWeight = (exercise['bar_weight'] as num?)?.toDouble();

    final previous = previousSets[exerciseId] ?? const [];
    Map<String, Object?>? previousSuggestion;
    if (previous.isNotEmpty) {
      previousSuggestion = previous[(nextSet - 1).clamp(0, previous.length - 1)];
      if (previousSuggestion['reps'] != null) reps.text = '${previousSuggestion['reps']}';
      if (previousSuggestion['weight'] != null) weight.text = '${previousSuggestion['weight']}';
      if (previousSuggestion['rpe'] != null) rpe.text = '${previousSuggestion['rpe']}';
    }

    final loadSuggestion = await advanced.getLoadSuggestion(
      exerciseId: exerciseId,
      plan: widget.plan,
      targetReps: exercise['target_reps'] as String?,
    );
    if (loadSuggestion != null) weight.text = '${loadSuggestion.weight}';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          final currentWeight = double.tryParse(weight.text.trim());
          final plates = barWeight != null && currentWeight != null
              ? advanced.calculatePlates(totalWeight: currentWeight, barWeight: barWeight)
              : null;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const TamrinoLogo(size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Text(exercise['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 4),
                  Text('ست $nextSet${perSide ? ' • تکرار برای هر سمت' : ''}'),
                  if (loadSuggestion != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('پیشنهاد اختیاری', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${loadSuggestion.weight} kg • ${loadSuggestion.reason}'),
                      ]),
                    ),
                  ] else if (previousSuggestion != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Text('جلسه قبل: ${previousSuggestion['reps'] ?? '—'} تکرار${previousSuggestion['weight'] != null ? ' • ${previousSuggestion['weight']} kg' : ''}'),
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
                      onChanged: (_) => modalSetState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: bodyweight ? 'وزنه اضافه (kg)' : 'وزنه (kg)'),
                    )),
                  ]),
                  if (plates != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const Icon(Icons.fitness_center_rounded),
                        const SizedBox(width: 8),
                        Expanded(child: Text(plates.platesPerSide.isEmpty
                            ? 'فقط میله $barWeight kg'
                            : 'هر سمت: ${plates.platesPerSide.map((e) => '${e}kg').join(' + ')}${plates.exact ? '' : ' • باقیمانده ${plates.remainder.toStringAsFixed(1)}kg'}')),
                      ]),
                    ),
                  ],
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
          );
        },
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
      case 'warmup': return 'گرم‌کردن';
      case 'drop': return 'دراپ‌ست';
      case 'rest_pause': return 'Rest-Pause';
      case 'failure': return 'ست سنگین';
      default: return 'معمولی';
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
    if (bodyweight) return '$reps تکرار$side${weight != null ? ' • +$weight kg' : ' • وزن بدن'}';
    return '$reps تکرار$side × ${weight ?? '—'} kg';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 10,
          title: Row(children: [
            const TamrinoLogo(size: 34),
            const SizedBox(width: 9),
            Expanded(child: Text(widget.plan['name'] as String, overflow: TextOverflow.ellipsis)),
          ]),
          actions: [
            IconButton(onPressed: _addExerciseMidSession, icon: const Icon(Icons.add_circle_outline_rounded), tooltip: 'افزودن حرکت'),
            IconButton(onPressed: _editSessionNotes, icon: const Icon(Icons.sticky_note_2_outlined), tooltip: 'یادداشت جلسه'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  child: sessionExercises.isEmpty
                      ? Center(child: FilledButton.icon(onPressed: _addExerciseMidSession, icon: const Icon(Icons.add_rounded), label: const Text('افزودن اولین حرکت')))
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: sessionExercises.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final exercise = sessionExercises[index];
                            final exerciseId = exercise['exercise_id'] as int;
                            final exerciseSets = sets.where((s) => s['exercise_id'] == exerciseId).toList();
                            final targetSets = exercise['target_sets'] as int?;
                            final rest = (exercise['rest_seconds'] as num?)?.toInt() ?? 90;
                            final timed = exercise['exercise_mode'] == 'timed';
                            final bodyweight = exercise['is_bodyweight'] == 1;
                            final perSide = exercise['per_side'] == 1;
                            final barWeight = exercise['bar_weight'];
                            final tags = <String>[
                              timed ? 'زمانی' : 'تکراری',
                              if (bodyweight) 'وزن بدن',
                              if (perSide) 'هر سمت',
                              if (barWeight != null) 'میله ${barWeight}kg',
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
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'swap') _swapExercise(exercise);
                                        if (value == 'remove') _removeExercise(exercise);
                                        if (value == 'bar') _setBarWeight(exercise);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'swap', child: Text('تعویض حرکت')),
                                        PopupMenuItem(value: 'bar', child: Text('وزن میله / Plate Math')),
                                        PopupMenuItem(value: 'remove', child: Text('حذف از همین جلسه')),
                                      ],
                                    ),
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
  const _TimedSetSheet({required this.exerciseName, required this.setNumber, required this.allowWeight, this.suggestedSeconds});
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
            Row(children: [
              const TamrinoLogo(size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.exerciseName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            ]),
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
                if (!running && seconds > 0) TextButton(onPressed: () => setState(() => seconds = 0), child: const Text('صفر کردن')),
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
                      Navigator.pop(context, _TimedSetDraft(
                        seconds: seconds,
                        weight: double.tryParse(weight.text.trim()),
                        rpe: double.tryParse(rpe.text.trim()),
                        setType: setType,
                      ));
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
