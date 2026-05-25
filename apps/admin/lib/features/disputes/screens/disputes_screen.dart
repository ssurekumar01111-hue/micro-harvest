import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/status_badge.dart';
import 'package:admin/core/widgets/confirm_dialog.dart';
import 'package:admin/features/disputes/bloc/disputes_bloc.dart';

import 'package:admin/core/widgets/data_table_card.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  final List<String> _disputeFilterTabs = ['ALL', 'OPEN', 'RESOLVED', 'DISMISSED'];

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  String _formatCurrency(double amount) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_US');
    return formatCurrency.format(amount);
  }

  void _resolveDispute(BuildContext context, String disputeId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController adminNoteController = TextEditingController();
        return ConfirmDialog(
          title: 'Resolve Dispute',
          message: 'Enter admin note for resolving this dispute:',
          hasNoteField: true,
          onConfirm: () {
            context.read<DisputesBloc>().add(
                  ResolveDispute(
                    disputeId: disputeId,
                    adminNote: adminNoteController.text,
                  ),
                );
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _dismissDispute(BuildContext context, String disputeId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController adminNoteController = TextEditingController();
        return ConfirmDialog(
          title: 'Dismiss Dispute',
          message: 'Enter admin note for dismissing this dispute:',
          hasNoteField: true,
          onConfirm: () {
            context.read<DisputesBloc>().add(
                  DismissDispute(
                    disputeId: disputeId,
                    adminNote: adminNoteController.text,
                  ),
                );
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DisputesBloc()..add(const FilterDisputes(status: 'ALL')),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Disputes',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.bark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
        body: BlocBuilder<DisputesBloc, DisputesState>(
          builder: (context, state) {
            if (state is DisputesLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is DisputesError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is DisputesLoaded) {
              return Column(
                children: [
                  // Filter Tabs
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _disputeFilterTabs
                              .map(
                                (tabStatus) => ChoiceChip(
                                  label: Text(tabStatus),
                                  selected: state.selectedFilterStatus == tabStatus,
                                  onSelected: (bool selected) {
                                    if (selected) {
                                      context.read<DisputesBloc>().add(FilterDisputes(status: tabStatus));
                                    }
                                  },
                                  selectedColor: AppColors.moss,
                                  labelStyle: GoogleFonts.dmSans(
                                    color: state.selectedFilterStatus == tabStatus
                                        ? Colors.white
                                        : AppColors.bark,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),

                  // Disputes Data Table
                  Expanded(
                    child: DataTableCard(
                      title: 'All Disputes',
                      showCheckboxColumn: false,
                      expand: true,
                      headers: const [
                        'Handoff ID',
                        'Crop',
                        'Grower',
                        'Producer',
                        'Amount',
                        'Raised Date',
                        'Status',
                        'Actions'
                      ],
                      rows: state.disputes.map((dispute) {
                        final String disputeId = dispute['id'] ?? 'N/A';
                        final String status = dispute['status'] ?? 'UNKNOWN';
                        final bool isOpen = status == 'OPEN' || status == 'RAISED';
                        final handoff = dispute['_handoff'] as Map<String, dynamic>?;
                        final handoffId = dispute['handoffId'] as String? ?? 'N/A';

                        return DataRow(
                          cells: [
                            DataCell(Text(handoffId.length >= 8
                                ? handoffId.substring(handoffId.length - 8)
                                : handoffId)),
                            DataCell(Text(handoff?['cropType'] ?? 'N/A')),
                            DataCell(Text(handoff?['growerName'] ?? 'N/A')),
                            DataCell(Text(handoff?['producerName'] ?? 'N/A')),
                            DataCell(Text(_formatCurrency(
                                (handoff?['payment']?['totalUSD'] as num?)?.toDouble() ?? 0.0))),
                            DataCell(Text(_formatDateTime(dispute['raisedAt'] as Timestamp?))),
                            DataCell(StatusBadge(status: status)),
                            DataCell(Row(
                              children: [
                                if (isOpen) ...[
                                  TextButton(
                                    onPressed: () => _resolveDispute(context, disputeId),
                                    child: const Text('Resolve'),
                                  ),
                                  TextButton(
                                    onPressed: () => _dismissDispute(context, disputeId),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                                    child: const Text('Dismiss'),
                                  ),
                                ] else ...[
                                  Text(dispute['adminNote'] ?? 'N/A', 
                                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                                ],
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

