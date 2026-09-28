import 'package:flutter/material.dart';

import '../../core/backup/google_drive_backup_service.dart';
import '../../core/backup/local_backup_service.dart';
import '../exercises/exercises_screen.dart';
import '../progress/progress_screen.dart';
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
      const _Dashboard(),
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

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('تمرینو', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('تمرین شخصی، آفلاین و خصوصی', style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.fitness_center_rounded, color: colors.primary),
                const SizedBox(height: 16),
                Text('آماده تمرین هستی؟', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('از تب تمرین، برنامه واقعی خودت را بساز و ست‌ها را همان لحظه ثبت کن.'),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('از تب «تمرین» شروع کن'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: colors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('اطلاعات تمرین روی گوشی ذخیره می‌شود و فقط با انتخاب خودت بکاپ گرفته می‌شود.'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
        Card(
          child: Column(
            children: [
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
                onTap: busy ? null : () => run(local.restoreFromPicker, 'اطلاعات بازیابی شد.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('بکاپ Google Drive'),
                subtitle: const Text('ذخیره خصوصی در فضای مخصوص تمرینو'),
                onTap: busy ? null : () => run(drive.uploadBackup, 'بکاپ در Google Drive ذخیره شد.'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('بازیابی از Google Drive'),
                onTap: busy ? null : () => run(drive.restoreLatest, 'آخرین بکاپ Google Drive بازیابی شد.'),
              ),
            ],
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
