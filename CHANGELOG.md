# Changelog

Releases of Permanence **machinery** — `runtime/`, `.githooks/`, `templates/`, and the
docs. Your own streams, `_meta/REGISTRY.md`, and notes are never part of a release;
they're yours, not the template's.

Tagged `vMAJOR.MINOR.PATCH`. `/perma-upgrade` diffs your installed version (recorded
in `_meta/VERSION`) against the latest tag here and walks you through what changed.

A release entry gets a **Migration notes** section only when it changes something
that existing streams may need to adapt to (a `SPEC.md` convention, a canonical file's
expected shape). No section = nothing for your streams to do; `/perma-upgrade` just
refreshes machinery as usual. Migration notes are read and *proposed* against your
streams, never applied without your say-so (SPEC.md invariant 5).

## [Unreleased]

## [1.0.0] — first public release

Baseline: streams (`PROJECT`/`LOG`/`PEOPLE`/`QUESTIONS`), the four conventions,
`/perma-*` commands, `/perma-upgrade`, opt-in events/search/cognitive-debt-scan,
programme groups. No migration notes — this is the starting point.
