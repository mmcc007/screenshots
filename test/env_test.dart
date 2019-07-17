import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';

void main() {
  test('store and retrieve environment', () async {
    final Config config = Config(configPath: 'test/screenshots_test.yaml');
    final screens = await Screens();
    await screens.init();

    final env = {
      'screen_size': '1440x2560',
      'locale': 'en_US',
      'device_name': 'Nexus 6P',
      'device_type': 'android',
    };

    // called by screenshots before test
    await config.storeEnv(
        screens, env['device_name'], env['locale'], env['device_type']);

    // called by test
    final Config testConfig = Config(configPath: 'test/screenshots_test.yaml');
    expect(await testConfig.screenshotsEnv, env);
  });
}
