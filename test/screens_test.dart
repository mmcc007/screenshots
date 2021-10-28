import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';

void main() {
  group('screens', () {
    test('get supported device names', () async {
      final screens = Screens();
      expect(
          screens.getSupportedDeviceNamesByOs(DeviceType.ios).length, greaterThan(12));
    });
  });
}
