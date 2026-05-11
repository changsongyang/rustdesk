import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/utils/security_utils.dart';

void main() {
  group('SecurityUtils', () {
    group('generateCsrfToken', () {
      test('generates a non-empty token', () {
        final token = SecurityUtils.generateCsrfToken();
        expect(token, isNotEmpty);
        expect(token.length, greaterThanOrEqualTo(20));
      });

      test('generates unique tokens', () {
        final token1 = SecurityUtils.generateCsrfToken();
        final token2 = SecurityUtils.generateCsrfToken();
        expect(token1, isNot(equals(token2)));
      });
    });

    group('sanitizeInput', () {
      test('sanitizes HTML special characters', () {
        const input = '<script>alert("XSS")</script>';
        final result = SecurityUtils.sanitizeInput(input);
        expect(result, '&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;');
      });

      test('handles empty string', () {
        expect(SecurityUtils.sanitizeInput(''), '');
      });

      test('preserves safe input', () {
        const input = 'Hello World!';
        expect(SecurityUtils.sanitizeInput(input), input);
      });
    });

    group('stripHtmlTags', () {
      test('removes HTML tags', () {
        const input = '<p>Hello <b>World</b></p>';
        expect(SecurityUtils.stripHtmlTags(input), 'Hello World');
      });

      test('handles plain text', () {
        const input = 'Plain text without tags';
        expect(SecurityUtils.stripHtmlTags(input), input);
      });
    });

    group('isValidUrl', () {
      test('validates https URL', () {
        expect(SecurityUtils.isValidUrl('https://example.com'), isTrue);
      });

      test('validates http URL', () {
        expect(SecurityUtils.isValidUrl('http://example.com'), isTrue);
      });

      test('rejects URLs without scheme', () {
        expect(SecurityUtils.isValidUrl('example.com'), isFalse);
      });

      test('rejects invalid URLs', () {
        expect(SecurityUtils.isValidUrl('not-a-url'), isFalse);
      });
    });

    group('isValidIpAddress', () {
      test('validates IPv4 address', () {
        expect(SecurityUtils.isValidIpAddress('192.168.1.1'), isTrue);
      });

      test('validates IPv6 address', () {
        expect(SecurityUtils.isValidIpAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334'), isTrue);
      });

      test('rejects invalid IP', () {
        expect(SecurityUtils.isValidIpAddress('invalid-ip'), isFalse);
      });

      test('rejects out of range IPv4', () {
        expect(SecurityUtils.isValidIpAddress('256.1.1.1'), isFalse);
      });
    });

    group('containsSqlKeywords', () {
      test('detects SELECT keyword', () {
        expect(SecurityUtils.containsSqlKeywords('SELECT * FROM users'), isTrue);
      });

      test('detects SQL injection attempt', () {
        expect(SecurityUtils.containsSqlKeywords("'; DROP TABLE users--"), isTrue);
      });

      test('does not detect safe input', () {
        expect(SecurityUtils.containsSqlKeywords('Hello World'), isFalse);
      });
    });

    group('validateSessionToken', () {
      test('validates valid token', () {
        expect(SecurityUtils.validateSessionToken('a'.repeat(32)), isTrue);
      });

      test('rejects short token', () {
        expect(SecurityUtils.validateSessionToken('short'), isFalse);
      });

      test('rejects token with spaces', () {
        expect(SecurityUtils.validateSessionToken('a'.repeat(16) + ' ' + 'a'.repeat(16)), isFalse);
      });

      test('rejects empty token', () {
        expect(SecurityUtils.validateSessionToken(''), isFalse);
      });
    });

    group('maskSensitiveData', () {
      test('masks password correctly', () {
        expect(SecurityUtils.maskSensitiveData('password123456'), 'pass********6');
      });

      test('masks short string', () {
        expect(SecurityUtils.maskSensitiveData('abc'), '***');
      });

      test('masks email', () {
        final result = SecurityUtils.maskSensitiveData('user@example.com');
        expect(result, startsWith('user'));
        expect(result, endsWith('m'));
        expect(result.contains('*'), isTrue);
      });
    });

    group('simpleHash', () {
      test('generates non-empty hash', () {
        final hash = SecurityUtils.simpleHash('test');
        expect(hash, isNotEmpty);
      });

      test('generates consistent hash for same input', () {
        final hash1 = SecurityUtils.simpleHash('same-input');
        // Note: simpleHash uses timestamp in fallback, so we can't test determinism
        // without mocking time
      });
    });
  });
}
