import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:resource/resource.dart';

///
/// Parse screens file.
///
class Screens {
  static const devicePath = 'resources/screens.yaml';
  Map _screens;

  ///
  /// Get screens yaml file from resources and parse.
  ///
  Future<void> init() async {
    final resource = Resource("package:screenshots/$devicePath");
    String screens = await resource.readAsString(encoding: utf8);
    _screens = loadYaml(screens) as Map;
  }

  /// Get screen information
  Map get screens => _screens;

  ///
  /// Get map of screen properties from screens yaml file
  ///
  Map screenProps(String deviceName) {
    Map screenProps;

    (screens as YamlNode).value.forEach((os, v) {
      v.value.forEach((screenNum, _screenProps) {
        if (_screenProps['devices'].contains(deviceName)) {
          screenProps = _screenProps;
        }
      });
    });
    return screenProps;
  }
}
