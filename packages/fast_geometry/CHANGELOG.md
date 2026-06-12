# Changelog

## Unreleased

- `Matrix`: added structural `operator ==`, `hashCode`, and `toString`. Equality
  and hashing exploit the canonical-lowering representation (a `_rest`
  null/non-null mismatch decides inequality without comparing the extension) and
  normalize `-0.0` so equal matrices hash equally.
