import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final repo = WorkoutRepository();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: repo.getRecentSessions(),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('پیشرفت', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : sessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insights_rounded, size: 76, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(height: 18),
                                Text('هنوز تمرینی ثبت نشده', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 8),
                                const Text('بعد از اولین تمرین، تاریخچه واقعی اینجا نمایش داده می‌شود.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final s = sessions[index];
                              final started = DateTime.tryParse(s['started_at'] as String? ?? '');
                              final finished = DateTime.tryParse(s['finished_at'] as String? ?? '');
                              final duration = started != null && finished != null ? finished.difference(started) : null;

                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
                                  title: Text((s['plan_name'] as String?) ?? 'تمرین', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  subtitle: Text([
                                    '${s['set_count'] ?? 0} ست',
                                    if (duration != null) '${duration.inMinutes} دقیقه',
                                  ].join(' • ')),
                                  trailing: started == null
                                      ? null
                                      : Text('${started.year}/${started.month.toString().padLeft(2, '0')}/${started.day.toString().padLeft(2, '0')}'),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
