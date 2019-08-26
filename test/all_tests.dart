import 'package:screenshots/src/utils.dart';

import 'screenshots_test.dart' as screenshots_test;
import 'daemon_test.dart' as daemon_test;
import 'env_test.dart' as env_test;
import 'frame_test.dart' as frame_test;
import 'process_images_test.dart' as process_images_test;
import 'screenshots_yaml_test.dart' as screenshots_yaml_test;
import 'statusbar_color_test.dart' as statusbar_color_test;
import 'regression/issue_29.dart' as regression_issue_29_test;
import 'regression/regression_test.dart' as regression_regression_test;
import 'run_test.dart' as run_test;
import 'base/process_test.dart' as base_process_test;

void main() {
  isCI() ? print('running in CI') : print('not running in CI');

  run_test.main();
  base_process_test.main();
  screenshots_test.main();
  daemon_test.main();
  env_test.main();
  frame_test.main();
  process_images_test.main();
  screenshots_yaml_test.main();
  statusbar_color_test.main();
  regression_issue_29_test.main();
  regression_regression_test.main();
}
