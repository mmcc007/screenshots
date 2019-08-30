// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:process/process.dart';

import 'base/context.dart';
import 'base/io.dart';
import 'base/logger.dart';
import 'base/platform.dart';
import 'base/utils.dart';

Future<T> runInContext<T>(
  FutureOr<T> runner(), {
  Map<Type, Generator> overrides,
}) async {
  return await context.run<T>(
    name: 'global fallbacks',
    body: runner,
    overrides: overrides,
    fallbacks: <Type, Generator>{
      BotDetector: () => const BotDetector(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      ProcessManager: () => LocalProcessManager(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
      Stdio: () => const Stdio(),
    },
  );
}
