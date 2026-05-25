import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dart_geohash/dart_geohash.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/listing_model.dart';
import '../../../data/repositories/location_repository.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isDetectingLocation = false;

  String? _selectedCrop;
  String _selectedContainer = 'MACRO_BIN';
  int _containerCount = 1;
  final _priceController = TextEditingController();
  PerishTier _selectedPerishTier = PerishTier.hours24;
  DateTime? _selectedDateTime;
  final _notesController = TextEditingController();

  // Location
  Position? _detectedPosition;
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final Map<String, double> _weights = {
    'MACRO_BIN': 90.7,
    'HALF_BIN': 45.4,
    'LUG_BOX': 19.5,
    'BULK_BAG': 500.0,
    'CRATE': 20.0,
    'SACK': 50.0,
    'QUINTAL': 100.0,
    'TROLLEY': 250.0,
  };

  double get _computedWeightKg => (_weights[_selectedContainer] ?? 0) * _containerCount;

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
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
            content: const Text('We need your location to accurately place your harvest on the map for producers.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final position = await locationRepo.getCurrentPosition();
      setState(() {
        _detectedPosition = position;
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error detecting location: $e')));
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a crop type')));
      return;
    }
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select harvest window end')));
      return;
    }

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide plot location')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Listing'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfirmRow('Crop', ListingModel.cropDisplayName(_selectedCrop)),
              _buildConfirmRow('Container', ListingModel.containerDisplayName(_selectedContainer)),
              _buildConfirmRow('Count', _containerCount.toString()),
              _buildConfirmRow('Weight', '${_computedWeightKg.toStringAsFixed(1)} kg'),
              _buildConfirmRow('Price', '\$${_priceController.text}'),
              _buildConfirmRow('Expires', DateFormat('MMM dd, yyyy @ hh:mm a').format(_selectedDateTime!)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final geohash = GeoHasher().encode(lng, lat);

      await FirebaseFirestore.instance.collection('listings').add({
        'growerId': user.uid,
        'cropType': _selectedCrop,
        'containerType': _selectedContainer,
        'containerCount': _containerCount,
        'weightKg': _computedWeightKg,
        'perishTier': _selectedPerishTier.name.toUpperCase(),
        'askingPricePerTon': double.parse(_priceController.text),
        'plotLocation': GeoPoint(lat, lng),
        'geohash': geohash,
        'harvestWindowEnd': Timestamp.fromDate(_selectedDateTime!),
        'status': 'OPEN',
        'producerId': null,
        'transporterId': null,
        'listingSource': 'MANUAL',
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing created successfully!')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('New Listing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop Type
                    Text('Crop Type', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCrop,
                      decoration: _inputDecoration('Select crop'),
                      items: ListingModel.cropTypes.map((crop) {
                        return DropdownMenuItem(
                          value: crop,
                          child: Text(ListingModel.cropDisplayName(crop)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCrop = val),
                    ),
                    const SizedBox(height: 24),

                    // Container Type
                    Text('Container Type', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildContainerCard('MACRO_BIN', '📦', 'Macro'),
                        _buildContainerCard('HALF_BIN', '🗃️', 'Half'),
                        _buildContainerCard('LUG_BOX', '📫', 'Lug'),
                        _buildContainerCard('BULK_BAG', '🎒', 'Bulk'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Container Count
                    Text('Number of Containers', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _countButton(Icons.remove, () {
                          if (_containerCount > 1) setState(() => _containerCount--);
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _containerCount.toString(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Playfair Display'),
                          ),
                        ),
                        _countButton(Icons.add, () {
                          if (_containerCount < 999) setState(() => _containerCount++);
                        }),
                        const Spacer(),
                        Text(
                          'Est. Weight: ${_computedWeightKg.toStringAsFixed(1)} kg',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.moss, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Asking Price
                    Text('Asking Price (USD per ton)', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('e.g. 2500').copyWith(prefixText: '\$ '),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Perishability
                    Text('How urgent is this?', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPerishChip(PerishTier.hours12, '⚡ 12h'),
                        _buildPerishChip(PerishTier.hours24, '🔥 24h'),
                        _buildPerishChip(PerishTier.days3, '📅 3d'),
                        _buildPerishChip(PerishTier.days7, '🗓️ 7d'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Harvest Window End
                    Text('Listing expires at', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.stone.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: AppColors.moss),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDateTime == null
                                  ? 'Select date & time'
                                  : DateFormat('MMM dd, yyyy @ hh:mm a').format(_selectedDateTime!),
                              style: AppTextStyles.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Plot Location
                    Text('Farm/Plot Location', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isDetectingLocation ? null : _detectLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_detectedPosition != null ? Icons.check : Icons.my_location),
                      label: Text(_isDetectingLocation
                          ? 'Detecting...'
                          : (_detectedPosition != null ? 'Location Detected' : 'Detect My Location')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _detectedPosition != null ? Colors.green : AppColors.moss,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_detectedPosition != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '📍 ${_detectedPosition!.latitude.toStringAsFixed(4)}° N, ${_detectedPosition!.longitude.toStringAsFixed(4)}° W',
                          style: const TextStyle(fontSize: 12, color: AppColors.moss),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Latitude'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Longitude'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Notes
                    Text('Additional Notes', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration('Quality notes, special instructions...'),
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.moss,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Create Listing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContainerCard(String type, String emoji, String label) {
    final isSelected = _selectedContainer == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedContainer = type),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.moss.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.moss : AppColors.bark, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPerishChip(PerishTier tier, String label) {
    final isSelected = _selectedPerishTier == tier;
    final isUrgent = tier == PerishTier.hours12 || tier == PerishTier.hours24;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedPerishTier = tier),
      selectedColor: isUrgent ? AppColors.rust : AppColors.moss,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.bark),
      backgroundColor: Colors.white,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.stone.withValues(alpha: 0.3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.stone.withValues(alpha: 0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.moss, width: 2)),
    );
  }
}
