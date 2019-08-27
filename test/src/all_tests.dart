import 'context_test.dart' as context_test;
import 'fake_daemon_client_test.dart' as fake_daemon_client_test;
import 'fake_process_manager_test.dart' as fake_process_manager_test;

main() {
  context_test.main();
  fake_daemon_client_test.main();
  fake_process_manager_test.main();
}
