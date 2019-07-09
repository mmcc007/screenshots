import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/image_magick.dart' as im;
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';

main() {
  test('frame Nexus 9', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 9');
    final Config config = Config(configPath: 'test/screenshots_test.yaml');
    Map appConfig = config.configInfo;

    final Map ScreenResources = screen['resources'];
    await resources.unpackImages(ScreenResources, '/tmp/screenshots');

    final screenshotPath = './test/resources/nexus_9_0.png';
    final statusbarPath =
        '${appConfig['staging']}/${ScreenResources['statusbar']}';

    var options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    print('options=$options');
    await im.imagemagick('overlay', options);

    final screenshotNavbarPath =
        '${appConfig['staging']}/${ScreenResources['navbar']}';
    options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    print('options=$options');
    await im.imagemagick('append', options);

    final framePath = appConfig['staging'] + '/' + ScreenResources['frame'];
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
    print('options=$options');
    await im.imagemagick('frame', options);
  });
}
