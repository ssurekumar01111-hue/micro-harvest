import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
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
          }
        },
        builder: (context, state) {
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
                      Text('Producer Location', style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat)),
                      const SizedBox(height: 12),
                      const Text(
                        'LAT: 38.5611   LON: -121.7222',
                        style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.moss, size: 16),
                          SizedBox(width: 8),
                          Text('Within 500m of destination', style: TextStyle(color: AppColors.moss, fontSize: 12)),
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
                  onPressed: _image == null || state is GateConfirming
                    ? null
                    : () async {
                        final pos = await Geolocator.getCurrentPosition();
                        if (context.mounted) {
                          context.read<GateBloc>().add(
                            ConfirmGate2(
                              handoffId: widget.handoffId,
                              gps: GeoPoint(pos.latitude, pos.longitude),
                              image: _image!,
                            ),
                          );
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
      ),
    );
  }
}
