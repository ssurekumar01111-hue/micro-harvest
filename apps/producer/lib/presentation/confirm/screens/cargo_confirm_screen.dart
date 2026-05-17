import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/confirm_bloc.dart';
import '../bloc/confirm_event.dart';
import '../bloc/confirm_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CargoConfirmScreen extends StatefulWidget {
  final String handoffId;
  const CargoConfirmScreen({super.key, required this.handoffId});

  @override
  State<CargoConfirmScreen> createState() => _CargoConfirmScreenState();
}

class _CargoConfirmScreenState extends State<CargoConfirmScreen> {
  File? _image;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Delivery')),
      body: BlocConsumer<ConfirmBloc, ConfirmState>(
        listener: (context, state) {
          if (state is ConfirmGate2Success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery confirmed!')));
          } else if (state is SettleSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment released!')));
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.moss,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Cargo on-site', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.bark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text('Gate 2 Confirmation', style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat)),
                      const SizedBox(height: 24),
                      if (_image != null)
                        Image.file(_image!, height: 200)
                      else
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Cargo Photo'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.wheat),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _image == null || state is ConfirmLoading
                          ? null
                          : () async {
                              final pos = await Geolocator.getCurrentPosition();
                              if (context.mounted) {
                                context.read<ConfirmBloc>().add(
                                  ConfirmGate2(
                                    handoffId: widget.handoffId,
                                    gps: GeoPoint(pos.latitude, pos.longitude),
                                    image: _image!,
                                  ),
                                );
                              }
                            },
                        child: state is ConfirmLoading 
                          ? const CircularProgressIndicator()
                          : const Text('Confirm Delivery & Release Payment'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('Payment Summary', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 16),
                        _buildPaymentRow('Grower Share (80%)', '\$2,400.00'),
                        _buildPaymentRow('Transporter Fee (15%)', '\$450.00'),
                        _buildPaymentRow('Platform Fee (5%)', '\$150.00'),
                        const Divider(height: 32),
                        _buildPaymentRow('Total Amount', '\$3,000.00', isTotal: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(amount, style: isTotal ? AppTextStyles.headlineLarge.copyWith(fontSize: 24) : null),
        ],
      ),
    );
  }
}
