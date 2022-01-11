import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/utils.dart';
import 'package:tool_base/tool_base.dart';

final DaemonClient _kDaemonClient = DaemonClient();

/// Currently active implementation of the daemon client.
///
/// Override this in tests with a fake/mocked daemon client.
DaemonClient get daemonClient => context.get<DaemonClient>() ?? _kDaemonClient;

enum EventType { deviceRemoved }

/// Starts and communicates with flutter daemon.
class DaemonClient {
  Process? _process;
  int _messageId = 0;
  bool _connected = false;
  Completer? _waitForConnection;
  final Map<int, Completer<Map<String, dynamic>>> _waitForResponse = {};
  Completer<Map<String, dynamic>> _waitForEvent = Completer();
  List<Map<String, String>>? _iosDevices; // contains model of device, used by screenshots
  StreamSubscription? _stdOutListener;
  StreamSubscription? _stdErrListener;

  /// Start flutter tools daemon.
  Future<void> get start async {
    if (!_connected) {
      _process = await runCommand(['flutter', 'daemon']);
      _listen();
      _waitForConnection = Completer<bool>();
      _connected = await _waitForConnection?.future;
      await enableDeviceDiscovery();
      // maybe should check if iOS run type is active
      if (platform.isMacOS) _iosDevices = getIosDevices();
      // wait for device discovery
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  @visibleForTesting
  Future enableDeviceDiscovery() async {
    await _sendCommandWaitResponse(
        <String, dynamic>{'method': 'device.enable'});
  }

  /// List installed emulators (not including iOS simulators).
  Future<List<DaemonEmulator>> get emulators async {
    final emulators = await _sendCommandWaitResponse(
        <String, dynamic>{'method': 'emulator.getEmulators'});
    final daemonEmulators = <DaemonEmulator>[];
    for (var emulator in emulators) {
      final daemonEmulator = loadDaemonEmulator(emulator);
      if (daemonEmulator == null) {
        continue;
      }
      printTrace('daemonEmulator=$daemonEmulator');
      daemonEmulators.add(daemonEmulator);
    }
    return daemonEmulators;
  }

  /// Launch an emulator and return device id.
  Future<String> launchEmulator(String emulatorId) async {
    final command = <String, dynamic>{
      'method': 'emulator.launch',
      'params': {
        'emulatorId': emulatorId,
      },
    };
    var result = await _sendCommand(command);
    _processResponse(result, command);

    var e = await emulators;

    return "unknown";
  }

  /// List running real devices and booted emulators/simulators.
  Future<List<DaemonDevice>> get devices async {
    final devices =
        await _sendCommandWaitResponse({'method': 'device.getDevices'});
    return devices.map((device) {
      // add model name if real ios device present
      if (platform.isMacOS &&
          device['platform'] == 'ios' &&
          device['emulator'] == false) {
        final iosDevice = _iosDevices
            ?.firstWhereOrNull((iosDevice) => iosDevice['id'] == device['id']);
        if (iosDevice == null) {
          throw 'Error: could not find model name for real ios device: ${device['name']}';
        }
        device['model'] = iosDevice['model'];
      }
      final daemonDevice = loadDaemonDevice(device);
      printTrace('daemonDevice=$daemonDevice');
      return daemonDevice;
    }).toList();
  }

  /// Wait for an event of type [EventType] and return event info.
  Future<Map> waitForEvent(EventType eventType) async {
    final eventInfo = await _waitForEvent.future;
    switch (eventType) {
      case EventType.deviceRemoved:
        // event info is a device descriptor
        if (eventInfo.length != 1 ||
            eventInfo[0]['event'] != 'device.removed') {
          throw 'Error: expected: $eventType, received: $eventInfo';
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
    if (!_connected) throw 'Error: not connected to daemon.';
    await _sendCommandWaitResponse(
        <String, dynamic>{'method': 'daemon.shutdown'});
    _connected = false;
    _exitCode = await _process!.exitCode;
    await _stdOutListener?.cancel();
    await _stdErrListener?.cancel();
    return _exitCode;
  }

  void _listen() {
    _stdOutListener = _process!.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .map((String line) {
      printTrace('<== $line');
      return line;
    }).expand<dynamic>((String line) {
      try {
        return jsonDecode(line) as List<dynamic>;
      } catch (e) {
        printError("Could not decode JSON from flutter daemon:\n$e\n$line");
        return [];
      }
    }).listen((dynamic data) async {
      if(data is! Map<String, dynamic>) {
        return;
      }

      var event = data.remove('event');
      var id = data.remove('id');

      if (event != null) {
        if (event == 'daemon.logMessage') {
          var params = data['params'] ?? {};
          var level = params['level'] ?? '';
          var message = params['message'] ?? '';
          printTrace('flutter daemon: $level $message');
        } else if (event == 'daemon.connected') {
          _waitForConnection!.complete(true);
        } else {
          _waitForEvent.complete(data);
          _waitForEvent = Completer(); // enable wait for next event
        }
      } else if (id != null && id is int) {
        var res = _waitForResponse.remove(id);
        if (res != null) {
          res.complete(data);
        }
      }
    });
    _stdErrListener =
        _process!.stderr.listen((dynamic data) => stderr.add(data));
  }

  Future<Map<String, dynamic>> _sendCommand(Map<String, dynamic> command) {
    if (!_connected) {
      throw 'Error: not connected to daemon.';
    }

    var res = Completer<Map<String, dynamic>>();
    var id = _messageId++;
    _waitForResponse[id] = res;
    command['id'] = id;
    final str = '[${json.encode(command)}]';
    _process!.stdin
      ..writeln(str)
      ..flush();
    printTrace('==> $str');
    return res.future;
  }

  Future<List> _sendCommandWaitResponse(Map<String, dynamic> command) async {
    var response = await _sendCommand(command);
    return _processResponse(response, command);
  }

  List _processResponse(Map<String, dynamic> data, Map<String, dynamic> command) {
    var result = data.remove('result');
    if (result != null) {
      return result;
    }

    var error = data['error'];
    if (error != null) {
      // todo: handle errors separately
      throw 'Error: command $command failed:\n$error';
    }

    // Responses with only id are ok
    if (data.isEmpty) {
      return [];
    }

    throw 'Unknown response: ${jsonEncode(data)}';
  }
}

/// Get attached ios devices with id and model.
List<Map<String, String>> getIosDevices() {
  final regExp = RegExp(r'Found (\w+) \(\w+, (.*), \w+, \w+\)');
  final noAttachedDevices = 'no attached devices';
  final iosDeployDevices =
      cmd(['sh', '-c', 'ios-deploy -c || echo "$noAttachedDevices"'])
          .trim()
          .split('\n')
          .sublist(1);
  if (iosDeployDevices.isEmpty || iosDeployDevices[0] == noAttachedDevices) {
    return [];
  }
  return iosDeployDevices.map((line) {
    final matches = regExp.firstMatch(line)!;
    final device = <String, String>{};
    device['id'] = matches.group(1)!;
    device['model'] = matches.group(2)!;
    return device;
  }).toList();
}

/// Wait for emulator or simulator to start
Future waitForEmulatorToStart(
    DaemonClient daemonClient, String deviceId) async {
  var started = false;
  while (!started) {
    printTrace(
        'waiting for emulator/simulator with device id \'$deviceId\' to start...');
    final devices = await daemonClient.devices;
    final device = devices.firstWhereOrNull(
        (device) => device.id == deviceId && device.emulator);
    started = device != null;
    await Future.delayed(Duration(milliseconds: 1000));
  }
}

abstract class BaseDevice {
  final String id;
  final String name;
  final String category;
  final DeviceType deviceType;

  BaseDevice(this.id, this.name, this.category, this.deviceType);

  @override
  bool operator ==(other) {
    return other is BaseDevice &&
        other.name == name &&
        other.id == id &&
        other.category == category &&
        other.deviceType == deviceType;
  }

  @override
  String toString() {
    return 'id: $id, name: $name, category: $category, deviceType: $deviceType';
  }
}

/// Describe an emulator.
class DaemonEmulator extends BaseDevice {
  DaemonEmulator(
    String id,
    String name,
    String category,
    DeviceType deviceType,
  ) : super(id, name, category, deviceType);
}

/// Describe a device.
class DaemonDevice extends BaseDevice {
  final bool emulator;
  final bool ephemeral;
  final String emulatorId;
  final String? iosModel;
  DaemonDevice(
    String id,
    String name,
    String category,
    DeviceType deviceType,
    this.emulator,
    this.ephemeral,
    this.emulatorId, {
    this.iosModel,
  }) : super(id, name, category, deviceType);

  @override
  bool operator ==(other) {
    return super == other &&
        other is DaemonDevice &&
        other.deviceType == deviceType &&
        other.emulator == emulator &&
        other.ephemeral == ephemeral &&
        other.emulatorId == emulatorId &&
        other.iosModel == iosModel;
  }

  @override
  String toString() {
    return super.toString() +
        ' platform: $platform, emulator: $emulator, ephemeral: $ephemeral, emulatorId: $emulatorId, iosModel: $iosModel';
  }
}

DaemonEmulator? loadDaemonEmulator(Map<String, dynamic> emulator) {
  var platformType = emulator['platformType'];

  // TODO(trygvis): check what ios would return there
  var deviceType = platformType == 'android' ? DeviceType.android
      : DeviceType.ios;

  return DaemonEmulator(
    emulator['id'],
    emulator['name'],
    emulator['category'],
    deviceType,
  );
}

DaemonDevice loadDaemonDevice(Map<String, dynamic> device) {
  // hack for CI testing.
  // flutter daemon is reporting x64 emulator as real device while
  // flutter doctor is reporting correctly.
  // Platform is reporting as 'android-arm' instead of 'android-x64', etc...
  if (platform.environment['CI']?.toLowerCase() == 'true' &&
      device['emulator'] == false) {
    return DaemonDevice(
      device['id'],
      device['name'],
      device['category'],
      device['platformType'],
      device['platform'],
      true,
      device['ephemeral'],
      // 'NEXUS_6P_API_28',
      iosModel: device['model'],
    );
  }
  print("device: $device");
  return DaemonDevice(
    device['id'],
    device['name'],
    device['category'],
    device['platformType'] == 'android' ? DeviceType.android : DeviceType.ios,
    device['emulator'],
    device['ephemeral'],
    device['emulatorId'],
    iosModel: device['model'],
  );
}
