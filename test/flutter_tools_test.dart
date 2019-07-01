import 'package:screenshots/flutter_tools/lib/src/emulator.dart';
import 'package:test_api/test_api.dart' hide TypeMatcher, isInstanceOf;
import 'flutter_tools/test/src/context.dart';

export 'package:test_api/test_api.dart'
    hide TypeMatcher, isInstanceOf; // Defines a 'package:test' shim.

main() {
  test('start flutter tools device daemon', () {});

  group('EmulatorManager', () {
    testUsingContext('getEmulators', () async {
      // Test that EmulatorManager.getEmulators() doesn't throw.
      final List<Emulator> emulators =
          await emulatorManager.getAllAvailableEmulators();
      print('emulators=$emulators');
      expect(emulators, isList);
    });
  });
}
