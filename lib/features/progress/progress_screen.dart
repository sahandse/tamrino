import 'package:flutter/material.dart';

import '../../core/database/workout_repository.dart';
import 'session_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final repo = WorkoutRepository();

  Future<_ProgressData> _load() async {
    final summary = await repo.getProgressSummary();
    final sessions = await repo.getRecentSessions();
    final records = await repo.getPersonalRecords();
    final trend = await repo.getVolumeTrend();
    return _ProgressData(summary, sessions, records, trend);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProgressData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('پیشرفت', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (data == null || data.sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      Icon(Icons.insights_rounded, size: 76, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 18),
                      Text('هنوز تمرینی ثبت نشده', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('بعد از اولین تمرین، آمار واقعی اینجا نمایش داده می‌شود.'),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: _SummaryCard(title: 'تمرین‌ها', value: '${data.summary['workout_count'] ?? 0}', icon: Icons.calendar_month_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryCard(title: 'ست‌ها', value: '${data.summary['set_count'] ?? 0}', icon: Icons.check_circle_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                _SummaryCard(
                  title: 'حجم کل تمرین',
                  value: '${_formatNumber(data.summary['total_volume'])} kg',
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 22),
                Text('روند حجم تمرین', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _VolumeChart(items: data.trend),
                const SizedBox(height: 22),
                Text('رکوردهای شخصی', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                if (data.records.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('هنوز رکورد وزنه‌ای ثبت نشده است.')))
                else
                  ...data.records.take(6).map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
                          title: Text(record['exercise_name'] as String? ?? 'حرکت', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('بیشترین وزنه: ${_formatNumber(record['max_weight'])} kg'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('1RM تخمینی', style: TextStyle(fontSize: 11)),
                              Text('${_formatNumber(record['estimated_1rm'])} kg', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('تاریخچه تمرین', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ...data.sessions.map((s) {
                  final started = DateTime.tryParse(s['started_at'] as String? ?? '');
                  final finished = DateTime.tryParse(s['finished_at'] as String? ?? '');
                  final duration = started != null && finished != null ? finished.difference(started) : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
                        title: Text((s['plan_name'] as String?) ?? 'تمرین', style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text([
                          '${s['set_count'] ?? 0} ست',
                          '${_formatNumber(s['volume'])} kg حجم',
                          if (duration != null) '${duration.inMinutes} دقیقه',
                        ].join(' • ')),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _formatNumber(Object? value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return n.toStringAsFixed(n % 1 == 0 ? 0 : 1);
  }
}

class _ProgressData {
  _ProgressData(this.summary, this.sessions, this.records, this.trend);
  final Map<String, Object?> summary;
  final List<Map<String, Object?>> sessions;
  final List<Map<String, Object?>> records;
  final List<Map<String, Object?>> trend;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.items});
  final List<Map<String, Object?>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('هنوز داده کافی برای نمودار وجود ندارد.')));
    }

    final values = items.map((e) => (e['volume'] as num?)?.toDouble() ?? 0).toList();
    final maxValue = values.fold<double>(0, (a, b) => b > a ? b : a);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(items.length, (index) {
              final value = values[index];
              final ratio = maxValue <= 0 ? 0.05 : (value / maxValue).clamp(0.05, 1.0);
              final started = DateTime.tryParse(items[index]['started_at'] as String? ?? '');
              final label = started == null ? '—' : '${started.month}/${started.day}';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(_ProgressScreenState._formatNumber(value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
