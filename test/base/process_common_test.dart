import 'package:screenshots/src/base/process_common.dart';
import 'package:test/test.dart';

void main() {
  group('process common', () {
    test('check executable path', () {
      final flutterPath = getExecutablePath('dart', '.');
      expect(flutterPath, isNotNull);
    });
  });
}
