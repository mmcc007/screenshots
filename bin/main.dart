import 'dart:io';

import 'package:args/args.dart';
import 'package:screenshots/screenshots.dart';

const usage =
    'usage: screenshots [-h] [-c <config file>] [-m <normal|recording|comparison|archive>]';
const sampleUsage = 'sample usage: screenshots';

void main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final modeArg = 'mode';
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
            'If mode is recording, screenshots will be saved for later comparison. \nIf mode is archive, screenshots will be archived and cannot be uploaded via fastlane.',
        allowed: ['normal', 'recording', 'comparison', 'archive'],
        valueHelp: 'normal|recording|comparison|archive')
    ..addFlag(helpArg,
        abbr: 'h', help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // confirm os
  switch (Platform.operatingSystem) {
    case 'windows':
      print(
          'Screenshots is not supported on windows. Try running on MacOS or Linux in cloud.');
      exit(1);
      break;
    case 'linux':
    case 'macos':
      break;
    default:
      throw 'unknown os: ${Platform.operatingSystem}';
  }

  // check imagemagick is installed
  if (!cmd('sh', ['-c', 'which convert && echo convert || echo not installed'],
          '.', true)
      .toString()
      .contains('convert')) {
    stderr.write(
        '#############################################################\n');
    stderr.write("# You have to install ImageMagick to use Screenshots\n");
    stderr.write(
        "# Install it using 'brew update && brew install imagemagick'\n");
    stderr.write("# If you don't have homebrew: goto http://brew.sh\n");
    stderr.write(
        '#############################################################\n');
    exit(1);
  }

  // check adb is in path
  if (!cmd('sh', ['-c', 'which adb && echo adb || echo not installed'], '.',
          true)
      .toString()
      .contains('adb')) {
    stderr.write(
        '#############################################################\n');
    stderr.write("# 'adb' must be in the PATH to use Screenshots\n");
    stderr.write("# You can usually add it to the PATH using\n"
        "# export PATH='~/Library/Android/sdk/platform-tools:\$PATH'  \n");
    stderr.write(
        '#############################################################\n');
    exit(1);
  }

  // show help
  if (argResults[helpArg]) {
    _showUsage(argParser);
    exit(0);
  }

  // validate args
  final file = File(argResults[configArg]);
  if (!await file.exists()) {
    _handleError(argParser, "File not found: ${argResults[configArg]}");
  }

  await run(argResults[configArg], argResults[modeArg]);
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
