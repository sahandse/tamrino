import 'package:flutter/material.dart';

import '../../core/backup/local_backup_service.dart';
import '../../core/branding/tamrino_logo.dart';
import '../../core/database/active_session_repository.dart';
import '../../core/database/advanced_workout_repository.dart';
import '../../core/database/workout_repository.dart';
import '../exercises/exercises_screen.dart';
import '../progress/progress_screen.dart';
import '../progress/training_calendar_screen.dart';
import '../settings/advanced_workout_tools_screen.dart';
import '../settings/workout_reminders_screen.dart';
import '../workouts/workout_session_screen.dart';
import '../workouts/workouts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Dashboard(onOpenWorkouts: () => setState(() => index = 1)),
      const WorkoutsScreen(),
      const ExercisesScreen(),
      const ProgressScreen(),
      const _SettingsPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: IndexedStack(index: index, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: TamrinoLogo(size: 23), selectedIcon: TamrinoLogo(size: 26), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center_rounded), label: 'تمرین'),
            NavigationDestination(icon: Icon(Icons.sports_gymnastics_outlined), selectedIcon: Icon(Icons.sports_gymnastics_rounded), label: 'حرکات'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'پیشرفت'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'بیشتر'),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.onOpenWorkouts});
  final VoidCallback onOpenWorkouts;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final repo = WorkoutRepository();
  final advanced = AdvancedWorkoutRepository();
  final activeRepo = ActiveSessionRepository();

  Future<_DashboardData> _load() async {
    final summary = await repo.getProgressSummary();
    final plans = await advanced.getPlansForDate(DateTime.now());
    final recent = await repo.getRecentSessions(limit: 1);
    final active = await activeRepo.getActiveSession();
    return _DashboardData(summary, plans, recent, active);
  }

  Future<void> _resumeActive(Map<String, Object?> active) async {
    final planId = active['plan_id'] as int?;
    if (planId == null) return;
    final exercises = await repo.getPlanExercises(planId);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutSessionScreen(
        plan: {'id': planId, 'name': active['plan_name'] ?? 'تمرین'},
        exercises: exercises,
        existingSessionId: active['id'] as int,
        existingStartedAt: DateTime.tryParse(active['started_at'] as String? ?? ''),
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _cancelActive(Map<String, Object?> active) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لغو جلسه فعال؟'),
        content: const Text('ست‌های ثبت‌شده این جلسه حذف می‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('لغو جلسه')),
        ],
      ),
    );
    if (confirm != true) return;
    await activeRepo.cancelActiveSession(active['id'] as int);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<_DashboardData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final todayPlan = data?.plans.isNotEmpty == true ? data!.plans.first : null;
        final active = data?.active;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Row(children: [
                const TamrinoLogo(size: 44),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تمرینو', style: Theme.of(context).textTheme.headlineSmall),
                  Text('تمرین امروزت، بدون شلوغی', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ])),
                IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingCalendarScreen())),
                  icon: const Icon(Icons.calendar_month_rounded),
                  tooltip: 'تقویم',
                ),
              ]),
              const SizedBox(height: 22),
              if (active != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.play_arrow_rounded, color: colors.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('جلسه فعال', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text(active['plan_name'] as String? ?? 'تمرین', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    TextButton(onPressed: () => _resumeActive(active), child: const Text('ادامه')),
                    IconButton(onPressed: () => _cancelActive(active), icon: const Icon(Icons.close_rounded), tooltip: 'لغو'),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: colors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
                      child: Icon(todayPlan == null ? Icons.bolt_rounded : Icons.fitness_center_rounded, color: colors.primary),
                    ),
                    const Spacer(),
                    if (todayPlan?['scheduled_date'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: colors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
                        child: Text('جابجا شده', style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  const SizedBox(height: 18),
                  Text(todayPlan == null ? 'امروز برنامه‌ای نداری' : todayPlan['name'] as String, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    todayPlan == null ? 'می‌توانی از تمرین آزاد شروع کنی یا برنامه هفتگی بسازی.' : 'همه‌چیز برای شروع آماده است.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: widget.onOpenWorkouts,
                    icon: Icon(todayPlan == null ? Icons.add_rounded : Icons.play_arrow_rounded),
                    label: Text(todayPlan == null ? 'رفتن به تمرین‌ها' : 'شروع تمرین'),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _Metric(value: '${data?.summary['workout_count'] ?? 0}', label: 'تمرین')),
                const SizedBox(width: 10),
                Expanded(child: _Metric(value: '${data?.summary['set_count'] ?? 0}', label: 'ست')),
                const SizedBox(width: 10),
                Expanded(child: _Metric(value: _shortVolume(data?.summary['total_volume']), label: 'حجم')),
              ]),
              if (data?.recent.isNotEmpty == true) ...[
                const SizedBox(height: 22),
                Text('آخرین فعالیت', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    leading: const TamrinoLogo(size: 30),
                    title: Text(data!.recent.first['plan_name'] as String? ?? 'تمرین'),
                    subtitle: Text('${data.recent.first['set_count'] ?? 0} ست ثبت شده'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _shortVolume(Object? value) {
    final n = value is num ? value.toDouble() : 0.0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return n.toStringAsFixed(n % 1 == 0 ? 0 : 1);
  }
}

class _DashboardData {
  _DashboardData(this.summary, this.plans, this.recent, this.active);
  final Map<String, Object?> summary;
  final List<Map<String, Object?>> plans;
  final List<Map<String, Object?>> recent;
  final Map<String, Object?>? active;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool busy = false;

  Future<void> run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = LocalBackupService();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(children: [
          const TamrinoLogo(size: 42),
          const SizedBox(width: 10),
          Text('بیشتر', style: Theme.of(context).textTheme.headlineSmall),
        ]),
        const SizedBox(height: 22),
        _SettingTile(
          icon: Icons.notifications_none_rounded,
          title: 'یادآوری تمرین',
          subtitle: 'اعلان هفتگی برنامه‌ها',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutRemindersScreen())),
        ),
        const SizedBox(height: 10),
        _SettingTile(
          icon: Icons.tune_rounded,
          title: 'ابزارهای پیشرفته',
          subtitle: 'کاردیو، RIR/RPE، 1RM، Share/Import و تنظیمات تمرین',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvancedWorkoutToolsScreen())),
        ),
        const SizedBox(height: 10),
        _SettingTile(
          icon: Icons.save_alt_rounded,
          title: 'بکاپ محلی',
          subtitle: 'ذخیره فایل اطلاعات روی گوشی',
          onTap: busy ? null : () => run(() async { await local.exportBackup(); }, 'بکاپ محلی ساخته شد.'),
        ),
        const SizedBox(height: 10),
        _SettingTile(
          icon: Icons.restore_rounded,
          title: 'بازیابی بکاپ',
          subtitle: 'برگرداندن اطلاعات از فایل',
          onTap: busy ? null : () => run(local.restoreFromPicker, 'اطلاعات بازیابی شد.'),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const TamrinoLogo(size: 34),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('کاملاً آفلاین', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('اطلاعات تمرین فقط روی دستگاه ذخیره می‌شود.', style: Theme.of(context).textTheme.bodySmall),
            ])),
          ]),
        ),
        if (busy) ...[const SizedBox(height: 18), const Center(child: CircularProgressIndicator())],
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      );
}
