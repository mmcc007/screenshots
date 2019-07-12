import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';

main() {
  test('process screenshots for iPhone X and iPhone XS Max', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config(configPath: 'test/screenshots_test.yaml');
    Map appConfig = config.configInfo;

    final Map devices = {
      'iPhone X': 'iphone_x_1.png',
      'iPhone XS Max': 'iphone_xs_max_1.png',
      'iPad Pro (12.9-inch) (3rd generation)':
          'ipad_pro_12.9inch_3rd_generation_1.png',
    };

    for (final String deviceName in devices.keys) {
      final screenshotName = devices[deviceName];
      print('deviceName=$deviceName, screenshotName=$screenshotName');
      Map screen = screens.screenProps(deviceName);

      final Map screenResources = screen['resources'];
      await resources.unpackImages(screenResources, '/tmp/screenshots');

      final screenshotPath = './test/resources/$screenshotName';
      final statusbarPath =
          '${appConfig['staging']}/${screenResources['statusbar']}';

      var options = {
        'screenshotPath': screenshotPath,
        'statusbarPath': statusbarPath,
      };
//      print('options=$options');
      await im.convert('overlay', options);

      final framePath = appConfig['staging'] + '/' + screenResources['frame'];
      final size = screen['size'];
      final resize = screen['resize'];
      final offset = screen['offset'];
      options = {
        'framePath': framePath,
        'size': size,
        'resize': resize,
        'offset': offset,
        'screenshotPath': screenshotPath,
        'backgroundColor': ImageProcessor.kDefaultAndroidBackground,
      };
//      print('options=$options');
      await im.convert('frame', options);
    }
  });
}
