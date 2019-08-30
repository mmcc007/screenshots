import 'dart:async';
import 'dart:convert';
import 'dart:io' as io show IOSink, ProcessSignal;
import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/base/io.dart';

/// A strategy for creating Process objects from a list of commands.
typedef ProcessFactory = Process Function(List<String> command);

/// A ProcessManager that starts Processes by delegating to a ProcessFactory.
class MockProcessManager implements ProcessManager {
  ProcessFactory processFactory = (List<String> commands) => MockProcess();
  bool succeed = true;
  List<String> commands;

  @override
  bool canRun(dynamic command, {String workingDirectory}) => succeed;

  @override
  Future<Process> start(
    List<dynamic> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    if (!succeed) {
      final String executable = command[0];
      final List<String> arguments =
          command.length > 1 ? command.sublist(1) : <String>[];
      throw ProcessException(executable, arguments);
    }

    commands = command;
    return Future<Process>.value(processFactory(command));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A process that exits successfully with no output and ignores all input.
class MockProcess extends Mock implements Process {
  MockProcess({
    this.pid = 1,
    Future<int> exitCode,
    Stream<List<int>> stdin,
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
    final Completer<void> completer = Completer<void>();
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
  void write(Object obj) {
    add(encoding.encode('$obj'));
  }

  @override
  void writeln([Object obj = '']) {
    add(encoding.encode('$obj\n'));
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    bool addSeparator = false;
    for (dynamic object in objects) {
      if (addSeparator) {
        write(separator);
      }
      write(object);
      addSeparator = true;
    }
  }

  @override
  void addError(dynamic error, [StackTrace stackTrace]) {
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

  @override
  IOSink get stdout => _stdout;

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
