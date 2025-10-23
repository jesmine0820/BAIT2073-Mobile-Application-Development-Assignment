import 'package:development/pod_details.dart';
import 'package:development/spare_parts_details.dart';
import 'package:flutter/material.dart';
import '../models/firebase_service.dart';
import '../models/delivery.dart';
import '../models/spare_part.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_confirmation_form.dart';

class DeliveryDetailsPage extends StatefulWidget {
  const DeliveryDetailsPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<DeliveryDetailsPage> createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage>
    with WidgetsBindingObserver {
  MobileScannerController? _scannerController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Delivery?>(
      stream: deliveries.watch(widget.deliveryId),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final d = snap.data!;

        return FutureBuilder<SparePart?>(
          future: spareParts.get(d.spID),
          builder: (ctx, partSnap) {
            final partName = partSnap.data?.name ?? d.spID;

            return Scaffold(
              appBar: AppBar(title: const Text('Delivery')),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company logo
                      Center(
                        child: Image.asset(
                          'assets/images/gs_icon.webp',
                          height: 50,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress section header
                      Text(
                        'Delivery Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Custom progress indicator widget
                      _deliveryProgress(d),
                      const SizedBox(height: 32),

                      // Details section listing part, destination and date
                      _detailsSection(partName, d),

                      const SizedBox(height: 48),
                      // Action button to transition to the next state or close
                      _buildButtons(d),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── header (part + status) ────────────────────────────────────────────────
  Widget _deliveryHeader(String partName, Delivery d) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.settings, size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(d.destination, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
      Text(
        d.status.name.toUpperCase(),
        style: TextStyle(color: d.status.color, fontWeight: FontWeight.w700),
      ),
    ],
  );

  // ── label/value row ───────────────────────────────────────────────────────
Widget _labelValue(
  String label,
  String value, {
  required IconData icon,
  VoidCallback? onTap,
  bool isDestination = false, // New parameter to identify destination field
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              if (isDestination && onTap != null)
                // Enhanced UI for clickable destination: Use InkWell for ripple effect,
                // added subtle shadow, softer colors, better padding for mobile touch,
                // and ensured responsive text wrapping for smaller screens.
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.blue.withOpacity(0.2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Increased padding for better touch target
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05), // Softer background for elegance
                      borderRadius: BorderRadius.circular(12), // Softer corners
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ], // Subtle shadow for depth, matching app's shadow styles
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded( // Use Expanded for better responsiveness on mobile
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Colors.blueAccent, // Slightly deeper blue for better contrast
                              fontWeight: FontWeight.w500,
                              fontSize: 14, // Slightly larger font for readability on mobile
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3, // Allow more lines for longer addresses
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.map_rounded, // Rounded icon for modern look
                          size: 18, // Slightly larger for visibility
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                )
              else if (onTap != null)
                // Standard clickable text for other fields
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                )
              else
                // Non-clickable text
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ── delivery progress indicator ───────────────────────────────────────────
  Widget _deliveryProgress(Delivery d) {
    final int currentIndex = _statusIndex(d.status);
    // Define colours for each step. These colours loosely match the
    // reference design: green for picked up, purple for en‑route, grey for
    // delivered. Note that the delivered colour will be overridden for the
    // final state if necessary.
    final List<Color> stepColours = [
      const Color(0xFF42A5F5), // sky blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFF22C55E), // green
    ];
    final List<IconData> stepIcons = [
      Icons.inventory_2, // picked up
      Icons.local_shipping, // en route
      Icons.domain, // delivered
    ];
    final List<String> stepTitles = const [
      'Picked Up',
      'En Route',
      'Delivered',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 3; i++) ...[
            _stepItem(
              i,
              currentIndex,
              stepIcons[i],
              stepTitles[i],
              stepColours,
            ),
            if (i < 2) _buildConnector(i, currentIndex, stepColours),
          ],
        ],
      ),
    );
  }

  Widget _stepItem(
    int index,
    int currentIndex,
    IconData icon,
    String title,
    List<Color> colours,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepIcon(index, currentIndex, icon, colours),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Builds the circular icon for a single step in the progress indicator.
  ///
  /// * When [currentIndex] >= [index], the step is considered complete and
  ///   draws its coloured background with a white icon.
  /// * When [currentIndex] + 1 == [index], the step is upcoming and draws
  ///   a coloured border with a white background and coloured icon.
  /// * Otherwise the step is inactive and draws a grey border with a grey
  ///   icon.
  Widget _buildStepIcon(
    int index,
    int currentIndex,
    IconData icon,
    List<Color> colours,
  ) {
    Color fillColor;
    Color borderColor;
    Color iconColor;
    if (currentIndex >= index) {
      fillColor = colours[index];
      borderColor = colours[index];
      iconColor = Colors.white;
    } else if (currentIndex + 1 == index) {
      fillColor = Colors.white;
      borderColor = colours[index];
      iconColor = colours[index];
    } else {
      fillColor = Colors.white;
      borderColor = Colors.grey.shade300;
      iconColor = Colors.grey.shade400;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  /// Builds a dotted connector between two steps. The connector colour is
  /// derived from the colour of the step it points to if the connection has
  /// been traversed; otherwise it is grey. The dotted appearance is
  /// achieved by drawing a row of small circles evenly spaced along a
  /// horizontal container.
  Widget _buildConnector(
    int connectorIndex,
    int currentIndex,
    List<Color> colours,
  ) {
    // Determine the colour for this connector. If the current index is
    // greater than the connector index (meaning the user has moved past
    // this connector), use the colour of the next step; otherwise use
    // a light grey to indicate inactivity.
    final Color colour = currentIndex >= connectorIndex + 1
        ? colours[connectorIndex + 1]
        : Colors.grey.shade300;
    return Container(
      width: 50,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          6,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  /// Converts a [DeliveryStatus] to its corresponding index used by the
  /// progress indicator. Pending deliveries return -1 so that no steps are
  /// marked complete. Picked up -> 0, en route -> 1 and delivered -> 2.
  int _statusIndex(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pickedUp:
        return 0;
      case DeliveryStatus.enRoute:
        return 1;
      case DeliveryStatus.delivered:
        return 2;
      default:
        return -1;
    }
  }

  // ── details section ───────────────────────────────────────────────────────
  Widget _detailsSection(String partName, Delivery d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _labelValue(
                'Assigned Parts',
                partName,
                icon: Icons.settings,
                onTap: d.status == DeliveryStatus.pending
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SparePartDetailsPage(
                              deliveryId: d.id,
                              spID: d.spID,
                            ),
                          ),
                        );
                      }
                    : null, // not clickable when NOT pending
              ),
              _labelValue(
                'Destination', 
                d.destination, 
                icon: Icons.place,
                onTap: d.status != DeliveryStatus.pending
                    ? () => _openInGoogleMaps(d.destination)
                    : null,
                isDestination: true,
              ),
              _labelValue(
                'Required By',
                '${d.requiredTime.day}/${d.requiredTime.month}/${d.requiredTime.year}',
                icon: Icons.schedule,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── gradient button ──────────────────────────────────────────────────────
  Widget _gradientButton(
    String text,
    Color startColor,
    Color endColor,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [startColor, endColor]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _openInGoogleMaps(String destination) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destination)}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }
  // ── confirmation dialog ───────────────────────────────────────────────────
  /// Displays a modal asking the user to confirm a status change. The
  /// returned Future resolves to true if the user chooses 'Yes', or
  /// false/null if the user cancels the action. The visual design
  /// mirrors the reference with a white panel, rounded corners and two
  /// coloured buttons.
  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'NO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'YES',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── barcode scanner dialog ───────────────────────────────────────────────
  Future<String?> _showBarcodeScannerDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Barcode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please scan the barcode on the package to verify pickup',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Position camera over barcode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Align the barcode within the frame',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _showScannerView();
                  },
                  child: const Text(
                    'Start Scanning',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showManualEntryDialog();
                  },
                  child: const Text(
                    'Enter code manually',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── scanner view ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
  }

  @override
  void dispose() {
    _scannerController?.stop(); // Stop camera to release buffers
    _scannerController?.dispose(); // Dispose controller to clear resources
    _scannerController = null;
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scannerController == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _scannerController?.stop(); // Stop camera to release buffers
    } else if (state == AppLifecycleState.resumed) {
      _scannerController?.start(); // Restart camera safely
    }
  }

  void _showScannerView() {
    Navigator.of(context).pop(); // Close the initial dialog
    bool isScanning = false;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates, // Minimize buffer usage
      facing: CameraFacing.back,
      autoStart: true,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Barcode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _scannerController?.stop(); // Stop camera to release buffers
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (BarcodeCapture capture) async {
                    if (isScanning) return;
                    isScanning = true;

                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String code = barcodes.first.rawValue ?? '';
                      _scannerController?.stop(); // Stop camera to release buffers
                      Navigator.of(context).pop(); // Close scanner
                      await _verifyBarcodeAndUpdateStatus(code);
                    }

                    await Future.delayed(const Duration(seconds: 2));
                    isScanning = false;
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _scannerController?.stop(); // Ensure camera stops
      _scannerController?.dispose(); // Ensure buffers are released
      _scannerController = null;
    });
  }

  // ── verify barcode against database ───────────────────────────────────
  Future<void> _verifyBarcodeAndUpdateStatus(String scannedCode) async {
    try {
      // First get the delivery to find the spare part ID
      final delivery = await deliveries.get(widget.deliveryId);
      if (delivery == null) {
        _showErrorDialog('Could not find delivery information.');
        return;
      }

      // Get the spare part using the spare part ID from the delivery
      final sparePart = await spareParts.get(delivery.spID);

      if (sparePart == null) {
        // Spare part not found
        _showErrorDialog(
          'Could not find spare part information for ID: ${delivery.spID}',
        );
        return;
      }

      if (sparePart.barcode.isEmpty) {
        // Barcode is missing in the database
        _showErrorDialog(
          'The spare part does not have a barcode registered in the system.',
        );
        return;
      }

      if (sparePart.barcode == scannedCode) {
        // Barcode matches - show success dialog
        _showSuccessDialog(scannedCode);
      } else {
        // Barcode doesn't match - show error dialog
        _showErrorDialog(
          'The scanned barcode "$scannedCode" does not match for this part.',
        );
      }
    } catch (e) {
      // Error occurred during verification
      _showErrorDialog('An error occurred while verifying the barcode: $e');
    }
  }

  // ── error dialog ───────────────────────────────────────────────────────
  Future<void> _showErrorDialog(String errorMessage) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showBarcodeScannerDialog(); // Try again
                  },
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── manual entry dialog ───────────────────────────────────────────────────
  Future<void> _showManualEntryDialog() async {
    final TextEditingController codeController = TextEditingController();

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enter Code Manually',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please enter the barcode number from the package',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Barcode Number',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        hintText: 'Enter 12 digit code',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (codeController.text.isNotEmpty) {
                      Navigator.of(context).pop(codeController.text);
                    }
                  },
                  child: const Text(
                    'Submit Barcode Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showBarcodeScannerDialog();
                  },
                  child: const Text(
                    'Try scanning again',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Exit',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Verify the manually entered barcode against the database
      await _verifyBarcodeAndUpdateStatus(result);
    }
  }

  // ── success dialog ───────────────────────────────────────────────────────
  Future<void> _showSuccessDialog(String code) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Code Verified Successfully!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Verified At',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Today, ${DateTime.now().hour}:${DateTime.now().minute} PM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      // Update the delivery status
      final delivery = await deliveries.get(widget.deliveryId);
      if (delivery != null) {
        await _setStatus(delivery, DeliveryStatus.pickedUp);
      }
    }
  }

  // ── status-change buttons ────────────────────────────────────────────────
  Widget _buildButtons(Delivery d) {
    // Choose the appropriate button label and colours based on the current
    // delivery status. When the status is pending, the next action is
    // "Pick Up"; when picked up the next action is "En‑route"; when en
    // route the next action is "Delivered". After delivery the button
    // simply closes the page.
    switch (d.status) {
      case DeliveryStatus.pending:
        return _gradientButton(
          'Pick Up',
          const Color(0xFF1E88E5), // blue start
          const Color(0xFF42A5F5), // blue end
          () async {
            await _showBarcodeScannerDialog();
          },
        );
      case DeliveryStatus.pickedUp:
        return _gradientButton(
          'En‑route',
          const Color(0xFFFB8C00), // orange start
          const Color(0xFFFFB74D), // orange end
          () async {
            final confirmed = await _showConfirmationDialog();
            if (confirmed == true) {
              await _setStatus(d, DeliveryStatus.enRoute);
            }
          },
        );
      case DeliveryStatus.enRoute:
        return _gradientButton(
          'Delivered',
          const Color(0xFF2CA58D), // green start
          const Color(0xFF66BB6A), // green end
          () async {
            final confirmed = await _showConfirmationDialog();
            if (confirmed == true) {
              await _setStatus(d, DeliveryStatus.delivered);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DeliveryConfirmationFormPage(delivery: d),
                ),
              );
            }
          },
        );
      case DeliveryStatus.delivered:
        // When already delivered, close the page on tap without a
        // confirmation.
        return _gradientButton(
          'Proof Of Delivery',
          const Color(0xFF2CA58D),
          const Color(0xFF66BB6A),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProofOfDeliveryPage(delivery: d),
              ),
            );
          },
        );
    }
  }

  // NOTE: The original _actionBtn helper remains in the file for
  // compatibility but is no longer used in the redesigned layout.

  Widget _actionBtn(String text, Color color, VoidCallback onPressed) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white)),
      );

  Future<void> _setStatus(Delivery d, DeliveryStatus s) =>
      deliveries.patch(d.id, {'status': s.name});
}
