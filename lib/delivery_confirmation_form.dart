import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/firebase_service.dart';
import '../models/delivery.dart';
import '../models/pod.dart';
import '../models/spare_part.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_confirmation.dart';

class DeliveryConfirmationFormPage extends StatefulWidget {
  final Delivery delivery;

  const DeliveryConfirmationFormPage({
    super.key,
    required this.delivery,
  });

  @override
  State<DeliveryConfirmationFormPage> createState() =>
      _DeliveryConfirmationFormPageState();
}

class _DeliveryConfirmationFormPageState
    extends State<DeliveryConfirmationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _remarkController = TextEditingController();

  String? _currentLocation;

  File? _signatureImage;
  final List<File> _podImages = [];
  File? _evidenceImage;

  final ImagePicker _picker = ImagePicker();

  bool _hasIncident = false;
  String? _selectedIncidentType;
  final TextEditingController _otherIncidentController =
  TextEditingController();
  final List<String> _incidentTypes = [
    'Damaged Part',
    'Traffic Delay',
    'Security Issue',
    'Other'
  ];

  DeliveryNote? _selectedDeliveryNote;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  bool get _isFormComplete {
    return _signatureImage != null &&
        _podImages.isNotEmpty &&
        _selectedDeliveryNote != null;
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentLocation =
        "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      setState(() {
        _currentLocation = "Unable to fetch location";
      });
    }
  }

  Future<void> _pickSignatureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _signatureImage = File(image.path);
      });
    }
  }

  Future<void> _pickPodImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _podImages.add(File(image.path));
      });
    }
  }

  Future<void> _pickEvidenceImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _evidenceImage = File(image.path);
      });
    }
  }

  void _removeEvidenceImage() {
    setState(() {
      _evidenceImage = null;
    });
  }

  void _showIncidentReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Incident Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Incident Type:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._incidentTypes.map((type) {
                      return RadioListTile<String>(
                        title: type == 'Other'
                            ? Row(
                          children: [
                            const Text('Other:'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _otherIncidentController,
                                decoration: const InputDecoration(
                                  hintText: 'Specify incident',
                                  isDense: true,
                                ),
                                enabled: _selectedIncidentType == 'Other',
                              ),
                            ),
                          ],
                        )
                            : Text(type),
                        value: type,
                        groupValue: _selectedIncidentType,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedIncidentType = value;
                          });
                        },
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    const Text('Evidence:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickEvidenceImage,
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _evidenceImage != null
                            ? Stack(
                          children: [
                            Image.file(
                              _evidenceImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    size: 20, color: Colors.white),
                                onPressed: _removeEvidenceImage,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.all(4),
                                ),
                              ),
                            ),
                          ],
                        )
                            : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40),
                              SizedBox(height: 8),
                              Text('Add Evidence Photo'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedIncidentType != null) {
                      setState(() {
                        _hasIncident = true;
                      });
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select an incident type')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showContactOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Contact Dispatcher"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text("Call Dispatcher"),
                onTap: () {
                  Navigator.of(context).pop();
                  _callDispatcher();
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.teal),
                title: const Text("WhatsApp Dispatcher"),
                onTap: () {
                  Navigator.of(context).pop();
                  _whatsAppDispatcher();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _callDispatcher() async {
    const phoneNumber = 'tel:+1234567890';
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  Future<void> _whatsAppDispatcher() async {
    const phoneNumber = 'https://wa.me/1234567890';
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Confirmation"),
      ),
      body: _createForm(widget.delivery),
    );
  }

  Widget _createForm(Delivery delivery) {
    final today = DateFormat("dd/MM/yyyy").format(DateTime.now());

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Blue Header Row
            Container(
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(delivery.id,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const Text("PROOF OF DELIVERY",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(today,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Information Card
                  FutureBuilder<SparePart?>(

                    future: spareParts.get(delivery.spID),
                    builder: (ctx, partSnap) {
                      if (!partSnap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final part = partSnap.data!;
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.settings, size: 20),
                                  const SizedBox(width: 6),
                                  const Text("Assigned Part:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Text(part.name),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 20),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "Destination: ${delivery.destination}"),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentLocation != null
                                              ? "Current Location: $_currentLocation"
                                              : "Fetching current location...",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Required By: ${DateFormat("dd/MM/yyyy").format(delivery.requiredTime)}",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Signature & Proof of Delivery
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Staff's Signature"),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickSignatureImage,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black38),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _signatureImage != null
                                    ? Image.file(_signatureImage!,
                                    fit: BoxFit.cover)
                                    : const Center(
                                  child:
                                  Icon(Icons.camera_alt, size: 40),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Proof of Delivery"),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._podImages.map((img) => Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Image.file(img,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _podImages.remove(img);
                                        });
                                      },
                                    ),
                                  ],
                                )),
                                GestureDetector(
                                  onTap: _pickPodImage,
                                  child: Container(
                                    width: 200,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      border:
                                      Border.all(color: Colors.black38),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child:
                                      Icon(Icons.add_a_photo, size: 40),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Delivery Note
                  DropdownButtonFormField<DeliveryNote>(
                    value: _selectedDeliveryNote,
                    decoration: const InputDecoration(
                      labelText: "Delivery Note",
                      border: OutlineInputBorder(),
                    ),
                    items: DeliveryNote.values.map((note) {
                      return DropdownMenuItem(
                        value: note,
                        child: Text(note.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDeliveryNote = val;
                      });
                    },
                    validator: (val) => val == null
                        ? "Please select a delivery note option"
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // Remark
                  TextFormField(
                    controller: _remarkController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Remark",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Incident Report + Contact
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: _showIncidentReportDialog,
                        icon: Icon(Icons.warning_amber,
                            size: 16,
                            color: _hasIncident ? Colors.orange : Colors.black),
                        label: Text(
                          "INCIDENT REPORT",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _hasIncident ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _showContactOptionsDialog,
                        icon: const Icon(Icons.phone,
                            size: 16, color: Colors.black),
                        label: const Text(
                          "CONTACT",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _isFormComplete ? Colors.green : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                      ),
                      onPressed: _isFormComplete
                          ? () async {
                        if (_formKey.currentState!.validate()) {
                          // Create POD object
                          final pod = await _createNewPod(delivery.id);
                          await pods.save(pod, id: pod.podID);

                          // Fetch spare part if needed
                          final sparePart = await spareParts.get(delivery.spID);

                          // Navigate to DeliverySuccessPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeliverySuccessPage(
                                pod: pod,
                                delivery: delivery,
                                sparePart: sparePart,
                              ),
                            ),
                          );
                        }
                      }
                          : null,

                      child: const Text("SUBMIT",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<ProofOfDelivery> _createNewPod(String deliveryID) async {
    final allPods = await pods.all();
    final nextIndex = allPods.length + 1;
    final podID = "P${nextIndex.toString().padLeft(3, '0')}";
    final noteText = _selectedDeliveryNote?.label ?? '';

    String incidentType = '';
    if (_selectedIncidentType != null) {
      incidentType = _selectedIncidentType == 'Other'
          ? _otherIncidentController.text
          : _selectedIncidentType!;
    }

    return ProofOfDelivery(
      podID: podID,
      deliveryID: deliveryID,
      signature: _signatureImage?.path ?? "",
      pictureUrl: _podImages.map((f) => f.path).toList(),
      deliveryNote: noteText,
      remark: _remarkController.text,
      issue: incidentType,
      evidenceUrl: _evidenceImage?.path ?? "",
      createdAt: DateTime.now(),
    );
  }
}
