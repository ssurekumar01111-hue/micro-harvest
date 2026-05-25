import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/data_table_card.dart';
import 'package:admin/core/widgets/status_badge.dart';
import 'package:admin/core/widgets/confirm_dialog.dart';
import 'package:admin/features/users/bloc/users_bloc.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String? _selectedRoleFilter;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _userRoles = [
    'ALL',
    'GROWER',
    'PRODUCER',
    'TRANSPORTER',
    'ADMIN'
  ];

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  String _maskPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.length < 10) return phoneNumber ?? 'N/A';
    // Assuming +91 format, mask middle 6 digits
    return '${phoneNumber.substring(0, 3)} ******${phoneNumber.substring(9)}';
  }

  void _applyFilters() {
    context.read<UsersBloc>().add(
          FilterUsers(
            role: _selectedRoleFilter,
            query: _searchController.text,
          ),
        );
  }

  void _clearFilters() {
    setState(() {
      _selectedRoleFilter = null;
      _searchController.clear();
    });
    context.read<UsersBloc>().add(LoadUsers());
  }

  void _suspendUser(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmDialog(
          title: 'Confirm User Suspension',
          message: 'Are you sure you want to suspend this user?',
          onConfirm: () {
            context.read<UsersBloc>().add(SuspendUser(uid: uid));
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _reactivateUser(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmDialog(
          title: 'Confirm User Reactivation',
          message: 'Are you sure you want to reactivate this user?',
          onConfirm: () {
            context.read<UsersBloc>().add(ReactivateUser(uid: uid));
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UsersBloc()..add(LoadUsers()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Users',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.bark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
        body: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is UsersLoaded) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Bar
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
                              value: _selectedRoleFilter,
                              hint: const Text('Role'),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedRoleFilter = newValue;
                                });
                              },
                              items: _userRoles
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                            SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  labelText: 'Search Name or Phone',
                                  isDense: true,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _applyFilters,
                              child: const Text('Apply Filters'),
                            ),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Users Data Table
                  Expanded(
                    child: DataTableCard(
                      title: 'All Users',
                      showCheckboxColumn: false,
                      expand: true,
                      headers: const [
                        'Display Name',
                        'Role',
                        'Phone',
                        'Location',
                        'Member Since',
                        'Status',
                        'Actions'
                      ],
                      rows: state.users.map((user) {
                        final String uid = user['uid'] ?? 'N/A';
                        final bool isSuspended = user['suspended'] ?? false;
                        final String role = user['role'] ?? 'N/A';
                        final String geohash = user['geohash'] ?? 'N/A';
                        final String location = geohash != 'N/A' 
                            ? (geohash.length > 8 ? geohash.substring(0, 8) : geohash)
                            : (user['city'] ?? 'N/A');

                        return DataRow(
                          color: isSuspended
                              ? WidgetStateProperty.all(
                                  AppColors.rust.withValues(alpha: 0.1))
                              : null,
                          cells: [
                            DataCell(Text(user['displayName'] ?? user['name'] ?? 'N/A')),
                            DataCell(StatusBadge(status: role)),
                            DataCell(Text(_maskPhoneNumber(user['phoneNumber']))),
                            DataCell(Text(location)),
                            DataCell(Text(_formatDateTime(user['createdAt'] as Timestamp?))),
                            DataCell(StatusBadge(status: isSuspended ? 'SUSPENDED' : 'ACTIVE')),
                            DataCell(Row(
                              children: [
                                if (isSuspended)
                                  TextButton(
                                    onPressed: () => _reactivateUser(context, uid),
                                    child: const Text('Reactivate'),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => _suspendUser(context, uid),
                                    child: const Text('Suspend'),
                                  ),
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

