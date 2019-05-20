import 'package:screenshots/config.dart';
import 'package:screenshots/image_magick.dart';
import 'package:screenshots/process_images.dart';
import 'package:screenshots/resources.dart';
import 'package:screenshots/screens.dart';
import 'package:test/test.dart';

main() {
  test('frame Nexus 9', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 9');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');

    final screenshotPath = './test/resources/nexus_9_0.png';
    final statusbarPath = '${appConfig['staging']}/${resources['statusbar']}';

    var options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    print('options=$options');
    await imagemagick('overlay', options);

    final screenshotNavbarPath =
        '${appConfig['staging']}/${resources['navbar']}';
    options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    print('options=$options');
    await imagemagick('append', options);

    final framePath = appConfig['staging'] + '/' + resources['frame'];
    final size = screen['size'];
    final resize = screen['resize'];
    final offset = screen['offset'];
    options = {
      'framePath': framePath,
      'size': size,
      'resize': resize,
      'offset': offset,
      'screenshotPath': screenshotPath,
      'backgroundColor': kDefaultAndroidBackground,
    };
    print('options=$options');
    await imagemagick('frame', options);
  });
}
