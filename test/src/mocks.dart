import 'dart:async';
import 'dart:io' as io show IOSink;

import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_mobile/tool_mobile.dart';

/// An SDK installation with several SDK levels (19, 22, 23).
class MockAndroidSdk extends Mock implements AndroidSdk {
  static Directory createSdkDirectory({
    bool withAndroidN = false,
    String? withNdkDir,
    int ndkVersion = 16,
    bool withNdkSysroot = false,
    bool withSdkManager = true,
    bool withPlatformTools = true,
    bool withBuildTools = true,
  }) {
    final dir =
    fs.systemTempDirectory.createTempSync('flutter_mock_android_sdk.');
    final exe = platform.isWindows ? '.exe' : '';
    final bat = platform.isWindows ? '.bat' : '';

    _createDir(dir, 'licenses');

    if (withPlatformTools) {
      _createSdkFile(dir, 'platform-tools/adb$exe');
    }

    if (withBuildTools) {
      _createSdkFile(dir, 'build-tools/19.1.0/aapt$exe');
      _createSdkFile(dir, 'build-tools/22.0.1/aapt$exe');
      _createSdkFile(dir, 'build-tools/23.0.2/aapt$exe');
      if (withAndroidN) {
        _createSdkFile(dir, 'build-tools/24.0.0-preview/aapt$exe');
      }
    }

    _createSdkFile(dir, 'platforms/android-22/android.jar');
    _createSdkFile(dir, 'platforms/android-23/android.jar');
    if (withAndroidN) {
      _createSdkFile(dir, 'platforms/android-N/android.jar');
      _createSdkFile(dir, 'platforms/android-N/build.prop',
          contents: _buildProp);
    }

    if (withSdkManager) _createSdkFile(dir, 'tools/bin/sdkmanager$bat');

    if (withNdkDir != null) {
      final ndkToolchainBin = fs.path.join(
        'ndk-bundle',
        'toolchains',
        'arm-linux-androideabi-4.9',
        'prebuilt',
        withNdkDir,
        'bin',
      );
      final ndkCompiler = fs.path.join(
        ndkToolchainBin,
        'arm-linux-androideabi-gcc',
      );
      final ndkLinker = fs.path.join(
        ndkToolchainBin,
        'arm-linux-androideabi-ld',
      );
      _createSdkFile(dir, ndkCompiler);
      _createSdkFile(dir, ndkLinker);
      _createSdkFile(dir, fs.path.join('ndk-bundle', 'source.properties'),
          contents: '''
Pkg.Desc = Android NDK[]
Pkg.Revision = $ndkVersion.1.5063045

''');
    }
    if (withNdkSysroot) {
      final armPlatform = fs.path.join(
        'ndk-bundle',
        'platforms',
        'android-9',
        'arch-arm',
      );
      _createDir(dir, armPlatform);
    }

    return dir;
  }

  static void _createSdkFile(Directory dir, String filePath,
      {String? contents}) {
    final file = dir.childFile(filePath);
    file.createSync(recursive: true);
    if (contents != null) {
      file.writeAsStringSync(contents, flush: true);
    }
  }

  static void _createDir(Directory dir, String path) {
    final directory = fs.directory(fs.path.join(dir.path, path));
    directory.createSync(recursive: true);
  }

  static const String _buildProp = r'''
ro.build.version.incremental=1624448
ro.build.version.sdk=24
ro.build.version.codename=REL
''';
}

/// A strategy for creating Process objects from a list of commands.
typedef ProcessFactory = Process Function(List<String> command);

/// A ProcessManager that starts Processes by delegating to a ProcessFactory.
class MockReturningProcessManager implements ProcessManager {
  final ProcessFactory processFactory = (List<String> commands) => MockProcess();

  @override
  bool canRun(dynamic command, {String? workingDirectory}) => true;

  @override
  Future<Process> start(
    List<Object>? command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    command ??= [];
    var args = command.map((e) => e.toString()).toList();

    return Future<Process>.value(processFactory(args));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockProcessManager extends Mock implements ProcessManager {

  @override
  Future<Process> start(
      List<Object>? command, {
        String? workingDirectory,
        Map<String, String>? environment,
        bool? includeParentEnvironment,
        bool? runInShell,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) =>
      super.noSuchMethod(Invocation.method(#start, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #mode: mode,
      }));

  @override
  Future<ProcessResult> run(
      List<Object>? command, {
        String? workingDirectory,
        Map<String, String>? environment,
        bool? includeParentEnvironment,
        bool? runInShell,
        covariant Encoding? stdoutEncoding = systemEncoding,
        covariant Encoding? stderrEncoding = systemEncoding,
      }) =>
      super.noSuchMethod(Invocation.method(#run, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #stdoutEncoding: stdoutEncoding,
        #stderrEncoding: stderrEncoding,
      }));

  @override
  ProcessResult runSync(
      List<Object>? command, {
        String? workingDirectory,
        Map<String, String>? environment,
        bool? includeParentEnvironment,
        bool? runInShell,
        covariant Encoding? stdoutEncoding = systemEncoding,
        covariant Encoding? stderrEncoding = systemEncoding,
      }) =>
      super.noSuchMethod(Invocation.method(#runSync, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #stdoutEncoding: stdoutEncoding,
        #stderrEncoding: stderrEncoding,
      }));
}

/// A process that exits successfully with no output and ignores all input.
class MockProcess extends Mock implements Process {
  MockProcess({
    this.pid = 1,
    Future<int>? exitCode,
    io.IOSink? stdin,
    this.stdout = const Stream<List<int>>.empty(),
    this.stderr = const Stream<List<int>>.empty(),
  })  : exitCode = exitCode ?? Future<int>.value(0),
        stdin = stdin ?? MemoryIOSink();

  @override
  final int pid;

  @override
  final Future<int> exitCode;

  @override
  final io.IOSink stdin;

  @override
  final Stream<List<int>> stdout;

  @override
  final Stream<List<int>> stderr;
}

/// An IOSink that collects whatever is written to it.
class MemoryIOSink implements IOSink {
  @override
  Encoding encoding = utf8;

  final List<List<int>> writes = <List<int>>[];

  @override
  void add(List<int> data) {
    writes.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    final completer = Completer<void>();
    stream.listen((List<int> data) {
      add(data);
    }).onDone(() => completer.complete());
    return completer.future;
  }

  @override
  void writeCharCode(int charCode) {
    add(<int>[charCode]);
  }

  @override
  void write(Object? obj) {
    add(encoding.encode('$obj'));
  }

  @override
  void writeln([Object? obj = '']) {
    add(encoding.encode('$obj\n'));
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    var addSeparator = false;
    for (dynamic object in objects) {
      if (addSeparator) {
        write(separator);
      }
      write(object);
      addSeparator = true;
    }
  }

  @override
  void addError(dynamic error, [StackTrace? stackTrace]) {
    throw UnimplementedError();
  }

  @override
  Future<void> get done => close();

  @override
  Future<void> close() async {}

  @override
  Future<void> flush() async {}
}

/// A Stdio that collects stdout and supports simulated stdin.
class MockStdio extends Stdio {
  final MemoryIOSink _stdout = MemoryIOSink();
  final MemoryIOSink _stderr = MemoryIOSink();
  final StreamController<List<int>> _stdin = StreamController<List<int>>();

//  @override
//  IOSink get stdout => _stdout;

  @override
  IOSink get stderr => _stderr;

  @override
  Stream<List<int>> get stdin => _stdin.stream;

  void simulateStdin(String line) {
    _stdin.add(utf8.encode('$line\n'));
  }

  List<String> get writtenToStdout =>
      _stdout.writes.map<String>(_stdout.encoding.decode).toList();
  List<String> get writtenToStderr =>
      _stderr.writes.map<String>(_stderr.encoding.decode).toList();
}

class FakeProcessResult implements ProcessResult {
  FakeProcessResult({
    this.exitCode = 0,
    this.pid = 1,
    this.stderr,
    this.stdout,
  });

  @override
  final int exitCode;

  @override
  final int pid;

  @override
  final dynamic stderr;

  @override
  final dynamic stdout;

  @override
  String toString() => stdout?.toString() ?? stderr?.toString() ?? runtimeType.toString();
}
