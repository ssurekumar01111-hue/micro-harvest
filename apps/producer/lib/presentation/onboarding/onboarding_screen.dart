import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Position? _currentPosition;
  bool _isDetectingLocation = false;
  final List<String> _selectedCrops = [];
  double _radius = 80.0;

  final List<String> _crops = [
    'PINOT_NOIR',
    'CHARDONNAY',
    'RIESLING',
    'CABERNET',
    'MERLOT',
    'SAUVIGNON_BLANC',
  ];

  Future<void> _detectLocation() async {
    final locationRepo = context.read<LocationRepository>();
    setState(() => _isDetectingLocation = true);

    try {
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
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect your location')),
      );
      return;
    }
    if (_selectedCrops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one crop interest')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final geohash = GeoHasher().encode(_currentPosition!.longitude, _currentPosition!.latitude);

    try {
      debugPrint('Onboarding: Saving to Firestore for $uid. Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _nameController.text.trim(),
        'geoPoint': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'geohash': geohash,
        'cropInterests': _selectedCrops,
        'radiusMiles': _radius,
        'role': 'PRODUCER',
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        context.read<AuthBloc>().add(AppStarted());
        context.go('/dashboard');
      }
    } catch (e) {
      debugPrint('Onboarding: Error saving to Firestore: $e');
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
        title: const Text('Producer Onboarding'),
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
              Text('Welcome to Micro-Harvest', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 8),
              Text('Set up your producer profile to start discovering listings.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
              const SizedBox(height: 32),
              Text('Business Name', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter business name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Text('Location', style: AppTextStyles.labelLarge),
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
              Text('Crop Interests', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _crops.map((crop) {
                  final isSelected = _selectedCrops.contains(crop);
                  return FilterChip(
                    label: Text(crop.replaceAll('_', ' ')),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCrops.add(crop);
                        } else {
                          _selectedCrops.remove(crop);
                        }
                      });
                    },
                    selectedColor: AppColors.wheat,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Search Radius', style: AppTextStyles.labelLarge),
                  Text('${_radius.toInt()} km', style: AppTextStyles.labelLarge.copyWith(color: AppColors.moss)),
                ],
              ),
              Slider(
                value: _radius,
                min: 10,
                max: 200,
                divisions: 19,
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
