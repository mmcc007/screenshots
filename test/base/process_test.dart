import 'dart:io';

import 'package:logging/logging.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/base/logger.dart';
import 'package:screenshots/src/base/process.dart';
import 'package:test/test.dart';

import '../src/context.dart';
import '../src/fake_process_manager.dart';

main() {
  final testCmd = ['echo', 'hello'];
  final expected = testCmd[1];
  FakeProcessManager fakeProcessManager;

  setUp(() async {
    fakeProcessManager = FakeProcessManager();
    final Map<String, List<ProcessResult>> calls =
        <String, List<ProcessResult>>{
      testCmd.join(' '): <ProcessResult>[
        ProcessResult(0, 0, expected, ''),
      ],
    };
    fakeProcessManager.fakeResults = calls;
  });

  group('process', () {
    testUsingContext('run command and capture output', () {
      final result = cmd(testCmd);
      expect(result, expected);
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Logger: () => initTraceLogger()
    }, skip: false);

    testUsingContext('run command and stream output', () async {
      await streamCmd(testCmd);
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Logger: () => initTraceLogger()
    }, skip: false);

    testUsingContext('run command and stream output', () async {
      await runCommandAndStreamOutput(testCmd);
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Logger: () => initTraceLogger()
    }, skip: false);

    testUsingContext('run command', () async {
      final process = await runCommand(testCmd);
      expect(process, isNotNull);
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Logger: () => initTraceLogger()
    }, skip: false);

  });
}
