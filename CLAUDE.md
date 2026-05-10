# fast_path

Pure-Dart 2D path library with behavioral parity to Flutter's `dart:ui.Path`.
See [DESIGN.md](DESIGN.md) for full design rationale.

## Repo layout

```
packages/
  fast_path/              Core library — pure Dart, published to pub.dev
  fast_path_conformance/  Parity tests against dart:ui — Flutter only, not published
  fast_path_flutter/      Future Flutter bridge — not yet implemented
skills/
  add-path-api/           Checklist for adding/changing PathBuilder or Path API
  port-from-skia/         Checklist for porting algorithms from Skia/Flutter
```

## Hard rules

These are non-negotiable. If following them seems impossible for a given task,
stop and ask rather than bending a rule.

**No native bindings in `packages/fast_path/lib/`.**
No `dart:ffi`, `dart:io`, or `dart:ui` imports. The package must run on plain
Dart VMs with no Flutter dependency. `dart:ui` is allowed only inside
`packages/fast_path_conformance/`.

**Mutation lives on `PathBuilder`. Queries live on `Path`.**
`Path` is immutable — never add a mutating method to it. Never add a query
method or derived cache to `PathBuilder`. The split is load-bearing; see
DESIGN.md §4.1 for why.

**Parity with `dart:ui.Path` is the contract.**
Every public method on `PathBuilder` or `Path` is a behavioral parity claim.
When the correct behavior is unclear, observe actual `dart:ui.Path` behavior
and pin it in a parity test before implementing. "Almost like Flutter's Path"
is not acceptable.

**No allocations in hot paths.**
Builder methods append to `Uint8List`/`Float32List` buffers in place. Query
methods read those buffers in place. No `Offset`, `List`, or other heap
objects allocated per call in inner loops.

**Parity tests are required before a method is done.**
Every new method needs a passing test in
`packages/fast_path_conformance/test/parity/` that replays the same call
sequence on both `fast_path` and `dart:ui.Path` and asserts agreement within
the tolerances documented in DESIGN.md §8.2.

## Skills

Read and follow the appropriate skill file before starting these tasks:

- Adding or changing anything on `PathBuilder` or `Path` →
  `skills/add-path-api/SKILL.md`
- Porting an algorithm from Skia or the Flutter engine →
  `skills/port-from-skia/SKILL.md`

## Escalate, don't decide alone

Raise these with the user rather than resolving them unilaterally:

- A proposed addition that has no `dart:ui.Path` equivalent.
- A behavior where `dart:ui.Path` is itself buggy or undocumented and we must
  pick a behavior.
- Anything that would require importing `dart:ui` from `packages/fast_path/lib/`.
- A method that seems like it should mutate a `Path` rather than return a new one.
- A port from Skia where upstream behavior contradicts what `dart:ui.Path`
  actually does.
