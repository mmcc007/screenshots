import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(Center(child: Flavor()));
}

class Flavor extends StatefulWidget {
  @override
  _FlavorState createState() => _FlavorState();
}

class _FlavorState extends State<Flavor> {
  String? _flavor;

  @override
  void initState() {
    super.initState();
    const MethodChannel('flavor')
        .invokeMethod<String>('getFlavor')
        .then((String? flavor) {
      setState(() {
        _flavor = flavor;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _flavor == null
          ? const Text('Awaiting flavor...')
          : Text(_flavor ?? "??", key: const ValueKey<String>('flavor')),
    );
  }
}
