import 'package:screenshots/config.dart';
import 'package:screenshots/utils.dart' as utils;
import 'package:test/test.dart';

void main() {
  // issue #29
  test('check full matching emulator name', () {
    // emulator named in config must match name of installed emulator
    final Config config = Config('test/screenshots_test.yaml');
    final List emulators = utils.getAvdNames();
    expect(config.isEmulatorInstalled(emulators, 'Nexus 6P'), true);
    expect(config.isEmulatorInstalled(emulators, 'Nexus_6P_API_27'), true);
    expect(config.isEmulatorInstalled(emulators, 'Nexus 6P API 27'), true);
  });
}
