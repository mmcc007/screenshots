import 'dart:async';

import 'package:screenshots/generated/screens/script/android-wait-for-emulator-to-stop.dart' as android_wait_for_emulator_to_stop;
import 'package:screenshots/generated/screens/script/android-wait-for-emulator.dart' as android_wait_for_emulator;
import 'package:screenshots/generated/screens/script/sim_orientation.scpt.dart' as sim_orientation_scpt;
import 'package:screenshots/generated/screens/script/simulator-controller.dart' as simulator_controller;
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/utils.dart';
import 'package:tool_base/tool_base.dart';

class EmbeddedResource {
  final String path;
  final List<int> bytes;

  const EmbeddedResource(this.path, this.bytes);
}

class ScreenInfo {
  final DeviceType deviceType;
  final String name;
  final String? size;
  final String? resize;
  final String? offset;
  final String? destName;
  final List<String> devices;
  final EmbeddedResource? statusbar;
  final EmbeddedResource? statusbarBlack;
  final EmbeddedResource? statusbarWhite;
  final EmbeddedResource? frame;
  final EmbeddedResource? navbar;

  const ScreenInfo(
    this.deviceType,
    this.name,
    this.size,
    this.resize,
    this.offset,
    this.destName,
    this.devices, {
    this.statusbar,
    this.statusbarBlack,
    this.statusbarWhite,
    this.frame,
    this.navbar,
  });
}

class ScreenImagePaths {
  final File? statusbar;
  final File? statusbarBlack;
  final File? statusbarWhite;
  final File? frame;
  final File? navbar;

  ScreenImagePaths(
    this.statusbar,
    this.statusbarBlack,
    this.statusbarWhite,
    this.frame,
    this.navbar,
  );
}

class Scripts {
  final File android_wait_for_emulator_to_stop;
  final File android_wait_for_emulator;
  final File sim_orientation_scpt;
  final File simulator_controller;

  Scripts(
    this.android_wait_for_emulator_to_stop,
    this.android_wait_for_emulator,
    this.sim_orientation_scpt,
    this.simulator_controller,
  );
}

///
/// Copy resource images for a screen from package to files.
///
Future<ScreenImagePaths> unpackImages(ScreenInfo screen, String dstDir) async =>
    ScreenImagePaths(
      screen.statusbar == null
          ? null
          : await writeImage(screen.statusbar!, '$dstDir/statusbar.png'),
      screen.statusbarBlack == null
          ? null
          : await writeImage(
              screen.statusbarBlack!, '$dstDir/statusbarBlack.png'),
      screen.statusbarWhite == null
          ? null
          : await writeImage(
              screen.statusbarWhite!, '$dstDir/statusbarWhite.png'),
      screen.frame == null
          ? null
          : await writeImage(screen.frame!, '$dstDir/frame.png'),
      screen.navbar == null
          ? null
          : await writeImage(screen.navbar!, '$dstDir/navbar.png'),
    );

/// Read scripts from resources and install in staging area.
Future<Scripts> unpackScripts(String dstDir) async {
  return Scripts(
    await unpackScript(android_wait_for_emulator_to_stop.r, dstDir),
    await unpackScript(android_wait_for_emulator.r, dstDir),
    await unpackScript(sim_orientation_scpt.r, dstDir),
    await unpackScript(simulator_controller.r, dstDir),
  );
}

/// Read script from resources and install in staging area.
Future<File> unpackScript(EmbeddedResource r, String dstDir) async {
  var f = fs.file('$dstDir/${r.path}');
  final file = await f.create(recursive: true);
  await file.writeAsBytes(r.bytes, flush: true);
  // make executable
  cmd(['chmod', 'u+x', f.path]);

  return file;
}

Future<File> writeImage(EmbeddedResource r, String path) async {
  final file = await fs.file(path).create(recursive: true);
  await file.writeAsBytes(r.bytes, flush: true);
  return file;
}
