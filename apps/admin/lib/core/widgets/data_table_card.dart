import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin/core/constants/app_colors.dart';

class DataTableCard extends StatelessWidget {
  final String title;
  final List<String> headers;
  final List<DataRow> rows;
  final Widget? trailing;
  final bool showCheckboxColumn;
  final bool expand;

  const DataTableCard({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
    this.trailing,
    this.showCheckboxColumn = true,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget tableContent = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.cream),
          columnSpacing: 56,
          horizontalMargin: 12,
          showCheckboxColumn: showCheckboxColumn,
          columns: headers
              .map(
                (header) => DataColumn(
                  label: Text(
                    header,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      color: AppColors.bark,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
              .toList(),
          rows: rows,
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            if (expand) Expanded(child: tableContent) else tableContent,
          ],
        ),
      ),
    );
  }
}

