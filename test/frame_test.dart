import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('frame test', () {
    test('frame Nexus 9', () async {
      final Screens screens = Screens();
      await screens.init();
      Map screen = screens.getScreen('Nexus 9');
      final Config config = Config(configPath: 'test/screenshots_test.yaml');

      final Map ScreenResources = screen['resources'];
      await resources.unpackImages(ScreenResources, '/tmp/screenshots');

      final screenshotPath = './test/resources/nexus_9_0.png';
      final statusbarPath =
          '${config.stagingDir}/${ScreenResources['statusbar']}';

      var options = {
        'screenshotPath': screenshotPath,
        'statusbarPath': statusbarPath,
      };
//      print('options=$options');
      await runInContext<void>(() async {
        return im.convert('overlay', options);
      });
      final screenshotNavbarPath =
          '${config.stagingDir}/${ScreenResources['navbar']}';
      options = {
        'screenshotPath': screenshotPath,
        'screenshotNavbarPath': screenshotNavbarPath,
      };
//      print('options=$options');
      await runInContext<void>(() async {
        return im.convert('append', options);
      });
      final framePath = config.stagingDir + '/' + ScreenResources['frame'];
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
      await runInContext<void>(() async {
        return im.convert('frame', options);
      });
      await runInContext<void>(() async {
        return cmd(['git', 'checkout', screenshotPath]);
      });
    });
  });
}
