import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../models/spare_part.dart';
import '../models/firebase_service.dart';
import '../models/pod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProofOfDeliveryPage extends StatelessWidget {
  final Delivery delivery;

  /// Safely convert common Firestore/time types to DateTime.
  DateTime _toDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }


  const ProofOfDeliveryPage({
    super.key,
    required this.delivery,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proof of Delivery"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data found'));
          }

          final data = snapshot.data!;
          final pod = data['pod'] as ProofOfDelivery?;
          final sparePart = data['sparePart'] as SparePart?;

          return _buildReceiptContent(pod, delivery, sparePart, context);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final allPods = await pods.all();
    final ProofOfDelivery? pod =
    allPods.firstWhereOrNull((p) => p.deliveryID == delivery.id);
    final sparePart = await spareParts.get(delivery.spID);
    return {'pod': pod, 'sparePart': sparePart};
  }

  Widget _buildReceiptContent(
      ProofOfDelivery? pod, Delivery delivery, SparePart? sparePart, BuildContext context) {

    final formattedDate =
    DateFormat("dd/MM/yyyy HH:mm").format(_toDateTime(pod?.createdAt));



    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(2, 2),
            )
          ],
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 10),
                  const Text(
                    "DELIVERED",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 6),
                  Text("Delivered at: $formattedDate",
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 1),

            // Delivery details
            _buildSectionTitle("Delivery Details"),
            _buildDetailRow("Assigned Part", sparePart?.name ?? "N/A"),
            _buildDetailRow("Destination", delivery.destination),
            _buildDetailRow("Required By",
                DateFormat("dd/MM/yyyy").format(delivery.requiredTime)),
            const Divider(height: 30, thickness: 1),

            // Signature
            _buildSectionTitle("Staff Signature"),
            const SizedBox(height: 8),
            if (pod != null && pod.signature.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(pod.signature),
                      height: 120, fit: BoxFit.contain),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text("No signature available")),
              ),
            const SizedBox(height: 24),

            // Photos
            _buildSectionTitle("Proof of Delivery Photos"),
            const SizedBox(height: 8),
            if (pod != null && pod.pictureUrl.isNotEmpty)
              Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: pod.pictureUrl
                      .map((path) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path),
                        width: 100, height: 100, fit: BoxFit.cover),
                  ))
                      .toList(),
                ),
              )
            else
              const Center(child: Text("No photos provided")),
            const Divider(height: 30, thickness: 1),

            // Remark
            _buildSectionTitle("Remark"),
            Text(pod?.remark.isNotEmpty == true ? pod!.remark : "No remarks",
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),

            // Incident Report
            if (pod != null && pod.issue.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Incident Report"),
                  Text(pod.issue,
                      style: const TextStyle(fontSize: 14, color: Colors.orange)),
                  const SizedBox(height: 20),
                ],
              ),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStyledButton(
                  label: "Share",
                  icon: Icons.share,
                  onPressed: () =>
                      _shareProofOfDelivery(pod, delivery, sparePart, context),
                ),
                _buildStyledButton(
                  label: "Export PDF",
                  icon: Icons.picture_as_pdf,
                  onPressed: () =>
                      _previewPDF(pod, delivery, sparePart, context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Back Button
            Center(
              child: _buildStyledButton(
                label: "Back",
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // align top for multi-line
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              softWrap: true,
              overflow: TextOverflow.visible, // let it wrap instead of ellipsis
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightGreen.shade300,
        foregroundColor: Colors.black,
        elevation: 5,
        shadowColor: Colors.greenAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onPressed,
    );
  }

  Future<File> _generatePDF(
      ProofOfDelivery? pod, Delivery delivery, SparePart? sparePart) async {
    final pdf = pw.Document();

    final formattedDate =
    DateFormat("dd/MM/yyyy HH:mm").format(_toDateTime(pod?.createdAt));


    // Load logo
    final logoData = await rootBundle.load("assets/images/gs_icon.webp");
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Signature
    pw.Widget signatureWidget = pw.Container(
      height: 80,
      width: 150,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      alignment: pw.Alignment.center,
      child: (pod != null && pod.signature.isNotEmpty)
          ? pw.Image(pw.MemoryImage(await File(pod.signature).readAsBytes()),
          width: 120, height: 80, fit: pw.BoxFit.contain)
          : pw.Text("No signature",
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
    );

    // Photos
    List<pw.Widget> photoWidgets = [];
    if (pod != null && pod.pictureUrl.isNotEmpty) {
      for (var path in pod.pictureUrl) {
        final imgFile = File(path);
        if (await imgFile.exists()) {
          final bytes = await imgFile.readAsBytes();
          final img = pw.MemoryImage(bytes);
          photoWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Image(img, width: 100, height: 100, fit: pw.BoxFit.cover),
            ),
          );
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 1),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logoImage, width: 60, height: 60),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("PROOF OF DELIVERY",
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text("Delivered at: $formattedDate",
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),

              // DELIVERY DETAILS
              pw.Text("Delivery Details",
                  style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                children: [
                  _buildTableRow("Assigned Part", sparePart?.name ?? "N/A"),
                  _buildTableRow("Destination", delivery.destination),
                  _buildTableRow(
                      "Required By",
                      DateFormat("dd/MM/yyyy").format(delivery.requiredTime)),
                ],
              ),
              pw.SizedBox(height: 16),

              // REMARK
              if (pod != null && pod.remark.isNotEmpty) ...[
                pw.Text("Remark",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.grey200,
                  child: pw.Text(pod.remark),
                ),
                pw.SizedBox(height: 16),
              ],

              // INCIDENT REPORT
              if (pod != null && pod.issue.isNotEmpty) ...[
                pw.Text("Incident Report",
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red)),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child:
                  pw.Text(pod.issue, style: pw.TextStyle(color: PdfColors.red)),
                ),
                pw.SizedBox(height: 16),
              ],

              // SIGNATURE
              pw.Text("Staff Signature",
                  style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              signatureWidget,
              pw.SizedBox(height: 20),

              // PHOTOS
              if (photoWidgets.isNotEmpty) ...[
                pw.Text("Proof of Delivery Photos",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Wrap(children: photoWidgets),
                pw.SizedBox(height: 20),
              ],

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text("Generated by Delivery App",
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            ],
          ),
        ),
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/proof_of_delivery.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: PdfColors.grey200,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  void _previewPDF(ProofOfDelivery? pod, Delivery delivery,
      SparePart? sparePart, BuildContext context) async {
    final pdf = await _generatePDF(pod, delivery, sparePart);
    final bytes = await pdf.readAsBytes();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("PDF Preview")),
          body: PdfPreview(
            build: (format) async => bytes,
          ),
        ),
      ),
    );
  }

  void _shareProofOfDelivery(ProofOfDelivery? pod, Delivery delivery,
      SparePart? sparePart, BuildContext context) async {
    final file = await _generatePDF(pod, delivery, sparePart);

    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: "Here is the Proof of Delivery");
    } else {
      print("File not found: ${file.path}");
    }

  }
}
