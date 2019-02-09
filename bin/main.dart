import 'dart:io';

import 'package:screenshots/screenshots.dart' as screenshots;
import 'package:args/args.dart';
import 'package:screenshots/utils.dart' as utils;

const usage = 'usage: screenshots [--help] [--config <config file>]';
const sampleUsage = 'sample usage: screenshots';

void main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final helpArg = 'help';
  final ArgParser argParser = new ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'screenshots.yaml',
        help: 'Path to config file.',
        valueHelp: 'screenshots.yaml')
    ..addFlag(helpArg,
        help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // confirm os
  switch (Platform.operatingSystem) {
    case 'windows':
      print(
          'screenshots is not supported on windows. Try running on MacOS or Linux in cloud.');
      exit(1);
      break;
    case 'linux':
    case 'macos':
      break;
    default:
      throw 'unknown os: ${Platform.operatingSystem}';
  }

  if (!utils
      .cmd('sh', ['-c', 'which convert && echo convert || echo not installed'],
          '.', true)
      .toString()
      .contains('convert')) {
    stderr.write(
        '#############################################################\n');
    stderr.write("# You have to install ImageMagick to use screenshots\n");
    stderr.write(
        "# Install it using 'brew update && brew install imagemagick'\n");
    stderr.write("# If you don't have homebrew: goto http://brew.sh\n");
    stderr.write(
        '#############################################################\n');
    exit(1);
  }
  // validate args
  final file = File(argResults[configArg]);
  if (!await file.exists())
    _handleError(argParser, "File not found: ${argResults[configArg]}");

  await screenshots.run(argResults[configArg]);
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
