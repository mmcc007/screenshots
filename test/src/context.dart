import 'dart:async';

import 'package:meta/meta.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'mocks.dart';

/// Return the test logger. This assumes that the current Logger is a BufferLogger.
BufferLogger get testLogger => context.get<Logger>() as BufferLogger;

typedef ContextInitializer = void Function(AppContext testContext);

@isTest
void testUsingContext(
  String description,
    dynamic Function() testMethod, {
  Timeout? timeout,
  Map<Type, Generator> overrides = const <Type, Generator>{},
  bool initializeFlutterRoot = true,
  String? testOn,
  bool? skip, // should default to `false`, but https://github.com/dart-lang/test/issues/545 doesn't allow this
}) {
  // Ensure we don't rely on the default [Config] constructor which will
  // leak a sticky $HOME/.flutter_settings behind!
  Directory? configDir;
  tearDown(() {
    if (configDir != null) {
      tryToDelete(configDir);
      configDir = null;
    }
  });
  Config buildConfig(FileSystem fs) {
    configDir =
        fs.systemTempDirectory.createTempSync('flutter_config_dir_test.');
    final settingsFile =
        fs.file(fs.path.join(configDir!.path, '.flutter_settings'));
    return Config(settingsFile);
  }

  test(description, () async {
    await runInContext<dynamic>(() {
      return context.run<dynamic>(
        name: 'mocks',
        overrides: <Type, Generator>{
          Config: () => buildConfig(fs),
          Logger: () => BufferLogger(),
          OperatingSystemUtils: () => MockOperatingSystemUtils(),
          OutputPreferences: () => OutputPreferences(showColor: false),
//          ProcessManager: () => FakeProcessManager(),
          FileSystem: () => LocalFileSystemBlockingSetCurrentDirectory(),
          TimeoutConfiguration: () => const TimeoutConfiguration(),
        },
        body: () {
//          final String flutterRoot = getFlutterRoot();

          return runZoned<Future<dynamic>>(() {
            try {
              return context.run<dynamic>(
                // Apply the overrides to the test context in the zone since their
                // instantiation may reference items already stored on the context.
                overrides: overrides,
                name: 'test-specific overrides',
                body: () async {
//                  if (initializeFlutterRoot) {
//                    // Provide a sane default for the flutterRoot directory. Individual
//                    // tests can override this either in the test or during setup.
//                    Cache.flutterRoot ??= flutterRoot;
//                  }

                  return await testMethod();
                },
              );
            } catch (error) {
//              _printBufferedErrors(context);
              rethrow;
            }
          }, onError: (dynamic error, StackTrace stackTrace) {
            stdout.writeln(error);
            stdout.writeln(stackTrace);
//            _printBufferedErrors(context);
            throw error;
          });
        },
      );
    });
  },
      timeout: timeout ?? const Timeout(Duration(seconds: 60)),
      testOn: testOn,
      skip: skip);
}

class MockOperatingSystemUtils implements OperatingSystemUtils {
  @override
  ProcessResult makeExecutable(File file) => FakeProcessResult();

  @override
  void chmod(FileSystemEntity entity, String mode) {}

  @override
  File which(String execName) => throw 'Not implemented';

  @override
  List<File> whichAll(String execName) => <File>[];

  @override
  File makePipe(String path) => throw 'Not implemented';

  @override
  void zip(Directory data, File zipFile) {}

  @override
  void unzip(File file, Directory targetDirectory) {}

  @override
  bool verifyZip(File file) => true;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) {}

  @override
  bool verifyGzip(File gzippedFile) => true;

  @override
  String get name => 'fake OS name and version';

  @override
  String get pathVarSeparator => ';';

  @override
  Future<int> findFreePort({bool ipv6 = false}) async => 12345;
}

class LocalFileSystemBlockingSetCurrentDirectory extends LocalFileSystem {
  const LocalFileSystemBlockingSetCurrentDirectory();

  @override
  set currentDirectory(dynamic value) {
    throw 'fs.currentDirectory should not be set on the local file system during '
        'tests as this can cause race conditions with concurrent tests. '
        'Consider using a MemoryFileSystem for testing if possible or refactor '
        'code to not require setting fs.currentDirectory.';
  }
}
