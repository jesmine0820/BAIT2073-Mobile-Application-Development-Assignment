// lib/models/spare_part.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SparePart {
  final String id;                    // Firestore doc-id
  final String name;                  // spare part name
  final int amount;                   // quantity in stock
  final String barcode;               // barcode value

  // Keep only specifications (if you still want structured details)
  final Map<String, String> specifications; // key -> value map for specs

  const SparePart({
    required this.id,
    required this.name,
    required this.amount,
    required this.barcode,
    this.specifications = const {},
  });

  String get spID => id;

  // ---------- Firestore <--> Dart ----------

  factory SparePart.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final rawSpecs = data['specifications'];
    final specs = <String, String>{};
    if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) {
        final key = k?.toString() ?? '';
        if (key.isNotEmpty) specs[key] = v?.toString() ?? '';
      });
    }

    return SparePart(
      id: doc.id,
      name: data['spare_part_name'] ?? '',
      amount: (data['amount'] ?? 0) is int
          ? (data['amount'] as int)
          : int.tryParse((data['amount'] ?? '0').toString()) ?? 0,
      barcode: data['barcode_value'] ?? '',
      specifications: specs,
    );
  }

  Map<String, dynamic> toMap() => {
    'spare_part_name': name,
    'amount': amount,
    'barcode_value': barcode,
    'specifications': specifications,
  };

  // ---------- helpers ----------

  SparePart copyWith({
    String? id,
    String? name,
    int? amount,
    String? barcode,
    Map<String, String>? specifications,
  }) {
    return SparePart(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      barcode: barcode ?? this.barcode,
      specifications: specifications ?? this.specifications,
    );
  }
}
