import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/client_image.dart';
import '../services/mongo_service.dart';

class ImagesScreen extends StatefulWidget {
  final String clientId;
  final ClientImage? image;

  const ImagesScreen({
    super.key,
    required this.clientId,
    this.image,
  });

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final _filenameCtrl = TextEditingController();
  final _filenameFocus = FocusNode();

  Uint8List? _pickedBytes;
  String? _pickedMimeType;

  // The other existing image doc (different id) whose filename collides
  // with the one currently typed. When set, saving will overwrite it.
  ClientImage? _matchedExistingImage;
  String? _confirmedOverwriteFilename;

  bool _saving = false;

  bool get _isUpdate => widget.image != null;

  @override
  void initState() {
    super.initState();
    if (widget.image != null) {
      _filenameCtrl.text = widget.image!.filename;
      _pickedBytes = widget.image!.data;
      _pickedMimeType = widget.image!.mimeType;
    }
    _filenameFocus.addListener(() {
      if (!_filenameFocus.hasFocus) _handleFilenameFocusLost();
    });
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    _filenameFocus.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _mimeTypeForExtension(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'application/octet-stream';
    }
  }

  // ── Filename existence check ─────────────────────────────────────────────

  Future<void> _handleFilenameFocusLost() async {
    final name = _filenameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _matchedExistingImage = null);
      return;
    }

    ClientImage? match;
    try {
      match = await MongoService.instance.findImageByFilename(
        widget.clientId,
        name,
        excludeId: widget.image?.id,
      );
    } catch (e) {
      _showError('Failed to check filename: $e');
      return;
    }
    if (!mounted) return;

    if (!_isUpdate) {
      setState(() => _matchedExistingImage = match);
      return;
    }

    // Update flow: confirm before allowing an overwrite of a different doc.
    if (match == null) {
      setState(() {
        _matchedExistingImage = null;
        _confirmedOverwriteFilename = null;
      });
      return;
    }
    if (_confirmedOverwriteFilename == name) {
      setState(() => _matchedExistingImage = match);
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite Existing Image?'),
        content: const Text('This will overwrite the existing file'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (proceed == true) {
      setState(() {
        _confirmedOverwriteFilename = name;
        _matchedExistingImage = match;
      });
    } else {
      setState(() {
        _confirmedOverwriteFilename = null;
        _matchedExistingImage = null;
      });
      FocusScope.of(context).requestFocus(_filenameFocus);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) {
      _showError('Could not read the selected file.');
      return;
    }

    setState(() {
      _pickedBytes = bytes;
      _pickedMimeType = _mimeTypeForExtension(file.extension);
      _filenameCtrl.text = file.name;
    });
    await _handleFilenameFocusLost();
  }

  Future<void> _handleSave() async {
    final filename = _filenameCtrl.text.trim();
    if (filename.isEmpty) {
      _showError('Filename is required.');
      return;
    }
    if (_pickedBytes == null || _pickedBytes!.isEmpty) {
      _showError('Please select an image.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isUpdate) {
        if (_matchedExistingImage != null) {
          await MongoService.instance.deleteImage(_matchedExistingImage!.id!);
        }
        await MongoService.instance.updateImage(ClientImage(
          id: widget.image!.id,
          clientId: widget.clientId,
          filename: filename,
          mimeType: _pickedMimeType ?? widget.image!.mimeType,
          data: _pickedBytes!,
        ));
      } else if (_matchedExistingImage != null) {
        await MongoService.instance.updateImage(ClientImage(
          id: _matchedExistingImage!.id,
          clientId: widget.clientId,
          filename: filename,
          mimeType: _pickedMimeType ?? _matchedExistingImage!.mimeType,
          data: _pickedBytes!,
        ));
      } else {
        await MongoService.instance.createImage(ClientImage(
          clientId: widget.clientId,
          filename: filename,
          mimeType: _pickedMimeType ?? 'application/octet-stream',
          data: _pickedBytes!,
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Error saving image: $e');
      setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final actionLabel =
        (_isUpdate || _matchedExistingImage != null) ? 'Update' : 'Create';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdate ? 'Update Image' : 'Add Image'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _filenameCtrl,
              focusNode: _filenameFocus,
              decoration: const InputDecoration(
                labelText: 'Filename',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_pickedBytes != null && _pickedBytes!.isNotEmpty)
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Select Image'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
