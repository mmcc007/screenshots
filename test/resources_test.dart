import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/resources.dart';
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

//import 'src/common_tools.dart';
import 'src/context.dart';

class PlainMockProcessManager extends Mock implements ProcessManager {}

main() {
  group('resources', () {
    final tmpDir = '/tmp/screenshots_test';

    group('in context', () {
      ProcessManager mockProcessManager;

      setUp(() {
        mockProcessManager = PlainMockProcessManager();
        when(mockProcessManager.runSync(
          any,
          environment: anyNamed('environment'),
          workingDirectory: anyNamed('workingDirectory'),
          runInShell: anyNamed('runInShell'),
        )).thenAnswer(
            (Invocation invocation) => ProcessResult(0, 0, null, null));
      });

      testUsingContext('unpack scripts', () async {
        final result = await unpackScripts(tmpDir);
        expect(result, isNull);
      }, overrides: {ProcessManager: () => mockProcessManager});
    });

    group('no context', () {
      test('unpack screen resource images', () async {
        final Screens screens = Screens();
        await screens.init();
        final screen = screens.getScreen('iPhone 7 Plus');
        final Map screenResources = screen['resources'];
        await unpackImages(screenResources, tmpDir);
      });
    });
  });
}
