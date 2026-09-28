import 'package:flutter/material.dart';

import '../../core/backup/google_drive_backup_service.dart';
import '../../core/backup/local_backup_service.dart';

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
      const _EmptyPage(title: 'تمرین‌ها', icon: Icons.fitness_center_rounded, text: 'اولین برنامه تمرینی خودت را بساز.'),
      const _EmptyPage(title: 'حرکات', icon: Icons.sports_gymnastics_rounded, text: 'هنوز حرکتی ثبت نشده است.'),
      const _EmptyPage(title: 'پیشرفت', icon: Icons.insights_rounded, text: 'بعد از اولین تمرین، پیشرفت واقعی اینجا نمایش داده می‌شود.'),
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
                Icon(Icons.add_circle_outline_rounded, color: colors.primary),
                const SizedBox(height: 16),
                Text('هنوز برنامه تمرینی نداری', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('هیچ دیتای دمو یا آزمایشی داخل برنامه قرار نگرفته است.'),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text('ساخت برنامه تمرینی')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.title, required this.icon, required this.text});
  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const Spacer(),
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(text, textAlign: TextAlign.center),
          const Spacer(),
        ],
      ),
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
