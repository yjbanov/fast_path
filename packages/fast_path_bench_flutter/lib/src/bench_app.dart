// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'runner.dart';

/// Manual Flutter web benchmark UI.
///
/// Renders the catalog as a column of cards — one card per workload —
/// rather than the raw JSON dump it used to. Paired benchmarks show
/// fast_path on the left and `dart:ui` on the right, separated by a
/// [VerticalDivider]; the JSON is still `print()`-ed to the browser
/// console for copy-paste, and matches the schema other modes produce.
class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fast_path bench (web)',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3F51B5),
      ),
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
  CatalogResults? _results;

  Future<void> _run() async {
    setState(() {
      _status = _Status.running;
      _results = null;
    });

    // Yield to the event loop so the "Running…" state paints before
    // the measurement loop monopolizes the isolate.
    await Future<void>.delayed(Duration.zero);

    final results = runCatalog();
    final json = encodeReport(
      mode: 'flutter-web',
      os: 'web',
      dartVersion: 'flutter-web (${defaultTargetPlatform.name})',
      results: flattenResults(results),
    );

    // ignore: avoid_print — this is a benchmark UI; print is the contract.
    print(json);

    setState(() {
      _status = _Status.done;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairs = allPairs();
    final solos = allSolos();
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('fast_path benchmarks'),
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ControlBar(status: _status, onRun: _run),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: <Widget>[
                      const _SectionHeader(
                        title: 'Side-by-side: fast_path vs dart:ui',
                        subtitle:
                            'Each card runs the same workload through both '
                            'APIs. Lower ns/op is better.',
                      ),
                      for (var i = 0; i < pairs.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PairCard(
                            spec: pairs[i],
                            result: results == null ? null : results.pairs[i],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const _SectionHeader(
                        title: 'fast_path only',
                        subtitle:
                            'Features without a dart:ui counterpart — '
                            'no comparison to draw.',
                      ),
                      for (var i = 0; i < solos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SoloCard(
                            spec: solos[i],
                            result: results == null ? null : results.solos[i],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Full JSON report is also printed to the browser '
                        'console (open DevTools).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.status, required this.onRun});

  final _Status status;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          FilledButton.icon(
            onPressed: status == _Status.running ? null : onRun,
            icon: status == _Status.running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              switch (status) {
                _Status.ready => 'Run benchmarks',
                _Status.running => 'Running…',
                _Status.done => 'Run again',
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              switch (status) {
                _Status.ready =>
                  'Measurement takes ~18 s total (~2 s per benchmark).',
                _Status.running =>
                  'UI will freeze during the measurement loop.',
                _Status.done => 'Done. Click again to re-run.',
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.spec, required this.result});

  final PairedBenchmark spec;
  final PairResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(spec.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              spec.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _SideValue(
                      label: 'fast_path',
                      result: result?.fp,
                      deltaPercent: result?.fpDeltaPercent,
                    ),
                  ),
                  const VerticalDivider(width: 32, thickness: 1),
                  Expanded(
                    child: _SideValue(
                      label: 'dart:ui',
                      result: result?.ui,
                      // Baseline — no delta shown on this side.
                      deltaPercent: null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideValue extends StatelessWidget {
  const _SideValue({
    required this.label,
    required this.result,
    required this.deltaPercent,
  });

  final String label;
  final BenchResult? result;
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result == null ? '—' : _formatNs(result!.nsPerOp),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        if (deltaPercent != null)
          _DeltaBadge(percent: deltaPercent!)
        else
          // Reserve space so both sides of the card align vertically
          // whether or not a delta is shown.
          const SizedBox(height: 24),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWin = percent < 0;
    final color = isWin ? Colors.green.shade700 : theme.colorScheme.error;
    final sign = percent >= 0 ? '+' : '−';
    final magnitude = percent.abs();
    final formatted = magnitude >= 100
        ? '${magnitude.toStringAsFixed(0)}%'
        : '${magnitude.toStringAsFixed(1)}%';
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '$sign$formatted vs dart:ui',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SoloCard extends StatelessWidget {
  const _SoloCard({required this.spec, required this.result});

  final SoloBenchmark spec;
  final SoloResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(spec.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              spec.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result == null ? '—' : _formatNs(result!.bench.nsPerOp),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNs(double ns) {
  if (ns < 1000) {
    return '${ns.toStringAsFixed(1)} ns';
  }
  if (ns < 1000000) {
    return '${(ns / 1000).toStringAsFixed(2)} µs';
  }
  return '${(ns / 1000000).toStringAsFixed(2)} ms';
}

enum _Status { ready, running, done }
