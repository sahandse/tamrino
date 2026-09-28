import 'package:flutter/material.dart';

import '../../core/database/body_metrics_repository.dart';

class BodyMetricsScreen extends StatefulWidget {
  const BodyMetricsScreen({super.key});

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  final repo = BodyMetricsRepository();

  Future<void> _add() async {
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    final chest = TextEditingController();
    final waist = TextEditingController();
    final arm = TextEditingController();
    final thigh = TextEditingController();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ثبت اندازه‌های بدن', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزن (kg)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: bodyFat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'درصد چربی'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: chest, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'دور سینه (cm)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: waist, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'دور کمر (cm)'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: arm, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'دور بازو (cm)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: thigh, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'دور ران (cm)'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'یادداشت')),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final values = [weight.text, bodyFat.text, chest.text, waist.text, arm.text, thigh.text];
                    if (values.every((e) => e.trim().isEmpty)) return;
                    await repo.addMeasurement(
                      measuredAt: DateTime.now(),
                      weight: double.tryParse(weight.text.trim()),
                      bodyFat: double.tryParse(bodyFat.text.trim()),
                      chest: double.tryParse(chest.text.trim()),
                      waist: double.tryParse(waist.text.trim()),
                      arm: double.tryParse(arm.text.trim()),
                      thigh: double.tryParse(thigh.text.trim()),
                      notes: notes.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ذخیره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('وزن و اندازه‌های بدن')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ثبت جدید'),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: repo.getMeasurements(),
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (rows.isEmpty) {
              return const Center(child: Text('هنوز اندازه‌ای ثبت نشده است.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final date = DateTime.tryParse(row['measured_at'] as String? ?? '');
                final metrics = <String>[];
                if (row['weight'] != null) metrics.add('${row['weight']} kg');
                if (row['body_fat'] != null) metrics.add('${row['body_fat']}٪ چربی');
                if (row['waist'] != null) metrics.add('کمر ${row['waist']} cm');
                return Dismissible(
                  key: ValueKey(row['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.delete_outline_rounded),
                  ),
                  onDismissed: (_) async {
                    await repo.deleteMeasurement(row['id'] as int);
                    if (mounted) setState(() {});
                  },
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
                      title: Text(metrics.isEmpty ? 'اندازه بدن' : metrics.join(' • '), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: date == null ? null : Text('${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
