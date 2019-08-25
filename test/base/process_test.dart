import 'dart:io';

import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/base/process.dart';
import 'package:test/test.dart';

import '../src/context.dart';
import '../src/fake_process_manager.dart';

main() {
  FakeProcessManager fakeProcessManager;
  final List<String> stdinCaptured = <String>[];

  setUp(() async {
    fakeProcessManager = FakeProcessManager();
  });

  group('process', () {
    testUsingContext('run command and capture output', () {
      final Map<String, List<ProcessResult>> calls =
          <String, List<ProcessResult>>{
        'ls -la': <ProcessResult>[
          ProcessResult(0, 0, 'output from ls -la', ''),
        ],
      };
      fakeProcessManager.fakeResults = calls;
      final result = cmd(['ls', '-la']);
      expect(result, 'output from ls -la');
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => initTraceLogger()
    });

    testUsingContext('run command and stream output', () async {
      final Map<String, List<ProcessResult>> calls =
          <String, List<ProcessResult>>{
        'ls -la': <ProcessResult>[
          ProcessResult(0, 0, 'output from ls -la', ''),
        ],
      };
      fakeProcessManager.fakeResults = calls;
      await streamCmd(['ls', '-la']);
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => initTraceLogger()
    });

//    test('xreal run command and capture output ', () async {
//      final result = cmd(['ls', '-la'], '.', true);
//      print('result=$result');
//    });
//
//    test('real run command and stream output', () async {
//      await runCommandAndStreamOutput(['ls', '-la']);
//    });
  });
}
