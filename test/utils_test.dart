import 'package:screenshots/screenshots.dart';
import 'package:test/test.dart';

import 'src/context.dart';

main() {
  group('utils', () {
    testUsingContext('get adb path', () async {
      final adbPathFound = await isAdbPath();
      expect(adbPathFound, isTrue);
    });

    testUsingContext('get emulator path', () async {
      final emulatorPathFound = await isEmulatorPath();
      expect(emulatorPathFound, isTrue);
    });
  });
}
