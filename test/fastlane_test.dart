import 'package:file/memory.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/fastlane.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'src/context.dart';

main() {
  group('fastlane', () {
    final dirPath = 'test/$kTestScreenshotsDir';
    MemoryFileSystem memoryFileSystem;

    setUp(() {
      // create test files
      memoryFileSystem = MemoryFileSystem();
      memoryFileSystem.directory(dirPath).createSync(recursive: true);
      final filePaths = [
        '$dirPath/file1.$kImageExtension',
        '$dirPath/file2.$kImageExtension'
      ];
      for (final filePath in filePaths) {
        memoryFileSystem.file(filePath).createSync();
      }
      expect(memoryFileSystem.directory(dirPath).listSync().length, filePaths.length);
    });

    testUsingContext('prefix files and delete matching files', () async {
      final prefix = 'my_prefix';
      expect(memoryFileSystem.directory(dirPath).listSync().length, 2);
      await for (final file in memoryFileSystem.directory(dirPath).list()) {
        expect(file.path.contains(prefix), isFalse);
      }
      await prefixFilesInDir(dirPath, prefix);
      await for (final file in memoryFileSystem.directory(dirPath).list()) {
        expect(file.path.contains(prefix), isTrue);
      }
      // cleanup
      deleteMatchingFiles(dirPath, RegExp(prefix));
      expect(memoryFileSystem.directory(dirPath).listSync().length, 0);
    }, overrides: {
      FileSystem: () => memoryFileSystem
    });

    testUsingContext('clear fastlane dirs', () async {
      final configStr = '''
        devices:
          android:
            android device1:
          ios:
            ios device1:
        locales:
          - locale1
          - locale2
        frame: true
        ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      await screens.init();

      for (final locale in config.locales) {
        for (final device in config.devices) {
          // create files
          int i=0;
          final path = getDirPath(device.deviceType, locale,
              getAndroidModelType(screens.getScreen(device.name)));
          expect(memoryFileSystem.directory(path).existsSync(), isFalse);
          memoryFileSystem.file('$path/${device.name}-$i.$kImageExtension').createSync(recursive: true);
          expect(memoryFileSystem.directory(path).listSync().length, 1);
        }
      }
      await clearFastlaneDirs(config, screens, RunMode.normal);
      for (final locale in config.locales) {
        for (final device in config.devices) {
          // check files deleted
          final path = getDirPath(device.deviceType, locale,
              getAndroidModelType(screens.getScreen(device.name)));
          expect(memoryFileSystem.directory(path).listSync().length, 0);
        }
      }
    }, overrides: {
      FileSystem: () => memoryFileSystem,
    });
  });
}
