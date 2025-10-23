import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/delivery.dart';
import '../models/spare_part.dart';
import '../models/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SparePartDetailsPage extends StatefulWidget {
  const SparePartDetailsPage({
    super.key,
    required this.deliveryId,
    required this.spID,
  });

  final String deliveryId;
  final String spID;

  @override
  State<SparePartDetailsPage> createState() => _SparePartDetailsPageState();
}

class _SparePartDetailsPageState extends State<SparePartDetailsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Delivery?>(
      stream: deliveries.watch(widget.deliveryId),
      builder: (context, dSnap) {
        final delivery = dSnap.data;
        return StreamBuilder<SparePart?>(
          stream: spareParts.watch(widget.spID),
          builder: (context, spSnap) {
            final part = spSnap.data;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Spare Part Details'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareDetails(delivery, part),
                    tooltip: 'Share Details',
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () => _refreshData(),
                child: _buildContent(delivery, part),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(Delivery? delivery, SparePart? part) {
    if (delivery == null && part == null && !_isLoading) {
      return _buildErrorState();
    }

    final partName = part?.name ?? widget.spID;
    final amount = part?.amount ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with logo
            Center(
              child: Image.asset('assets/images/gs_icon.webp', height: 50),
            ),
            const SizedBox(height: 24),

            // Stock warning if applicable
            _stockWarning(amount),
            const SizedBox(height: 16),

            // Delivery information
            _sectionTitle('Delivery Information'),
            const SizedBox(height: 12),
            _section(
              children: [
                _kv(
                  Icons.receipt_long,
                  'Order ID',
                  delivery?.id ?? widget.deliveryId,
                ),
                _kv(
                  Icons.flag,
                  'Delivery Status',
                  delivery?.status.label ?? 'PENDING',
                ),
                _kv(Icons.place, 'Delivery To', delivery?.destination ?? '-'),
                _kv(
                  Icons.access_time,
                  'Required Date',
                  _formatDate(delivery?.requiredTime),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Contact section
            _contactSection(delivery),

            const SizedBox(height: 24),

            // Spare parts details
            _sectionTitle('Spare Parts Details'),
            const SizedBox(height: 12),
            _section(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount in stock',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: amount > 5
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'x$amount',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: amount > 5
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _cancelTile(context, amount),
              ],
            ),

            const SizedBox(height: 24),

            // Part specifications (if available)
            _partSpecifications(part),

            const SizedBox(height: 24),

            // Action buttons
            _actionButtons(context, part, delivery),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Unable to load data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _stockWarning(int amount) {
    if (amount > 5) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amount == 0 ? Colors.red.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: amount == 0 ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            amount == 0 ? Icons.error : Icons.warning,
            color: amount == 0 ? Colors.red.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              amount == 0
                  ? 'Out of Stock - Immediate restock required!'
                  : 'Low Stock Alert: Only $amount remaining',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: amount == 0
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactSection(Delivery? delivery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Communication'),
        const SizedBox(height: 12),
        _section(
          children: [
            _kv(Icons.person, 'Contact Person', delivery?.contactPerson ?? '-'),
            _kv(Icons.phone, 'Phone Number', delivery?.contactNumber ?? '-'),
          ],
        ),
      ],
    );
  }

  Widget _partSpecifications(SparePart? part) {
    if (part == null || part.specifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Specifications'),
        const SizedBox(height: 12),
        _section(
          children: part.specifications.entries
              .map((entry) => _kv(Icons.info_outline, entry.key, entry.value))
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _actionButtons(
    BuildContext context,
    SparePart? part,
    Delivery? delivery,
  ) {
    return Column(
      children: [
        // Contact and Reschedule Actions
        Row(
          children: [
            Expanded(
              child: _actionCard('Contact', Icons.phone, () {
                if (delivery != null) {
                  _showContactDialog(context, delivery);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No delivery data available")),
                  );
                }
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard('Reschedule', Icons.schedule, () {
                if (delivery != null) {
                  _rescheduleDelivery(context, delivery);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No delivery data available")),
                  );
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Primary Restock Action - Big Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.inventory, color: Colors.white, size: 24),
            label: const Text(
              'RESTOCK SPARE PART',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _showRestockDialog(context, part?.amount ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('BACK TO DASHBOARD'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelTile(BuildContext context, int amount) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.cancel_outlined, color: Colors.red.shade600),
      title: const Text(
        'Cancel Delivery',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('Deletes the delivery if there is no more stock'),
      onTap: () async {
        final ok = await _confirm(context, 'Confirm Cancel Order?');
        if (ok != true) return;

        // Only allow cancel if no stock left
        final part = await spareParts.get(widget.spID);
        if ((part?.amount ?? 0) <= 0) {
          await deliveries.delete(widget.deliveryId);
          if (context.mounted) {
            // Go straight back to the first route (Dashboard / main.dart home)
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot cancel: $amount still in stock.')),
            );
          }
        }
      },
    );
  }

  // ---------- Action Methods ----------

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      // Simulate refresh delay
      await Future.delayed(const Duration(milliseconds: 500));
      // In real app: await Future.wait([...])
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareDetails(Delivery? delivery, SparePart? part) {
    final details =
        '''
Spare Part Details:
- Name: ${part?.name ?? 'Unknown'}
- Stock: ${part?.amount ?? 0}
- Delivery ID: ${delivery?.id ?? widget.deliveryId}
- Status: ${delivery?.status.label ?? 'Unknown'}
- Destination: ${delivery?.destination ?? 'Unknown'}
    ''';

    // In real app, use share_plus package
    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Details copied to clipboard')),
    );
  }

  void _showContactDialog(BuildContext context, Delivery delivery) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Contact Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.phone, color: Colors.white, size: 20),
              ),
              title: const Text('Call'),
              subtitle: Text(delivery.contactNumber ?? 'N/A'),
              onTap: () {
                Navigator.pop(ctx);
                if (delivery.contactNumber != null) {
                  _makePhoneCall(delivery.contactNumber!);
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.message, color: Colors.white, size: 20),
              ),
              title: const Text('SMS'),
              subtitle: const Text('Send text message'),
              onTap: () {
                Navigator.pop(ctx);
                if (delivery.contactNumber != null) {
                  _sendSMS(delivery.contactNumber!);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch dialer for $phoneNumber");
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'sms', path: phoneNumber);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch SMS app for $phoneNumber");
    }
  }

  void _showRestockDialog(BuildContext context, int currentStock) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restock Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to restock',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_box),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Current stock: $currentStock',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty > 0) {
                _requestRestock(qty);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                  ),
                );
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _requestRestock(int quantity) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restock request sent for $quantity units')),
    );
  }

  void _rescheduleDelivery(BuildContext context, Delivery? delivery) async {
    if (delivery == null) return;

    final newDate = await showDatePicker(
      context: context,
      initialDate: delivery.requiredTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null) return; // user canceled

    final deliveryRef = FirebaseFirestore.instance
        .collection('delivery')
        .doc(delivery.id);

    try {
      // 🔹 Update requiredTime in Firestore (only deliveries collection)
      await deliveryRef.update({
        'requiredTime': Timestamp.fromDate(newDate),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery rescheduled to ${_formatDate(newDate)}'),
          ),
        );

        // 🔹 If you’re keeping Delivery in state, call setState
        setState(() {
          // replace old delivery with updated one
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating delivery: $e')),
        );
      }
    }
  }



  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool?> _confirm(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'YES',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'NO',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
