// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_mobile/tool_mobile.dart';

Future<T> runInContext<T>(
  FutureOr<T> runner(), {
  Map<Type, Generator>? overrides,
}) async {
  return await context.run<T>(
    name: 'global fallbacks',
    body: runner,
    overrides: overrides,
    fallbacks: <Type, Generator>{
      AndroidSdk: AndroidSdk.locateAndroidSdk,
      BotDetector: () => const BotDetector(),
      Config: () => Config(),
      DaemonClient: () => DaemonClient(),
      ImageMagick: () => ImageMagick(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ProcessManager: () => LocalProcessManager(),
      Stdio: () => const Stdio(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
    },
  );
}
