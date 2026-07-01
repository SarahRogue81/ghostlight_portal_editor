import 'dart:typed_data';
import 'package:mongo_dart/mongo_dart.dart';

class ClientImage {
  final ObjectId? id;
  final String clientId;
  final String filename;
  final String mimeType;
  final Uint8List data;

  const ClientImage({
    this.id,
    required this.clientId,
    required this.filename,
    required this.mimeType,
    required this.data,
  });

  factory ClientImage.fromMap(Map<String, dynamic> map) => ClientImage(
        id: map['_id'] as ObjectId?,
        clientId: (map['client_id'] as String?) ?? '',
        filename: (map['filename'] as String?) ?? '',
        mimeType: (map['mime-type'] as String?) ?? '',
        data: (map['data'] as BsonBinary?)?.byteList ?? Uint8List(0),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) '_id': id,
        'client_id': clientId,
        'filename': filename,
        'mime-type': mimeType,
        'data': BsonBinary.from(data),
      };
}
