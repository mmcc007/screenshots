import 'dart:io' as io;

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/fastlane.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'src/context.dart';

main() {
  test('process screenshots for iPhone X and iPhone XS Max', () async {
    final imageDir = 'test/resources';
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config(configPath: 'test/screenshots_test.yaml');

    final Map devices = {
      'iPhone X': 'iphone_x_1.png',
      'iPhone XS Max': 'iphone_xs_max_1.png',
      'iPad Pro (12.9-inch) (3rd generation)':
          'ipad_pro_12.9inch_3rd_generation_1.png',
    };

    for (final String deviceName in devices.keys) {
      final screenshotName = devices[deviceName];
//      print('deviceName=$deviceName, screenshotName=$screenshotName');
      Map screen = screens.getScreen(deviceName);

      final Map screenResources = screen['resources'];
      await resources.unpackImages(screenResources, '/tmp/screenshots');

      final screenshotPath = '$imageDir/$screenshotName';
      final statusbarPath =
          '${config.stagingDir}/${screenResources['statusbar']}';

      var options = {
        'screenshotPath': screenshotPath,
        'statusbarPath': statusbarPath,
      };
      await runInContext<void>(() async {
        return im.convert('overlay', options);
      });
      final framePath = config.stagingDir + '/' + screenResources['frame'];
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
      await runInContext<void>(() async {
        return im.convert('frame', options);
      });
    }
    for (var deviceName in devices.values) {
      await runInContext<void>(() async {
        return cmd(['git', 'checkout', '$imageDir/$deviceName']);
      });
    }
  });

  group('image processor', () {
    FakeProcessManager fakeProcessManager;
    MemoryFileSystem memoryFileSystem;
    MockImageMagick mockImageMagick;

    setUp(() async {
      memoryFileSystem = MemoryFileSystem();
      fakeProcessManager = FakeProcessManager();
      mockImageMagick = MockImageMagick();
    });

    testUsingContext('process', () async {
      final stagingDir = '/tmp/screenshots';
      // copy a screenshot to memory file system
      final imagePath = 'test/resources/screenshot_Nexus_6P.png';
      copyFileToMemory(imagePath, stagingDir);

      final screens = Screens();
      await screens.init();
      final deviceName = 'Nexus 6P';
      final locale = 'en-US';
      final configStr = '''
          staging: $stagingDir
          devices:
            android:
              $deviceName:
          frame: true      
      ''';
      final config = Config(configStr: configStr);

      fakeProcessManager.calls = [
        Call(
            'convert /tmp/screenshots/test/screenshot.png -crop 1000x40+0+0 +repage -colorspace gray -format ""%[fx:(mean>0.76)?1:0]"" info:',
            ProcessResult(0, 0, '0', '')),
        Call(
            'convert /tmp/screenshots/test/screenshot.png /tmp/screenshots/resources/android/1440/statusbar.png -gravity north -composite /tmp/screenshots/test/screenshot.png',
            null),
        Call(
            'convert -append /tmp/screenshots/test/screenshot.png /tmp/screenshots/resources/android/1440/navbar_black.png /tmp/screenshots/test/screenshot.png',
            null),
        Call(
            'convert -size 1440x2560 xc:none ( /tmp/screenshots/test/screenshot.png -resize 80% ) -gravity center -geometry -3+8 -composite ( /tmp/screenshots/resources/android/phones/Nexus 6P.png -resize 80% ) -gravity center -composite /tmp/screenshots/test/screenshot.png',
            null),
      ];

      final imageProcessor = ImageProcessor(screens, config);
      final result = await imageProcessor.process(
          DeviceType.android, deviceName, locale, null, RunMode.normal, null);
      expect(result, isTrue);
      expect(fs.directory(stagingDir).existsSync(), isTrue);
      final dstDir = getDirPath(DeviceType.android, locale,
          getAndroidModelType(screens.getScreen(deviceName)));
      expect(fs.directory(dstDir).listSync().length, 1);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      FileSystem: () => memoryFileSystem
    });

    testUsingContext('compare images', () async {
      final comparisonDir = 'test/resources/comparison';
      final recordingDir = 'test/resources/recording';
      final deviceName = 'Nexus 6P';
      final expected = {
        'Nexus 6P-0.png': {
          'recording': 'test/resources/recording/Nexus 6P-0.png',
          'comparison': 'test/resources/comparison/Nexus 6P-0.png',
          'diff': 'test/resources/diff file${ImageMagick.kDiffSuffix}.png'
        },
        'Nexus 6P-1.png': {
          'recording': 'test/resources/recording/Nexus 6P-1.png',
          'comparison': 'test/resources/comparison/Nexus 6P-1.png',
          'diff': 'test/resources/diff file${ImageMagick.kDiffSuffix}.png'
        }
      };

      when(mockImageMagick.compare(any, any)).thenReturn(false);
      when(mockImageMagick.getDiffImagePath(any)).thenReturn(
          'test/resources/diff file${ImageMagick.kDiffSuffix}.png');

      final failedCompare = await ImageProcessor.compareImages(
          deviceName, recordingDir, comparisonDir);
      expect(failedCompare, expected);
      // show diffs
      ImageProcessor.showFailedCompare(failedCompare);
      final BufferLogger logger = context.get<Logger>();
      expect(logger.errorText, contains('Comparison failed:'));
    }, overrides: <Type, Generator>{
//      ProcessManager: () => fakeProcessManager,
      Logger: () => BufferLogger(),
//      FileSystem: () => memoryFileSystem,
      ImageMagick: () => mockImageMagick,
    });
  });
}

void copyFileToMemory(String imagePath, String stagingDir) {
  final fileImage = io.File(imagePath).readAsBytesSync();
  final screenshotsDir = '$stagingDir/$kTestScreenshotsDir';
  fs.directory(screenshotsDir).createSync(recursive: true);
  fs.file('$screenshotsDir/screenshot.png').writeAsBytesSync(fileImage);
}

class MockImageMagick extends Mock implements ImageMagick {}
