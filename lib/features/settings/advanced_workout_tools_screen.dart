import 'package:flutter/material.dart';

import '../../core/database/open_gym_feature_repository.dart';
import '../../core/database/workout_repository.dart';
import '../../core/settings/app_preferences.dart';
import '../../core/sharing/plan_share_service.dart';
import '../workouts/cardio_log_screen.dart';

class AdvancedWorkoutToolsScreen extends StatefulWidget {
  const AdvancedWorkoutToolsScreen({super.key});

  @override
  State<AdvancedWorkoutToolsScreen> createState() => _AdvancedWorkoutToolsScreenState();
}

class _AdvancedWorkoutToolsScreenState extends State<AdvancedWorkoutToolsScreen> {
  final _prefs = AppPreferences.instance;
  final _repo = WorkoutRepository();
  final _features = OpenGymFeatureRepository();
  final _share = PlanShareService();

  int _weekStart = DateTime.saturday;
  String _effortScale = 'rpe';
  String _mediaMode = 'small';
  bool _keepAwake = true;
  bool _timerFlash = false;
  List<double> _plates = const [25, 20, 15, 10, 5, 2.5, 1.25];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      _prefs.weekStart(),
      _prefs.effortScale(),
      _prefs.exerciseMediaMode(),
      _prefs.keepAwakeDuringWorkout(),
      _prefs.timerFlash(),
      _prefs.ownedPlatesKg(),
    ]);
    if (!mounted) return;
    setState(() {
      _weekStart = values[0] as int;
      _effortScale = values[1] as String;
      _mediaMode = values[2] as String;
      _keepAwake = values[3] as bool;
      _timerFlash = values[4] as bool;
      _plates = values[5] as List<double>;
      _ready = true;
    });
  }

  Future<void> _editPlates() async {
    final controller = TextEditingController(text: _plates.join(', '));
    final saved = await showDialog<List<double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صفحات وزنه موجود'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '25, 20, 15, 10, 5, 2.5, 1.25',
            helperText: 'وزن هر صفحه را با ویرگول جدا کن.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final values = controller.text
                  .split(',')
                  .map((e) => double.tryParse(e.trim()))
                  .whereType<double>()
                  .where((e) => e > 0)
                  .toSet()
                  .toList();
              Navigator.pop(context, values);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (saved == null || saved.isEmpty) return;
    await _prefs.setOwnedPlatesKg(saved);
    final updated = await _prefs.ownedPlatesKg();
    if (mounted) setState(() => _plates = updated);
  }

  Future<void> _oneRmCalculator() async {
    final weight = TextEditingController();
    final reps = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final w = double.tryParse(weight.text.trim()) ?? 0;
          final r = int.tryParse(reps.text.trim()) ?? 0;
          final estimate = w > 0 && r >= 1 && r <= 12 ? w * (1 + r / 30) : null;
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('محاسبه 1RM تخمینی', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: weight,
                    onChanged: (_) => setSheetState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'وزنه (kg)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: reps,
                    onChanged: (_) => setSheetState(() {}),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تکرار 1 تا 12'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  estimate == null ? 'برای برآورد، وزنه و ۱ تا ۱۲ تکرار وارد کن.' : '${estimate.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'این مقدار فقط برآورد تمرینی است و برای تصمیم‌های پزشکی یا فشار بیشتر استفاده نمی‌شود.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _exportPlan() async {
    final plans = await _repo.getPlans();
    if (!mounted) return;
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هنوز برنامه‌ای برای خروجی وجود ندارد.')));
      return;
    }
    final planId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: plans
              .map((plan) => ListTile(
                    title: Text(plan['name'] as String),
                    subtitle: Text('${plan['exercise_count'] ?? 0} حرکت'),
                    onTap: () => Navigator.pop(context, plan['id'] as int),
                  ))
              .toList(),
        ),
      ),
    );
    if (planId == null) return;
    await _share.exportPlan(planId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل برنامه آماده شد.')));
  }

  Future<void> _importPlan() async {
    final id = await _share.importPlan();
    if (!mounted || id == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برنامه وارد شد و با برنامه‌های فعلی ادغام شد.')));
  }

  Future<void> _showStrengthRecords() async {
    final rows = await _features.relativeStrength();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('مقایسه رکوردهای قدرت', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('هنوز داده کافی وجود ندارد.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final value = (row['estimated_1rm'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          title: Text(row['exercise_name'] as String),
                          subtitle: Text(row['muscle_group'] as String? ?? 'بدون گروه عضلانی'),
                          trailing: Text('${value.toStringAsFixed(1)} kg'),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  String _plateLabel(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ابزارهای پیشرفته')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.directions_run_rounded),
                  title: const Text('ثبت کاردیو'),
                  subtitle: const Text('مدت، مسافت، سرعت و میزان تلاش'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardioLogScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('1RM تخمینی'),
                  subtitle: const Text('محاسبه از وزنه و حداکثر ۱۲ تکرار'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _oneRmCalculator,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.balance_rounded),
                  title: const Text('مقایسه رکوردهای قدرت'),
                  subtitle: const Text('نمایش رکوردهای ثبت‌شده بدون رتبه‌بندی بدنی'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _showStrengthRecords,
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('خروجی برنامه'),
                  subtitle: const Text('فایل کوچک شامل برنامه و حرکات، بدون تاریخچه'),
                  onTap: _exportPlan,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('ورود برنامه'),
                  subtitle: const Text('ادغام فایل برنامه با اطلاعات فعلی'),
                  onTap: _importPlan,
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                ListTile(
                  title: const Text('شروع هفته'),
                  trailing: DropdownButton<int>(
                    value: _weekStart,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: DateTime.saturday, child: Text('شنبه')),
                      DropdownMenuItem(value: DateTime.sunday, child: Text('یکشنبه')),
                      DropdownMenuItem(value: DateTime.monday, child: Text('دوشنبه')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await _prefs.setWeekStart(value);
                      setState(() => _weekStart = value);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('مقیاس تلاش'),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'rpe', label: Text('RPE')),
                      ButtonSegment(value: 'rir', label: Text('RIR')),
                    ],
                    selected: {_effortScale},
                    onSelectionChanged: (value) async {
                      final scale = value.first;
                      await _prefs.setEffortScale(scale);
                      setState(() => _effortScale = scale);
                    },
                  ),
                ),
                SwitchListTile.adaptive(
                  title: const Text('روشن ماندن صفحه هنگام تمرین'),
                  value: _keepAwake,
                  onChanged: (value) async {
                    await _prefs.setKeepAwakeDuringWorkout(value);
                    setState(() => _keepAwake = value);
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('فلش تصویری پایان تایمر'),
                  value: _timerFlash,
                  onChanged: (value) async {
                    await _prefs.setTimerFlash(value);
                    setState(() => _timerFlash = value);
                  },
                ),
                ListTile(
                  title: const Text('نمایش مدیای حرکت'),
                  trailing: DropdownButton<String>(
                    value: _mediaMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'full', child: Text('بزرگ')),
                      DropdownMenuItem(value: 'small', child: Text('کوچک')),
                      DropdownMenuItem(value: 'hidden', child: Text('مخفی')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await _prefs.setExerciseMediaMode(value);
                      setState(() => _mediaMode = value);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('صفحات وزنه موجود'),
                  subtitle: Text(_plates.map(_plateLabel).join('، ')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _editPlates,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
