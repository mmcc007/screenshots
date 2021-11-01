import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/utils.dart' as utils;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  // issue #29
  test('check full matching emulator name', () async {
    // emulator named in config must match name of installed emulator
    final screenshotsYaml = '''
devices:
  ios:
    iPhone X:
  android:
    Nexus 5X:
    Nexus 6P:
    Nexus 9:
''';
    final configInfo = loadYaml(screenshotsYaml);
//    final List emulators = utils.getAvdNames();
    final daemonClient = DaemonClient();
    await daemonClient.start;
    final emulators = await daemonClient.emulators;
    final foundIt = (emulator) => emulator != null;

    print('emulators=$emulators');
    final deviceNames = configInfo['devices']['android'];
    print('deviceNames=$deviceNames');
    for (final deviceName in deviceNames.keys) {
      var emulator = utils.findEmulator(emulators, deviceName);
//      if (!foundIt(emulator)) {
//        // find by emulatorId
//        emulator = findEmulatorById(emulators, deviceName);
//      }
      expect(foundIt(emulator), true);
    }
//    expect(foundIt(findEmulator(emulators, 'Nexus 6P')), true);
//    expect(foundIt(findEmulator(emulators, 'Nexus_6P_API_27')), false);
//    expect(foundIt(findEmulator(emulators, 'Nexus 6P API 27')), false);
  }, skip:     true  );
}

Map findEmulatorById(List emulators, String emulatorName) {
  return emulators.firstWhere(
      (emulator) => emulator['id'].replaceAll('_', ' ').contains(emulatorName),
      orElse: () => null);
}
