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

  Future<void> _addExercise() async {
    final name = TextEditingController();
    final muscle = TextEditingController();
    final equipment = TextEditingController();
    final notes = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('افزودن حرکت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'نام حرکت *')),
            const SizedBox(height: 12),
            TextField(controller: muscle, decoration: const InputDecoration(labelText: 'عضله هدف')),
            const SizedBox(height: 12),
            TextField(controller: equipment, decoration: const InputDecoration(labelText: 'تجهیزات')),
            const SizedBox(height: 12),
            TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await repo.addExercise(name: name.text, muscleGroup: muscle.text, equipment: equipment.text, notes: notes.text);
              if (context.mounted) Navigator.pop(context, true);
            }, child: const Text('ذخیره حرکت'))),
          ]),
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _editNotes(Map<String, Object?> item) async {
    final notes = TextEditingController(text: item['notes'] as String? ?? '');
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
            TextField(controller: notes, maxLines: 5, decoration: const InputDecoration(labelText: 'یادداشت حرکت')),
            const SizedBox(height: 14),
            FilledButton(onPressed: () async {
              await repo.updateExerciseNotes(item['id'] as int, notes.text);
              if (context.mounted) Navigator.pop(context);
            }, child: const Text('ذخیره یادداشت')),
          ]),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getExercises(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const [];
        final muscles = all.map((e) => e['muscle_group'] as String?).whereType<String>().where((e) => e.isNotEmpty).toSet().toList()..sort();
        final equipment = all.map((e) => e['equipment'] as String?).whereType<String>().where((e) => e.isNotEmpty).toSet().toList()..sort();
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
                IconButton.filledTonal(onPressed: _addExercise, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 14),
              TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(hintText: 'جستجوی حرکت', prefixIcon: Icon(Icons.search_rounded))),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                FilterChip(label: const Text('علاقه‌مندی'), selected: favoritesOnly, onSelected: (v) => setState(() => favoritesOnly = v)),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (v) => setState(() => muscleFilter = v == '__all' ? null : v),
                  itemBuilder: (_) => [const PopupMenuItem(value: '__all', child: Text('همه عضلات')), ...muscles.map((m) => PopupMenuItem(value: m, child: Text(m)))],
                  child: Chip(label: Text(muscleFilter ?? 'عضله')),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (v) => setState(() => equipmentFilter = v == '__all' ? null : v),
                  itemBuilder: (_) => [const PopupMenuItem(value: '__all', child: Text('همه تجهیزات')), ...equipment.map((m) => PopupMenuItem(value: m, child: Text(m)))],
                  child: Chip(label: Text(equipmentFilter ?? 'تجهیزات')),
                ),
              ])),
              const SizedBox(height: 14),
              Expanded(child: snapshot.connectionState == ConnectionState.waiting
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
                            return Card(child: ListTile(
                              leading: CircleAvatar(child: Icon(item['is_favorite'] == 1 ? Icons.star_rounded : Icons.fitness_center_rounded)),
                              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text([if (muscle?.isNotEmpty == true) muscle!, if (eq?.isNotEmpty == true) eq!].join(' • ')),
                              trailing: IconButton(
                                icon: Icon(item['is_favorite'] == 1 ? Icons.star_rounded : Icons.star_border_rounded),
                                onPressed: () async {
                                  await repo.toggleExerciseFavorite(item['id'] as int, item['is_favorite'] != 1);
                                  if (mounted) setState(() {});
                                },
                              ),
                              onTap: () => _editNotes(item),
                            ));
                          },
                        )),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(onPressed: _addExercise, icon: const Icon(Icons.add_rounded), label: const Text('حرکت جدید')),
        );
      },
    );
  }
}

class _EmptyExercises extends StatelessWidget {
  const _EmptyExercises();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.sports_gymnastics_rounded, size: 76, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 18),
    Text('حرکتی پیدا نشد', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    const Text('حرکت واقعی خودت را اضافه کن یا فیلترها را تغییر بده.', textAlign: TextAlign.center),
  ]));
}
