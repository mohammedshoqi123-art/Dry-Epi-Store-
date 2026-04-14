import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/security/encryption_service.dart';
import 'dart:convert';

void main() {
  group('EncryptionService - Security Tests', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService(overrideKey: 'EPI_SUPERVISOR_TEST_KEY_32_CHARS_MINIMUM');
    });

    test('encrypt produces non-empty base64 output', () {
      final encrypted = service.encrypt('test data');
      expect(encrypted, isNotEmpty);
      // Should be valid base64
      expect(() => base64Decode(encrypted), returnsNormally);
    });

    test('different IVs produce different ciphertexts for same plaintext', () {
      const plaintext = 'identical plaintext for both encryptions';
      final enc1 = service.encrypt(plaintext);
      final enc2 = service.encrypt(plaintext);
      // Due to random IV, outputs should differ
      expect(enc1, isNot(equals(enc2)));
    });

    test('roundtrip: encrypt then decrypt returns original plaintext', () {
      const original = 'بيانات حساسة للنظام الصحي';
      final encrypted = service.encrypt(original);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, equals(original));
    });

    test('roundtrip works with empty string', () {
      final encrypted = service.encrypt('');
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, equals(''));
    });

    test('roundtrip works with unicode and emoji', () {
      const original = 'تطعيم 💉 2024 — الحصبة والشلل';
      final encrypted = service.encrypt(original);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, equals(original));
    });

    test('roundtrip works with large data (100KB)', () {
      final largeData = 'x' * 100000;
      final encrypted = service.encrypt(largeData);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, equals(largeData));
    });

    test('tampered ciphertext throws exception', () {
      final encrypted = service.encrypt('secret data');
      final bytes = base64Decode(encrypted);
      // Flip a byte in the middle of the ciphertext
      if (bytes.length > 30) {
        bytes[bytes.length - 5] = bytes[bytes.length - 5] ^ 0xFF;
      }
      final tampered = base64Encode(bytes);
      expect(
        () => service.decrypt(tampered),
        throwsA(isA<Exception>()),
      );
    });

    test('truncated ciphertext throws exception', () {
      final encrypted = service.encrypt('test');
      final bytes = base64Decode(encrypted);
      // Truncate to half
      final truncated = base64Encode(bytes.sublist(0, bytes.length ~/ 2));
      expect(
        () => service.decrypt(truncated),
        throwsA(isA<Exception>()),
      );
    });

    test('invalid base64 throws exception', () {
      expect(
        () => service.decrypt('not-valid-base64!!!'),
        throwsA(isA<Exception>()),
      );
    });

    test('encryptMap and decryptMap roundtrip', () {
      final map = {
        'name': 'أحمد',
        'role': 'supervisor',
        'count': 42,
        'nested': {'key': 'value'},
      };
      final encrypted = service.encryptMap(map);
      final decrypted = service.decryptMap(encrypted);
      expect(decrypted['name'], equals('أحمد'));
      expect(decrypted['role'], equals('supervisor'));
      expect(decrypted['count'], equals(42));
      expect(decrypted['nested'], equals({'key': 'value'}));
    });

    test('hash is deterministic', () {
      final hash1 = service.hash('test input');
      final hash2 = service.hash('test input');
      expect(hash1, equals(hash2));
    });

    test('different inputs produce different hashes', () {
      final hash1 = service.hash('input A');
      final hash2 = service.hash('input B');
      expect(hash1, isNot(equals(hash2)));
    });

    test('verifyIntegrity works correctly', () {
      const data = 'important data';
      final hash = service.hash(data);
      expect(service.verifyIntegrity(data, hash), isTrue);
      expect(service.verifyIntegrity('tampered data', hash), isFalse);
    });
  });
}
