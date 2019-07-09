import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'run.dart' as run;

enum Event { deviceRemoved }

/// Creates and communicates with flutter daemon.
class DaemonClient {
  static final DaemonClient _daemonClient = DaemonClient._internal();

  factory DaemonClient() {
    return _daemonClient;
  }

  DaemonClient._internal();

  bool verbose = false;

  Process _process;
  int _messageId = 0;
  bool _connected = false;
  Completer _waitForConnection;
  Completer _waitForResponse;
  Completer _waitForEvent = Completer<String>();
  List _iosDevices; // contains model of device, used by screenshots

  /// Start flutter tools daemon.
  Future<void> get start async {
    if (!_connected) {
      _process = await Process.start('flutter', ['daemon']);
      _listen();
      _waitForConnection = Completer<bool>();
      _connected = await _waitForConnection.future;
      // enable device discovery
      await _sendCommandWaitResponse(
          <String, dynamic>{'method': 'device.enable'});
      _iosDevices = iosDevices();
      // wait for device discovery
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  /// List installed emulators (not including iOS simulators).
  Future<List> get emulators async {
    return _sendCommandWaitResponse(
        <String, dynamic>{'method': 'emulator.getEmulators'});
  }

  /// Launch an emulator and return device id.
  Future<String> launchEmulator(String emulatorId) async {
    final command = <String, dynamic>{
      'method': 'emulator.launch',
      'params': <String, dynamic>{
        'emulatorId': emulatorId,
      },
    };
    await _sendCommand(command);

    // wait for expected device-added-emulator event
    final results = await Future.wait(
        <Future>[_waitForResponse.future, _waitForEvent.future]);
    _processResponse(results[0], command);
    final event = results[1];
    final eventInfo = jsonDecode(event);
    if (eventInfo.length != 1 ||
        eventInfo[0]['event'] != 'device.added' ||
        eventInfo[0]['params']['emulator'] != true) {
      throw 'Error: emulator $emulatorId not started: $event';
    }

    return Future.value(eventInfo[0]['params']['id']);
  }

  /// List running real devices and booted emulators/simulators.
  Future<List> get devices async {
    final devices = await _sendCommandWaitResponse(
        <String, dynamic>{'method': 'device.getDevices'});
    return Future.value(devices.map((device) {
      // add model name if real ios device present
      if (device['platform'] == 'ios' && device['emulator'] == false) {
        final iosDevice = _iosDevices.firstWhere(
            (iosDevice) => iosDevice['id'] == device['id'],
            orElse: () =>
                throw 'Error: could not find model name for real ios device: ${device['name']}');
        device['model'] = iosDevice['model'];
      }
      return device;
    }).toList());
  }

  Future<Map> waitForEvent(Event event) async {
    final eventInfo = jsonDecode(await _waitForEvent.future);
    switch (event) {
      case Event.deviceRemoved:
        if (eventInfo.length != 1 ||
            eventInfo[0]['event'] != 'device.removed') {
          throw 'Error: expected: $event, received: $eventInfo';
        }
        break;
      default:
        throw 'Error: unexpected event: $eventInfo';
    }
    return Future.value(eventInfo[0]['params']);
  }

  int _exitCode = 0;

  /// Stop daemon.
  Future<int> get stop async {
    if (!_connected) return _exitCode;
    await _sendCommandWaitResponse(
        <String, dynamic>{'method': 'daemon.shutdown'});
    _connected = false;
    _exitCode = await _process.exitCode;
    return _exitCode;
  }

  void _listen() {
    _process.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .listen((String line) async {
      if (verbose) print('<== $line');
      if (line.contains('daemon.connected')) {
        _waitForConnection.complete(true);
      } else {
        // get response
        if (line.contains('"result":') ||
            line.contains('"error":') ||
            line == '[{"id":${_messageId - 1}}]') {
          _waitForResponse.complete(line);
        } else {
          // get event
          if (line.contains('[{"event":')) {
            if (line.contains('"event":"daemon.logMessage"')) {
              print('Warning: ignoring log message: $line');
            } else {
              _waitForEvent.complete(line);
              _waitForEvent = Completer<String>(); // enable wait for next event
            }
          } else if (line != 'Starting device daemon...') {
            throw 'Error: unexpected response from daemon: $line';
          }
        }
      }
    });
    _process.stderr.listen((dynamic data) => stderr.add(data));
  }

  void _sendCommand(Map<String, dynamic> command) {
    if (_connected) {
      _waitForResponse = Completer<String>();
      command['id'] = _messageId++;
      final String str = '[${json.encode(command)}]';
      _process.stdin.writeln(str);
      if (verbose) print('==> $str');
    } else {
      throw 'Error: not connected to daemon.';
    }
  }

  Future<List> _sendCommandWaitResponse(Map<String, dynamic> command) async {
    _sendCommand(command);
    final String response = await _waitForResponse.future;
    return _processResponse(response, command);
  }

  List _processResponse(String response, Map<String, dynamic> command) {
    if (response.contains('result')) {
      final respExp = RegExp(r'result":(.*)}\]');
      return jsonDecode(respExp.firstMatch(response).group(1));
    } else if (response.contains('error')) {
      // todo: handle errors separately
      throw 'Error: command $command failed:\n ${jsonDecode(response)[0]['error']}';
    } else {
      return jsonDecode(response);
    }
  }
}

/// Get attached ios devices with id and model.
List iosDevices() {
  final regExp = RegExp(r'Found (\w+) \(\w+, (.*), \w+, \w+\)');
  final noAttachedDevices = 'no attached devices';
  final iosDeployDevices = run
      .cmd(
          'sh', ['-c', 'ios-deploy -c || echo "$noAttachedDevices"'], '.', true)
      .trim()
      .split('\n')
      .sublist(1);
  if (iosDeployDevices[0] == noAttachedDevices) return [];
  return iosDeployDevices.map((line) {
    final matches = regExp.firstMatch(line);
    final device = {};
    device['id'] = matches.group(1);
    device['model'] = matches.group(2);
    return device;
  }).toList();
}
