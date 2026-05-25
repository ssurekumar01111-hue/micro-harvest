import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

import '../../data/models/user_model.dart';

class OnboardingScreen extends StatefulWidget {
  final UserModel? initialUser;
  const OnboardingScreen({super.key, this.initialUser});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentStep = 0;
  bool _isDetectingLocation = false;

  // Step 1: Personal Info
  late final TextEditingController _nameController;
  late final TextEditingController _farmNameController;
  File? _profileImage;
  final _picker = ImagePicker();

  // Step 2: Location
  Position? _currentPosition;
  String? _manualAddress;
  double _radius = 50.0;

  // Step 3: Crops
  final List<String> _selectedCrops = [];
  String? _harvestSize;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _nameController = TextEditingController(text: widget.initialUser?.displayName);
    _farmNameController = TextEditingController(text: widget.initialUser?.farmName);
    if (widget.initialUser != null) {
      _radius = widget.initialUser!.radiusMiles;
      _selectedCrops.addAll(widget.initialUser!.cropInterests);
      _harvestSize = widget.initialUser!.harvestSize;
      if (widget.initialUser!.geoPoint.latitude != 0) {
        _currentPosition = Position(
          latitude: widget.initialUser!.geoPoint.latitude,
          longitude: widget.initialUser!.geoPoint.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    }
  }

  final List<String> _crops = [
    '🍇 Pinot Noir',
    '🍾 Chardonnay',
    '🌿 Riesling',
    '🍷 Cabernet',
    '🌱 Merlot',
    '🥂 Sauvignon Blanc',
  ];

  final List<String> _harvestSizes = [
    'Small (< 1 ton)',
    'Medium (1-5 tons)',
    'Large (5-20 tons)',
    'Very Large (20+ tons)',
  ];

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _detectLocation() async {
    final locationRepo = context.read<LocationRepository>();
    setState(() => _isDetectingLocation = true);

    try {
      final granted = await locationRepo.requestPermission();
      if (!granted) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Needed'),
            content: const Text('We need your location to show your farm to nearby buyers.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final position = await locationRepo.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error detecting location: $e')));
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _completeSetup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final geohash = _currentPosition != null
        ? GeoHasher().encode(_currentPosition!.longitude, _currentPosition!.latitude)
        : '';

    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (!mounted) return;

    final authBloc = context.read<AuthBloc>();
    final router = GoRouter.of(context);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'role': 'GROWER',
      'displayName': _nameController.text.trim(),
      'farmName': _farmNameController.text.trim(),
      'phone': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'geoPoint': GeoPoint(
        _currentPosition?.latitude ?? 0,
        _currentPosition?.longitude ?? 0,
      ),
      'geohash': geohash,
      'radiusMiles': _radius,
      'cropInterests': _selectedCrops,
      'harvestSize': _harvestSize,
      'createdAt': widget.initialUser != null
          ? Timestamp.fromDate(widget.initialUser!.createdAt)
          : FieldValue.serverTimestamp(),
      'fcmTokens': fcmToken != null ? FieldValue.arrayUnion([fcmToken]) : [],
      'availabilityStatus': widget.initialUser?.availabilityStatus ?? 'AVAILABLE',
      'totalEarned': widget.initialUser?.totalEarned ?? 0.0,
      'totalHauled': widget.initialUser?.totalHauled ?? 0,
      'onboardingComplete': true,
    }, SetOptions(merge: true));

    // Notify AuthBloc to refresh state
    authBloc.add(AppStarted());
    if (widget.initialUser != null) {
      router.pop();
    } else {
      router.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.bark),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              if (widget.initialUser != null) {
                Navigator.of(context).pop();
              } else {
                context.read<AuthBloc>().add(SignOutRequested());
              }
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int page) {
                setState(() {
                  _currentStep = page;
                });
              },
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index <= _currentStep ? AppColors.moss : AppColors.stone.withValues(alpha: 0.5),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tell us about yourself 🌾", style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text("Help buyers know who you are", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.stone.withValues(alpha: 0.2),
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null
                    ? const Icon(Icons.camera_alt, size: 40, color: AppColors.bark)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text("Full Name", style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "Your Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.bark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.moss, width: 2),
              ),
            ),
            style: AppTextStyles.bodyLarge.copyWith(fontFamily: 'DM Sans'),
          ),
          const SizedBox(height: 24),
          Text("Farm Name (optional)", style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _farmNameController,
            decoration: InputDecoration(
              hintText: "e.g. RJ Ranch",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.bark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.moss, width: 2),
              ),
            ),
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().length >= 2) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your full name (min 2 chars)')),
                );
              }
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Where is your farm? 📍", style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text("Buyers nearby will find your listings", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isDetectingLocation ? null : _detectLocation,
            icon: _isDetectingLocation
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_currentPosition != null ? Icons.check : Icons.my_location),
            label: Text(_isDetectingLocation
                ? "Detecting..."
                : (_currentPosition != null ? "Location Detected" : "Auto-detect location")),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPosition != null ? Colors.green : AppColors.moss,
            ),
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 16),
            Text(
              "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}",
              style: AppTextStyles.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          Text("Manual address field (fallback)", style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            onChanged: (val) => _manualAddress = val,
            decoration: InputDecoration(
              hintText: "City, State",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Alert buyers within:", style: AppTextStyles.labelLarge),
              Text("${_radius.toInt()} miles", style: AppTextStyles.labelLarge.copyWith(color: AppColors.moss)),
            ],
          ),
          Slider(
            value: _radius,
            min: 10,
            max: 100,
            divisions: 9,
            activeColor: AppColors.moss,
            inactiveColor: AppColors.stone.withValues(alpha: 0.3),
            onChanged: (val) {
              setState(() {
                _radius = val;
              });
            },
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              if (_currentPosition != null || (_manualAddress != null && _manualAddress!.isNotEmpty)) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide your location')),
                );
              }
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What do you grow? 🍇", style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text("Select all that apply", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _crops.map((crop) {
              final isSelected = _selectedCrops.contains(crop);
              return FilterChip(
                label: Text(crop),
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
                selectedColor: AppColors.moss,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.bark,
                ),
                backgroundColor: AppColors.cream,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.bark),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text("Typical harvest size:", style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _harvestSize,
            items: _harvestSizes.map((size) {
              return DropdownMenuItem(
                value: size,
                child: Text(size),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _harvestSize = val;
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              if (_selectedCrops.isNotEmpty && _harvestSize != null) {
                _completeSetup();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select crops and harvest size')),
                );
              }
            },
            child: const Text("Complete Setup"),
          ),
        ],
      ),
    );
  }
}
