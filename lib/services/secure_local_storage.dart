import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase LocalStorage backed by flutter_secure_storage.
///
/// On Android: uses EncryptedSharedPreferences (AES-256, key in Keystore).
/// On iOS: uses Keychain with `first_unlock_this_device` accessibility.
///
/// Replaces the default SharedPreferences storage so access/refresh tokens
/// are not readable from a rooted device or device-to-cloud backup.
class SecureLocalStorage extends LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: supabasePersistSessionKey);

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.read(key: supabasePersistSessionKey) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: supabasePersistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: supabasePersistSessionKey);
}
