import 'dart:io';

import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/base/process.dart';
import 'package:test/test.dart';

import 'context.dart';
import 'fake_process_manager.dart';

main() {
  final testCmd = ['echo', 'hello'];
  final response = '${testCmd[1]}\n';

  group('context only', () {
    FakeProcessManager fakeProcessManager = FakeProcessManager();

    testUsingContext('test', () async {
      final Map<String, List<ProcessResult>> processCalls = {
        testCmd.join(' '): [
          ProcessResult(0, 0, response, ''),
        ],
      };
      fakeProcessManager.fakeResults = processCalls;
      // todo: replace FakeProcessManager with a mock to get to stdout
      await streamCmd(testCmd);
      expect(cmd(testCmd), response);
    }, overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});
  });

  group('no context', () {
    test('test', () async {
      await streamCmd(testCmd);
      expect(cmd(testCmd), response);
    });
  });
}
