import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/client.dart';
import '../models/client_image.dart';
import '../services/mongo_service.dart';
import '../widgets/delete_client_dialog.dart';
import 'article_editor_screen.dart';
import 'client_form_screen.dart';
import 'images_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Client> _clients = [];
  Client? _selected;
  List<Article> _articles = [];
  List<ClientImage> _images = [];
  bool _loadingClients = true;
  bool _loadingArticles = false;
  bool _loadingImages = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadClients({String? keepClientId}) async {
    setState(() => _loadingClients = true);
    try {
      final clients = await MongoService.instance.getClients();
      Client? reselect;
      if (keepClientId != null) {
        try {
          reselect =
              clients.firstWhere((c) => c.clientId == keepClientId);
        } catch (_) {}
      }
      setState(() {
        _clients = clients;
        _selected = reselect;
        _articles = [];
        _images = [];
        _loadingClients = false;
      });
      if (reselect != null) {
        _loadArticles(reselect.clientId);
        _loadImages(reselect.clientId);
      }
    } catch (e) {
      setState(() => _loadingClients = false);
      _showError('Failed to load clients: $e');
    }
  }

  Future<void> _loadArticles(String clientId) async {
    setState(() => _loadingArticles = true);
    try {
      final articles = await MongoService.instance.getArticles(clientId);
      setState(() {
        _articles = articles;
        _loadingArticles = false;
      });
    } catch (e) {
      setState(() => _loadingArticles = false);
      _showError('Failed to load articles: $e');
    }
  }

  Future<void> _loadImages(String clientId) async {
    setState(() => _loadingImages = true);
    try {
      final images = await MongoService.instance.getImages(clientId);
      setState(() {
        _images = images;
        _loadingImages = false;
      });
    } catch (e) {
      setState(() => _loadingImages = false);
      _showError('Failed to load images: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Client actions ────────────────────────────────────────────────────────

  void _onClientSelected(Client? c) {
    setState(() {
      _selected = c;
      _articles = [];
      _images = [];
    });
    if (c != null) {
      _loadArticles(c.clientId);
      _loadImages(c.clientId);
    }
  }

  Future<void> _handleClientCreate() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientFormScreen(),
        fullscreenDialog: true,
      ),
    );
    if (saved == true) await _loadClients();
  }

  Future<void> _handleClientUpdate() async {
    if (_selected == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientFormScreen(client: _selected!),
        fullscreenDialog: true,
      ),
    );
    if (saved == true) {
      await _loadClients(keepClientId: _selected?.clientId);
    }
  }

  Future<void> _handleClientDelete() async {
    if (_selected == null) return;
    final result = await showDialog<bool?>(
      context: context,
      builder: (_) =>
          DeleteClientDialog(companyName: _selected!.companyName),
    );
    if (result == null) return;
    try {
      if (result) {
        await MongoService.instance.archiveClient(_selected!.id!);
      } else {
        await MongoService.instance.deleteClientAndArticles(
          _selected!.id!,
          _selected!.clientId,
        );
      }
      await _loadClients();
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  // ── Article actions ───────────────────────────────────────────────────────

  Future<void> _openArticleEditor({Article? article}) async {
    if (_selected == null) return;
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleEditorScreen(
          clientId: _selected!.clientId,
          article: article,
        ),
        fullscreenDialog: true,
      ),
    );
    if (published == true && _selected != null) {
      await _loadArticles(_selected!.clientId);
    }
  }

  Future<void> _handleArticleDelete(Article article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await MongoService.instance.deleteArticle(article.id!);
        if (_selected != null) await _loadArticles(_selected!.clientId);
      } catch (e) {
        _showError('Delete failed: $e');
      }
    }
  }

  // ── Image actions ────────────────────────────────────────────────────────

  Future<void> _openImageEditor({ClientImage? image}) async {
    if (_selected == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagesScreen(
          clientId: _selected!.clientId,
          image: image,
        ),
        fullscreenDialog: true,
      ),
    );
    if (saved == true && _selected != null) {
      await _loadImages(_selected!.clientId);
    }
  }

  Future<void> _handleImageDelete(ClientImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await MongoService.instance.deleteImage(image.id!);
        if (_selected != null) await _loadImages(_selected!.clientId);
      } catch (e) {
        _showError('Delete failed: $e');
      }
    }
  }

  Future<void> _showImageContextMenu(
    Offset globalPosition,
    ClientImage image,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'update', child: Text('Update')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (selected == 'update') {
      _openImageEditor(image: image);
    } else if (selected == 'delete') {
      _handleImageDelete(image);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime utc) {
    final d = utc.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GhostLight Portal Editor')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectorRow(),
          if (_selected != null)
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildClientDetails(_selected!),
                    const SizedBox(height: 24),
                    _buildArticlesSection(),
                    const SizedBox(height: 24),
                    _buildImagesSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Selector row ──────────────────────────────────────────────────────────

  Widget _buildSelectorRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: _loadingClients
                ? const LinearProgressIndicator()
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Client>(
                      isExpanded: true,
                      hint: const Text('Select a client…'),
                      value: _selected,
                      items: _clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.companyName),
                            ),
                          )
                          .toList(),
                      onChanged: _onClientSelected,
                    ),
                  ),
          ),
          FilledButton(
            onPressed: _handleClientCreate,
            child: const Text('Create'),
          ),
          FilledButton(
            onPressed: _selected != null ? _handleClientUpdate : null,
            child: const Text('Update'),
          ),
          FilledButton(
            style: _selected != null
                ? FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.error,
                    foregroundColor:
                        Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: _selected != null ? _handleClientDelete : null,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Client details ────────────────────────────────────────────────────────

  Widget _buildClientDetails(Client c) {
    final left = <(String, String)>[
      ('Client ID', c.clientId),
      ('Company Name', c.companyName),
      ('Contact', c.contact),
      ('Email', c.email),
    ];
    final right = <(String, String)>[
      ('Archived', c.archived ? 'Yes' : 'No'),
      ...c.phoneNumbers.entries
          .map((e) => ('Phone — ${e.key}', e.value)),
    ];
    final all = [...left, ...right];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return _detailCard(all);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _detailCard(left)),
          const SizedBox(width: 16),
          Expanded(child: _detailCard(right)),
        ],
      );
    });
  }

  Widget _detailCard(List<(String, String)> fields) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            f.$1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(f.$2),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );

  // ── Articles section ──────────────────────────────────────────────────────

  Widget _buildArticlesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Articles',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_loadingArticles)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_articles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No articles yet.')),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Modified')),
                DataColumn(label: Text('')),
              ],
              rows: _articles
                  .map(
                    (a) => DataRow(cells: [
                      DataCell(Text(a.title)),
                      DataCell(Text(_fmtDate(a.created))),
                      DataCell(Text(_fmtDate(a.modified))),
                      DataCell(
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            if (v == 'update') {
                              _openArticleEditor(article: a);
                            } else if (v == 'delete') {
                              _handleArticleDelete(a);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'update',
                              child: Text('Update'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _openArticleEditor(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Article'),
          ),
        ),
      ],
    );
  }

  // ── Images section ────────────────────────────────────────────────────────

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Images', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_loadingImages)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_images.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No images yet.')),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _images.map(_buildImageThumbnail).toList(),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _openImageEditor(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Image'),
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(ClientImage image) {
    return GestureDetector(
      onLongPressStart: (details) =>
          _showImageContextMenu(details.globalPosition, image),
      onSecondaryTapDown: (details) =>
          _showImageContextMenu(details.globalPosition, image),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: image.data.isNotEmpty
                ? Image.memory(image.data, fit: BoxFit.cover)
                : const Icon(Icons.broken_image),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 100,
            child: Text(
              image.filename,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
