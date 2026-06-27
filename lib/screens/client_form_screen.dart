import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/mongo_service.dart';

// Top-level so compute() can send it to an isolate.
String _bcryptHash(String password) =>
    BCrypt.hashpw(password, BCrypt.gensalt());

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _archived = false;
  bool _saving = false;

  // Each entry: (typeController, numberController)
  final List<(TextEditingController, TextEditingController)> _phones = [];

  bool get _isUpdate => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (_isUpdate) {
      final c = widget.client!;
      _clientIdCtrl.text = c.clientId;
      _companyCtrl.text = c.companyName;
      _contactCtrl.text = c.contact;
      _emailCtrl.text = c.email;
      _archived = c.archived;
      for (final e in c.phoneNumbers.entries) {
        _phones.add((
          TextEditingController(text: e.key),
          TextEditingController(text: e.value),
        ));
      }
    }
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _companyCtrl.dispose();
    _passwordCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    for (final p in _phones) {
      p.$1.dispose();
      p.$2.dispose();
    }
    super.dispose();
  }

  void _addPhone() => setState(() {
        _phones.add((TextEditingController(), TextEditingController()));
      });

  void _removePhone(int i) {
    final p = _phones[i];
    p.$1.dispose();
    p.$2.dispose();
    setState(() => _phones.removeAt(i));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final phones = {
        for (final p in _phones)
          if (p.$1.text.trim().isNotEmpty) p.$1.text.trim(): p.$2.text.trim(),
      };

      if (_isUpdate) {
        String digest = widget.client!.passwordDigest;
        if (_passwordCtrl.text.isNotEmpty) {
          digest = await compute(_bcryptHash, _passwordCtrl.text);
        }
        await MongoService.instance.updateClient(
          widget.client!.copyWith(
            clientId: _clientIdCtrl.text.trim(),
            companyName: _companyCtrl.text.trim(),
            passwordDigest: digest,
            archived: _archived,
            contact: _contactCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phoneNumbers: phones,
          ),
        );
      } else {
        final digest = await compute(_bcryptHash, _passwordCtrl.text);
        await MongoService.instance.createClient(
          Client(
            clientId: _clientIdCtrl.text.trim(),
            companyName: _companyCtrl.text.trim(),
            passwordDigest: digest,
            archived: false,
            contact: _contactCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phoneNumbers: phones,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_isUpdate ? 'Update Client' : 'Create Client'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _formField(
                      ctrl: _clientIdCtrl,
                      label: 'Client ID',
                      required: true),
                  const SizedBox(height: 16),
                  _formField(
                      ctrl: _companyCtrl,
                      label: 'Company Name',
                      required: true),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: _isUpdate
                          ? 'Password (leave blank to keep current)'
                          : 'Password',
                      border: const OutlineInputBorder(),
                    ),
                    validator: _isUpdate
                        ? null
                        : (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _formField(
                      ctrl: _contactCtrl,
                      label: 'Contact',
                      required: true),
                  const SizedBox(height: 16),
                  _formField(
                      ctrl: _emailCtrl, label: 'Email', required: true),
                  if (_isUpdate) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _archived,
                          onChanged: (v) =>
                              setState(() => _archived = v ?? false),
                        ),
                        const SizedBox(width: 8),
                        const Text('Archived'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Text('Phone Numbers',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _addPhone,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ..._phones.asMap().entries.map((e) {
                    final i = e.key;
                    final (typeCtrl, numCtrl) = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: typeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Type (e.g. landline)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: numCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Number',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _removePhone(i),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: theme.colorScheme.error,
                          iconSize: 20,
                        ),
                      ]),
                    );
                  }),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _formField({
    required TextEditingController ctrl,
    required String label,
    bool required = false,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      );
}
