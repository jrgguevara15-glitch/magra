import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import 'measurement.dart';

/// Abre el formulario de nueva medición en una hoja inferior.
Future<void> showMeasurementForm(BuildContext context, {required Sex sex}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: MeasurementForm(sex: sex)),
    ),
  );
}

class MeasurementForm extends ConsumerStatefulWidget {
  const MeasurementForm({super.key, required this.sex});

  final Sex sex;

  @override
  ConsumerState<MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends ConsumerState<MeasurementForm> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _neck = TextEditingController();
  final _waist = TextEditingController();
  final _hip = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_weight, _neck, _waist, _hip]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _optional(String? v, double min, double max) {
    if (v == null || v.trim().isEmpty) return null;
    final n = parseNum(v);
    return n == null || n < min || n > max
        ? 'Entre ${fmt(min)} y ${fmt(max)}'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final m = Measurement(
      date: _date,
      weightKg: parseNum(_weight.text)!,
      neckCm: parseNum(_neck.text),
      waistCm: parseNum(_waist.text),
      hipCm: parseNum(_hip.text),
    );
    if (m.neckCm != null && m.waistCm != null && m.waistCm! <= m.neckCm!) {
      setState(() => _error = 'La cintura debe ser mayor que el cuello.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(measurementRepositoryProvider).save(m);
      ref.invalidate(measurementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nueva medición', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
              'En ayunas. Cuello bajo la nuez; cintura a la altura del ombligo, relajado.'),
          gap,
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(fmtDate(_date)),
          ),
          gap,
          TextFormField(
            controller: _weight,
            autofocus: true,
            keyboardType: decimal,
            decoration:
                const InputDecoration(labelText: 'Peso', suffixText: 'kg'),
            validator: (v) {
              final n = parseNum(v ?? '');
              return n == null || n < 30 || n > 300
                  ? 'Peso entre 30 y 300 kg'
                  : null;
            },
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _neck,
                  keyboardType: decimal,
                  decoration: const InputDecoration(
                      labelText: 'Cuello', suffixText: 'cm'),
                  validator: (v) => _optional(v, 20, 70),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _waist,
                  keyboardType: decimal,
                  decoration: const InputDecoration(
                      labelText: 'Cintura', suffixText: 'cm'),
                  validator: (v) => _optional(v, 40, 200),
                ),
              ),
              if (widget.sex == Sex.female) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _hip,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                        labelText: 'Cadera', suffixText: 'cm'),
                    validator: (v) => _optional(v, 50, 200),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          const Text('Sin cuello y cintura se guarda solo el peso.'),
          if (_error != null) ...[
            gap,
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Guardar medición'),
            ),
          ),
        ],
      ),
    );
  }
}
