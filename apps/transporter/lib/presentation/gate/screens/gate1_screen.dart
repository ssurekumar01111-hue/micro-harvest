import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/listing_model.dart';
import '../../../../data/repositories/haul_repository.dart';
import '../../../../data/repositories/location_repository.dart';
import '../bloc/gate_bloc.dart';
import '../bloc/gate_event.dart';
import '../bloc/gate_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class Gate1Screen extends StatefulWidget {
  final String handoffId;
  const Gate1Screen({super.key, required this.handoffId});

  @override
  State<Gate1Screen> createState() => _Gate1ScreenState();
}

class _Gate1ScreenState extends State<Gate1Screen> {
  File? _image;
  final _picker = ImagePicker();
  late Future<ListingModel> _listingFuture;

  @override
  void initState() {
    super.initState();
    _listingFuture = _loadListing();
  }

  Future<ListingModel> _loadListing() async {
    final repository = context.read<HaulRepository>();
    final handoff = await repository.getHandoff(widget.handoffId);
    return repository.getListing(handoff.listingId);
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
      appBar: AppBar(title: const Text('Gate 1 · Pickup')),
      body: BlocConsumer<GateBloc, GateState>(
        listener: (context, state) {
          if (state is GateConfirmed) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup confirmed!')));
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          return FutureBuilder<ListingModel>(
            future: _listingFuture,
            builder: (context, snapshot) {
              final listing = snapshot.data;
              final lat = listing?.plotLocation.latitude;
              final lon = listing?.plotLocation.longitude;

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
                          Text('Confirm pickup at grower\'s plot', 
                            style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat, fontSize: 18)),
                          const SizedBox(height: 12),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const CircularProgressIndicator(color: AppColors.wheat)
                          else if (listing == null)
                            const Text('Listing unavailable', style: TextStyle(color: Colors.white))
                          else ...[
                            Text(
                              'LAT: ${lat?.toStringAsFixed(4)}   LON: ${lon?.toStringAsFixed(4)}',
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
                              Text('Arrive within 500m of plot', 
                                style: TextStyle(color: AppColors.moss, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Capture Cargo', style: AppTextStyles.titleLarge),
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
                      onPressed: _image == null || state is GateConfirming || listing == null
                        ? null
                        : () async {
                            try {
                              final pos = await context.read<LocationRepository>().getCurrentPosition();
                              if (context.mounted) {
                                context.read<GateBloc>().add(
                                  ConfirmGate1(
                                    handoffId: widget.handoffId,
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
                        : const Text('Confirm Pickup'),
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

