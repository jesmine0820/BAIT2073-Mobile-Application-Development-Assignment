import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../models/spare_part.dart';
import '../models/pod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

class DeliverySuccessPage extends StatelessWidget {
  final ProofOfDelivery? pod;
  final Delivery delivery;
  final SparePart? sparePart;

  const DeliverySuccessPage({
    super.key,
    required this.pod,
    required this.delivery,
    this.sparePart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Confirmation"),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green,
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Delivered",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _shareProofOfDelivery(
                          pod, delivery, sparePart, context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Share To"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _previewPDF(pod, delivery, sparePart, context);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Export to PDF"),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "Back to Main Page",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File> _generatePDF(
      ProofOfDelivery? pod, Delivery delivery, SparePart? sparePart) async {
    final pdf = pw.Document();
    final formattedDate =
    DateFormat("dd/MM/yyyy HH:mm").format(pod?.createdAt ?? DateTime.now());

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load("assets/images/gs_icon.webp");
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }

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
          ? pw.Image(
        pw.MemoryImage(await File(pod.signature).readAsBytes()),
        width: 120,
        height: 80,
        fit: pw.BoxFit.contain,
      )
          : pw.Text(
        "No signature",
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );

    // Photos
    List<pw.Widget> photoWidgets = [];
    if (pod != null && pod.pictureUrl.isNotEmpty) {
      for (var path in pod.pictureUrl) {
        try {
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
        } catch (e) {
          print("Error loading image $path: $e");
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
                  if (logoImage != null) pw.Image(logoImage, width: 60, height: 60),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "PROOF OF DELIVERY",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Delivered at: $formattedDate",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),

              // DELIVERY DETAILS
              pw.Text(
                "Delivery Details",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                children: [
                  _buildTableRow("Assigned Part", sparePart?.name ?? "N/A"),
                  _buildTableRow("Destination", delivery.destination),
                  _buildTableRow(
                    "Required By",
                    DateFormat("dd/MM/yyyy").format(delivery.requiredTime),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // REMARK
              if (pod != null && pod.remark.isNotEmpty) ...[
                pw.Text(
                  "Remark",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
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
                pw.Text(
                  "Incident Report",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    pod.issue,
                    style: pw.TextStyle(color: PdfColors.red),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // SIGNATURE
              pw.Text(
                "Staff Signature",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              signatureWidget,
              pw.SizedBox(height: 20),

              // PHOTOS
              if (photoWidgets.isNotEmpty) ...[
                pw.Text(
                  "Proof of Delivery Photos",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Wrap(children: photoWidgets),
                pw.SizedBox(height: 20),
              ],

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  "Generated by Delivery App",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/proof_of_delivery_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: PdfColors.grey200,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12),
            softWrap: true,
            overflow: pw.TextOverflow.span,
          ),
        ),
      ],
    );
  }

  Future<void> _previewPDF(ProofOfDelivery? pod, Delivery delivery,
      SparePart? sparePart, BuildContext context) async {
    try {
      final file = await _generatePDF(pod, delivery, sparePart);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("PDF Preview")),
            body: PdfPreview(
              build: (format) => file.readAsBytes(),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating PDF: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareProofOfDelivery(
      ProofOfDelivery? pod,
      Delivery delivery,
      SparePart? sparePart,
      BuildContext context) async {
    try {
      final file = await _generatePDF(pod, delivery, sparePart);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Proof of Delivery - ${delivery.destination}",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sharing document: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
