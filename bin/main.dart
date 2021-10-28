import 'dart:io';

import 'package:args/args.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/globals.dart';

const usage =
    'usage: screenshots [-h] [-c <config file>] [-m <normal|recording|comparison|archive>] [-f <flavor>] [-b <true|false>] [-v]';
const sampleUsage = 'sample usage: screenshots';

void main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final modeArg = 'mode';
  final flavorArg = 'flavor';
  final buildArg = 'build';
  final helpArg = 'help';
  final verboseArg = 'verbose';
  final argParser = ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: kConfigFileName,
        help: 'Path to config file.',
        valueHelp: kConfigFileName)
    ..addOption(modeArg,
        abbr: 'm',
        defaultsTo: 'normal',
        help:
            'If mode is recording, screenshots will be saved for later comparison. \nIf mode is comparison, screenshots will be compared with recorded.\nIf mode is archive, screenshots will be archived (and cannot be uploaded via fastlane).',
        allowed: ['normal', 'recording', 'comparison', 'archive'],
        valueHelp: 'normal|recording|comparison|archive')
    ..addOption(flavorArg,
        abbr: 'f', help: 'Flavor name.', valueHelp: 'flavor name')
    ..addOption(buildArg,
        abbr: 'b',
        help:
            'Force build and install of app for all devices.\nOverride settings in screenshots.yaml (if any).',
        allowed: ['true', 'false'],
        valueHelp: 'true|false')
    ..addFlag(verboseArg,
        abbr: 'v',
        help: 'Noisy logging, including all shell commands executed.',
        negatable: false)
    ..addFlag(helpArg,
        abbr: 'h', help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    return _handleError(argParser, e.toString());
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
  if (!await isImageMagicInstalled()) {
    stderr.writeln(
        '#############################################################');
    stderr.writeln("# You have to install ImageMagick to use Screenshots");
    if (Platform.isMacOS) {
      stderr.writeln(
          "# Install it using 'brew update && brew install imagemagick'");
      stderr.writeln("# If you don't have homebrew: goto http://brew.sh");
    }
    stderr.writeln(
        '#############################################################');
    exit(1);
  }

  // validate args
  if (!await File(argResults[configArg]).exists()) {
    _handleError(argParser, "File not found: ${argResults[configArg]}");
  }

  // Check flutter command is found
  // https://github.com/mmcc007/screenshots/issues/135
  if (getExecutablePath('flutter', '.') == null) {
    stderr.writeln(
        '#############################################################');
    stderr.writeln("# 'flutter' must be in the PATH to use Screenshots");
    stderr.writeln("# You can usually add it to the PATH using"
        "# export PATH='\$HOME/Library/flutter/bin:\$PATH'");
    stderr.writeln(
        '#############################################################');
    exit(1);
  }

  final config = Config(configPath: argResults[configArg]);
  if (config.isRunTypeActive(DeviceType.android)) {
    // check required executables for android
    if (!await isAdbPath()) {
      stderr.writeln(
          '#############################################################');
      stderr.writeln("# 'adb' must be in the PATH to use Screenshots");
      stderr.writeln("# You can usually add it to the PATH using"
          "# export PATH='\$HOME/Library/Android/sdk/platform-tools:\$PATH'");
      stderr.writeln(
          '#############################################################');
      exit(1);
    }
    if (!await isEmulatorPath()) {
      stderr.writeln(
          '#############################################################');
      stderr.writeln("# 'emulator' must be in the PATH to use Screenshots");
      stderr.writeln("# You can usually add it to the PATH using"
          "# export PATH='\$HOME/Library/Android/sdk/emulator:\$PATH'");
      stderr.writeln(
          '#############################################################');
      exit(1);
    }
  }

  final success = await screenshots(
    configPath: argResults[configArg],
    mode: argResults[modeArg],
    flavor: argResults[flavorArg] as String? ?? kNoFlavor,
    isBuild: argResults.wasParsed(buildArg)
        ? argResults[buildArg] == 'true' ? true : false
        : null,
    isVerbose: argResults.wasParsed(verboseArg) ? true : false,
  );
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
