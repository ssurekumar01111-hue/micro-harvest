import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../bloc/confirm_bloc.dart';
import '../bloc/confirm_event.dart';
import '../bloc/confirm_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CargoConfirmScreen extends StatefulWidget {
  final String? handoffId;
  final VoidCallback? onBack;
  const CargoConfirmScreen({super.key, this.handoffId, this.onBack});

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (widget.onBack != null) {
            widget.onBack!();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirm Delivery'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
        ),
        body: widget.handoffId == null || widget.handoffId!.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 64, color: AppColors.stone),
                    const SizedBox(height: 16),
                    Text('No pending confirmation', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.stone, fontSize: 24)),
                    const SizedBox(height: 8),
                    const Text('Select a haul from the Active tab to confirm delivery'),
                  ],
                ),
              )
            : BlocConsumer<ConfirmBloc, ConfirmState>(
                listener: (context, state) {
                  if (state is ConfirmGate2Success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery confirmed!')));
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
                                            handoffId: widget.handoffId!,
                                            gps: GeoPoint(pos.latitude, pos.longitude),
                                            image: _image!,
                                          ),
                                        );
                                      }
                                    },
                                child: (state is ConfirmLoading)
                                  ? const CircularProgressIndicator()
                                  : const Text('Confirm Delivery'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => _showDisputeDialog(context),
                                child: const Text('Raise Dispute', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('handoffs').doc(widget.handoffId).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox.shrink();
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data == null) return const SizedBox.shrink();

                            final payment = data['payment'] as Map<String, dynamic>?;
                            final releasedAt = payment?['releasedAt'];

                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: releasedAt != null ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: releasedAt != null ? Colors.green : Colors.orange),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        releasedAt != null ? Icons.verified : Icons.pending,
                                        color: releasedAt != null ? Colors.green : Colors.orange,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        releasedAt != null ? 'Payment Processed' : 'Pending Settlement',
                                        style: TextStyle(
                                          color: releasedAt != null ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        _buildPaymentRow(
                                          'Grower Share (80%)',
                                          NumberFormat.simpleCurrency().format(payment?['growerShareUSD'] ?? 0),
                                        ),
                                        _buildPaymentRow(
                                          'Transporter Fee (15%)',
                                          NumberFormat.simpleCurrency().format(payment?['transporterFeeUSD'] ?? 0),
                                        ),
                                        _buildPaymentRow(
                                          'Platform Fee (5%)',
                                          NumberFormat.simpleCurrency().format(payment?['platformFeeUSD'] ?? 0),
                                        ),
                                        const Divider(height: 32),
                                        _buildPaymentRow(
                                          'Total Amount',
                                          NumberFormat.simpleCurrency().format(payment?['totalUSD'] ?? 0),
                                          isTotal: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
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

  void _showDisputeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Raise Dispute'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Reason for dispute'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('handoffs').doc(widget.handoffId).update({
                  'disputeStatus': 'RAISED',
                  'disputeReason': controller.text,
                  'disputedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dispute raised successfully')),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
