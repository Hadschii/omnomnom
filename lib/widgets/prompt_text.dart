import 'package:flutter/material.dart';

/// A single-text-field AlertDialog: enter a name, Cancel or confirm. Returns
/// the trimmed text, or null if cancelled/empty. [confirmLabel] is the
/// action button text (e.g. "Create", "Save").
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirmLabel = 'Save',
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(confirmLabel)),
      ],
    ),
  );
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
