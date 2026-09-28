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
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await repo.addExercise(
                      name: name.text,
                      muscleGroup: muscle.text,
                      equipment: equipment.text,
                      notes: notes.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('ذخیره حرکت'),
                ),
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
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getExercises(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const [];
        final items = all.where((e) {
          final name = (e['name'] as String).toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('حرکات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton.filledTonal(onPressed: _addExercise, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(hintText: 'جستجوی حرکت', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 16),
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
                                final equipment = item['equipment'] as String?;
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.fitness_center_rounded)),
                                    title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text([
                                      if (muscle?.isNotEmpty == true) muscle!,
                                      if (equipment?.isNotEmpty == true) equipment!,
                                    ].join(' • ')),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addExercise,
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
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_gymnastics_rounded, size: 76, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text('هنوز حرکتی ثبت نشده', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('اولین حرکت واقعی خودت را اضافه کن.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
