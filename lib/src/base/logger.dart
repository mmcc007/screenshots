import 'package:logging/logging.dart';

import 'context.dart';

Logger initTraceLogger([Level level = Level.ALL]) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  return Logger.root;
}

Logger initDefaultLogger() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord rec) {
    print(rec.message);
  });
  return Logger.root;
}

final Logger _kLogger = initDefaultLogger();

/// The active logger.
Logger get logger => context.get<Logger>() ?? _kLogger;
//final Logger logger = Logger('MyClassName');

/// Use this for verbose tracing output. Users can turn this output on in order
/// to help diagnose issues with the toolchain or with their setup.
void printTrace(String message) => logger.finest(message);

/// Display an error level message to the user. Commands should use this if they
/// fail in some way.
///
/// Set [emphasis] to true to make the output bold if it's supported.
/// Set [color] to a [TerminalColor] to color the output, if the logger
/// supports it. The [color] defaults to [TerminalColor.red].
void printError(
  String message, {
  StackTrace stackTrace,
  bool emphasis,
  TerminalColor color,
  int indent,
  int hangingIndent,
  bool wrap,
}) {
  logger.severe(
    message,
    stackTrace,
//    emphasis: emphasis ?? false,
//    color: color,
//    indent: indent,
//    hangingIndent: hangingIndent,
//    wrap: wrap,
  );
}

/// Display normal output of the command. This should be used for things like
/// progress messages, success messages, or just normal command output.
///
/// Set `emphasis` to true to make the output bold if it's supported.
///
/// Set `newline` to false to skip the trailing linefeed.
///
/// If `indent` is provided, each line of the message will be prepended by the
/// specified number of whitespaces.
void printStatus(
  String message, {
  bool emphasis,
  bool newline,
  TerminalColor color,
  int indent,
  int hangingIndent,
  bool wrap,
}) {
  logger.info(
    message,
//    emphasis: emphasis ?? false,
//    color: color,
//    newline: newline ?? true,
//    indent: indent,
//    hangingIndent: hangingIndent,
//    wrap: wrap,
  );
}

enum TerminalColor {
  red,
  green,
  blue,
  cyan,
  yellow,
  magenta,
  grey,
}
