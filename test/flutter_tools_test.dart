import 'package:screenshots/flutter_tools/lib/src/context_runner.dart';
import 'package:screenshots/flutter_tools/lib/src/device.dart';
import 'package:screenshots/flutter_tools/lib/src/emulator.dart';
import 'package:test/test.dart';

main() {
  test('start flutter tools device daemon', () {});

  group('EmulatorManager', () {
    test('getEmulators', () async {
      await runInContext(() async {
        final List<Emulator> emulators =
            await emulatorManager.getAllAvailableEmulators();
        print('emulators=$emulators');
        expect(emulators, isList);
      });
    });
  });

  group('DeviceManager', () {
    test('getDevices', () async {
      await runInContext(() async {
        final DeviceManager deviceManager = DeviceManager();
        final List<Device> devices = await deviceManager.getDevices().toList();
        print('devices=$devices');
        expect(devices, isList);
      });
    });
  });
}
