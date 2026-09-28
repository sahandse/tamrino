import 'package:flutter/material.dart';

import '../../core/backup/local_backup_service.dart';
import '../../core/branding/tamrino_logo.dart';
import '../../core/database/active_session_repository.dart';
import '../../core/database/advanced_workout_repository.dart';
import '../../core/database/workout_repository.dart';
import '../exercises/exercises_screen.dart';
import '../progress/progress_screen.dart';
import '../progress/training_calendar_screen.dart';
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
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: TamrinoLogo(size: 25), selectedIcon: TamrinoLogo(size: 28), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), label: 'تمرین'),
            NavigationDestination(icon: Icon(Icons.sports_gymnastics_outlined), label: 'حرکات'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'پیشرفت'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), label: 'بیشتر'),
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
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                const TamrinoLogo(size: 58),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تمرینو', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('تمرین شخصی، آفلاین و خصوصی', style: TextStyle(color: colors.onSurfaceVariant)),
                ])),
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingCalendarScreen())),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ]),
              const SizedBox(height: 22),
              if (active != null) ...[
                Card(
                  color: colors.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const TamrinoLogo(size: 38),
                        const SizedBox(width: 10),
                        Expanded(child: Text('جلسه تمرین فعال', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                      ]),
                      const SizedBox(height: 8),
                      Text(active['plan_name'] as String? ?? 'تمرین'),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: FilledButton.icon(onPressed: () => _resumeActive(active), icon: const Icon(Icons.play_arrow_rounded), label: const Text('ادامه تمرین'))),
                        const SizedBox(width: 10),
                        IconButton.outlined(onPressed: () => _cancelActive(active), icon: const Icon(Icons.close_rounded), tooltip: 'لغو جلسه'),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(todayPlan == null ? Icons.bolt_rounded : Icons.fitness_center_rounded, color: colors.primary, size: 30),
                    const SizedBox(height: 14),
                    Text(todayPlan == null ? 'برنامه امروز مشخص نشده' : 'تمرین امروز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(todayPlan == null ? 'از بخش تمرین برای برنامه‌ها روز هفته تعیین کن.' : todayPlan['name'] as String),
                    if (todayPlan?['scheduled_date'] != null) ...[
                      const SizedBox(height: 6),
                      Text('برای همین هفته جابه‌جا شده', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: widget.onOpenWorkouts, icon: const Icon(Icons.arrow_back_rounded), label: Text(todayPlan == null ? 'مدیریت برنامه‌ها' : 'رفتن به تمرین')),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.event_available_rounded, value: '${data?.summary['workout_count'] ?? 0}', label: 'کل تمرین‌ها')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.check_circle_outline_rounded, value: '${data?.summary['set_count'] ?? 0}', label: 'کل ست‌ها')),
              ]),
              const SizedBox(height: 10),
              _MetricCard(icon: Icons.monitor_weight_outlined, value: _formatVolume(data?.summary['total_volume']), label: 'حجم کل تمرین'),
              if (data?.recent.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text('آخرین تمرین', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Card(child: ListTile(
                  leading: const CircleAvatar(child: TamrinoLogo(size: 24)),
                  title: Text(data!.recent.first['plan_name'] as String? ?? 'تمرین'),
                  subtitle: Text('${data.recent.first['set_count'] ?? 0} ست'),
                )),
              ],
              const SizedBox(height: 14),
              Card(child: ListTile(
                leading: const TamrinoLogo(size: 34),
                title: const Text('اطلاعاتت روی دستگاه می‌ماند'),
                subtitle: const Text('تمرینو بدون حساب کاربری و بدون فضای ابری کار می‌کند.'),
              )),
            ],
          ),
        );
      },
    );
  }

  String _formatVolume(Object? value) {
    final n = value is num ? value.toDouble() : 0.0;
    return '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)} kg';
  }
}

class _DashboardData {
  _DashboardData(this.summary, this.plans, this.recent, this.active);
  final Map<String, Object?> summary;
  final List<Map<String, Object?>> plans;
  final List<Map<String, Object?>> recent;
  final Map<String, Object?>? active;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
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
      padding: const EdgeInsets.all(20),
      children: [
        const TamrinoLogo(size: 54, showWordmark: true),
        const SizedBox(height: 8),
        Text('بیشتر', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        Card(child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('یادآوری تمرین'),
          subtitle: const Text('تنظیم اعلان هفتگی برای برنامه‌ها'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutRemindersScreen())),
        )),
        const SizedBox(height: 14),
        Card(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('بکاپ محلی'),
            subtitle: const Text('ذخیره فایل اطلاعات روی گوشی'),
            onTap: busy ? null : () => run(() async { await local.exportBackup(); }, 'بکاپ محلی ساخته شد.'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('بازیابی بکاپ محلی'),
            subtitle: const Text('بازیابی اطلاعات از فایل بکاپ'),
            onTap: busy ? null : () => run(local.restoreFromPicker, 'اطلاعات بازیابی شد.'),
          ),
        ])),
        const SizedBox(height: 14),
        const Card(child: ListTile(
          leading: TamrinoLogo(size: 34),
          title: Text('حریم خصوصی'),
          subtitle: Text('اطلاعات تمرین فقط روی دستگاه ذخیره می‌شود و بکاپ ابری در برنامه وجود ندارد.'),
        )),
        if (busy) ...[const SizedBox(height: 18), const Center(child: CircularProgressIndicator())],
      ],
    );
  }
}
