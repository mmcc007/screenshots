import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'utils.dart';

/// Creates and communicates with flutter daemon.
class DaemonClient {
  DaemonClient._();

  static final DaemonClient instance = DaemonClient._();

  bool verbose = false;

  Process _process;
  int _messageId = 0;
  bool _connected = false;
  Completer _waitForConnection;
  Completer _waitForResponse;
  Completer _waitForEvent = Completer<String>();
  List _iosDevices; // contains model of device, used by screenshots

  Future<void> get start async {
    if (!_connected) {
      _process = await Process.start('flutter', ['daemon']);
      _listen();
      _waitForConnection = Completer<bool>();
      _connected = await _waitForConnection.future;

      // enable device discovery
      await _sendCommand(<String, dynamic>{'method': 'device.enable'});
      _iosDevices = iosDevices();
      // wait for device discovery
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  Future<List> get emulators async {
    return _sendCommand(<String, dynamic>{'method': 'emulator.getEmulators'});
  }

  Future<void> launchEmulator(String id) async {
    unawaited(_sendCommand(<String, dynamic>{
      'method': 'emulator.launch',
      'params': <String, dynamic>{
        'emulatorId': id,
      },
    }));

    // wait for expected device-added-emulator event
    final deviceAdded = await _waitForEvent.future;
    if (!(deviceAdded.contains('device.added') &&
        deviceAdded.contains('"emulator":true'))) {
      throw 'Error: emulator $id not started: $deviceAdded';
    }

    return Future.value();
  }

  Future<List> get devices async {
    final devices =
        await _sendCommand(<String, dynamic>{'method': 'device.getDevices'});
    return Future.value(devices.map((device) {
      // add model name if real ios device present
      if (device['platform'] == 'ios' && device['emulator'] == false) {
        final iosDevice = _iosDevices.firstWhere(
            (iosDevice) => iosDevice['id'] == device['id'],
            orElse: () => null);
        device['model'] = iosDevice['model'];
      }
      return device;
    }).toList());
  }

  int _exitCode = 0;
  Future<int> get stop async {
    if (!_connected) return _exitCode;
    await _sendCommand(<String, dynamic>{'method': 'daemon.shutdown'});
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
      }
      // get response
      if (line.contains('"result":') ||
          line.contains('"error":') ||
          line == '[{"id":${_messageId - 1}}]') {
        _waitForResponse.complete(line);
      }
      // get event
      if (line.contains('[{"event":')) {
        _waitForEvent.complete(line);
        _waitForEvent = Completer<String>(); // enable wait for next event
      }
    });
    _process.stderr.listen((dynamic data) => stderr.add(data));
  }

  Future<List> _sendCommand(Map<String, dynamic> command) async {
    if (_connected) {
      _waitForResponse = Completer<String>();
      command['id'] = _messageId++;
      final String str = '[${json.encode(command)}]';
      _process.stdin.writeln(str);
      if (verbose) print('==> $str');
      final String response = await _waitForResponse.future;
      if (response.contains('result')) {
        final respExp = RegExp(r'result":(.*)}\]');
        return jsonDecode(respExp.firstMatch(response).group(1));
      } else if (response.contains('error')) {
        throw 'Error: command $command failed:\n ${jsonDecode(response)[0]['error']}';
      } else {
        return jsonDecode(response);
      }
    }
    throw 'Error: not connected to daemon.';
  }
}

Future shutdownAndroidEmulator(
    DaemonClient daemonClient, String emulatorId) async {
  final emulators = await daemonClient.emulators;
  final emulator = emulators.firstWhere(
      (emulator) => emulator['id'] == emulatorId,
      orElse: () =>
          throw 'Error: emulator for emulatorId $emulatorId not found');
  final devices = await daemonClient.devices;
  final device = devices.firstWhere(
      (device) =>
          //            device['emulator'] == true && // bug??
          device['id'].contains('emulator') &&
          device['platform'] != 'ios' &&
          getAndroidEmulatorId(device['id']) == emulatorId,
      orElse: () =>
          throw 'Error: device not found for emulatorId: $emulatorId');
  cmd('adb', ['-s', device['id'], 'emu', 'kill'], '.', true);
  await waitAndroidEmulatorShutdown(device['id'], emulator['name']);
}

/// Get attached ios devices with id and model.
List iosDevices() {
  final regExp = RegExp(r'Found (\w+) \(\w+, (.*), \w+, \w+\)');
  final iosDeployDevices =
      cmd('ios-deploy', ['-c'], '.', true).trim().split('\n').sublist(1);
  return iosDeployDevices.map((line) {
    final matches = regExp.firstMatch(line);
    final device = {};
    device['id'] = matches.group(1);
    device['model'] = matches.group(2);
    return device;
  }).toList();
}

/// Indicates to the linter that the given future is intentionally not `await`-ed.
///
/// Has the same functionality as `unawaited` from `package:pedantic`.
///
/// In an async context, it is normally expected than all Futures are awaited,
/// and that is the basis of the lint unawaited_futures which is turned on for
/// the flutter_tools package. However, there are times where one or more
/// futures are intentionally not awaited. This function may be used to ignore a
/// particular future. It silences the unawaited_futures lint.
void unawaited(Future<void> future) {}
