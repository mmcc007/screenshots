import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:resource/resource.dart';

///
/// Parse screens file.
///
class Screens {
  static const devicePath = 'resources/screens.yaml';

  ///
  /// Get screens yaml file from resources and parse.
  ///
  Future<Map> init() async {
    var resource = Resource("package:screenshots/$devicePath");
    String screens = await resource.readAsString(encoding: utf8);
    return loadYaml(screens) as Map;
  }

  ///
  /// Get map of screen properties from screens yaml file
  ///
  Map screenProps(Map screens, String deviceName) {
    Map screenProps;

    (screens as YamlNode).value.forEach((os, v) {
      v.value.forEach((screenNum, _screenProps) {
//        print('devices=${_screenProps['devices'][0]}');
        if (_screenProps['devices'].contains(deviceName)) {
          screenProps = _screenProps;
        }
      });
    });
    return screenProps;
  }
}
