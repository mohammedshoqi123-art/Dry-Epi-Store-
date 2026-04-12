import 'package:flutter_test/flutter_test.dart';
import 'package:epi_core/src/security/encryption_service.dart';

void main() {
  late EncryptionService encryption;

  setUp(() {
    encryption = EncryptionService();
  });

  group('EncryptionService', () {
    test('encrypt returns non-empty string', () {
      final result = encryption.encrypt('hello');
      expect(result, isNotEmpty);
      expect(result, isNot('hello'));
    });

    test('decrypt reverses encrypt for simple string', () {
      const plaintext = 'Hello, World!';
      final encrypted = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt reverses encrypt for Arabic text', () {
      const plaintext = 'مرحباً بالعالم - منصة مشرف EPI';
      final encrypted = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt reverses encrypt for JSON data', () {
      const plaintext = '{"form_id":"abc-123","data":{"name":"test","value":42}}';
      final encrypted = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('each encryption produces different output (random salt+IV)', () {
      const plaintext = 'same input';
      final enc1 = encryption.encrypt(plaintext);
      final enc2 = encryption.encrypt(plaintext);
      expect(enc1, isNot(enc2)); // different due to random salt/IV
      // But both should decrypt to same plaintext
      expect(encryption.decrypt(enc1), equals(plaintext));
      expect(encryption.decrypt(enc2), equals(plaintext));
    });

    test('decrypt with invalid input throws', () {
      expect(() => encryption.decrypt('not-encrypted'), throwsException);
      expect(() => encryption.decrypt(''), throwsException);
    });

    test('encryptMap and decryptMap roundtrip', () {
      final map = {
        'form_id': 'test-123',
        'status': 'submitted',
        'count': 42,
        'nested': {'key': 'value'},
      };
      final encrypted = encryption.encryptMap(map);
      final decrypted = encryption.decryptMap(encrypted);
      expect(decrypted['form_id'], equals('test-123'));
      expect(decrypted['status'], equals('submitted'));
      expect(decrypted['count'], equals(42));
      expect(decrypted['nested']['key'], equals('value'));
    });

    test('hash returns consistent results', () {
      final h1 = encryption.hash('test input');
      final h2 = encryption.hash('test input');
      expect(h1, equals(h2));
      expect(h1.length, equals(16));
    });

    test('hash returns different results for different inputs', () {
      final h1 = encryption.hash('input1');
      final h2 = encryption.hash('input2');
      expect(h1, isNot(h2));
    });

    test('verifyIntegrity works correctly', () {
      final h = encryption.hash('important data');
      expect(encryption.verifyIntegrity('important data', h), isTrue);
      expect(encryption.verifyIntegrity('tampered data', h), isFalse);
    });

    test('handles empty string', () {
      final encrypted = encryption.encrypt('');
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, equals(''));
    });

    test('handles long string (10KB)', () {
      final plaintext = 'A' * 10240;
      final encrypted = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });
  });
}
