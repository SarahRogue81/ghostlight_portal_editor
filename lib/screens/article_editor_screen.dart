import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/article.dart';
import '../services/mongo_service.dart';

class ArticleEditorScreen extends StatefulWidget {
  final String clientId;
  final Article? article;

  const ArticleEditorScreen({
    super.key,
    required this.clientId,
    this.article,
  });

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  static String? _cachedJs;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _previewing = false;
  bool _publishing = false;
  String? _previewHtml;

  bool get _isUpdate => widget.article != null;

  static Future<String> _fetchAsciidoctorJs() async {
    if (_cachedJs != null) return _cachedJs!;
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(
        'https://cdn.jsdelivr.net/npm/@asciidoctor/core@2.2.6/dist/browser/asciidoctor.min.js',
      ));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw Exception('CDN returned HTTP ${res.statusCode}');
      }
      final js = await res.transform(const Utf8Decoder()).join();
      if (!js.contains('Asciidoctor')) {
        throw Exception(
          'Response does not look like asciidoctor.js '
          '(${js.length} chars). First 100: "${js.substring(0, js.length.clamp(0, 100))}"',
        );
      }
      _cachedJs = js;
      return _cachedJs!;
    } finally {
      client.close();
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isUpdate) {
      _titleCtrl.text = widget.article!.title;
      _contentCtrl.text = widget.article!.asciidocContent;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  static const _previewBaseHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 1.5em 2em;
      max-width: 900px;
      margin: 0 auto;
      line-height: 1.7;
      background: #000000;
      color: #ffffff;
    }
    h1,h2,h3,h4,h5,h6 { line-height: 1.3; margin-top: 1.4em; color: #ffffff; }
    code { background:#1e1e1e; padding:2px 5px; border-radius:3px; font-size:.9em; }
    pre  { background:#1e1e1e; padding:1em; border-radius:4px; overflow-x:auto; }
    blockquote { border-left:4px solid #555; margin:0; padding-left:1em; color:#cccccc; }
    table { border-collapse:collapse; width:100%; margin:1em 0; }
    th,td { border:1px solid #444; padding:8px 12px; text-align:left; }
    th { background:#1e1e1e; font-weight:600; }
    img { max-width:100%; }
    a { color:#7aadff; }
  </style>
</head>
<body>
  <div id="content"></div>
</body>
</html>''';

  Future<void> _togglePreview() async {
    if (_previewing) {
      setState(() {
        _previewing = false;
        _previewHtml = null;
      });
      return;
    }
    try {
      await _fetchAsciidoctorJs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fetch asciidoctor.js: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _previewHtml = _previewBaseHtml;
      _previewing = true;
    });
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('All changes will be lost!'),
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
    if (confirmed == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are both required.')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final now = DateTime.now().toUtc();
      if (_isUpdate) {
        await MongoService.instance.updateArticle(
          Article(
            id: widget.article!.id,
            clientId: widget.article!.clientId,
            title: _titleCtrl.text.trim(),
            created: widget.article!.created,
            modified: now,
            asciidocContent: _contentCtrl.text,
          ),
        );
      } else {
        await MongoService.instance.createArticle(
          Article(
            clientId: widget.clientId,
            title: _titleCtrl.text.trim(),
            created: now,
            modified: now,
            asciidocContent: _contentCtrl.text,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving article: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_isUpdate ? 'Edit Article' : 'New Article'),
          actions: [
            TextButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
            TextButton(
              onPressed: _togglePreview,
              child: Text(_previewing ? 'Go Back' : 'Preview'),
            ),
            TextButton(
              onPressed: _publishing ? null : _handleCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _previewing ? _buildPreviewBody() : _buildEditorBody(),
      ),
    );
  }

  Widget _buildEditorBody() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Write AsciiDoc content here…',
                  alignLabelWithHint: true,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildPreviewBody() {
    if (_previewHtml == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = _contentCtrl.text;
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _previewHtml!,
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
      ),
      onLoadStop: (controller, _) async {
        // Inject via a dynamic <script> element so the library runs in the
        // page's true global scope (avoids UMD module-detection false positives
        // that occur when using evaluateJavascript directly).
        await controller.evaluateJavascript(source: '''
          (function() {
            var s = document.createElement('script');
            s.textContent = ${jsonEncode(_cachedJs!)};
            document.head.appendChild(s);
          })();
        ''');
        await controller.evaluateJavascript(source: '''
          try {
            var adoc = Asciidoctor();
            document.getElementById('content').innerHTML =
              adoc.convert(${jsonEncode(content)}, { safe: 'safe' });
          } catch (e) {
            document.getElementById('content').innerHTML =
              '<p style="color:red"><b>Preview error:</b> ' + e.message + '</p>';
          }
        ''');
      },
    );
  }
}
