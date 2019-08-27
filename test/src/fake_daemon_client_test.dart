import 'package:test/test.dart';

import 'fake_daemon_client.dart';

main() {
  group('fake process', () {
    test('server process', () {});
  });

  group('fake daemon client', () {
    FakeDaemonClient fakeDaemonClient;

    setUp(() {
      fakeDaemonClient = FakeDaemonClient();
    });

    test('start works', () {
      expect(fakeDaemonClient.start, isNotNull);
    });
  });
}
