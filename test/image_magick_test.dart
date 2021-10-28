import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'src/context.dart';
import 'src/mocks.dart';

void main() {
  group('image magick', () {
    var mockProcessManager = MockProcessManager();

    setUp(() {
      mockProcessManager = MockProcessManager();
      when(mockProcessManager.runSync(
        any,
        environment: anyNamed('environment'),
        workingDirectory: anyNamed('workingDirectory'),
        runInShell: anyNamed('runInShell'),
      )).thenAnswer((Invocation invocation) => ProcessResult(0, 0, null, null));
    });

    testUsingContext('overlay', () async {
      final options = {
        'screenshotPath': 'screenshotPath',
        'statusbarPath': 'statusbarPath',
      };
      final result = await im.convert('overlay', options);
      expect(result, isNull);
    }, overrides: <Type, Generator>{ProcessManager: () => mockProcessManager});

    testUsingContext('append', () async {
      final options = {
        'screenshotPath': 'screenshotPath',
        'screenshotNavbarPath': 'screenshotNavbarPath',
      };
      final result = await im.convert('append', options);
      expect(result, isNull);
    }, overrides: <Type, Generator>{ProcessManager: () => mockProcessManager});

    testUsingContext('frame', () async {
      final options = {
        'framePath': 'framePath',
        'size': 'size',
        'resize': 'resize',
        'offset': 'offset',
        'screenshotPath': 'screenshotPath',
        'backgroundColor': ImageProcessor.kDefaultAndroidBackground,
      };
      final result = await im.convert('frame', options);
      expect(result, isNull);
    }, overrides: <Type, Generator>{ProcessManager: () => mockProcessManager});

    test('threshold exceeded', () async {
      final imagePath = toPlatformPath('./test/resources/0.png');
      final cropSizeOffset = '1242x42+0+0';
      bool isThresholdExceeded = await runInContext<bool>(() async {
        return im.isThresholdExceeded(imagePath, cropSizeOffset, 0.5);
      });
      expect(isThresholdExceeded, isTrue);
      isThresholdExceeded = await runInContext<bool>(() async {
        return im.isThresholdExceeded(imagePath, cropSizeOffset);
      });
      expect(isThresholdExceeded, isFalse);
    });
  });

  group('main image magick', () {
    var fakeProcessManager = FakeProcessManager();

    setUp(() async {
      fakeProcessManager = FakeProcessManager();
    });

    testUsingContext('is installed on macOS/linux', () async {
      fakeProcessManager.calls = [Call('convert -version', ProcessResult(0, 0, '', ''))];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform(operatingSystem: 'macos'),
    });

    testUsingContext('is installed on windows', () async {
      fakeProcessManager.calls = [Call('magick -version', ProcessResult(0, 0, '', ''))];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform(operatingSystem: 'windows'),
    });

    testUsingContext('is not installed on windows', () async {
      fakeProcessManager.calls = [
        Call('magick -version', null, sideEffects: ()=> throw 'exception')
      ];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isFalse);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform(operatingSystem: 'windows'),
    });
  });

}
