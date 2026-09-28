import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';
import 'freestyle_workout_screen.dart';
import 'past_workout_screen.dart';
import 'plate_calculator_screen.dart';
import 'workout_session_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final repo = WorkoutRepository();
  static const weekdays = <int, String>{
    6: 'شنبه',
    7: 'یکشنبه',
    1: 'دوشنبه',
    2: 'سه‌شنبه',
    3: 'چهارشنبه',
    4: 'پنجشنبه',
    5: 'جمعه',
  };

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _createPlan() async {
    final name = TextEditingController();
    final notes = TextEditingController();
    int? weekday;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, localSetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('برنامه جدید', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'نام برنامه *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: weekday,
                  decoration: const InputDecoration(labelText: 'روز هفته'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('بدون روز مشخص')),
                    ...weekdays.entries.map((e) => DropdownMenuItem<int?>(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (value) => localSetState(() => weekday = value),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await repo.createPlan(name: name.text, notes: notes.text, weekday: weekday);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('ساخت برنامه'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created == true && mounted) setState(() {});
  }

  Future<void> _duplicatePlan(Map<String, Object?> plan) async {
    await repo.duplicatePlan(plan['id'] as int);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نسخه کپی برنامه ساخته شد.')));
  }

  Future<void> _changeWeekday(Map<String, Object?> plan) async {
    final current = plan['weekday'] as int?;
    final value = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('بدون روز مشخص'), selected: current == null, onTap: () => Navigator.pop(context, 0)),
              ...weekdays.entries.map((e) => ListTile(title: Text(e.value), selected: current == e.key, onTap: () => Navigator.pop(context, e.key))),
            ],
          ),
        ),
      ),
    );
    if (!mounted || value == null) return;
    await repo.setPlanWeekday(plan['id'] as int, value == 0 ? null : value);
    setState(() {});
  }

  Future<void> _editPlanExercise(Map<String, Object?> item) async {
    final sets = TextEditingController(text: '${item['target_sets'] ?? ''}');
    final reps = TextEditingController(text: '${item['target_reps'] ?? ''}');
    final rest = TextEditingController(text: '${item['rest_seconds'] ?? 90}');
    await showModalBottomSheet<void>(
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
              Text(item['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد ست'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: reps, decoration: InputDecoration(labelText: item['exercise_mode'] == 'timed' ? 'هدف زمان' : 'هدف تکرار'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: rest, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'استراحت (ثانیه)')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await repo.updatePlanExercise(
                    planExerciseId: item['id'] as int,
                    targetSets: int.tryParse(sets.text),
                    targetReps: reps.text,
                    restSeconds: int.tryParse(rest.text) ?? 90,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('ذخیره'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await repo.removePlanExercise(item['id'] as int);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف حرکت از برنامه'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _managePlan(Map<String, Object?> plan) async {
    final planId = plan['id'] as int;
    final exercises = await repo.getExercises();
    if (!mounted) return;
    var selected = await repo.getPlanExercises(planId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, localSetState) {
            Future<void> reload() async {
              selected = await repo.getPlanExercises(planId);
              localSetState(() {});
              if (mounted) setState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: .85,
              maxChildSize: .96,
              builder: (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  Text(plan['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('ترتیب حرکات را نگه دار و تنظیم هر حرکت را جدا تغییر بده.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  if (selected.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('هنوز حرکتی اضافه نشده است.')))
                  else
                    SizedBox(
                      height: (selected.length * 82).clamp(82, 410).toDouble(),
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: selected.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;
                          final moved = selected.removeAt(oldIndex);
                          selected.insert(newIndex, moved);
                          localSetState(() {});
                          await repo.reorderPlanExercises(planId, selected.map((e) => e['id'] as int).toList());
                        },
                        itemBuilder: (context, index) {
                          final item = selected[index];
                          return Card(
                            key: ValueKey(item['id']),
                            child: ListTile(
                              leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator_rounded)),
                              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text('${item['target_sets'] ?? '—'} ست • ${item['target_reps'] ?? '—'} • ${item['rest_seconds'] ?? 90}s'),
                              trailing: const Icon(Icons.tune_rounded),
                              onTap: () async {
                                await _editPlanExercise(item);
                                await reload();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text('افزودن حرکت', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (exercises.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('ابتدا از تب حرکات، یک حرکت بساز.')))
                  else
                    ...exercises.map((exercise) => ListTile(
                          leading: CircleAvatar(child: Icon(exercise['is_favorite'] == 1 ? Icons.star_rounded : Icons.add_rounded)),
                          title: Text(exercise['name'] as String),
                          subtitle: Text([
                            exercise['exercise_mode'] == 'timed' ? 'زمانی' : 'تکراری',
                            if (exercise['is_bodyweight'] == 1) 'وزن بدن',
                            if (exercise['per_side'] == 1) 'هر سمت',
                          ].join(' • ')),
                          onTap: () async {
                            await repo.addExerciseToPlan(
                              planId: planId,
                              exerciseId: exercise['id'] as int,
                              targetSets: 3,
                              targetReps: exercise['exercise_mode'] == 'timed' ? '30s' : '8-12',
                            );
                            await reload();
                          },
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _startPlan(Map<String, Object?> plan) async {
    final exercises = await repo.getPlanExercises(plan['id'] as int);
    if (!mounted) return;
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ابتدا به برنامه حرکت اضافه کن.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutSessionScreen(plan: plan, exercises: exercises)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getPlans(),
      builder: (context, snapshot) {
        final plans = (snapshot.data ?? const <Map<String, Object?>>[])
            .where((p) => p['notes'] != '__tamrino_freestyle__')
            .toList();
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                Expanded(child: Text('تمرین', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                IconButton.filledTonal(onPressed: _createPlan, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 6),
              Text('برنامه هفتگی یا تمرین آزاد؛ هر دو با تاریخچه واقعی ذخیره می‌شوند.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _QuickAction(
                  icon: Icons.bolt_rounded,
                  title: 'تمرین آزاد',
                  subtitle: 'بدون برنامه',
                  onTap: () => _open(const FreestyleWorkoutScreen()),
                )),
                const SizedBox(width: 10),
                Expanded(child: _QuickAction(
                  icon: Icons.history_rounded,
                  title: 'تمرین گذشته',
                  subtitle: 'ثبت دستی',
                  onTap: () => _open(const PastWorkoutScreen()),
                )),
              ]),
              const SizedBox(height: 10),
              _QuickAction(
                icon: Icons.calculate_rounded,
                title: 'محاسبه صفحه هالتر',
                subtitle: 'وزن کل → صفحه‌های هر سمت',
                onTap: () => _open(const PlateCalculatorScreen()),
                horizontal: true,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Text('برنامه‌های هفتگی', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                TextButton.icon(onPressed: _createPlan, icon: const Icon(Icons.add_rounded), label: const Text('جدید')),
              ]),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
              else if (plans.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('هنوز برنامه هفتگی نداری؛ می‌توانی مستقیم تمرین آزاد شروع کنی.')))
              else
                ...plans.map((plan) {
                  final weekday = plan['weekday'] as int?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Expanded(child: Text(plan['name'] as String, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'copy') _duplicatePlan(plan);
                                if (value == 'day') _changeWeekday(plan);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'copy', child: Text('کپی برنامه')),
                                PopupMenuItem(value: 'day', child: Text('تغییر روز هفته')),
                              ],
                            ),
                          ]),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            Chip(label: Text('${plan['exercise_count'] ?? 0} حرکت')),
                            Chip(label: Text(weekday == null ? 'بدون روز' : weekdays[weekday]!)),
                          ]),
                          if ((plan['notes'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(plan['notes'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(onPressed: () => _managePlan(plan), icon: const Icon(Icons.tune_rounded), label: const Text('مدیریت'))),
                            const SizedBox(width: 10),
                            Expanded(child: FilledButton.icon(onPressed: () => _startPlan(plan), icon: const Icon(Icons.play_arrow_rounded), label: const Text('شروع'))),
                          ]),
                        ]),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 90),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(onPressed: _createPlan, icon: const Icon(Icons.add_rounded), label: const Text('برنامه جدید')),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final content = horizontal
        ? Row(children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            const Icon(Icons.chevron_left_rounded),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}
