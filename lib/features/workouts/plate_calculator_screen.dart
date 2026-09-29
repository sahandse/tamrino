import 'package:flutter/material.dart';

import '../../core/settings/app_preferences.dart';

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  final total = TextEditingController(text: '60');
  final bar = TextEditingController(text: '20');
  List<double> ownedPlates = const [25, 20, 15, 10, 5, 2.5, 1.25];
  List<double> result = const [];
  double remainder = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plates = await AppPreferences.instance.ownedPlatesKg();
    if (!mounted) return;
    setState(() => ownedPlates = plates);
    _calculate();
  }

  void _calculate() {
    final totalWeight = double.tryParse(total.text.trim());
    final barWeight = double.tryParse(bar.text.trim());
    if (totalWeight == null || barWeight == null || totalWeight < barWeight) {
      setState(() {
        result = const [];
        remainder = 0;
      });
      return;
    }

    var perSide = (totalWeight - barWeight) / 2;
    final selected = <double>[];
    for (final plate in ownedPlates) {
      while (perSide + 0.0001 >= plate) {
        selected.add(plate);
        perSide -= plate;
      }
    }

    setState(() {
      result = selected;
      remainder = perSide.abs() < 0.001 ? 0 : perSide;
    });
  }

  String _label(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

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
            Text('محاسبه صفحه هالتر', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'محاسبه بر اساس صفحه‌هایی که در ابزارهای پیشرفته مشخص کرده‌ای.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: total,
                  onChanged: (_) => _calculate(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'وزن کل (kg)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: bar,
                  onChanged: (_) => _calculate(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'وزن میله (kg)'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('هر سمت', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${perSide < 0 ? '0' : _label(perSide)} kg',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (result.isEmpty)
                    const Text('صفحه‌ای لازم نیست یا وزن واردشده قابل ساخت نیست.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: result.map((p) => Chip(label: Text('${_label(p)} kg'))).toList(),
                    ),
                  if (remainder > 0.001) ...[
                    const SizedBox(height: 14),
                    Text(
                      'با صفحه‌های موجود، ${_label(remainder)} kg در هر سمت باقی می‌ماند.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'صفحه‌های موجود: ${ownedPlates.map(_label).join('، ')} kg',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
