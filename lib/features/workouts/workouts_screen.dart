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
  static const weekdays = <int, String>{
    6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه',
  };

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
        child: StatefulBuilder(builder: (context, localSetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              onChanged: (v) => localSetState(() => weekday = v),
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
          ]),
        )),
      ),
    );
    if (created == true && mounted) setState(() {});
  }

  Future<void> _duplicatePlan(Map<String, Object?> plan) async {
    await repo.duplicatePlan(plan['id'] as int);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('یک نسخه کپی از برنامه ساخته شد.')));
  }

  Future<void> _changeWeekday(Map<String, Object?> plan) async {
    final current = plan['weekday'] as int?;
    final value = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('بدون روز مشخص'), selected: current == null, onTap: () => Navigator.pop(context, 0)),
          ...weekdays.entries.map((e) => ListTile(title: Text(e.value), selected: current == e.key, onTap: () => Navigator.pop(context, e.key))),
        ])),
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(item['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعداد ست'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: reps, decoration: const InputDecoration(labelText: 'تکرار'))),
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
          ]),
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
        child: StatefulBuilder(builder: (context, localSetState) {
          Future<void> reload() async {
            selected = await repo.getPlanExercises(planId);
            localSetState(() {});
            if (mounted) setState(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .82,
            maxChildSize: .95,
            builder: (context, controller) => CustomScrollView(
              controller: controller,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plan['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('ترتیب حرکات را با کشیدن جابه‌جا کن.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 14),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: selected.isEmpty
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('هنوز حرکتی به این برنامه اضافه نشده است.', textAlign: TextAlign.center))
                        : SizedBox(
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
                                    subtitle: Text('${item['target_sets'] ?? '—'} ست • ${item['target_reps'] ?? '—'} تکرار • ${item['rest_seconds'] ?? 90} ثانیه'),
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
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  sliver: SliverToBoxAdapter(child: Text('افزودن حرکت', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                ),
                if (exercises.isEmpty)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Text('ابتدا از تب حرکات، یک حرکت واقعی اضافه کن.')))
                else
                  SliverList.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
                        title: Text(exercise['name'] as String),
                        subtitle: exercise['is_favorite'] == 1 ? const Text('★ علاقه‌مندی') : null,
                        onTap: () async {
                          await repo.addExerciseToPlan(
                            planId: planId,
                            exerciseId: exercise['id'] as int,
                            targetSets: 3,
                            targetReps: '8-12',
                          );
                          await reload();
                        },
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        }),
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
        final plans = snapshot.data ?? const [];
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('برنامه‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                IconButton.filledTonal(onPressed: _createPlan, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 16),
              Expanded(child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : plans.isEmpty
                      ? const Center(child: Text('هنوز برنامه تمرینی ساخته نشده است.'))
                      : ListView.separated(
                          itemCount: plans.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final plan = plans[index];
                            final weekday = plan['weekday'] as int?;
                            return Card(
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
                                  const SizedBox(height: 4),
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
                            );
                          },
                        )),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(onPressed: _createPlan, icon: const Icon(Icons.add_rounded), label: const Text('برنامه جدید')),
        );
      },
    );
  }
}
