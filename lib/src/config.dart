import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'screens.dart';
import 'utils.dart' as utils;
import 'globals.dart';

///
/// Config info used to process screenshots for android and ios.
///
class Config {
  Config({this.configPath = kConfigFileName, String configStr}) {
    if (configStr != null) {
      _configInfo = utils.parseYamlStr(configStr);
    } else {
      _configInfo = utils.parseYamlFile(configPath);
    }
  }

  final String configPath;
  Map _configInfo;
  Map _screenshotsEnv; // current screenshots env

  /// Get configuration information for supported devices
  Map get configInfo => _configInfo;

  /// Current screenshots runtime environment
  /// (updated before start of each test)
  Future<Map> get screenshotsEnv async {
    if (_screenshotsEnv == null) await _retrieveEnv();
    return _screenshotsEnv;
  }

  File get _envStore {
    return File(configInfo['staging'] + '/' + kEnvFileName);
  }

  /// Records screenshots environment before start of each test
  /// (called by screenshots)
  @visibleForTesting
  Future<void> storeEnv(Screens screens, String emulatorName, String locale,
      String deviceType, String orientation) async {
    // store env for later use by tests
    final screenProps = screens.getScreen(emulatorName);
    final screenSize = screenProps == null ? null : screenProps['size'];
    final currentEnv = {
      'screen_size': screenSize,
      'locale': locale,
      'device_name': emulatorName,
      'device_type': deviceType,
      'orientation': orientation
    };
    await _envStore.writeAsString(json.encode(currentEnv));
  }

  Future<void> _retrieveEnv() async {
    _screenshotsEnv = json.decode(await _envStore.readAsString());
  }
}
