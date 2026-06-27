import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _uriKey = 'mongodb_uri';

  static Future<String?> getMongoUri() => _storage.read(key: _uriKey);
  static Future<void> saveMongoUri(String uri) =>
      _storage.write(key: _uriKey, value: uri);
}
