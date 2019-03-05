import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

// This imported file was generated in two steps, using the Dart intl tools. With the
// app's root directory (the one that contains pubspec.yaml) as the current
// directory:
//
// flutter pub get
// flutter pub pub run intl_translation:extract_to_arb --output-dir=lib/l10n lib/main.dart
// flutter pub pub run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/main.dart lib/l10n/intl_*.arb
//
// The second command generates intl_messages.arb and the third generates
// messages_all.dart. There's more about this process in
// https://pub.dartlang.org/packages/intl.
import 'l10n/messages_all.dart';

// For tips on internationalization see:
// https://phraseapp.com/blog/posts/how-to-internationalize-a-flutter-app

class ExampleLocalizations {
  static Future<ExampleLocalizations> load(Locale locale) {
    final String name = locale.countryCode == null || locale.countryCode.isEmpty
        ? locale.languageCode
        : locale.toString();
    final String localeName = Intl.canonicalizedLocale(name);

    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return ExampleLocalizations();
    });
  }

  static ExampleLocalizations of(BuildContext context) {
    return Localizations.of<ExampleLocalizations>(
        context, ExampleLocalizations);
  }

  String get title {
    return Intl.message(
      'Screenshots Example',
      name: 'title',
      desc: 'Title for the Example application',
    );
  }

  String get counterText {
    return Intl.message(
      'You have pushed the button this many times:',
      name: 'counterText',
      desc: 'Explanation for incrementing counter',
    );
  }

  String get counterIncrementButtonTooltip {
    return Intl.message(
      'Increment',
      name: 'counterIncrementButtonTooltip',
      desc: 'Tooltip for counter increment button',
    );
  }
}

class ExampleLocalizationsDelegate
    extends LocalizationsDelegate<ExampleLocalizations> {
  const ExampleLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<ExampleLocalizations> load(Locale locale) =>
      ExampleLocalizations.load(locale);

  @override
  bool shouldReload(ExampleLocalizationsDelegate old) => false;
}

class DemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ExampleLocalizations.of(context).title),
      ),
      body: Center(
        child: Text(ExampleLocalizations.of(context).title),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => ExampleLocalizations.of(context).title,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
      localizationsDelegates: [
        // ... app-specific localization delegate[s] here
        const ExampleLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'), // English
        const Locale('fr'), // French
//        const Locale('en', 'US'), // American English
//        const Locale('fr', 'CA'), // Canadian French
        // ... other locales the app supports
      ],
      // some android emulators on some machines may require the following:
      // see: https://github.com/flutter/flutter/issues/25325
//      locale: const Locale('en', ''),
//      localeResolutionCallback: (x, y) => const Locale('en', ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

//  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(ExampleLocalizations.of(context).title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              ExampleLocalizations.of(context).counterText,
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: ExampleLocalizations.of(context).counterIncrementButtonTooltip,
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
