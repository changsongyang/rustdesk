import 'security_utils.dart';

class CsrfTokenManager {
  static String? _currentToken;
  static DateTime? _tokenExpiry;
  static const Duration _tokenValidity = Duration(hours: 1);

  static String getToken() {
    try {
      if (_currentToken == null || isTokenExpired()) {
        refreshToken();
      }
      return _currentToken!;
    } catch (e) {
      // 降级：生成新令牌
      refreshToken();
      return _currentToken ?? SecurityUtils.generateCsrfToken();
    }
  }

  static void refreshToken() {
    try {
      _currentToken = SecurityUtils.generateCsrfToken();
      _tokenExpiry = DateTime.now().add(_tokenValidity);
    } catch (e) {
      // 降级：使用时间戳生成令牌
      _currentToken = SecurityUtils.generateCsrfToken();
      _tokenExpiry = DateTime.now().add(_tokenValidity);
    }
  }

  static bool isTokenExpired() {
    try {
      if (_tokenExpiry == null) return true;
      return DateTime.now().isAfter(_tokenExpiry!);
    } catch (e) {
      return true; // 降级：认为令牌已过期
    }
  }

  static bool validateToken(String token) {
    try {
      if (!SecurityUtils.validateSessionToken(token)) {
        return false;
      }
      if (token != _currentToken) {
        return false;
      }
      return !isTokenExpired();
    } catch (e) {
      return false; // 降级：验证失败
    }
  }

  static void clearToken() {
    _currentToken = null;
    _tokenExpiry = null;
  }

  static Map<String, String> getAuthHeaders() {
    try {
      return {
        'X-CSRF-Token': getToken(),
        'X-Request-ID': _generateRequestId(),
      };
    } catch (e) {
      // 降级：返回基本头部
      return {
        'X-CSRF-Token': SecurityUtils.generateCsrfToken(),
        'X-Request-ID': SecurityUtils.simpleHash(DateTime.now().toString()),
      };
    }
  }

  static String _generateRequestId() {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = SecurityUtils.generateCsrfToken().substring(0, 16);
      final data = '$timestamp:$random';
      return SecurityUtils.simpleHash(data);
    } catch (e) {
      // 降级：使用时间戳和随机数
      return SecurityUtils.simpleHash('${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  static bool validateRequest(String token, Map<String, String> headers) {
    try {
      if (!validateToken(token)) {
        return false;
      }
      final requestId = headers['X-Request-ID'];
      if (requestId == null || requestId.isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      return false; // 降级：验证失败
    }
  }
}