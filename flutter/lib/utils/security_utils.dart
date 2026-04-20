import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class SecurityUtils {
  static final Random _secureRandom = Random.secure();

  static String generateCsrfToken() {
    try {
      final values = List<int>.generate(32, (i) => _secureRandom.nextInt(256));
      return base64Url.encode(values);
    } catch (e) {
      // 降级方案：使用时间戳和随机数
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = _secureRandom.nextInt(999999).toString().padLeft(6, '0');
      return base64Url.encode(utf8.encode('$timestamp:$random'));
    }
  }

  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('\\', '&#x5C;')
        .replaceAll('\n', '<br>')
        .replaceAll('\r', '');
  }

  static String stripHtmlTags(String input) {
    try {
      final RegExp htmlTagRegex = RegExp(r'<[^>]*>');
      return input.replaceAll(htmlTagRegex, '');
    } catch (e) {
      return input; // 降级：返回原始输入
    }
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http');
    } catch (e) {
      return false;
    }
  }

  static bool isValidIpAddress(String ip) {
    try {
      final ipv4Regex = RegExp(
        r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
      );
      final ipv6Regex = RegExp(
        r'^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$',
      );
      return ipv4Regex.hasMatch(ip) || ipv6Regex.hasMatch(ip);
    } catch (e) {
      return false;
    }
  }

  static bool containsSqlKeywords(String input) {
    try {
      final sqlKeywords = [
        'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE',
        'ALTER', 'EXEC', 'EXECUTE', 'UNION', '--', ';', '/*', '*/'
      ];
      final lowerInput = input.toLowerCase();
      return sqlKeywords.any((keyword) => lowerInput.contains(keyword.toLowerCase()));
    } catch (e) {
      return false;
    }
  }

  static String encodeForHtml(String input) {
    return sanitizeInput(input);
  }

  static String decodeFromHtml(String input) {
    try {
      return input
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#x27;', "'")
          .replaceAll('&#x2F;', '/')
          .replaceAll('&#x5C;', '\\')
          .replaceAll('<br>', '\n');
    } catch (e) {
      return input; // 降级：返回原始输入
    }
  }

  static bool validateSessionToken(String token) {
    if (token.isEmpty) return false;
    if (token.length < 32) return false;
    return !token.contains(' ') && !token.contains('\n');
  }

  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    try {
      if (data.length <= visibleChars * 2) {
        return '*' * data.length;
      }
      final start = data.substring(0, visibleChars);
      final end = data.substring(data.length - 1);
      final masked = '*' * (data.length - visibleChars - 1);
      return '$start$masked$end';
    } catch (e) {
      return '*' * data.length;
    }
  }

  static String simpleHash(String input) {
    try {
      final bytes = utf8.encode(input);
      final hash = _computeSecureHash(bytes);
      return base64Url.encode(hash).replaceAll('=', '');
    } catch (e) {
      return _fallbackHash(input);
    }
  }

  static Uint8List _computeSecureHash(List<int> input) {
    var hash = 0;
    final salt = [0x5A, 0x3C, 0x8F, 0x2D];
    for (var i = 0; i < 1000; i++) {
      for (var j = 0; j < input.length; j++) {
        hash = ((hash << 5) - hash + (input[j] ^ salt[i % salt.length])) & 0xFFFFFFFF;
        hash = ((hash << 3) + hash + salt[j % salt.length]) & 0xFFFFFFFF;
      }
    }
    final result = Uint8List(32);
    for (var i = 0; i < 8; i++) {
      result[i * 4] = (hash >> (24 - (i % 4) * 8)) & 0xFF;
      result[i * 4 + 1] = (hash >> (16 - (i % 4) * 8)) & 0xFF;
      result[i * 4 + 2] = (hash >> (8 - (i % 4) * 8)) & 0xFF;
      result[i * 4 + 3] = (hash >> (0 - (i % 4) * 8)) & 0xFF;
    }
    return result;
  }

  static String _fallbackHash(String input) {
    var hash = 0;
    final bytes = utf8.encode(input);
    final salt = [0x5A, 0x3C, 0x8F, 0x2D];
    for (var i = 0; i < bytes.length; i++) {
      hash = ((hash << 5) - hash + (bytes[i] ^ salt[i % salt.length])) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}