// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

// ignore: unnecessary_new
final messages = new MessageLookup();

// ignore: unused_element
final _keepAnalysisHappy = Intl.defaultLocale;

// ignore: non_constant_identifier_names
typedef MessageIfAbsent = Function(String message_str, List args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  get localeName => 'en';

  @override
  final messages = _notInlinedMessages(_notInlinedMessages);
  static _notInlinedMessages(_) => <String, Function> {
    "counterIncrementButtonTooltip" : MessageLookupByLibrary.simpleMessage("Increment"),
    "counterText" : MessageLookupByLibrary.simpleMessage("You have pushed the button this many times:"),
    "title" : MessageLookupByLibrary.simpleMessage("Screenshots Example")
  };
}
