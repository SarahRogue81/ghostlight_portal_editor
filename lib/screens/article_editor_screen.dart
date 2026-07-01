import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_js/flutter_js.dart';
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

  JavascriptRuntime? _jsRuntime;
  bool _asciidoctorLoaded = false;

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
    _jsRuntime?.dispose();
    super.dispose();
  }

  static final Map<String, Style> _previewStyle = {
    'body': Style(
      color: Colors.white,
      backgroundColor: Colors.black,
      lineHeight: LineHeight.number(1.7),
    ),
    for (final tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
      tag: Style(color: Colors.white),
    'code': Style(
      backgroundColor: const Color(0xFF1E1E1E),
      padding: HtmlPaddings.symmetric(horizontal: 5),
    ),
    'pre': Style(
      backgroundColor: const Color(0xFF1E1E1E),
      padding: HtmlPaddings.all(12),
    ),
    'blockquote': Style(
      color: const Color(0xFFCCCCCC),
      padding: HtmlPaddings.only(left: 16),
      border: const Border(
        left: BorderSide(color: Color(0xFF555555), width: 4),
      ),
    ),
    'th': Style(
      backgroundColor: const Color(0xFF1E1E1E),
      fontWeight: FontWeight.w600,
      border: Border.all(color: const Color(0xFF444444)),
    ),
    'td': Style(border: Border.all(color: const Color(0xFF444444))),
    'a': Style(color: const Color(0xFF7AADFF)),
  };

  JsEvalResult _convertAsciidocToHtml(String asciidoc) {
    final runtime = _jsRuntime!;
    final encodedContent = jsonEncode(asciidoc);
    return runtime.evaluate('''
      (function() {
        try {
          var adoc = Asciidoctor();
          return adoc.convert($encodedContent, { safe: 'safe', attributes: { showtitle: '' } });
        } catch (e) {
          return '<p style="color:red"><b>Preview error:</b> ' + e.message + '</p>';
        }
      })();
    ''');
  }

  Future<void> _togglePreview() async {
    if (_previewing) {
      setState(() {
        _previewing = false;
        _previewHtml = null;
      });
      return;
    }
    try {
      final js = await _fetchAsciidoctorJs();
      _jsRuntime ??= getJavascriptRuntime();
      if (!_asciidoctorLoaded) {
        final loadResult = _jsRuntime!.evaluate(js);
        if (loadResult.isError) {
          throw Exception(loadResult.stringResult);
        }
        _asciidoctorLoaded = true;
      }
      final result = _convertAsciidocToHtml(_contentCtrl.text);
      if (!mounted) return;
      setState(() {
        _previewHtml = result.stringResult;
        _previewing = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not render preview: $e')),
      );
    }
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
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Html(
          data: _previewHtml!,
          style: _previewStyle,
        ),
      ),
    );
  }
}
