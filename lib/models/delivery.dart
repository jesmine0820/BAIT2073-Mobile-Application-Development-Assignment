// lib/models/delivery.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus { pending, pickedUp, enRoute, delivered }

extension DeliveryStatusX on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.pending => 'PENDING',
    DeliveryStatus.pickedUp => 'PICKED UP',
    DeliveryStatus.enRoute => 'EN-ROUTE',
    DeliveryStatus.delivered => 'DELIVERED',
  };

  Color get color => switch (this) {
    DeliveryStatus.pending => Colors.red,
    DeliveryStatus.pickedUp => Colors.blue,
    DeliveryStatus.enRoute => Colors.orange,
    DeliveryStatus.delivered => Colors.green,
  };
}

// ───────────────────────────────────────────────
//  MODEL
// ───────────────────────────────────────────────

class Delivery {
  final String id; // Firestore doc-id
  final String spID; // "SP001"
  final String destination;
  final DateTime requiredTime;
  final DeliveryStatus status;

  // NEW FIELDS
  final String? contactPerson;
  final String? contactNumber;

  const Delivery({
    required this.id,
    required this.spID,
    required this.destination,
    required this.requiredTime,
    this.status = DeliveryStatus.pending,
    this.contactPerson,
    this.contactNumber
  });

  // ---------- Firestore <--> Dart ----------

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Delivery(
      id: doc.id,
      spID: _extractSpID(d['spID']),
      destination: d['destination'] ?? '',
      requiredTime: _asDate(d['requiredTime']),
      status: DeliveryStatus.values.firstWhere(
            (e) => e.name == (d['status'] ?? 'pending'),
        orElse: () => DeliveryStatus.pending,
      ),
      contactPerson: d['contactPerson'],
      contactNumber: d['contactNumber']
    );
  }

  Map<String, dynamic> toMap() => {
    'spID': spID,
    'destination': destination,
    'requiredTime': Timestamp.fromDate(requiredTime),
    'status': status.name,
    'contactPerson': contactPerson,
    'contactNumber': contactNumber
  };

  // ---------- helpers ----------

  static String _extractSpID(dynamic ref) {
    if (ref is DocumentReference) return ref.id;
    if (ref is String && ref.contains('/')) {
      return ref.split('/').last;
    }
    return ref?.toString() ?? '';
  }

  static DateTime _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}
