// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'fake_process_manager.dart';

void main() {
  group('fake process manager', () {
    FakeProcessManager processManager;
    final List<String> stdinCaptured = <String>[];

    void _captureStdin(String item) {
      stdinCaptured.add(item);
    }

    setUp(() async {
      processManager = FakeProcessManager(stdinResults: _captureStdin);
    });

    tearDown(() async {});

    test('start works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final Process process = await processManager.start(key.split(' '));
        String output = '';
        process.stdout.listen((List<int> item) {
          output += utf8.decode(item);
        });
        await process.exitCode;
        expect(output, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('run works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final ProcessResult result = await processManager.run(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('runSync works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final ProcessResult result = processManager.runSync(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('captures stdin', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final Process process = await processManager.start(key.split(' '));
        String output = '';
        process.stdout.listen((List<int> item) {
          output += utf8.decode(item);
        });
        final String testInput = '${call.result.stdout} input';
        process.stdin.add(testInput.codeUnits);
        await process.exitCode;
        expect(output, equals(call.result.stdout));
        expect(stdinCaptured.last, equals(testInput));
      }
      processManager.verifyCalls();
    });
  });

  group('additional fake process manager tests', () {
    FakeProcessManager processManager;

    setUp(() async {
      processManager = FakeProcessManager();
    });

    test('repeated calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final ProcessResult result = processManager.runSync(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('unused calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      final key = calls[0].command;
      processManager.runSync(key.split(' '));
//      expect(() => processManager.verifyCalls(), throwsA(TestFailure));
    });

    test('out of sequence calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;

//      final key = calls[1].command;
//      processManager.runSync(key.split(' '));
    });
  });
}
