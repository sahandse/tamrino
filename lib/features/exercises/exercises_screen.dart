import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final repo = WorkoutRepository();
  String query = '';
  String? muscleFilter;
  String? equipmentFilter;
  bool favoritesOnly = false;

  Future<void> _openExerciseEditor([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final muscle = TextEditingController(text: item?['muscle_group'] as String? ?? '');
    final equipment = TextEditingController(text: item?['equipment'] as String? ?? '');
    final notes = TextEditingController(text: item?['notes'] as String? ?? '');
    var exerciseMode = item?['exercise_mode'] as String? ?? 'reps';
    var isBodyweight = item?['is_bodyweight'] == 1;
    var perSide = item?['per_side'] == 1;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item == null ? 'افزودن حرکت' : 'ویرایش حرکت',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'نام حرکت *')),
                  const SizedBox(height: 12),
                  TextField(controller: muscle, decoration: const InputDecoration(labelText: 'عضله هدف')),
                  const SizedBox(height: 12),
                  TextField(controller: equipment, decoration: const InputDecoration(labelText: 'تجهیزات')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: exerciseMode,
                    decoration: const InputDecoration(labelText: 'نوع ثبت حرکت'),
                    items: const [
                      DropdownMenuItem(value: 'reps', child: Text('تکرار و وزنه')),
                      DropdownMenuItem(value: 'timed', child: Text('زمانی')),
                    ],
                    onChanged: (value) {
                      if (value != null) modalSetState(() => exerciseMode = value);
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('حرکت با وزن بدن'),
                    subtitle: const Text('برای حرکت‌هایی مثل شنا، بارفیکس یا دیپ'),
                    value: isBodyweight,
                    onChanged: (value) => modalSetState(() => isBodyweight = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تکرار برای هر سمت'),
                    subtitle: const Text('برای حرکت‌های یک‌طرفه مثل لانج یا دمبل تک‌دست'),
                    value: perSide,
                    onChanged: (value) => modalSetState(() => perSide = value),
                  ),
                  const SizedBox(height: 6),
                  TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت')),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      if (item == null) {
                        await repo.addExercise(
                          name: name.text,
                          muscleGroup: muscle.text,
                          equipment: equipment.text,
                          notes: notes.text,
                          exerciseMode: exerciseMode,
                          isBodyweight: isBodyweight,
                          perSide: perSide,
                        );
                      } else {
                        await repo.updateExercise(
                          exerciseId: item['id'] as int,
                          name: name.text,
                          muscleGroup: muscle.text,
                          equipment: equipment.text,
                          notes: notes.text,
                          exerciseMode: exerciseMode,
                          isBodyweight: isBodyweight,
                          perSide: perSide,
                        );
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    child: Text(item == null ? 'ذخیره حرکت' : 'ذخیره تغییرات'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getExercises(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const [];
        final muscles = all
            .map((e) => e['muscle_group'] as String?)
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final equipment = all
            .map((e) => e['equipment'] as String?)
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final items = all.where((e) {
          final name = (e['name'] as String).toLowerCase();
          if (!name.contains(query.toLowerCase())) return false;
          if (favoritesOnly && e['is_favorite'] != 1) return false;
          if (muscleFilter != null && e['muscle_group'] != muscleFilter) return false;
          if (equipmentFilter != null && e['equipment'] != equipmentFilter) return false;
          return true;
        }).toList();

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('حرکات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                IconButton.filledTonal(onPressed: () => _openExerciseEditor(), icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(hintText: 'جستجوی حرکت', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChip(label: const Text('علاقه‌مندی'), selected: favoritesOnly, onSelected: (v) => setState(() => favoritesOnly = v)),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) => setState(() => muscleFilter = v == '__all' ? null : v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '__all', child: Text('همه عضلات')),
                      ...muscles.map((m) => PopupMenuItem(value: m, child: Text(m))),
                    ],
                    child: Chip(label: Text(muscleFilter ?? 'عضله')),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) => setState(() => equipmentFilter = v == '__all' ? null : v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '__all', child: Text('همه تجهیزات')),
                      ...equipment.map((m) => PopupMenuItem(value: m, child: Text(m))),
                    ],
                    child: Chip(label: Text(equipmentFilter ?? 'تجهیزات')),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? const _EmptyExercises()
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final muscle = item['muscle_group'] as String?;
                              final eq = item['equipment'] as String?;
                              final tags = <String>[
                                if (muscle?.isNotEmpty == true) muscle!,
                                if (eq?.isNotEmpty == true) eq!,
                                if (item['exercise_mode'] == 'timed') 'زمانی',
                                if (item['is_bodyweight'] == 1) 'وزن بدن',
                                if (item['per_side'] == 1) 'هر سمت',
                              ];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(child: Icon(item['is_favorite'] == 1 ? Icons.star_rounded : Icons.fitness_center_rounded)),
                                  title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(tags.join(' • ')),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(item['is_favorite'] == 1 ? Icons.star_rounded : Icons.star_border_rounded),
                                        onPressed: () async {
                                          await repo.toggleExerciseFavorite(item['id'] as int, item['is_favorite'] != 1);
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                      const Icon(Icons.edit_outlined),
                                    ],
                                  ),
                                  onTap: () => _openExerciseEditor(item),
                                ),
                              );
                            },
                          ),
              ),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openExerciseEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('حرکت جدید'),
          ),
        );
      },
    );
  }
}

class _EmptyExercises extends StatelessWidget {
  const _EmptyExercises();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_gymnastics_rounded, size: 76, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text('حرکتی پیدا نشد', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('حرکت واقعی خودت را اضافه کن یا فیلترها را تغییر بده.', textAlign: TextAlign.center),
        ]),
      );
}
