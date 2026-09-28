import 'package:flutter/material.dart';

import '../../core/database/advanced_workout_repository.dart';

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  final advanced = AdvancedWorkoutRepository();
  final total = TextEditingController(text: '60');
  final bar = TextEditingController(text: '20');
  List<double> result = const [];

  Future<void> _calculate() async {
    final totalWeight = double.tryParse(total.text.trim());
    final barWeight = double.tryParse(bar.text.trim());
    if (totalWeight == null || barWeight == null || totalWeight < barWeight) return;
    final plates = await advanced.plateBreakdown(totalWeight: totalWeight, barWeight: barWeight);
    if (mounted) setState(() => result = plates);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
  }

  @override
  Widget build(BuildContext context) {
    final perSide = ((double.tryParse(total.text) ?? 0) - (double.tryParse(bar.text) ?? 0)) / 2;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('محاسبه صفحه هالتر')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Plate Calculator', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('وزن کل را وارد کن؛ برنامه می‌گوید برای هر سمت چه صفحه‌هایی بگذاری.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextField(controller: total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزن کل (kg)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: bar, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'وزن میله (kg)'))),
            ]),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate_rounded), label: const Text('محاسبه')),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('هر سمت', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('${perSide < 0 ? 0 : perSide.toStringAsFixed(perSide % 1 == 0 ? 0 : 2)} kg', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (result.isEmpty)
                    const Text('صفحه‌ای لازم نیست یا وزن واردشده کمتر از وزن میله است.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: result.map((p) => Chip(label: Text('${p.toStringAsFixed(p % 1 == 0 ? 0 : 2)} kg'))).toList(),
                    ),
                  const SizedBox(height: 14),
                  Text('صفحه‌های استاندارد: 25، 20، 15، 10، 5، 2.5 و 1.25 کیلوگرم', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
