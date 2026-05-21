import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/utils/csrf_token_manager.dart';

void main() {
  group('CsrfTokenManager', () {
    setUp(() {
      CsrfTokenManager.clearToken();
    });

    group('getToken', () {
      test('returns a non-empty token', () {
        final token = CsrfTokenManager.getToken();
        expect(token, isNotEmpty);
        expect(token.length, greaterThanOrEqualTo(20));
      });

      test('returns the same token on multiple calls', () {
        final token1 = CsrfTokenManager.getToken();
        final token2 = CsrfTokenManager.getToken();
        expect(token1, equals(token2));
      });
    });

    group('refreshToken', () {
      test('generates a new token', () {
        final token1 = CsrfTokenManager.getToken();
        CsrfTokenManager.refreshToken();
        final token2 = CsrfTokenManager.getToken();
        expect(token1, isNot(equals(token2)));
      });
    });

    group('validateToken', () {
      test('validates correct token', () {
        final token = CsrfTokenManager.getToken();
        expect(CsrfTokenManager.validateToken(token), isTrue);
      });

      test('rejects invalid token', () {
        CsrfTokenManager.getToken(); // Initialize token
        expect(CsrfTokenManager.validateToken('invalid-token'), isFalse);
      });

      test('rejects empty token', () {
        CsrfTokenManager.getToken();
        expect(CsrfTokenManager.validateToken(''), isFalse);
      });
    });

    group('clearToken', () {
      test('clears the token', () {
        CsrfTokenManager.getToken();
        CsrfTokenManager.clearToken();
        // After clearing, getToken should generate a new token
        final token = CsrfTokenManager.getToken();
        expect(token, isNotEmpty);
      });
    });

    group('getAuthHeaders', () {
      test('returns headers with CSRF token', () {
        final headers = CsrfTokenManager.getAuthHeaders();
        expect(headers.containsKey('X-CSRF-Token'), isTrue);
        expect(headers.containsKey('X-Request-ID'), isTrue);
        expect(headers['X-CSRF-Token'], isNotEmpty);
        expect(headers['X-Request-ID'], isNotEmpty);
      });
    });

    group('validateRequest', () {
      test('validates valid request', () {
        final token = CsrfTokenManager.getToken();
        final headers = {'X-Request-ID': 'test-request-id'};
        expect(CsrfTokenManager.validateRequest(token, headers), isTrue);
      });

      test('rejects invalid token', () {
        CsrfTokenManager.getToken();
        final headers = {'X-Request-ID': 'test-request-id'};
        expect(CsrfTokenManager.validateRequest('invalid-token', headers),
            isFalse);
      });

      test('rejects missing request ID', () {
        final token = CsrfTokenManager.getToken();
        final headers = <String, String>{};
        expect(CsrfTokenManager.validateRequest(token, headers), isFalse);
      });
    });
  });
}
