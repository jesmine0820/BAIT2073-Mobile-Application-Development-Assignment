import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Enums for delivery note and issue reporting
enum DeliveryNote { guardhouse, door }
enum ReportIssue { damage, delay, security }

// Extensions for user-friendly labels
extension DeliveryNotes on DeliveryNote {
  String get label => switch (this) {
    DeliveryNote.guardhouse => 'Leave at guardhouse',
    DeliveryNote.door => 'Leave at door',
  };
}

extension ReportIssues on ReportIssue {
  String get label => switch (this) {
    ReportIssue.damage => 'Damaged Parts',
    ReportIssue.delay => 'Traffic Delay',
    ReportIssue.security => 'Security Issue',
  };
}

// ProofOfDelivery model
class ProofOfDelivery {
  final String podID;
  final String deliveryID;
  final String signature;
  final List<String> pictureUrl;
  final String deliveryNote;
  final String remark;
  final String issue;
  final String evidenceUrl;
  final DateTime createdAt;

  ProofOfDelivery({
    required this.podID,
    required this.deliveryID,
    required this.signature,
    required this.pictureUrl,
    required this.deliveryNote,
    required this.remark,
    required this.issue,
    required this.evidenceUrl,
    required this.createdAt
  });

  // Factory constructor to create from Firestore map (null safe)
  factory ProofOfDelivery.fromMap(Map<String, dynamic> map) => ProofOfDelivery(
    podID: map['podID'] ?? '',
    deliveryID: map['deliveryID'] ?? '',
    signature: map['signature'] ?? '',
    pictureUrl: List<String>.from(map['picture'] ?? []),
    deliveryNote: map['deliveryNote'] ?? '',
    remark: map['remark'] ?? '',
    issue: map['issue'] ?? '',
    evidenceUrl: map['evidenceUrl'] ?? '',
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  // Convert to Firestore map
  Map<String, dynamic> toMap() => {
    'podID': podID,
    'deliveryID': deliveryID,
    'signature': signature,
    'picture': pictureUrl,
    'deliveryNote': deliveryNote,
    'remark': remark,
    'issue': issue,
    'evidenceUrl': evidenceUrl,
    'createdAt': createdAt
  };
}
