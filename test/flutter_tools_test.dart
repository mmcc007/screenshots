import 'package:screenshots/flutter_tools/lib/src/context_runner.dart';
import 'package:screenshots/flutter_tools/lib/src/emulator.dart';
import 'package:test/test.dart';

main() {
  test('start flutter tools device daemon', () {});

  group('EmulatorManager', () {
    test('getEmulators', () async {
      await runInContext(() async {
        // Test that EmulatorManager.getEmulators() doesn't throw.
        final List<Emulator> emulators =
            await emulatorManager.getAllAvailableEmulators();
        print('emulators=$emulators');
        expect(emulators, isList);
      });
    });
  });
}
