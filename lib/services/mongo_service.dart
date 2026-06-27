import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/client.dart';
import '../models/article.dart';

class MongoService {
  static MongoService? _instance;

  static MongoService get instance {
    assert(_instance != null, 'MongoService.connect() has not been called');
    return _instance!;
  }

  final Db _db;
  MongoService._(this._db);

  // ── SRV resolution ────────────────────────────────────────────────────────
  //
  // mongo_dart does not support the mongodb+srv:// scheme, so we resolve
  // SRV and TXT records manually via Cloudflare DNS-over-HTTPS and produce
  // an equivalent mongodb:// URI that mongo_dart can consume.

  static Future<String> _toDirectUri(String uri) async {
    if (!uri.toLowerCase().startsWith('mongodb+srv://')) return uri;
    return _resolveSrv(uri);
  }

  static Future<String> _resolveSrv(String srvUri) async {
    final parsed = Uri.parse(srvUri);
    final host = parsed.host;

    // Step 1: SRV records → actual host:port list
    final srvAnswers = await _dohLookup('_mongodb._tcp.$host', 'SRV');
    if (srvAnswers.isEmpty) {
      throw Exception(
        'DNS SRV lookup returned no records for _mongodb._tcp.$host\n'
        'Check your internet connection.',
      );
    }
    final hostList = srvAnswers.map((data) {
      // SRV rdata: "priority weight port target."
      final parts = data.trim().split(' ');
      var target = parts[3];
      if (target.endsWith('.')) target = target.substring(0, target.length - 1);
      return '$target:${parts[2]}';
    }).join(',');

    // Step 2: TXT record → authSource + replicaSet options
    final txtAnswers = await _dohLookup(host, 'TXT');
    final txtOptions = txtAnswers.isEmpty
        ? 'authSource=admin'
        : txtAnswers.first.replaceAll('"', '').trim();

    // Step 3: rebuild as mongodb://
    final dbName = parsed.path.startsWith('/')
        ? parsed.path.substring(1)
        : parsed.path;
    final extra = parsed.query.isNotEmpty ? '&${parsed.query}' : '';

    return 'mongodb://${parsed.userInfo}@$hostList/$dbName'
        '?tls=true&$txtOptions$extra';
  }

  /// Queries Cloudflare DNS-over-HTTPS and returns the data fields of
  /// all Answer records. Returns empty list on any error.
  static Future<List<String>> _dohLookup(String name, String type) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(
            'https://cloudflare-dns.com/dns-query'
            '?name=${Uri.encodeComponent(name)}&type=$type',
          ))
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final body = await response.transform(const Utf8Decoder()).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ((json['Answer'] as List?) ?? [])
          .map((a) => (a as Map<String, dynamic>)['data'] as String)
          .toList();
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  // ── Connection ────────────────────────────────────────────────────────────

  /// Returns (success, errorMessage). errorMessage is null on success.
  static Future<(bool, String?)> testConnection(String uri) async {
    Db? db;
    try {
      db = Db(await _toDirectUri(uri));
      await db.open().timeout(const Duration(seconds: 30));
      return (true, null);
    } on TimeoutException {
      return (false,
          'Timed out after 30 s.\n'
          'Check your network and Atlas → Network Access → IP Allow List.');
    } catch (e) {
      return (false, e.toString());
    } finally {
      await db?.close().catchError((_) {});
    }
  }

  static Future<void> connect(String uri) async {
    await _instance?._db.close().catchError((_) {});
    final db = Db(await _toDirectUri(uri));
    await db.open().timeout(const Duration(seconds: 30));
    _instance = MongoService._(db);
  }

  DbCollection get _clients => _db.collection('clients');
  DbCollection get _articles => _db.collection('articles');

  // ── Clients ──────────────────────────────────────────────────────────────

  Future<List<Client>> getClients() async {
    final docs =
        await _clients.find(where.sortBy('company_name')).toList();
    return docs.map(Client.fromMap).toList();
  }

  Future<void> createClient(Client client) =>
      _clients.insertOne(client.toMap());

  Future<void> updateClient(Client client) async {
    final data = client.toMap()..remove('_id');
    await _clients.updateOne(where.id(client.id!), {'\$set': data});
  }

  Future<void> archiveClient(ObjectId id) =>
      _clients.updateOne(where.id(id), {'\$set': {'archived': true}});

  Future<void> deleteClientAndArticles(ObjectId id, String clientId) async {
    await _clients.deleteOne(where.id(id));
    await _articles.deleteMany(where.eq('client_id', clientId));
  }

  // ── Articles ─────────────────────────────────────────────────────────────

  Future<List<Article>> getArticles(String clientId) async {
    final docs = await _articles
        .find(
          where
              .eq('client_id', clientId)
              .sortBy('modified', descending: true),
        )
        .toList();
    return docs.map(Article.fromMap).toList();
  }

  Future<void> createArticle(Article article) =>
      _articles.insertOne(article.toMap());

  Future<void> updateArticle(Article article) async {
    final data = article.toMap()..remove('_id');
    await _articles.updateOne(where.id(article.id!), {'\$set': data});
  }

  Future<void> deleteArticle(ObjectId id) =>
      _articles.deleteOne(where.id(id));
}
