import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Example Flutter unit test', () {
    // 测试基本断言
    expect(2 + 2, equals(4));
  });

  test('String manipulation test', () {
    // 测试字符串操作
    final String testString = 'Hello, RustDesk!';
    expect(testString.length, equals(14));
    expect(testString.contains('RustDesk'), isTrue);
  });

  test('List operations test', () {
    // 测试列表操作
    final List<int> numbers = [1, 2, 3, 4, 5];
    expect(numbers.length, equals(5));
    expect(numbers.contains(3), isTrue);
    expect(numbers.reduce((a, b) => a + b), equals(15));
  });
}