import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';

import 'src/utils.dart' as utils;

Builder screens(BuilderOptions options) {
  return ScreensBuilder();
}

Builder resources(BuilderOptions options) {
  return ResourcesBuilder();
}

class ScreensBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '^lib/screens/{{}}.yaml': ['lib/generated/screens/{{}}.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final outputId = AssetId(inputId.package,
            inputId.path.replaceFirst('lib/screens/', 'lib/generated/screens/'))
        .changeExtension('.dart');

    var buf = await generateScreens(File(inputId.path));

    await buildStep.writeAsString(outputId, buf.toString());
  }
}

void main() async {
  var code = await generateScreens(File("lib/screens/screens.yaml"));

  print(code);

  await File("lib/generated/screens/screens.dart").writeAsString(code);
}

Future<String> generateScreens(File file) async {
  var yaml = utils.parseYamlStr(await file.readAsString());

  var imports = <String, String>{};

  final buf = StringBuffer();
  buf.writeln('const List<ScreenInfo> screens = [');
  for (var platform in yaml.entries) {
    var name = platform.key;
    var items = platform.value;
    if (items is Map<String, dynamic>) {
      // buf.writeln("// items: $items");
      for (var item2 in items.entries) {
        var key = item2.key;
        var values2 = item2.value;

        String str(Map<String, dynamic> map, String key) {
          final s = map[key];
          return s != null ? '"$s"' : 'null';
        }

        buf.writeln("  ScreenInfo(");
        buf.writeln("    DeviceType.$name,");
        buf.writeln("    '$key',");
        if (values2 is Map<String, dynamic>) {
          buf.writeln("    ${str(values2, 'size')},");
          buf.writeln("    ${str(values2, 'resize')},");
          buf.writeln("    ${str(values2, 'offset')},");
          buf.writeln("    ${str(values2, 'destName')},");
          var devices = values2['devices'];
          if (devices is List) {
            buf.writeln("    [");
            for (var device in devices) {
              buf.writeln("      '$device',");
            }
            buf.writeln("    ],");
          } else {
            buf.writeln("    [],");
          }

          var resources = values2['resources'];
          if (resources is Map<String, dynamic>) {
            for (var r in resources.entries) {
              var path = r.value;
              var key = r.key.replaceFirst(" b", "B").replaceFirst(" w", "W");

              var import =
                  imports.putIfAbsent(path, () => "i${imports.length + 1}");

              buf.writeln("    $key: $import.r,");
            }
          }
          buf.writeln("  ),");
        }
      }
    }
  }
  buf.writeln('];');

  var importBuf = StringBuffer();
  for (var item in imports.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    importBuf.writeln(
        "import '${item.key.replaceFirst('screens/', '')}.dart' as ${item.value};");
  }

  return (StringBuffer()
        ..writeln("import '../../src/globals.dart';")
        ..writeln("import '../../src/resources.dart';")
        ..writeln()
        ..write(importBuf.toString().trim())
        ..writeln()
        ..writeln()
        ..write(buf.toString().trim())
        ..writeln())
      .toString();
}

class ResourcesBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '^lib/screens/{{}}': ['lib/generated/screens/{{}}.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    // print('RESOURCE');

    final inputId = buildStep.inputId;
    final outputId = AssetId(
      inputId.package,
      inputId.path.replaceFirst('lib/screens/', 'lib/generated/screens/'),
    ).addExtension('.dart');

    var bytes = await buildStep.readAsBytes(inputId);

    final buf = StringBuffer();
    buf.writeln("import 'package:screenshots/src/resources.dart';");
    buf.writeln();
    buf.writeln('const r = EmbeddedResource(');
    buf.writeln('  "${inputId.path.replaceFirst('lib/screens/', '')}",');
    buf.writeln('  [');
    for (var b in bytes) {
      buf.writeln('    0x${b.toRadixString(16)},');
    }
    buf.writeln('  ],');
    buf.writeln(');');
    await buildStep.writeAsString(outputId, buf.toString());
  }
}
