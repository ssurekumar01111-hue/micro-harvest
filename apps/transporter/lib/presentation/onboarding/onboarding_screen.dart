import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dart_geohash/dart_geohash.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/location_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedVehicle;
  Position? _currentPosition;
  bool _isDetectingLocation = false;
  double _radius = 50.0;

  final List<String> _vehicles = [
    'TRUCK',
    'VAN',
    'PICKUP',
    'REFRIGERATED',
  ];

  Future<void> _detectLocation() async {
    final locationRepo = context.read<LocationRepository>();
    setState(() => _isDetectingLocation = true);

    try {
      // FIX: Ask for notification permission first if not already handled
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted = await locationRepo.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await locationRepo.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error detecting location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect your location')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final geohash = GeoHasher().encode(_currentPosition!.longitude, _currentPosition!.latitude);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _nameController.text.trim(),
        'vehicleType': _selectedVehicle,
        'geoPoint': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'geohash': geohash,
        'radiusMiles': _radius,
        'role': 'TRANSPORTER',
        'availabilityStatus': 'OFFLINE',
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        context.read<AuthBloc>().add(AppStarted());
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving onboarding data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Transporter Onboarding'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start Hauling', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 8),
              Text('Set up your transporter profile to start receiving haul alerts.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
              const SizedBox(height: 32),
              Text('Full Name', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Text('Vehicle Type', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicle,
                items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) => setState(() => _selectedVehicle = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Text('Home Base Location', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isDetectingLocation ? null : _detectLocation,
                icon: _isDetectingLocation
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_currentPosition != null ? 'Location Detected' : 'Auto-detect Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPosition != null ? Colors.green : AppColors.moss,
                ),
              ),
              if (_currentPosition != null) ...[
                const SizedBox(height: 8),
                Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Operating Radius', style: AppTextStyles.labelLarge),
                  Text('${_radius.toInt()} km', style: AppTextStyles.labelLarge.copyWith(color: AppColors.moss)),
                ],
              ),
              Slider(
                value: _radius,
                min: 10,
                max: 150,
                divisions: 14,
                onChanged: (val) => setState(() => _radius = val),
                activeColor: AppColors.moss,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.bark,
                  ),
                  child: const Text('Complete Setup', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
