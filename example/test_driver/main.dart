import 'dart:async';
import 'dart:convert' as c;
import 'dart:ui' as ui;

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:intl/intl.dart';

void main() {
  final DataHandler handler = (_) async {
    final localizations =
        await ExampleLocalizations.load(Locale(ui.window.locale.languageCode));
    final response = {
      'counterIncrementButtonTooltip':
          localizations.counterIncrementButtonTooltip,
      'counterText': localizations.counterText,
      'title': localizations.title,
      'locale': Intl.defaultLocale
    };
    return Future.value(c.jsonEncode(response));
  };
  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  enableFlutterDriverExtension(handler: handler);
  WidgetsApp.debugAllowBannerOverride = false; // remove debug banner
  runApp(MyApp());
}
