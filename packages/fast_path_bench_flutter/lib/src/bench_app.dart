// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'runner.dart';

/// Manual Flutter web benchmark UI: one button, one results pane.
///
/// Built for the web case where we don't have a headless driver yet. The
/// expectation is `flutter run -d chrome --release`, click the button,
/// read the panel (or browser console). Output uses the same JSON schema
/// the rest of `tool/bench.sh` produces so a screenshot is mechanically
/// comparable to a `--mode=aot --json` run.
class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fast_path bench (web)',
      theme: ThemeData(useMaterial3: true),
      home: const _BenchPage(),
    );
  }
}

class _BenchPage extends StatefulWidget {
  const _BenchPage();

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  _Status _status = _Status.ready;
  String _resultsJson = '';

  Future<void> _runBenchmarks() async {
    setState(() {
      _status = _Status.running;
      _resultsJson = '';
    });

    // Yield to the event loop so the "Running..." paint lands before the
    // measurement loop monopolizes the isolate.
    await Future<void>.delayed(Duration.zero);

    final results = runAll();
    final json = encodeReport(
      mode: 'flutter-web',
      os: 'web',
      dartVersion: 'flutter-web (${defaultTargetPlatform.name})',
      results: results,
    );

    // ignore: avoid_print — this is a benchmark UI; print is the contract.
    print(json);

    setState(() {
      _status = _Status.done;
      _resultsJson = json;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('fast_path benchmarks (web)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed:
                      _status == _Status.running ? null : _runBenchmarks,
                  child: const Text('Run benchmarks'),
                ),
                const SizedBox(width: 16),
                Text(
                  switch (_status) {
                    _Status.ready =>
                      'Ready — measurement takes ~12 seconds (6 benches × ~2 s).',
                    _Status.running =>
                      'Running… UI will freeze; results print to console too.',
                    _Status.done => 'Done. Output also printed to console.',
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _resultsJson.isEmpty
                      ? '(click "Run benchmarks" to start)'
                      : _resultsJson,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Status { ready, running, done }
