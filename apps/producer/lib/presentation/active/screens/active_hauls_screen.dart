import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../confirm/bloc/confirm_bloc.dart';
import '../../confirm/bloc/confirm_event.dart';
import '../../confirm/bloc/confirm_state.dart';
import '../../widgets/bottom_nav.dart';

class ActiveHaulsScreen extends StatefulWidget {
  const ActiveHaulsScreen({super.key});

  @override
  State<ActiveHaulsScreen> createState() => _ActiveHaulsScreenState();
}

class _ActiveHaulsScreenState extends State<ActiveHaulsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConfirmBloc>().add(LoadPendingDeliveries());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(),
      appBar: AppBar(title: const Text('Active Hauls')),
      body: BlocBuilder<ConfirmBloc, ConfirmState>(
        builder: (context, state) {
          if (state is ConfirmLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ConfirmLoaded) {
            if (state.handoffs.isEmpty) {
              return const Center(child: Text('No active hauls found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: state.handoffs.length,
              itemBuilder: (context, index) {
                final handoff = state.handoffs[index];
                return Card(
                  child: ListTile(
                    title: Text('Handoff #${handoff['handoffId'].substring(0, 8)}'),
                    subtitle: Text('Status: ${handoff['gate1'] != null ? 'In Transit' : 'Locked'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to confirm screen if ready for gate 2
                    },
                  ),
                );
              },
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }
}
