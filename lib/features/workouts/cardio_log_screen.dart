import 'package:flutter/material.dart';

import '../../core/database/open_gym_feature_repository.dart';
import '../../core/database/workout_repository.dart';
import '../../core/settings/app_preferences.dart';

class CardioLogScreen extends StatefulWidget {
  const CardioLogScreen({super.key});

  @override
  State<CardioLogScreen> createState() => _CardioLogScreenState();
}

class _CardioLogScreenState extends State<CardioLogScreen> {
  final _repo = WorkoutRepository();
  final _features = OpenGymFeatureRepository();
  final _minutes = TextEditingController(text: '20');
  final _distance = TextEditingController();
  final _speed = TextEditingController();
  final _effort = TextEditingController();
  final _notes = TextEditingController();
  int? _exerciseId;
  String _effortScale = 'rpe';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AppPreferences.instance.effortScale().then((value) {
      if (mounted) setState(() => _effortScale = value);
    });
  }

  Future<List<Map<String, Object?>>> _load() async {
    final cardio = await _features.cardioExercises();
    if (cardio.isNotEmpty) return cardio;
    return _repo.getExercises();
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_minutes.text.trim());
    if (_exerciseId == null || minutes == null || minutes <= 0) return;
    setState(() => _saving = true);
    try {
      await _features.logCardioSession(
        exerciseId: _exerciseId!,
        durationSeconds: minutes * 60,
        distanceKm: double.tryParse(_distance.text.trim()),
        speedKmh: double.tryParse(_speed.text.trim()),
        effort: double.tryParse(_effort.text.trim()),
        effortScale: _effortScale,
        notes: _notes.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاردیو ذخیره شد.')));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ثبت کاردیو')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _load(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _exerciseId,
                  decoration: const InputDecoration(labelText: 'فعالیت'),
                  items: items
                      .map((e) => DropdownMenuItem<int>(
                            value: e['id'] as int,
                            child: Text(e['name'] as String),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _exerciseId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مدت (دقیقه)'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _distance,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'مسافت (km)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _speed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'سرعت (km/h)'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _effort,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: _effortScale.toUpperCase()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'rpe', label: Text('RPE')),
                      ButtonSegment(value: 'rir', label: Text('RIR')),
                    ],
                    selected: {_effortScale},
                    onSelectionChanged: (value) {
                      final scale = value.first;
                      setState(() => _effortScale = scale);
                      AppPreferences.instance.setEffortScale(scale);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'یادداشت'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'در حال ذخیره...' : 'ثبت کاردیو'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
