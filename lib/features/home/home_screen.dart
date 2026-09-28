import 'package:flutter/material.dart';

import '../../core/backup/google_drive_backup_service.dart';
import '../../core/backup/local_backup_service.dart';
import '../../core/database/workout_repository.dart';
import '../exercises/exercises_screen.dart';
import '../progress/progress_screen.dart';
import '../progress/training_calendar_screen.dart';
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
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'خانه'),
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

  Future<_DashboardData> _load() async {
    final summary = await repo.getProgressSummary();
    final plans = await repo.getPlansForWeekday(DateTime.now().weekday);
    final recent = await repo.getRecentSessions(limit: 1);
    return _DashboardData(summary, plans, recent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<_DashboardData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final todayPlan = data?.plans.isNotEmpty == true ? data!.plans.first : null;
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(todayPlan == null ? Icons.bolt_rounded : Icons.fitness_center_rounded, color: colors.primary, size: 30),
                    const SizedBox(height: 14),
                    Text(todayPlan == null ? 'برنامه امروز مشخص نشده' : 'تمرین امروز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(todayPlan == null ? 'از بخش تمرین برای برنامه‌ها روز هفته تعیین کن.' : todayPlan['name'] as String),
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
                  leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
                  title: Text(data!.recent.first['plan_name'] as String? ?? 'تمرین'),
                  subtitle: Text('${data.recent.first['set_count'] ?? 0} ست'),
                )),
              ],
              const SizedBox(height: 14),
              Card(child: ListTile(
                leading: Icon(Icons.lock_outline_rounded, color: colors.primary),
                title: const Text('اطلاعاتت روی دستگاه می‌ماند'),
                subtitle: const Text('بکاپ فقط وقتی خودت انتخاب کنی ساخته می‌شود.'),
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
  _DashboardData(this.summary, this.plans, this.recent);
  final Map<String, Object?> summary;
  final List<Map<String, Object?>> plans;
  final List<Map<String, Object?>> recent;
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
    final drive = GoogleDriveBackupService();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('بیشتر', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.save_alt_rounded), title: const Text('بکاپ محلی'), subtitle: const Text('ذخیره فایل اطلاعات روی گوشی'), onTap: busy ? null : () => run(() async { await local.exportBackup(); }, 'بکاپ محلی ساخته شد.')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.restore_rounded), title: const Text('بازیابی بکاپ محلی'), onTap: busy ? null : () => run(local.restoreFromPicker, 'اطلاعات بازیابی شد.')),
        ])),
        const SizedBox(height: 14),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: const Text('بکاپ Google Drive'), subtitle: const Text('ذخیره خصوصی در فضای مخصوص تمرینو'), onTap: busy ? null : () => run(drive.uploadBackup, 'بکاپ در Google Drive ذخیره شد.')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.cloud_download_outlined), title: const Text('بازیابی از Google Drive'), onTap: busy ? null : () => run(drive.restoreLatest, 'آخرین بکاپ Google Drive بازیابی شد.')),
        ])),
        if (busy) ...[const SizedBox(height: 18), const Center(child: CircularProgressIndicator())],
      ],
    );
  }
}
