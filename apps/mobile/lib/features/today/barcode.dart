import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

/// Un producto envasado con sus nutrientes por 100 g o 100 ml.
class Product {
  const Product({
    required this.code,
    required this.name,
    this.brand,
    required this.unit,
    this.kcal100,
    this.protein100 = 0,
    this.carbs100 = 0,
    this.fat100 = 0,
    this.servingQuantity,
  });

  /// Lee la respuesta de Open Food Facts (`product`).
  factory Product.fromOpenFoodFacts(String code, Map<String, dynamic> p) {
    final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? d(Object? v) => v is num
        ? v.toDouble()
        : v is String
            ? double.tryParse(v.replaceAll(',', '.'))
            : null;
    var kcal = d(n['energy-kcal_100g']);
    final kj = d(n['energy_100g']);
    if (kcal == null && kj != null) kcal = kj / 4.184;
    String? text(String key) {
      final v = p[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final quantity = (text('quantity') ?? '').toLowerCase();
    final liquid = RegExp(r'\d\s*(ml|cl|l)\b').hasMatch(quantity);
    final serving = d(p['serving_quantity']);
    return Product(
      code: code,
      name: text('product_name_es') ?? text('product_name') ?? 'Producto $code',
      brand: text('brands')?.split(',').first.trim(),
      unit: liquid ? 'ml' : 'g',
      kcal100: kcal,
      protein100: d(n['proteins_100g']) ?? 0,
      carbs100: d(n['carbohydrates_100g']) ?? 0,
      fat100: d(n['fat_100g']) ?? 0,
      servingQuantity: serving != null && serving > 0 && serving <= 2000 ? serving : null,
    );
  }

  final String code;
  final String name;
  final String? brand;

  /// 'g' o 'ml'.
  final String unit;

  /// `null` si el producto no trae información nutricional.
  final double? kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;

  /// Porción declarada en el envase, en [unit].
  final double? servingQuantity;

  String get fullName => brand == null ? name : '$name ($brand)';

  ({double kcal, double protein, double carbs, double fat}) nutrientsFor(
      double qty) {
    final k = qty / 100;
    return (
      kcal: (kcal100 ?? 0) * k,
      protein: protein100 * k,
      carbs: carbs100 * k,
      fat: fat100 * k,
    );
  }
}

/// Solo los dígitos de un código EAN/UPC (8 a 14), o `null` si no lo es.
String? normalizeBarcode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 14 ? digits : null;
}

/// Error con un mensaje listo para mostrar.
class ProductLookupException implements Exception {
  const ProductLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ProductLookup {
  /// El producto, o `null` si no está en la base.
  Future<Product?> find(String code);
}

/// Base abierta y gratuita de productos (incluye muchos chilenos).
class OpenFoodFactsLookup implements ProductLookup {
  OpenFoodFactsLookup([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _fields = 'product_name,product_name_es,brands,quantity,'
      'serving_quantity,nutriments';

  @override
  Future<Product?> find(String code) async {
    final http.Response res;
    try {
      res = await _client
          .get(Uri.parse('https://world.openfoodfacts.org/api/v2/product/'
              '$code.json?fields=$_fields'))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const ProductLookupException(
          'No hay conexión con Open Food Facts. Revisa tu internet.');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ProductLookupException(
          'Open Food Facts no respondió (error ${res.statusCode}). Intenta de nuevo.');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final product = body['product'];
    if (body['status'] != 1 || product is! Map) return null;
    return Product.fromOpenFoodFacts(code, product.cast<String, dynamic>());
  }
}

/// Abre la cámara y devuelve el código leído, o `null` si se cancela.
typedef BarcodeScanFn = Future<String?> Function(BuildContext context);

Future<String?> scanWithCamera(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ScanPage(),
    ));

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = normalizeBarcode(b.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo abrir la cámara aquí. Cierra esta pantalla y '
                  'escribe los números del código.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Apunta al código de barras del envase.'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
