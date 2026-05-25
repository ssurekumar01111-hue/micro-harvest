import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin/core/constants/app_colors.dart';

class ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final bool hasNoteField;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.hasNoteField = false,
  });

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: GoogleFonts.playfairDisplay()),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(widget.message, style: GoogleFonts.dmSans()),
            if (widget.hasNoteField) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Admin Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel', style: GoogleFonts.dmSans(color: AppColors.stone)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.moss,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm();
          },
          child: Text('Confirm', style: GoogleFonts.dmSans(color: Colors.white)),
        ),
      ],
    );
  }
}

