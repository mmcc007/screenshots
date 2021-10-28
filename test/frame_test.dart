import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('frame test', () {
    test('frame Nexus 9', () async {
      final screens = Screens();
      final screen = screens.getScreen('Nexus 9')!;
      final config = Config(configPath: 'test/screenshots_test.yaml');

      var paths = await resources.unpackImages(screen, '/tmp/screenshots');

      final screenshotPath = './test/resources/nexus_9_0.png';
      final statusbarPath = paths.statusbar;

      var options = {
        'screenshotPath': screenshotPath,
        'statusbarPath': statusbarPath,
      };
//      print('options=$options');
      await runInContext<void>(() async {
        return im.convert('overlay', options);
      });
      final screenshotNavbarPath = paths.navbar;
      options = {
        'screenshotPath': screenshotPath,
        'screenshotNavbarPath': screenshotNavbarPath,
      };
//      print('options=$options');
      await runInContext<void>(() async {
        return im.convert('append', options);
      });
      options = {
        'framePath': paths.frame,
        'size': screen.size!,
        'resize': screen.resize!,
        'offset': screen.offset!,
        'screenshotPath': screenshotPath,
        'backgroundColor': ImageProcessor.kDefaultAndroidBackground,
      };
//      print('options=$options');
      await runInContext<void>(() async {
        return im.convert('frame', options);
      });
      await runInContext<void>(() async {
        cmd(['git', 'checkout', screenshotPath]);
      });
    });
  });
}
