import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/repositories/haul_repository.dart';
import '../../../../data/repositories/location_repository.dart';
import '../bloc/gate_bloc.dart';
import '../bloc/gate_event.dart';
import '../bloc/gate_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class Gate2Screen extends StatefulWidget {
  final String handoffId;
  const Gate2Screen({super.key, required this.handoffId});

  @override
  State<Gate2Screen> createState() => _Gate2ScreenState();
}

class _Gate2ScreenState extends State<Gate2Screen> {
  File? _image;
  final _picker = ImagePicker();
  late Future<DocumentSnapshot> _producerFuture;

  @override
  void initState() {
    super.initState();
    _producerFuture = _loadProducer();
  }

  Future<DocumentSnapshot> _loadProducer() async {
    final repository = context.read<HaulRepository>();
    final handoff = await repository.getHandoff(widget.handoffId);
    return FirebaseFirestore.instance.collection('users').doc(handoff.producerId).get();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _viewOnMap(double lat, double lon) async {
    final url = 'https://maps.google.com/?q=$lat,$lon';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gate 2 · Delivery')),
      body: BlocConsumer<GateBloc, GateState>(
        listener: (context, state) {
          if (state is GateConfirmed) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery confirmed!')));
            Navigator.pop(context);
          } else if (state is GateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}')),
            );
          }
        },
        builder: (context, state) {
          return FutureBuilder<DocumentSnapshot>(
            future: _producerFuture,
            builder: (context, snapshot) {
              final producerData = snapshot.data?.data() as Map<String, dynamic>?;
              final geoPoint = producerData?['geoPoint'] as GeoPoint?;
              final lat = geoPoint?.latitude;
              final lon = geoPoint?.longitude;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text('Confirm delivery at producer\'s location', 
                            style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat, fontSize: 18)),
                          const SizedBox(height: 12),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const CircularProgressIndicator(color: AppColors.wheat)
                          else if (geoPoint == null)
                            const Text('Producer location unavailable', style: TextStyle(color: Colors.white))
                          else ...[
                            Text(
                              'Deliver to: lat ${lat?.toStringAsFixed(4)}, lon ${lon?.toStringAsFixed(4)}',
                              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _viewOnMap(lat!, lon!),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('View on Map'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.wheat,
                                side: const BorderSide(color: AppColors.wheat),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: AppColors.moss, size: 16),
                              SizedBox(width: 8),
                              Text('Within 500m of destination', 
                                style: TextStyle(color: AppColors.moss, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Capture Handover', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 16),
                    if (_image != null)
                      Image.file(_image!, height: 300, fit: BoxFit.cover)
                    else
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Icon(Icons.camera_alt, size: 40, color: AppColors.stone)),
                        ),
                      ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _image == null || state is GateConfirming || geoPoint == null
                        ? null
                        : () async {
                            try {
                              final pos = await context.read<LocationRepository>().getCurrentPosition();
                              if (context.mounted) {
                                context.read<GateBloc>().add(
                                  ConfirmGate2(
                                    handoffId: widget.handoffId,
                                    producerId: snapshot.data!.id,
                                    gps: GeoPoint(pos.latitude, pos.longitude),
                                    image: _image!,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Location error: $e')),
                                );
                              }
                            }
                          },
                      child: state is GateConfirming 
                        ? const CircularProgressIndicator()
                        : const Text('Confirm Delivery'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

