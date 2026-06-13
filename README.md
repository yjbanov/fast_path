# fast_2d

A family of fast, **pure-Dart** 2D libraries — geometry, transforms, and paths
that run entirely on the Dart heap, with no native bindings and no manual memory
management.

The shared premise: the primitives behind 2D UI work (matrices, rectangles,
paths) don't need to cross an FFI boundary into C++ to be fast. Implemented
carefully in Dart, they stay GC-managed, portable to every Dart target, and —
where they mirror an existing API like Flutter's `dart:ui.Path` — faithful to
its behavior.

## Status

Early development. Public APIs are unstable and some libraries are incomplete.

## Packages

| Package | What it is | Published |
| --- | --- | --- |
| [`fast_path`](packages/fast_path) | Immutable 2D path with behavioral parity to `dart:ui.Path` (builder/path split). | yes |
| [`fast_geometry`](packages/fast_geometry) | 2D geometry value types (`Offset`, `Rect`, …) and an immutable, 2D-optimized 4×4 `Matrix`. | yes |
| [`bench_core`](packages/bench_core) | Domain-agnostic benchmark harness (subject/reference pairs, JSON, anti-DCE). | no |
| [`fast_path_conformance`](packages/fast_path_conformance) | Parity tests for `fast_path` against `dart:ui.Path` (Flutter-only). | no |
| [`fast_path_bench`](packages/fast_path_bench) | Pure-Dart `fast_path` benchmarks (JIT + AOT). | no |
| [`fast_path_bench_flutter`](packages/fast_path_bench_flutter) | Flutter-hosted benchmarks with a real `dart:ui` baseline (desktop AOT + web). | no |
| [`fast_path_flutter`](packages/fast_path_flutter) | Future Flutter interop bridge (not yet implemented). | no |

`fast_path` depends on `fast_geometry` for its value types and transforms;
`fast_geometry` stands on its own.

## Layout

This is a Dart workspace (`pubspec.yaml` lists the members). Design notes live in
[`design_docs/`](design_docs); each package carries its own `README`, `CHANGELOG`,
and — for `fast_path` — a full `DESIGN.md`.

## Development

```sh
tool/check.sh                      # analyze + test every package (mirrors CI)
tool/bench.sh --suite=path         # fast_path vs dart:ui benchmarks
tool/bench.sh --suite=geometry     # fast_geometry Matrix vs package:vector_math
```

## License

BSD-3-Clause. See [LICENSE](LICENSE).
