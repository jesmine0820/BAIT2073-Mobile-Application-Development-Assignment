import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery.dart';
import '../models/spare_part.dart';
import '../models/pod.dart';

// ---------------------------------------------------------------------------
// Generic Firestore repository that we can reuse for any model.
// ---------------------------------------------------------------------------
typedef FromDoc<T> = T Function(DocumentSnapshot<Map<String, dynamic>> doc);
typedef ToMap<T> = Map<String, dynamic> Function(T model);

class FirestoreRepo<T> {
  FirestoreRepo(
      this._path, {
        required this.fromDoc,
        required this.toMap,
      }) : _col = FirebaseFirestore.instance.collection(_path);

  final String _path;
  final FromDoc<T> fromDoc;
  final ToMap<T> toMap;
  final CollectionReference<Map<String, dynamic>> _col;

  // ────────────────────────────────────────────
  // Real-time stream of every doc in the collection
  // ────────────────────────────────────────────
  Stream<List<T>> stream() =>
      _col.snapshots().map((s) => s.docs.map(fromDoc).toList());

  // One-shot read of the whole collection
  Future<List<T>> all() async =>
      (await _col.get()).docs.map(fromDoc).toList();

  Future<T?> get(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? fromDoc(doc) : null;
  }

  /// Creates a new doc when [id] is null, otherwise upserts the doc.
  Future<void> save(T model, {String? id}) async {
    final data = toMap(model);
    if (id == null) {
      await _col.add(data);
    } else {
      await _col.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Stream<T?> watch(String id) =>
      _col.doc(id).snapshots().map(
            (s) => s.exists ? fromDoc(s) : null,
      );

  /// Partial update (merge)
  Future<void> patch(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  /// Increment a numeric field (safe stock adjustment, counters, etc.)
  Future<void> increment(String id, String field, num by) =>
      _col.doc(id).update({field: FieldValue.increment(by)});

  /// Update a timestamp field
  Future<void> updateTimestamp(String id, String field, DateTime time) =>
      _col.doc(id).update({field: Timestamp.fromDate(time)});

  Future<void> delete(String id) => _col.doc(id).delete();
}

// ─────────────────────────────────────────────────────────────────────────────
// ID helpers: generate next "D###" (and generic prefix) based on existing docs
// ─────────────────────────────────────────────────────────────────────────────
Future<String> _nextPrefixedId({
  required String collection,
  required String prefix,
  int pad = 3,
}) async {
  final col = FirebaseFirestore.instance.collection(collection);

  // Fetch only IDs that start with the prefix (e.g. "D")
  // NOTE: Firestore can't "startsWith" on documentId directly without an index,
  // so we just read IDs client-side and filter; OK for small/medium collections.
  final snap = await col.get();
  int maxNum = 0;

  for (final d in snap.docs) {
    final id = d.id;        // e.g. "D012"
    if (id.startsWith(prefix)) {
      final numStr = id.substring(prefix.length); // "012"
      final n = int.tryParse(numStr) ?? 0;
      if (n > maxNum) maxNum = n;
    }
  }

  final next = maxNum + 1;
  return '$prefix${next.toString().padLeft(pad, '0')}';
}

/// Public helper for deliveries: returns "D001", "D002", ...
Future<String> nextDeliveryId() =>
    _nextPrefixedId(collection: 'delivery', prefix: 'D', pad: 3);


// ---------------------------------------------------------------------------
// Concrete repositories – use these directly in widgets / services.
// ---------------------------------------------------------------------------

final deliveries = FirestoreRepo<Delivery>(
  'delivery',
  fromDoc: Delivery.fromDoc,
  toMap: (d) => d.toMap(),
);

/// Convenience helper: update delivery status
Future<void> updateDeliveryStatus(String id, DeliveryStatus status) =>
    deliveries.patch(id, {'status': status.name});

/// Convenience helper: update delivery required time
Future<void> updateDeliveryRequiredTime(String id, DateTime newTime) =>
    deliveries.updateTimestamp(id, 'requiredTime', newTime);

/// Convenience helper: update contact person
Future<void> updateDeliveryContactPerson(String id, String? person) =>
    deliveries.patch(id, {'contactPerson': person});

/// Convenience helper: update contact number
Future<void> updateDeliveryContactNumber(String id, String? number) =>
    deliveries.patch(id, {'contactNumber': number});

// ---------------------------------------------------------------------------
// Spare Parts
// ---------------------------------------------------------------------------

final spareParts = FirestoreRepo<SparePart>(
  'spare_part',
  fromDoc: SparePart.fromDoc,
  toMap: (s) => s.toMap(),
);

/// Convenience helper: set spare part stock
Future<void> updateSparePartAmount(String id, int newAmount) =>
    spareParts.patch(id, {'amount': newAmount});

/// Convenience helper: increment spare part stock
Future<void> incrementSparePartStock(String id, int increment) =>
    spareParts.increment(id, 'amount', increment);

// ---------------------------------------------------------------------------
// PODs
// ---------------------------------------------------------------------------

final pods = FirestoreRepo<ProofOfDelivery>(
  'pod',
  fromDoc: (doc) =>
      ProofOfDelivery.fromMap({'podID': doc.id, ...doc.data() ?? {}}),
  toMap: (p) => p.toMap(),
);
