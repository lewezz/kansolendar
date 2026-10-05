# Roadmap from the current source

The application and package modules already exist. This roadmap starts from that
implementation rather than repeating the original documentation-first phases.
It records sequencing, not deadlines or authorization to build or publish.

## 1. Verify the current refactor when requested

Compile the app, run relevant package suites, and validate document lifecycle,
signed file/Keychain access, independent windows, backup destination preservation,
and restore failure paths. Current static checks do not close those requirements.

## 2. Resolve lifecycle and temporal gaps

Define automatic-lock policy, verify restore/lock interaction, remove calendar
boundary traps, and validate system-calendar/DST behavior. Finish safe recurrence
editing before treating the UI as a complete series editor. See
[open work](open-questions.md).

## 3. Establish concrete GitHub delivery

Choose the actual artifact/identity/update process for the single app. Validate
installation, Finder association, fresh-Mac launch, and local-key continuity on
that artifact. No alternate product variant or release pipeline is present.

## 4. Evolve formats only with an explicit requirement

A password-change UI, new schema/payload versions, broader `.ics` semantics, or
additional features need a concrete compatibility and verification strategy.
The existing offline/no-account/no-telemetry boundaries remain product scope.

See [testing](testing.md), [distribution](distribution.md), and
[decision records](adr/README.md).
