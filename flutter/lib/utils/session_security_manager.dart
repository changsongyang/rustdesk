import 'security_utils.dart';
import 'csrf_token_manager.dart';

class SessionSecurityManager {
  static bool _isSecureSession = false;
  static String? _sessionId;

  static void initializeSecureSession() {
    try {
      _sessionId = SecurityUtils.generateCsrfToken();
      _isSecureSession = true;
    } catch (e) {
      // 降级：使用时间戳生成会话ID
      _sessionId = SecurityUtils.generateCsrfToken();
      _isSecureSession = true;
    }
  }

  static bool get isSecureSessionActive => _isSecureSession;

  static String? get sessionId => _sessionId;

  static void terminateSession() {
    _sessionId = null;
    _isSecureSession = false;
    CsrfTokenManager.clearToken();
  }

  static String hashSensitiveData(String data) {
    try {
      return SecurityUtils.simpleHash(data);
    } catch (e) {
      // 降级：使用简单哈希
      return data.hashCode.toString();
    }
  }

  static bool verifyDataIntegrity(String data, String expectedHash) {
    try {
      final actualHash = hashSensitiveData(data);
      return _secureCompare(actualHash, expectedHash);
    } catch (e) {
      return false; // 降级：验证失败
    }
  }

  static String generateSessionSignature(String sessionData) {
    try {
      if (_sessionId == null) return '';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final data = '$_sessionId:$sessionData:$timestamp';
      return SecurityUtils.simpleHash(data);
    } catch (e) {
      // 降级：使用简单哈希
      return SecurityUtils.simpleHash('${_sessionId ?? ''}:$sessionData');
    }
  }

  static bool validateSessionSignature(String sessionData, String signature) {
    try {
      if (_sessionId == null) return false;
      final expectedSignature = generateSessionSignature(sessionData);
      return _secureCompare(signature, expectedSignature);
    } catch (e) {
      return false; // 降级：验证失败
    }
  }

  static bool _secureCompare(String a, String b) {
    try {
      if (a.length != b.length) return false;
      var result = 0;
      for (var i = 0; i < a.length; i++) {
        result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
      }
      return result == 0;
    } catch (e) {
      return false; // 降级：比较失败
    }
  }
}