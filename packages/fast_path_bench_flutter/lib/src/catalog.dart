// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path_bench/benchmarks.dart' as fp;

import 'ui_benchmarks.dart';

/// A benchmark with no `dart:ui` counterpart — runs and reports alone.
///
/// Use when the operation is fast_path-specific (e.g. structural Path
/// equality, which `dart:ui.Path` lacks). The UI presents these in a
/// dedicated "fast_path only" section.
class SoloBenchmark {
  const SoloBenchmark({
    required this.displayName,
    required this.description,
    required this.create,
  });

  /// Short title shown at the top of the card.
  final String displayName;

  /// One-line explanation of the workload, shown under the title.
  final String description;

  /// Factory for the benchmark. Called once per run so `setup` state
  /// doesn't leak across runs.
  final fp.FastPathBenchmark Function() create;
}

/// A pair of benchmarks measuring the same workload — one via
/// `fast_path`, one via `dart:ui.Path`. The UI presents these
/// side-by-side with a [VerticalDivider] between them.
class PairedBenchmark {
  const PairedBenchmark({
    required this.displayName,
    required this.description,
    required this.createFp,
    required this.createUi,
  });

  /// Short title shown at the top of the card.
  final String displayName;

  /// One-line explanation of the workload.
  final String description;

  /// Factory for the fast_path side. Called once per run.
  final fp.FastPathBenchmark Function() createFp;

  /// Factory for the `dart:ui` side. Called once per run.
  final fp.FastPathBenchmark Function() createUi;
}

/// All paired benchmarks. Order is the order the UI renders cards and
/// the JSON output lists results.
///
/// Adding a new pair here is what wires it into the Flutter-hosted
/// benchmark suite — the runner and UI both pick it up automatically.
List<PairedBenchmark> allPairs() => const <PairedBenchmark>[
      PairedBenchmark(
        displayName: 'Build polyline — per-frame reuse',
        description:
            '1000 lineTo segments on a reused builder (reset + close + '
            'build). Models the custom-painter pattern.',
        createFp: fp.BuildPolyline1kBenchmark.new,
        createUi: BuildPolylineUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Build polyline — fresh builder',
        description:
            'Same workload, but allocates a fresh PathBuilder each '
            'iteration. Captures the cold construction cost.',
        createFp: fp.BuildPolylineCold1kBenchmark.new,
        createUi: BuildPolylineColdUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add polygon',
        description:
            '1000-vertex polygon built via the addPolygon convenience '
            'API.',
        createFp: fp.AddPolygon1kBenchmark.new,
        createUi: AddPolygonUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Relative polyline',
        description:
            '1000 relativeMoveTo / relativeLineTo segments. Exposes '
            'current-point bookkeeping overhead.',
        createFp: fp.RelativePolyline1kBenchmark.new,
        createUi: RelativePolylineUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Clone path',
        description:
            'PathBuilder.from(path).build() — the edit-an-existing-path '
            'pattern, no mutation, isolates the buffer-copy cost.',
        createFp: fp.PathFromPath1kBenchmark.new,
        createUi: PathFromPathUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add rects',
        description:
            '500 addRect calls per run on a reused builder. Models '
            'grid/table cell painting.',
        createFp: fp.AddRects500Benchmark.new,
        createUi: AddRectsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add ovals',
        description:
            '500 addOval calls per run on a reused builder. Each oval '
            'is four conic verbs.',
        createFp: fp.AddOvals500Benchmark.new,
        createUi: AddOvalsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add rounded rects',
        description:
            '500 addRRect calls per run on a reused builder. The '
            'rounded-container workload; radii clamping + line/conic '
            'mix.',
        createFp: fp.AddRRects500Benchmark.new,
        createUi: AddRRectsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add arcs',
        description:
            '500 addArc calls per run with quarter-to-full sweeps. '
            'Models gauge / progress-ring painting.',
        createFp: fp.AddArcs500Benchmark.new,
        createUi: AddArcsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Arc to point (SVG arcs)',
        description:
            '500 chained arcToPoint calls with mixed radii, rotations, '
            'and flags. The SVG path-data workload.',
        createFp: fp.ArcToPoint500Benchmark.new,
        createUi: ArcToPointUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Add path (stamping)',
        description:
            '100 addPath calls scattering a 40-segment stamp across a '
            'canvas.',
        createFp: fp.AddPath100Benchmark.new,
        createUi: AddPathUi100Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Extend with path',
        description:
            '100 extendWithPath joins chaining the same stamp into one '
            'connected contour.',
        createFp: fp.ExtendWithPath100Benchmark.new,
        createUi: ExtendWithPathUi100Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Build with quads',
        description:
            'Per-frame reuse, 500 quadraticBezierTo segments. Stresses '
            'the curve verb append + buffer growth path.',
        createFp: fp.BuildQuads500Benchmark.new,
        createUi: BuildQuadsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Build with conics',
        description:
            'Per-frame reuse, 500 conicTo segments with varying weights. '
            'Conics are what ovals, arcs, and rounded rects decompose '
            'into.',
        createFp: fp.BuildConics500Benchmark.new,
        createUi: BuildConicsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Build with cubics',
        description:
            'Per-frame reuse, 500 cubicTo segments. Three points per '
            'verb (two controls + endpoint).',
        createFp: fp.BuildCubics500Benchmark.new,
        createUi: BuildCubicsUi500Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Hit-test grid',
        description:
            '1024 contains() queries against a 100-vertex star polygon.',
        createFp: fp.ContainsGrid1024Benchmark.new,
        createUi: ContainsGridUi1024Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Hit-test grid (quads)',
        description:
            '1024 contains() queries against a 64-quad wavy ring. Tests '
            'the analytic quadratic-crossings hot path.',
        createFp: fp.ContainsQuadsGrid1024Benchmark.new,
        createUi: ContainsQuadsGridUi1024Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Hit-test grid (conics)',
        description:
            '1024 contains() queries against two concentric conic '
            'circles. Stresses the rational quadratic-crossings solver.',
        createFp: fp.ContainsConicsGrid1024Benchmark.new,
        createUi: ContainsConicsGridUi1024Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Hit-test grid (cubics)',
        description:
            '1024 contains() queries against a 32-cubic wavy ring. '
            'Stresses the Cardano / trig cubic-crossings solver.',
        createFp: fp.ContainsCubicsGrid1024Benchmark.new,
        createUi: ContainsCubicsGridUi1024Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Shift (translate)',
        description:
            '1000 shift calls returning fresh translated paths. The '
            'pure-function reposition.',
        createFp: fp.ShiftPath1kBenchmark.new,
        createUi: ShiftPathUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Transform (affine)',
        description:
            '1000 affine transform calls (rotate+scale) returning fresh '
            'paths.',
        createFp: fp.TransformPath1kBenchmark.new,
        createUi: TransformPathUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Metrics + tangents',
        description:
            'computeMetrics + 64 getTangentForOffset samples along a '
            'curve-heavy contour. The path-following / dashing workload.',
        createFp: fp.Metrics64Benchmark.new,
        createUi: MetricsUi64Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Extract sub-paths (dashing)',
        description:
            '32 extractPath calls walking a curve-heavy contour, the '
            'dashed-stroke workload.',
        createFp: fp.ExtractPath32Benchmark.new,
        createUi: ExtractPathUi32Benchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Combine — union',
        description:
            '20 union calls on an overlapping rounded-rect + oval. fast_path '
            'flattens to polygons; dart:ui preserves curves.',
        createFp: fp.CombineUnionBenchmark.new,
        createUi: CombineUnionUiBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Combine — intersect',
        description: '20 intersection calls on the same overlapping pair.',
        createFp: fp.CombineIntersectBenchmark.new,
        createUi: CombineIntersectUiBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Combine — difference',
        description: '20 difference calls on the same overlapping pair.',
        createFp: fp.CombineDifferenceBenchmark.new,
        createUi: CombineDifferenceUiBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'Combine — xor',
        description: '20 exclusive-or calls on the same overlapping pair.',
        createFp: fp.CombineXorBenchmark.new,
        createUi: CombineXorUiBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'getBounds — cached',
        description:
            '1000 calls on a path whose bounds cache is primed. Should '
            'bottom out at a cached field load.',
        createFp: fp.BoundsWarm1kBenchmark.new,
        createUi: BoundsWarmUi1kBenchmark.new,
      ),
      PairedBenchmark(
        displayName: 'getBounds — first call',
        description:
            'Fresh path each iteration so getBounds always walks every '
            'point. Build cost is bundled in.',
        createFp: fp.BoundsCold1kBenchmark.new,
        createUi: BoundsColdUi1kBenchmark.new,
      ),
    ];

/// All solo benchmarks. These are fast_path-specific features with no
/// `dart:ui` equivalent.
List<SoloBenchmark> allSolos() => const <SoloBenchmark>[
      SoloBenchmark(
        displayName: 'PathBuilder.from(path)',
        description:
            'Reseed a builder from a 1k-segment immutable Path. Isolates '
            'the Path → PathBuilder copy. fast_path-only — dart:ui has '
            'no separate builder.',
        create: fp.BuilderFromPath1kBenchmark.new,
      ),
      SoloBenchmark(
        displayName: 'PathBuilder.build()',
        description:
            'Snapshot a 1k-segment builder into a fresh immutable Path '
            '(build does not mutate the builder, so it is called per '
            'run). fast_path-only — dart:ui has no separate snapshot '
            'step.',
        create: fp.BuilderSnapshot1kBenchmark.new,
      ),
      SoloBenchmark(
        displayName: 'PathBuilder.fromBuilder(other)',
        description:
            'Clone a 1k-segment builder into a fresh working copy. '
            'fast_path-only — dart:ui has no builder to clone.',
        create: fp.BuilderClone1kBenchmark.new,
      ),
      SoloBenchmark(
        displayName: 'Path equality',
        description:
            '100 deep structural compares on two equal-but-distinct '
            'paths. No dart:ui counterpart — ui.Path uses identity '
            'equality.',
        create: fp.PathEquality1kBenchmark.new,
      ),
    ];
