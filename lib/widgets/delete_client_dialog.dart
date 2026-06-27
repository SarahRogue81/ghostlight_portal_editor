import 'package:flutter/material.dart';

class DeleteClientDialog extends StatefulWidget {
  final String companyName;
  const DeleteClientDialog({super.key, required this.companyName});

  @override
  State<DeleteClientDialog> createState() => _DeleteClientDialogState();
}

class _DeleteClientDialogState extends State<DeleteClientDialog> {
  bool _archiveInstead = true;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this client?',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _archiveInstead,
                  onChanged: (v) =>
                      setState(() => _archiveInstead = v ?? true),
                ),
                const SizedBox(width: 8),
                const Text('Archive instead'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(_archiveInstead),
            child: const Text('OK'),
          ),
        ],
      );
}
