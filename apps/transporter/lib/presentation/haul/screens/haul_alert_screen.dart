import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/haul_bloc.dart';
import '../bloc/haul_event.dart';
import '../bloc/haul_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HaulAlertScreen extends StatefulWidget {
  final dynamic listing; // Should be ListingModel
  const HaulAlertScreen({super.key, required this.listing});

  @override
  State<HaulAlertScreen> createState() => _HaulAlertScreenState();
}

class _HaulAlertScreenState extends State<HaulAlertScreen> {
  int _secondsRemaining = 1800; // 30 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          context.pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<HaulBloc, HaulState>(
        listener: (context, state) {
          if (state is HaulAccepted) {
            context.go('/dashboard');
          } else if (state is HaulError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Column(
          children: [
            Container(
              height: 300,
              decoration: const BoxDecoration(
                color: AppColors.harvest,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NEW HAUL ALERT', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text(_timerText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('Pinot Noir', style: AppTextStyles.displayMedium.copyWith(color: Colors.white)),
                    Text('2000kg · 30 MACRO_BINs', style: AppTextStyles.bodyLarge.copyWith(color: Colors.white)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLocationCard('Pickup', 'Valley Estates · 12mi away'),
                    const SizedBox(height: 16),
                    _buildLocationCard('Delivery', 'Central Winery · 24mi total'),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Earnings', style: AppTextStyles.bodyLarge),
                        Text('\$450.00', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.moss)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        context.read<HaulBloc>().add(AcceptHaul(widget.listing.listingId));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss),
                      child: const Text('Accept Haul'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Decline', style: TextStyle(color: AppColors.stone)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.harvest),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
                Text(value, style: AppTextStyles.titleLarge.copyWith(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
