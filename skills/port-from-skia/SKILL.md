---
name: port-from-skia
description: Use whenever code, algorithms, comments, or test cases are being copied or translated from Skia, the Flutter engine, or Impeller — OR from any other permissively-licensed third-party reference (an MIT/BSD/Apache library, or a reference implementation of a published algorithm) — into fast_path. Trigger on phrases like "port this from Skia", "translate SkPath", "borrow from Flutter engine", "the upstream version does X", "adapt this from <library>", "port the <algorithm> reference", or whenever a contributor opens a file under skia/, flutter/engine, or Impeller, or a third-party repo, and references it in a fast_path source file. Also trigger when reviewing a fast_path PR whose diff cites an upstream C++ file or a third-party implementation. Apply this even if the user does not explicitly say "port" — the moment external source is being adapted, this skill governs the workflow.
---

# Porting code from Skia / Flutter into fast_path

`fast_path` aims for behavioral parity with Flutter's `Path`, and the cheapest
path to parity is to port Skia's algorithms (since Flutter's Path is
implemented on top of Skia/Impeller). Porting is encouraged. Doing it sloppily
creates two long-term costs: license risk, and code that diverges from
upstream so far that future bug fixes can't be cherry-picked. This skill keeps
ports clean.

## Why this matters

The project is BSD-3-Clause specifically so we can borrow from Skia and
Flutter without relicensing. That choice only pays off if every port:

1. Carries the upstream license header so attribution is preserved.
2. Cites the exact upstream file and revision so we can re-sync when
   upstream fixes a bug.
3. Stays structurally close to upstream on the first commit, even if the
   Dart isn't yet idiomatic. Refactor in a follow-up.

Ports that silently rewrite the algorithm break this chain. A future
contributor reading a Skia bug fix will not know whether our code is
affected.

## When this skill applies

Apply this skill when:

- Translating a function, class, or algorithm from Skia (`SkPath`, `SkConic`,
  `SkPathOpsCommon`, etc.) into Dart.
- Mirroring a piece of Flutter engine code (`flutter/engine/.../path.cc`,
  Impeller path geometry).
- Copying a test case or fixture from Skia's `tests/` or Flutter's
  `engine/.../path_unittests.cc`.
- Adapting a **permissively-licensed third-party implementation that is not
  Skia/Flutter** — an MIT/BSD/Apache library, or someone's reference
  implementation of a published algorithm.

**Paper vs. implementation — the attribution line.** A *published algorithm* (a
paper, a textbook) is not copyrightable: clean-room Dart written from the
paper's description needs no upstream attribution. But a *specific
implementation* you read and closely follow — its data structures, control
flow, edge-case handling — *is* copyrightable. If your Dart tracks that
implementation, preserve its copyright and license notice and cite it (commit
or version + date), exactly as for a Skia port — even when you also cite the
underlying paper. When unsure which side of the line you're on, attribute; it's
cheap and safe.

Example in this repo: `lib/src/martinez.dart` ports the Martínez–Rueda
sweep-line boolean-op algorithm. Its header cites both the 2009 *paper* (the
algorithm) and the MIT `w8r/martinez` *implementation* it was adapted from, with
that project's copyright preserved — because the Dart follows the reference's
structure, not just the paper's prose.

## Workflow

### 1. Identify the source precisely

Before writing any Dart, capture:

- Upstream repository (Skia, Flutter engine, Impeller).
- File path within that repo.
- Git commit SHA or release tag at the time of the port.
- License of that file (read the header — it must be BSD-3-compatible).

If you can't pin the commit SHA, stop and ask. A port without provenance is
not mergeable.

### 2. Confirm license compatibility

The header must be one of: BSD (any clause count), MIT, or Apache 2.0. Reject
GPL, LGPL, AGPL, or anything custom-restrictive. If the file is dual-licensed,
pick the BSD/MIT/Apache option and note that choice in the port comment.

If unsure, surface the question to the human before writing code. This is the
one part of porting that's not reversible cheaply.

### 3. Preserve the upstream header

Copy the upstream copyright header verbatim to the top of the new Dart file,
above the Dart license header. Order matters: upstream first (so its
attribution is preserved), then a `fast_path` block underneath that explains
the port.

Example structure (skeleton — adapt to the actual upstream header):

```dart
// Copyright <YEARS> Google LLC.
//
// Use of this source code is governed by a BSD-style license that can be
// found in the Skia LICENSE file (https://skia.org/...).
//
// Ported into fast_path from:
//   <upstream repo>/<file path>
//   at commit <SHA>
//
// The Dart translation below preserves the algorithm and structure of the
// upstream source; deviations are documented inline.

// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.
```

If the upstream file already has a different style of header (e.g. Flutter's
`AUTHORS` reference), preserve that exact wording rather than rewriting it.

### 4. Translate, don't refactor — yet

On the first commit of a port, match the upstream structure:

- Same function decomposition (a `chopIntoQuadsPOW2` upstream stays
  `_chopIntoQuadsPow2` in Dart, not split or merged).
- Same control flow. Even if a `switch` could become a polymorphic dispatch,
  keep the `switch` so the diff against upstream is reviewable.
- Same variable names where they aren't reserved words. `t`, `dt`, `pts`,
  `verbs` survive verbatim.
- Inline comments from upstream are kept and translated only if they
  reference C++ syntax that no longer makes sense.

The goal is that someone holding the upstream file open in one window and
the Dart file in another can scan-compare them in minutes. Cleanup PRs come
later, once parity tests are green.

### 5. Translate C++ to Dart idiomatically (within the structural constraint)

Common substitutions:

| C++ idiom | Dart translation |
| --- | --- |
| `float`, `SkScalar` | `double` (we use f64 in arithmetic, store as f32 in buffers — see `packages/fast_path/DESIGN.md` §5) |
| `SkPoint pts[3]` | A view into the path's `Float32List`, indexed by base offset. Don't allocate a fresh list per call. |
| `SkScalar* dst` | Index + base offset on a `Float32List`. |
| Out-parameters (`SkScalar* outT`) | Return a record or a small mutable holder. Don't allocate per call in hot paths. |
| `memcpy` over `SkPoint` arrays | `Uint8List.setRange` on the underlying `ByteBuffer`, or `Float32List.setRange`. |
| `SkASSERT` | `assert(...)` (Dart asserts are stripped in release). |
| Virtual dispatch on a small enum (`SkPath::Verb`) | Plain `switch` over the verb byte. Faster and clearer. |
| Templates over `<typename T>` | Copy-paste specialize for `double` only. We have one floating point type. |
| Bit hacks on `float` (`SkFloatBits`) | Use `Float32List` viewed as `Int32List` via `ByteData` only when the algorithm genuinely depends on the bit pattern. Otherwise rewrite using regular comparisons. |
| `std::vector<T>` | `List<T>` or, in hot paths, a `Float32List`/`Uint8List` with a separate length cursor. |

Forbidden in ports:

- **No `dart:ffi`.** The whole point of fast_path is that it's pure Dart.
- **No `dart:io`.** The package must run in browsers and constrained
  environments.
- **No `dart:ui`.** The library is Flutter-independent. Tests under
  `test/parity/` may import `dart:ui`, but `lib/` may not.
- **No allocation in inner loops** unless upstream did so too. If upstream
  uses a stack array, port it as indices into a reusable buffer, not as a
  fresh `List` per call.

### 6. Add a port-provenance comment

Below the headers, add a short block that future maintainers can scan:

```dart
// Ported from: skia/src/core/SkConic.cpp @ <SHA>, function `chopIntoQuadsPOW2`.
// Last synced: 2026-05-09.
// Deviations from upstream:
//   - Operates on Float32List indices instead of SkPoint*.
//   - Drops the SkScalarsAreFinite check; callers in fast_path guarantee
//     finite inputs.
```

When upstream evolves, this block is the lifeline that tells the next
contributor whether to re-sync.

### 7. Tests come with the port

Whatever the algorithm is, it ships with:

- **Unit tests** for the function itself (round-trip, edge cases, NaN/Inf
  handling matching upstream's documented behavior).
- **Parity tests** in `test/parity/` that compare against `dart:ui.Path`
  output for the same input. See `add-path-api` skill for the parity
  harness shape.

If upstream has unit tests for this function (Skia's `tests/`,
Flutter's `path_unittests.cc`), port the relevant cases into Dart. The
license treatment is the same: preserve the upstream header on the test
file, cite the source.

### 8. Surface anything weird before merging

If any of these come up, stop and ask the human rather than deciding alone:

- Upstream uses GPU buffers, threading, or anything that doesn't translate
  to plain Dart.
- The C++ uses undefined behavior (signed overflow, type punning) and the
  Dart equivalent is genuinely different.
- Upstream's behavior contradicts what `dart:ui.Path` actually does
  (because Flutter has patched it). When in doubt, dart:ui's behavior wins
  — that's our parity target.
- Upstream's algorithm depends on a coordinate scaling regime (e.g.
  fixed-point internally) that we can't reproduce in f32 without divergence
  from `dart:ui.Path`.

## Quick checklist (use before opening a PR)

- [ ] Upstream file path and commit SHA are pinned in a comment.
- [ ] Upstream license header is at the top of the file, verbatim.
- [ ] License is BSD/MIT/Apache (not GPL/LGPL/AGPL).
- [ ] Code structure matches upstream — function boundaries, control flow,
      variable names — even where Dart would prefer differently.
- [ ] No `dart:ffi`, `dart:io`, or `dart:ui` imports in `lib/`.
- [ ] Hot paths allocate nothing per call.
- [ ] Unit tests + parity tests landed in the same PR.
- [ ] Deviations from upstream are documented in the port-provenance block.
