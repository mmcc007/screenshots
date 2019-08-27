import 'dart:io';

import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:test/test.dart';

import 'src/context.dart';
import 'src/fake_process_manager.dart';

main() {
  FakeProcessManager fakeProcessManager;

  setUp(() async {
    fakeProcessManager = FakeProcessManager();
  });

//  testUsingContext('run daemon client', () async {
  test('run daemon client', () async {
    final Map<String, List<ProcessResult>> processCalls = {
      'flutter daemon': [
        ProcessResult(0, 0, 'no attached devices', ''),
      ],
    };
    fakeProcessManager.fakeResults = processCalls;
    final daemonClient = DaemonClient();
    daemonClient.verbose = true;
    await daemonClient.start;
    final emulators = await daemonClient.emulators;
    expect(emulators.length, greaterThan(0));
//  }, overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});
  });
}
