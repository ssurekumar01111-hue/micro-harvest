import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/data_table_card.dart';
import 'package:admin/features/handoffs/bloc/handoffs_bloc.dart';

class HandoffsScreen extends StatefulWidget {
  const HandoffsScreen({super.key});

  @override
  State<HandoffsScreen> createState() => _HandoffsScreenState();
}

class _HandoffsScreenState extends State<HandoffsScreen> {
  String? _selectedStatusFilter;
  bool _showDetails = false;
  Map<String, dynamic>? _selectedHandoff;

  final List<String> _handoffStatuses = [
    'ALL',
    'MATCHED',
    'IN_TRANSIT',
    'SETTLED',
    'DISPUTED'
  ];

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is String) {
      try {
        return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(timestamp));
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'N/A';
  }

  String _formatCurrency(double amount) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_US');
    return formatCurrency.format(amount);
  }

  String _getStatus(Map<String, dynamic> handoff) {
    final payment = handoff['payment'] as Map<String, dynamic>?;
    final releasedAt = payment?['releasedAt'];
    final gate2 = handoff['gate2'];
    final gate1 = handoff['gate1'];

    if (releasedAt != null) return 'SETTLED';
    if (gate2 != null) return 'DELIVERED';
    if (gate1 != null) return 'IN_TRANSIT';
    return 'PENDING';
  }

  void _applyFilters() {
    context.read<HandoffsBloc>().add(
          FilterHandoffs(
            status: _selectedStatusFilter,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Handoffs',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.bark,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<HandoffsBloc, HandoffsState>(
        builder: (context, state) {
          if (state is HandoffsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HandoffsError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is HandoffsLoaded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Wrap(
                        spacing: 16.0,
                        runSpacing: 16.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<String>(
                            value: _selectedStatusFilter,
                            hint: const Text('Status'),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedStatusFilter = newValue;
                              });
                              _applyFilters();
                            },
                            items: _handoffStatuses
                                .map<DropdownMenuItem<String>>(
                                    (String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: DataTableCard(
                    title: 'All Handoffs',
                    showCheckboxColumn: false,
                    expand: true,
                    headers: const [
                      'ID',
                      'Crop',
                      'Route (Grower→Producer)',
                      'Transporter',
                      'Gate1',
                      'Gate2',
                      'Amount',
                      'Status'
                    ],
                    rows: state.handoffs.map((handoff) {
                      final String handoffId = handoff['handoffId'] ?? handoff['id'] ?? 'N/A';
                      final bool isSelected = _selectedHandoff?['id'] == handoff['id'];
                      final payment = handoff['payment'] as Map<String, dynamic>?;

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Text(handoffId.length > 8
                              ? handoffId.substring(handoffId.length - 8)
                              : handoffId)),
                          DataCell(Text(handoff['_cropType'] ?? 'N/A')),
                          DataCell(Text(
                              '${handoff['_growerName'] ?? 'N/A'} → ${handoff['_producerName'] ?? 'N/A'}')),
                          DataCell(Text(handoff['_transporterName'] ?? 'N/A')),
                          DataCell(Center(
                            child: handoff['gate1'] != null
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                : const Text('—', style: TextStyle(color: Colors.grey)),
                          )),
                          DataCell(Center(
                            child: handoff['gate2'] != null
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                : const Text('—', style: TextStyle(color: Colors.grey)),
                          )),
                          DataCell(Text(_formatCurrency(
                              (payment?['totalUSD'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(_buildStatusBadge(handoff)),
                        ],
                        onSelectChanged: (_) {
                          setState(() {
                            if (isSelected) {
                              _showDetails = false;
                              _selectedHandoff = null;
                            } else {
                              _showDetails = true;
                              _selectedHandoff = handoff;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

                if (_showDetails && _selectedHandoff != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SingleChildScrollView(
                        child: _buildExpandedHandoffDetails(context, _selectedHandoff!),
                      ),
                    ),
                  ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> handoff) {
    final status = _getStatus(handoff);
    
    Color badgeColor = Colors.grey;
    if (status == 'SETTLED') badgeColor = Colors.green;
    if (status == 'DELIVERED') badgeColor = Colors.blue;
    if (status == 'IN_TRANSIT') badgeColor = Colors.orange;
    if (status == 'PENDING') badgeColor = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildExpandedHandoffDetails(
      BuildContext context, Map<String, dynamic> handoff) {
    final payment = handoff['payment'] as Map<String, dynamic>?;
    final gate1 = handoff['gate1'] as Map<String, dynamic>?;
    final gate2 = handoff['gate2'] as Map<String, dynamic>?;
    final contractHash = handoff['contractHash'] as String?;
    
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Handoff Details',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _showDetails = false;
                    _selectedHandoff = null;
                  }),
                ),
              ],
            ),
            const Divider(height: 32),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Full Handoff ID', handoff['id'] ?? 'N/A'),
                      _buildDetailRow('Listing ID', handoff['listingId'] ?? 'N/A'),
                      _buildDetailRow('Contract Hash', contractHash != null 
                          ? (contractHash.length > 16 ? contractHash.substring(0, 16) : contractHash)
                          : 'N/A'),
                      _buildDetailRow('Dispute Status', handoff['disputeStatus'] ?? 'None'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Gate 1 Confirmed', _formatDateTime(gate1?['confirmedAt'])),
                      _buildDetailRow('Gate 2 Confirmed', _formatDateTime(gate2?['confirmedAt'])),
                      _buildDetailRow('Stripe Payment ID', payment?['stripePaymentId'] ?? 'N/A'),
                      _buildDetailRow('Settlement Date', _formatDateTime(payment?['releasedAt'])),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            Text(
              'Payment Breakdown',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.bark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPaymentRow('Total Amount', (payment?['totalUSD'] as num?)?.toDouble() ?? 0.0, isTotal: true),
                  const Divider(),
                  _buildPaymentRow('Grower Share (80%)', (payment?['growerShareUSD'] as num?)?.toDouble() ?? 0.0),
                  _buildPaymentRow('Transporter Fee (15%)', (payment?['transporterFeeUSD'] as num?)?.toDouble() ?? 0.0),
                  _buildPaymentRow('Platform Fee (5%)', (payment?['platformFeeUSD'] as num?)?.toDouble() ?? 0.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.dmSans(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? AppColors.bark : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.bark,
            ),
          ),
        ],
      ),
    );
  }
}

