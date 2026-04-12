import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter/foundation.dart';

/// Secure encryption service for local storage.
/// Uses AES-256-GCM with PBKDF2 key derivation.
///
/// Format: [salt(16)][iv(12)][ciphertext_with_tag]
/// GCM mode provides both confidentiality AND integrity — no separate HMAC needed.
class EncryptionService {
  static const String _envKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'EPI_SUPERVISOR_AES_KEY_CHANGE_IN_PRODUCTION_2024',
  );

  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16;
  static const int _ivLength = 12; // GCM standard IV length

  late final enc.Key _key;
  late final Uint8List _salt;

  EncryptionService() {
    final keyBytes = utf8.encode(_envKey);
    _salt = Uint8List.fromList(utf8.encode('EPI_SALT_2024_FIXED'));
    _key = _deriveKey(keyBytes, _salt);
  }

  /// PBKDF2 key derivation using HMAC-SHA256 (100,000 iterations per OWASP 2024)
  enc.Key _deriveKey(List<int> password, Uint8List salt) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, 100000, _keyLength));
    final derived = derivator.process(Uint8List.fromList(password));
    return enc.Key(derived);
  }

  /// Encrypt plaintext using AES-256-GCM.
  /// Returns: base64(salt(16) + iv(12) + ciphertext_with_tag)
  String encrypt(String plaintext) {
    try {
      final iv = enc.IV.fromSecureRandom(_ivLength);
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Assemble: salt + iv + ciphertext_with_tag
      final result = Uint8List(_saltLength + _ivLength + encrypted.bytes.length);
      var offset = 0;
      result.setAll(offset, _salt);
      offset += _saltLength;
      result.setAll(offset, iv.bytes);
      offset += _ivLength;
      result.setAll(offset, encrypted.bytes);

      return base64Encode(result);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.encrypt error: $e');
      rethrow;
    }
  }

  /// Decrypt AES-256-GCM ciphertext and verify authentication tag.
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final minLength = _saltLength + _ivLength + 17; // 16 tag + 1 min data

      if (bytes.length < minLength) {
        throw FormatException('Ciphertext too short');
      }

      // Parse: salt(16) + iv(12) + encrypted+tag
      var offset = 0;
      offset += _saltLength; // skip salt
      final iv = enc.IV(Uint8List.fromList(bytes.sublist(offset, offset + _ivLength)));
      offset += _ivLength;
      final encrypted = enc.Encrypted(Uint8List.fromList(bytes.sublist(offset)));

      // GCM automatically verifies the auth tag during decryption
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      rethrow;
    }
  }

  /// Encrypt a Map
  String encryptMap(Map<String, dynamic> map) => encrypt(jsonEncode(map));

  /// Decrypt to a Map
  Map<String, dynamic> decryptMap(String ciphertext) {
    final plain = decrypt(ciphertext);
    return Map<String, dynamic>.from(jsonDecode(plain));
  }

  /// Generate a short hash for integrity checking (not cryptographic)
  String hash(String input) {
    final bytes = utf8.encode(input);
    final hashed = sha256.convert(bytes);
    return base64Encode(hashed.bytes).substring(0, 16);
  }

  /// Verify integrity
  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }
}
