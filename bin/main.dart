import 'dart:io';

import 'package:args/args.dart';
import 'package:screenshots/screenshots.dart';
import 'package:path/path.dart' as path;

const usage =
    'usage: screenshots [-h] [-c <config file>] [-m <normal|recording|comparison|archive>] [-f <flavor>]';
const sampleUsage = 'sample usage: screenshots';

void main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final modeArg = 'mode';
  final flavorArg = 'flavor';
  final helpArg = 'help';
  final ArgParser argParser = ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'screenshots.yaml',
        help: 'Path to config file.',
        valueHelp: 'screenshots.yaml')
    ..addOption(modeArg,
        abbr: 'm',
        defaultsTo: 'normal',
        help:
            'If mode is recording, screenshots will be saved for later comparison. \nIf mode is comparison, screenshots will be compared with recorded.\nIf mode is archive, screenshots will be archived (and cannot be uploaded via fastlane).',
        allowed: ['normal', 'recording', 'comparison', 'archive'],
        valueHelp: 'normal|recording|comparison|archive')
    ..addOption(flavorArg,
        abbr: 'f', help: 'Flavor name.', valueHelp: 'flavor name')
    ..addFlag(helpArg,
        abbr: 'h', help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // show help
  if (argResults[helpArg]) {
    _showUsage(argParser);
    exit(0);
  }

  // confirm os
  if (!['windows', 'linux', 'macos'].contains(Platform.operatingSystem)) {
    stderr.writeln('Error: unsupported os: ${Platform.operatingSystem}');
    exit(1);
  }

  // check imagemagick is installed
  checkImageMagicInstalled();

  // validate args
  if (!await File(argResults[configArg]).exists()) {
    _handleError(argParser, "File not found: ${argResults[configArg]}");
  }

  // check adb is found
  final config = Config(configPath: argResults[configArg]);
  if (config.isRunTypeActive(DeviceType.android)) {
    getAdbPath();
  }

  final success = await run(
      configPath: argResults[configArg],
      mode: argResults[modeArg],
      flavor: argResults[flavorArg]);
  exit(success ? 0 : 1);
}

void _handleError(ArgParser argParser, String msg) {
  stderr.writeln(msg);
  _showUsage(argParser);
}

void _showUsage(ArgParser argParser) {
  print('$usage');
  print('\n$sampleUsage\n');
  print(argParser.usage);
  exit(2);
}

/// Path to the `adb` executable.
String getAdbPath() {
  final String androidHome = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (androidHome == null) {
    stderr.writeln(
        'The ANDROID_SDK_ROOT and ANDROID_HOME environment variables are '
        'missing. At least one of these variables must point to the Android '
        'SDK directory containing platform-tools.');
    exit(1);
  }
  final adbName = Platform.isWindows ? 'adb.exe' : 'adb';
  final String adbPath = path.join(androidHome, 'platform-tools/${adbName}');
  final absPath = path.absolute(adbPath);
  if (!File(adbPath).existsSync()) {
    stderr.write(
        '#############################################################\n');
    stderr.write("# 'adb' must be in the PATH to use Screenshots\n");
    stderr.write("# You can usually add it to the PATH using\n"
        "# export PATH='\$HOME/Library/Android/sdk/platform-tools:\$PATH'  \n");
    stderr.write(
        '#############################################################\n');
    exit(1);
  }
  return absPath;
}
