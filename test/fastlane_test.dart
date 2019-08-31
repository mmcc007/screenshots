import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/base/file_system.dart';
import 'package:screenshots/src/base/io.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/fastlane.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

//import 'src/common_tools.dart';
import 'src/context.dart';

class PlainMockProcessManager extends Mock implements ProcessManager {}

main() {
  group('fastlane', () {
    group('in context', () {
      final dirPath = 'test/$kTestScreenshotsDir';
      final ProcessManager mockProcessManager = PlainMockProcessManager();
      MemoryFileSystem fs;

      setUp(() {
        // create test files
        fs = MemoryFileSystem();
        fs.directory(dirPath).createSync(recursive: true);
        final filePaths = [
          '$dirPath/file1.$kImageExtension',
          '$dirPath/file2.$kImageExtension'
        ];
        for (final filePath in filePaths) {
          fs.file(filePath).createSync();
        }
//  expect(fs.directory(dirPath).listSync().length, filePaths.length);

        // fake process call
        when(mockProcessManager.runSync(
          any,
          environment: anyNamed('environment'),
          workingDirectory: anyNamed('workingDirectory'),
          runInShell: anyNamed('runInShell'),
        )).thenAnswer(
            (Invocation invocation) => ProcessResult(0, 0, null, null));
      });

      testUsingContext('prefix files and delete matching files', () async {
        final prefix = 'my_prefix';
        await prefixFilesInDir(dirPath, prefix);
        await for (final file in fs.directory(dirPath).list()) {
          expect(file.path.contains(prefix), isTrue);
        }
        // cleanup
        deleteMatchingFiles(dirPath, RegExp(prefix));
        expect(fs.directory(dirPath).listSync().length, 0);
      }, overrides: {
        ProcessManager: () => mockProcessManager,
        FileSystem: () => fs
      });
    });

    group('no context', () {
      test('clear fastlane dirs', () async {
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
        final runMode = RunMode.normal;
        await clearFastlaneDirs(config, screens, runMode);
      });
    });
  });
}
