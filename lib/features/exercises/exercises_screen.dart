import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/branding/tamrino_logo.dart';
import '../../core/database/open_gym_feature_repository.dart';
import '../../core/database/workout_repository.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final repo = WorkoutRepository();
  final features = OpenGymFeatureRepository();
  String query = '';
  String? muscleFilter;
  String? equipmentFilter;
  bool favoritesOnly = false;

  Future<void> _openExerciseEditor([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final muscle = TextEditingController(text: item?['muscle_group'] as String? ?? '');
    final equipment = TextEditingController(text: item?['equipment'] as String? ?? '');
    final notes = TextEditingController(text: item?['notes'] as String? ?? '');
    final guideUrl = TextEditingController(text: item?['guide_url'] as String? ?? '');

    var trackingType = item?['tracking_type'] as String? ??
        ((item?['exercise_mode'] as String?) == 'timed' ? 'timed' : 'strength');
    var isBodyweight = item?['is_bodyweight'] == 1;
    var perSide = item?['per_side'] == 1;
    var mediaPath = item?['media_path'] as String?;
    var mediaType = item?['media_type'] as String?;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item == null ? 'حرکت جدید' : 'ویرایش حرکت',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'نام حرکت *'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: muscle,
                        decoration: const InputDecoration(labelText: 'عضله'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: equipment,
                        decoration: const InputDecoration(labelText: 'تجهیزات'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: trackingType,
                    decoration: const InputDecoration(labelText: 'نوع فعالیت'),
                    items: const [
                      DropdownMenuItem(
                        value: 'strength',
                        child: Text('قدرتی / تکرار و وزنه'),
                      ),
                      DropdownMenuItem(
                        value: 'timed',
                        child: Text('زمانی'),
                      ),
                      DropdownMenuItem(
                        value: 'cardio',
                        child: Text('کاردیو / زمان، مسافت و سرعت'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        modalSetState(() => trackingType = value);
                      }
                    },
                  ),
                  if (trackingType == 'strength') ...[
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('وزن بدن'),
                      subtitle: const Text('مثل شنا، بارفیکس یا دیپ'),
                      value: isBodyweight,
                      onChanged: (v) => modalSetState(() => isBodyweight = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تکرار برای هر سمت'),
                      value: perSide,
                      onChanged: (v) => modalSetState(() => perSide = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: guideUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'لینک راهنما یا ویدئو',
                      hintText: 'اختیاری',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const [
                          'jpg',
                          'jpeg',
                          'png',
                          'gif',
                          'mp4',
                          'webm',
                        ],
                      );
                      if (picked == null || picked.files.isEmpty) return;
                      final file = picked.files.single;
                      final path = file.path;
                      if (path == null) return;
                      final ext = (file.extension ?? '').toLowerCase();
                      modalSetState(() {
                        mediaPath = path;
                        mediaType = {'mp4', 'webm'}.contains(ext)
                            ? 'video'
                            : ext == 'gif'
                                ? 'gif'
                                : 'image';
                      });
                    },
                    icon: const Icon(Icons.perm_media_outlined),
                    label: Text(
                      mediaPath == null ? 'انتخاب عکس / GIF / ویدئو' : 'تغییر مدیای حرکت',
                    ),
                  ),
                  if (mediaPath != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Text(
                          'مدیای محلی انتخاب شده • ${mediaType ?? 'media'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => modalSetState(() {
                          mediaPath = null;
                          mediaType = null;
                        }),
                        child: const Text('حذف'),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'یادداشت / توضیحات'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      final exerciseMode = trackingType == 'timed' ? 'timed' : 'reps';
                      final exerciseId = item == null
                          ? await repo.addExercise(
                              name: name.text,
                              muscleGroup: muscle.text,
                              equipment: equipment.text,
                              notes: notes.text,
                              exerciseMode: exerciseMode,
                              isBodyweight: trackingType == 'strength' && isBodyweight,
                              perSide: trackingType == 'strength' && perSide,
                            )
                          : item['id'] as int;

                      if (item != null) {
                        await repo.updateExercise(
                          exerciseId: exerciseId,
                          name: name.text,
                          muscleGroup: muscle.text,
                          equipment: equipment.text,
                          notes: notes.text,
                          exerciseMode: exerciseMode,
                          isBodyweight: trackingType == 'strength' && isBodyweight,
                          perSide: trackingType == 'strength' && perSide,
                        );
                      }

                      await features.setExerciseTracking(
                        exerciseId: exerciseId,
                        trackingType: trackingType,
                        mediaPath: mediaPath,
                        mediaType: mediaType,
                        guideUrl: guideUrl.text,
                      );

                      if (context.mounted) Navigator.pop(context, true);
                    },
                    child: const Text('ذخیره'),
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const TamrinoLogo(size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'حرکات',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _openExerciseEditor(),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]),
                const SizedBox(height: 18),
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'جستجو',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        label: const Text('★ علاقه‌مندی'),
                        selected: favoritesOnly,
                        onSelected: (v) => setState(() => favoritesOnly = v),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (v) => setState(
                          () => muscleFilter = v == '__all' ? null : v,
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '__all',
                            child: Text('همه عضلات'),
                          ),
                          ...muscles.map(
                            (m) => PopupMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        child: Chip(label: Text(muscleFilter ?? 'عضله')),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (v) => setState(
                          () => equipmentFilter = v == '__all' ? null : v,
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '__all',
                            child: Text('همه تجهیزات'),
                          ),
                          ...equipment.map(
                            (m) => PopupMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        child: Chip(label: Text(equipmentFilter ?? 'تجهیزات')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? const _EmptyExercises()
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final tracking = item['tracking_type'] as String? ??
                                    (item['exercise_mode'] == 'timed' ? 'timed' : 'strength');
                                final tags = <String>[
                                  if ((item['muscle_group'] as String?)?.isNotEmpty == true)
                                    item['muscle_group'] as String,
                                  if ((item['equipment'] as String?)?.isNotEmpty == true)
                                    item['equipment'] as String,
                                  if (tracking == 'timed') 'زمانی',
                                  if (tracking == 'cardio') 'کاردیو',
                                  if (item['is_bodyweight'] == 1) 'وزن بدن',
                                  if (item['per_side'] == 1) 'هر سمت',
                                  if (item['media_path'] != null) 'مدیا',
                                ];
                                final icon = tracking == 'cardio'
                                    ? Icons.directions_run_rounded
                                    : tracking == 'timed'
                                        ? Icons.timer_outlined
                                        : Icons.fitness_center_rounded;
                                return Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: .08),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    title: Text(
                                      item['name'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: tags.isEmpty
                                        ? null
                                        : Text(
                                            tags.join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        item['is_favorite'] == 1
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                      ),
                                      onPressed: () async {
                                        await repo.toggleExerciseFavorite(
                                          item['id'] as int,
                                          item['is_favorite'] != 1,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                    onTap: () => _openExerciseEditor(item),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
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
          const TamrinoLogo(size: 58),
          const SizedBox(height: 16),
          Text('حرکتی پیدا نشد', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'حرکت جدید اضافه کن یا فیلترها را تغییر بده.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ]),
      );
}
