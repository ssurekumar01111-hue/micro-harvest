import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/agent_bloc.dart';
import '../bloc/agent_event.dart';
import '../bloc/agent_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _inputController = TextEditingController();

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    
    if (permission == LocationPermission.deniedForever) return Future.error('Location permissions are permanently denied');

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('AI Harvest Assistant', style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
      ),
      body: BlocConsumer<AgentBloc, AgentState>(
        listener: (context, state) {
          if (state is AgentError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state is AgentInitial || state is AgentError) ...[
                  const Spacer(),
                  Text(
                    'What are you harvesting?',
                    style: AppTextStyles.displayMedium.copyWith(color: AppColors.wheat),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Example: "I have 20 MACRO_BINs of Pinot Noir ready, about 2000kg."',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cream2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _inputController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      hintText: 'Enter harvest details...',
                      hintStyle: const TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final pos = await _determinePosition();
                        context.read<AgentBloc>().add(
                          ProcessListing(_inputController.text, GeoPoint(pos.latitude, pos.longitude)),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: const Text('Process Listing'),
                  ),
                  const Spacer(),
                ] else if (state is AgentLoading) ...[
                  const Spacer(),
                  const Center(child: CircularProgressIndicator(color: AppColors.wheat)),
                  const SizedBox(height: 24),
                  Text(
                    'Analyzing your harvest...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat),
                  ),
                  const Spacer(),
                ] else if (state is AgentSuccess) ...[
                  const Spacer(),
                  const Icon(Icons.check_circle_outline, color: AppColors.moss2, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    'Listing Created!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLarge.copyWith(color: AppColors.wheat),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      state.summary,
                      style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => context.go('/listings/${state.listingId}'),
                    child: const Text('View Listing Details'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<AgentBloc>().add(ProcessListing('', const GeoPoint(0, 0))), // Reset-like
                    child: const Text('Create Another', style: TextStyle(color: AppColors.wheat)),
                  ),
                  const Spacer(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
