import 'package:flutter/material.dart';
import '../services/mongo_service.dart';
import '../services/storage_service.dart';

class UriDialog extends StatefulWidget {
  const UriDialog({super.key});

  @override
  State<UriDialog> createState() => _UriDialogState();
}

class _UriDialogState extends State<UriDialog> {
  final _controller = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final uri = _controller.text.trim();
    if (uri.isEmpty) return;
    setState(() {
      _testing = true;
      _error = null;
    });
    final (ok, errMsg) = await MongoService.testConnection(uri);
    if (!mounted) return;
    if (ok) {
      await MongoService.connect(uri);
      await StorageService.saveMongoUri(uri);
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _testing = false;
        _error = errMsg ?? 'Connection failed.';
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('MongoDB Connection Required'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter your MongoDB connection URI to continue.'),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  SelectableText(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: 'monospace',
                        fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _controller,
                  enabled: !_testing,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'MongoDB URI',
                    hintText: 'mongodb+srv://user:pass@cluster.mongodb.net/dbname',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                if (_testing) ...[
                  const SizedBox(height: 16),
                  const Row(children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Testing connection…'),
                  ]),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: _testing ? null : _connect,
              child: const Text('Connect'),
            ),
          ],
        ),
      );
}
