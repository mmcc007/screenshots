import 'package:screenshots/config.dart';
import 'package:screenshots/image_magick.dart';
import 'package:screenshots/image_processor.dart';
import 'package:screenshots/resources.dart';
import 'package:screenshots/screens.dart';
import 'package:test/test.dart';

main() {
  test('frame Nexus 9', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 9');
    final Config config = Config('test/screenshots_test.yaml');
    Map appConfig = config.config;

    final Map ScreenResources = screen['resources'];
    await unpackImages(ScreenResources, '/tmp/screenshots');

    final screenshotPath = './test/resources/nexus_9_0.png';
    final statusbarPath =
        '${appConfig['staging']}/${ScreenResources['statusbar']}';

    var options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    print('options=$options');
    await imagemagick('overlay', options);

    final screenshotNavbarPath =
        '${appConfig['staging']}/${ScreenResources['navbar']}';
    options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    print('options=$options');
    await imagemagick('append', options);

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
    await imagemagick('frame', options);
  });
}
