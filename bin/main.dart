import 'dart:io';

import 'package:args/args.dart';
import 'package:screenshots/screenshots.dart';

const usage =
    'usage: screenshots [-h] [-c <config file>] [-m <normal|recording|comparison|archive>] [-f <flavor>] [-v]';
const sampleUsage = 'sample usage: screenshots';

void main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final modeArg = 'mode';
  final flavorArg = 'flavor';
  final helpArg = 'help';
  final verboseArg = 'verbose';
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
    ..addFlag(verboseArg,
        abbr: 'v',
        help: 'Noisy logging, including all shell commands executed.',
        negatable: false)
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

  final config = Config(configPath: argResults[configArg]);
  if (config.isRunTypeActive(DeviceType.android)) {
    // check required executables for android
    checkAdbPath() == null ? exit(1) : Null;
    getEmulatorPath() == null ? exit(1) : Null;
  }

  final success = await screenshots(
    configPath: argResults[configArg],
    mode: argResults[modeArg],
    flavor: argResults[flavorArg],
    verbose: argResults.wasParsed(verboseArg) ? true : false,
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
