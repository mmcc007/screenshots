import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'utils.dart';

/// Creates and communicates with flutter tools daemon.
class DaemonClient {
  DaemonClient._();

  static final DaemonClient instance = DaemonClient._();

  bool verbose = false;

  Process _process;
  int _messageId = 0;
  bool _connected = false;
  Completer _waitForConnection;
  Completer _waitForResponse;
  List _iosDevices;

  Future<void> get start async {
    final flutterHome =
        dirname(dirname((cmd('which', ['flutter'], '.', true))));
    final flutterToolsHome = '$flutterHome/packages/flutter_tools';
    _process = await Process.start(
        'dart', <String>['bin/flutter_tools.dart', 'daemon'],
        workingDirectory: flutterToolsHome);
//    print('daemon client process started, pid: ${process.pid}');
    _listen();
    _waitForConnection = Completer<bool>();
    _connected = await _waitForConnection.future;

    // enable device discovery
    await _sendCommand(<String, dynamic>{'method': 'device.enable'});
    _iosDevices = iosDevices();
    // wait for devices to be discovered
    await Future.delayed(Duration(milliseconds: 1500));
  }

  Future<List> get emulators async {
    return _sendCommand(<String, dynamic>{'method': 'emulator.getEmulators'});
  }

  Future<List> launchEmulator(String id) async {
    return _sendCommand(<String, dynamic>{
      'method': 'emulator.launch',
      'params': <String, dynamic>{
        'emulatorId': id,
      },
    });
  }

  Future<List> get devices async {
    final devices =
        await _sendCommand(<String, dynamic>{'method': 'device.getDevices'});
    return Future.value(devices.map((device) {
      // add model name if ios device
      // todo: do same for android?
      if (device['platform'] == 'ios' && device['emulator'] == false) {
        final iosDevice = _iosDevices.firstWhere(
            (iosDevice) => iosDevice['id'] == device['id'],
            orElse: null);
        device['model'] = iosDevice['model'];
      }
      return device;
    }).toList());
  }

  int _exitCode = 0;
  bool _stopped = false;
  Future<int> get stop async {
    if (_stopped) return _exitCode;
    await _sendCommand(<String, dynamic>{'method': 'daemon.shutdown'});
    _connected = false;
//    _dispose();
    // wait for exit code
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
      if (line.contains('result') || line == '[{"id":${_messageId - 1}}]') {
        _waitForResponse.complete(line);
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
      } else {
        return jsonDecode(response);
      }
    }
    throw 'not connected to daemon';
  }

//  StreamSubscription<String> _stdioSub;
//  StreamSubscription<List<int>> _stderrSub;
//  void _dispose() {
//    _stdioSub?.cancel();
//    _stderrSub?.cancel();
//  }
}

Future shutdownEmulator(DaemonClient daemonClient, String id) async {
  final emulators = await daemonClient.emulators;
  final emulator = emulators.firstWhere((emulator) => emulator['id'] == id);
  final devices = await daemonClient.devices;
  final device = devices.firstWhere(
      (device) =>
          //            device['emulator'] == true && // bug??
          device['id'].contains('emulator') &&
          device['platform'] != 'ios' &&
          getAvdName(device['id']) == id,
      orElse: null);
  cmd('adb', ['-s', device['id'], 'emu', 'kill'], '.', true);
  await waitEmulatorShutdown(device['id'], emulator['name']);
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
