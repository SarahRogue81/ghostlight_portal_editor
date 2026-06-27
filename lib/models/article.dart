import 'package:mongo_dart/mongo_dart.dart';

class Article {
  final ObjectId? id;
  final String clientId;
  final String title;
  final DateTime created;
  final DateTime modified;
  final String asciidocContent;

  const Article({
    this.id,
    required this.clientId,
    required this.title,
    required this.created,
    required this.modified,
    required this.asciidocContent,
  });

  factory Article.fromMap(Map<String, dynamic> map) => Article(
        id: map['_id'] as ObjectId?,
        clientId: (map['client_id'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        created: (map['created'] as DateTime?) ?? DateTime.now().toUtc(),
        modified: (map['modified'] as DateTime?) ?? DateTime.now().toUtc(),
        asciidocContent: (map['asciidoc_content'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) '_id': id,
        'client_id': clientId,
        'title': title,
        'created': created,
        'modified': modified,
        'asciidoc_content': asciidocContent,
      };
}
