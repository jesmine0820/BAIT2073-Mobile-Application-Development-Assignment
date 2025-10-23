import 'dart:math' as math; // ↓ new
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/firebase_service.dart';
import 'models/delivery.dart';
import 'models/spare_part.dart';
import '../delivery_details.dart';

void main() async {
  //TODO - Insert initialisation of Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Dashboard',
    theme: ThemeData(useMaterial3: true),
    home: const DashboardPage(),
  );
}

// ───────────────────────────────────────────────
// DASHBOARD
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _svc = deliveries;
  final _search = TextEditingController();
  bool _ascending = true; // ↓ new

  /// Opens a bottom sheet that allows the user to create a new delivery
  /// document. The sheet collects a spare part, destination and required
  /// date. Upon submission a new Delivery is saved to Firestore via the
  /// `deliveries` repository.
  void _openAddDeliverySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selectedSpId;
        String destination = '';
        DateTime? selectedDate;
        String contactPerson = '';
        String contactNumber = '';

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dropdown to choose a spare part
                    FutureBuilder<List<SparePart>>(
                      future: spareParts.all(),
                      builder: (context, spSnap) {
                        final parts = spSnap.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: selectedSpId,
                          decoration: const InputDecoration(
                            labelText: 'Spare Part',
                            border: OutlineInputBorder(),
                          ),
                          items: parts
                              .map(
                                (sp) => DropdownMenuItem(
                                  value: sp.id,
                                  child: Text(sp.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setSheetState(() => selectedSpId = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Destination text input
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => destination = val,
                    ),
                    const SizedBox(height: 12),

                    // Contact Person input
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => contactPerson = val,
                    ),
                    const SizedBox(height: 12),

                    // Contact Number input
                    TextField(
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => contactNumber = val,
                    ),
                    const SizedBox(height: 12),

                    // Date picker button
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      child: Text(
                        selectedDate == null
                            ? 'Select required date'
                            : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedSpId != null &&
                              destination.trim().isNotEmpty &&
                              contactPerson.trim().isNotEmpty &&
                              contactNumber.trim().isNotEmpty &&
                              selectedDate != null) {
                            final newId = await nextDeliveryId();
                            final newDelivery = Delivery(
                              id: newId,
                              spID: selectedSpId!,
                              destination: destination.trim(),
                              requiredTime: selectedDate!,
                              status: DeliveryStatus.pending,
                              contactPerson: contactPerson.trim(),
                              contactNumber: contactNumber.trim(),
                            );
                            await deliveries.save(newDelivery, id: newId);
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Delivery>>(
    stream: _svc.stream(),
    builder: (ctx, snap) {
      final list = snap.data ?? [];

      final searchLower = _search.text.toLowerCase();
      final filtered = list
          .where(
            (d) => d.spID.toLowerCase().contains(searchLower) ||
                   d.destination.toLowerCase().contains(searchLower) ||
                   d.contactPerson!.toLowerCase().contains(searchLower) ||
                   d.contactNumber!.contains(searchLower),
          )
          .toList();

      // ↓ sort by requiredTime
      final sorted = [...filtered]
        ..sort(
          (a, b) => _ascending
              ? a.requiredTime.compareTo(b.requiredTime)
              : b.requiredTime.compareTo(a.requiredTime),
        );

      int cnt(DeliveryStatus s) => list.where((d) => d.status == s).length;

      return Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: BottomAppBar(
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.home_outlined),
                Text('Dashboard', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // header block
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
                      width: double.infinity,
                      color: const Color(0xFF0B3F82),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Dashboard",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _Stat(
                                cnt(DeliveryStatus.pickedUp),
                                DeliveryStatus.pickedUp.label,
                              ),
                              _Stat(
                                cnt(DeliveryStatus.enRoute),
                                DeliveryStatus.enRoute.label,
                              ),
                              _Stat(
                                cnt(DeliveryStatus.delivered),
                                DeliveryStatus.delivered.label,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // search bar
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // logo
                    Positioned(
                      top: 8,
                      child: Image.asset(
                        'assets/images/gs_icon.webp',
                        height: 55,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // catalog
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'Delivery Catalog',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Button to add a new delivery entry
                      IconButton(
                        onPressed: _openAddDeliverySheet,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add delivery',
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _ascending = !_ascending),
                        icon: Transform.rotate(
                          angle: _ascending ? 0 : math.pi,
                          child: const Icon(Icons.swap_vert),
                        ),
                        tooltip: 'Sort by date',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  // ↓ uses sorted
                  separatorBuilder: (_, __) =>
                      const Divider(indent: 72, endIndent: 20),
                  itemBuilder: (_, i) => _DeliveryTile(sorted[i]),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ───────────────────────────────────────────────
// SMALL HELPERS
class _Stat extends StatelessWidget {
  const _Stat(this.count, this.label, {super.key});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile(this.d, {super.key});

  final Delivery d;

  Future<String> _fetchSparePartName() async {
    final part = await spareParts.get(d.spID);
    return part?.name ?? 'Unnamed Part';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _fetchSparePartName(),
    builder: (ctx, snap) {
      final name = snap.data ?? 'Loading…';
      return ListTile(
        leading: const Icon(Icons.settings, size: 32),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Required by: ${d.requiredTime.toLocal().toString().split(' ').first}\n'
          'Destination: ${d.destination}',
        ),
        trailing: Text(
          d.status.label,
          style: TextStyle(color: d.status.color, fontWeight: FontWeight.w700),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryDetailsPage(deliveryId: d.id),
          ),
        ),
      );
    },
  );
}
