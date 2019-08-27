import 'package:mockito/mockito.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:test/test.dart';

class FakeDaemonClient extends Mock implements DaemonClient {
  FakeDaemonClient() {
    _setupMock();
  }
  Map<String, List<String>> _daemonResponses = <String, List<String>>{};
  Map<String, List<String>> get daemonResponses => _daemonResponses;

  set fakeResponses(Map<String, List<String>> value) {
    _daemonResponses = <String, List<String>>{};
    for (String key in value.keys) {
      _daemonResponses[key] = []..addAll(value[key] ?? ['']);
    }
  }

  String _popResult(List<String> command) {
    final String key = command.join(' ');
    expect(daemonResponses, isNotEmpty);
    expect(daemonResponses, contains(key));
    expect(daemonResponses[key], isNotEmpty);
    return daemonResponses[key].removeAt(0);
  }

  Future<String> _nextResultAsync(Invocation invocation) async {
    return Future<String>.value(_popResult(invocation.positionalArguments[0]));
  }

  void _setupMock() {
    when(start).thenAnswer((_) => Future<void>.value());
    when(stop).thenAnswer((_) => Future<void>.value());
    when(emulators).thenAnswer((_) => Future.value([]));
    when(devices).thenAnswer((_) => Future.value([]));
    when(launchEmulator(any)).thenAnswer((_) => Future.value(''));
    when(waitForEvent(any)).thenAnswer((_) => Future.value({}));

//    when(run(
//      any,
//      environment: anyNamed('environment'),
//      workingDirectory: anyNamed('workingDirectory'),
//    )).thenAnswer(_nextResult);
//
//    when(run(any)).thenAnswer(_nextResult);
//
//    when(runSync(
//      any,
//      environment: anyNamed('environment'),
//      workingDirectory: anyNamed('workingDirectory'),
//      runInShell: anyNamed('runInShell'),
//    )).thenAnswer(_nextResultSync);
//
//    when(runSync(any)).thenAnswer(_nextResultSync);
//
//    when(killPid(any, any)).thenReturn(true);
//
//    when(canRun(any, workingDirectory: anyNamed('workingDirectory')))
//        .thenReturn(true);
  }
}
