import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';

main() {
  group('screens', () {
    test('get supported device names', () async {
      final screens = Screens();
      await screens.init();
      expect(
          screens.getSupportedDeviceNamesByOs('ios').length, greaterThan(12));
    });
  });
}
