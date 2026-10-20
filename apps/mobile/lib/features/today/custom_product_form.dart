import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import 'barcode.dart';
import 'photo_analysis.dart';

/// Crea (o corrige) un producto que no está en Open Food Facts con los
/// valores por 100 g/ml de su etiqueta. Se puede llenar leyendo la etiqueta
/// con una foto.
class CustomProductForm extends ConsumerStatefulWidget {
  const CustomProductForm({
    super.key,
    required this.code,
    this.initial,
    required this.onSaved,
    required this.onCancel,
  });

  final String code;

  /// Datos para partir (un producto propio a corregir, o el nombre que
  /// trajo Open Food Facts sin nutrientes).
  final Product? initial;
  final ValueChanged<Product> onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<CustomProductForm> createState() => _CustomProductFormState();
}

class _CustomProductFormState extends ConsumerState<CustomProductForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _brand = TextEditingController(text: widget.initial?.brand);
  late final _kcal = TextEditingController(text: _num(widget.initial?.kcal100));
  late final _protein = TextEditingController(
      text: widget.initial?.custom == true ? _num(widget.initial?.protein100) : '');
  late final _carbs = TextEditingController(
      text: widget.initial?.custom == true ? _num(widget.initial?.carbs100) : '');
  late final _fat = TextEditingController(
      text: widget.initial?.custom == true ? _num(widget.initial?.fat100) : '');
  late final _serving =
      TextEditingController(text: _num(widget.initial?.servingQuantity));
  late String _unit = widget.initial?.unit ?? 'g';
  bool _reading = false;
  bool _busy = false;
  String? _error;
  String? _info;

  static String _num(double? v) =>
      v == null ? '' : (v % 1 == 0 ? v.round().toString() : fmt(v, 1));

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _protein, _carbs, _fat, _serving]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _readLabel() async {
    final mobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final picked = await ref.read(imagePickProvider)(camera: mobile);
    if (picked == null || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await ref.read(photoAnalyzerProvider).analyze(
            bytes: picked.bytes,
            mediaType: mediaTypeFor(picked.name, picked.mimeType),
            mode: PhotoMode.label,
          );
      if (!mounted) return;
      final item = result.items.firstOrNull;
      setState(() {
        if (item == null) {
          _error = result.notes.isNotEmpty
              ? result.notes
              : 'No pude leer la etiqueta. Escribe los valores.';
          return;
        }
        if (_name.text.trim().isEmpty) _name.text = item.name;
        if (item.unit == 'unidad' || item.quantity <= 0) {
          _error = 'La etiqueta trae la porción en unidades: escribe los '
              'valores de la columna "100 g".';
          return;
        }
        _unit = item.unit == 'ml' ? 'ml' : 'g';
        final k = 100 / item.quantity;
        _kcal.text = _num((item.kcal * k * 10).round() / 10);
        _protein.text = _num((item.protein * k * 10).round() / 10);
        _carbs.text = _num((item.carbs * k * 10).round() / 10);
        _fat.text = _num((item.fat * k * 10).round() / 10);
        _serving.text = _num(item.quantity);
        _info = 'Leí la porción de ${_num(item.quantity)} $_unit y la pasé a '
            '100 $_unit. Revisa contra la etiqueta.';
      });
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final kcal = parseNum(_kcal.text);
    double? macro(TextEditingController c) =>
        c.text.trim().isEmpty ? 0 : parseNum(c.text);
    final p = macro(_protein), c = macro(_carbs), f = macro(_fat);
    final serving = _serving.text.trim().isEmpty ? null : parseNum(_serving.text);
    bool bad(double? v, double max) => v == null || v < 0 || v > max;
    if (name.isEmpty || name.length > 80) {
      setState(() => _error = 'Escribe el nombre del producto.');
      return;
    }
    if (bad(kcal, 900) || bad(p, 100) || bad(c, 100) || bad(f, 100) ||
        p! + c! + f! > 100) {
      setState(() => _error = 'Revisa los valores por 100 $_unit: calorías '
          'entre 0 y 900 y proteína + carbohidratos + grasas hasta 100 g.');
      return;
    }
    if (serving != null && (serving <= 0 || serving > 2000) ||
        _serving.text.trim().isNotEmpty && serving == null) {
      setState(() => _error = 'La porción debe estar entre 1 y 2.000 $_unit.');
      return;
    }
    final brand = _brand.text.trim();
    final product = Product(
      code: widget.code,
      name: name,
      brand: brand.isEmpty ? null : (brand.length > 40 ? brand.substring(0, 40) : brand),
      unit: _unit,
      kcal100: kcal,
      protein100: p,
      carbs100: c,
      fat100: f,
      servingQuantity: serving,
      custom: true,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(customProductRepositoryProvider).save(product);
      widget.onSaved(product);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    Widget field(TextEditingController c, String label, {String? suffix}) =>
        TextField(
          controller: c,
          keyboardType: decimal,
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.initial?.custom == true ? 'Corregir producto' : 'Crear producto',
          style: theme.textTheme.titleMedium,
        ),
        Text('Código ${widget.code}. Queda guardado en tu cuenta para la '
            'próxima vez.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _reading || _busy ? null : _readLabel,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Leer la etiqueta con una foto'),
        ),
        if (_reading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_info != null) ...[
          const SizedBox(height: 4),
          Text(_info!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        TextField(
          controller: _brand,
          decoration: const InputDecoration(labelText: 'Marca (opcional)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text('Valores por 100', style: theme.textTheme.titleSmall),
            ),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'g', label: Text('g')),
                ButtonSegment(value: 'ml', label: Text('ml')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
          ],
        ),
        field(_kcal, 'Calorías', suffix: 'kcal'),
        Row(
          children: [
            Expanded(child: field(_protein, 'Proteína', suffix: 'g')),
            const SizedBox(width: 8),
            Expanded(child: field(_carbs, 'Carbos', suffix: 'g')),
            const SizedBox(width: 8),
            Expanded(child: field(_fat, 'Grasas', suffix: 'g')),
          ],
        ),
        field(_serving, 'Porción del envase (opcional)', suffix: _unit),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _busy ? null : widget.onCancel,
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _busy || _reading ? null : _save,
                child: const Text('Guardar producto'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
