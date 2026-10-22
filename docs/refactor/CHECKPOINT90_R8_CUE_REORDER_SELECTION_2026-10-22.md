# SubtitleStudio — CP90 R8: Accurate cue selection after timing changes

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Problem and change

Changing a cue's timing can move it in the persisted ordering. The V2
checkpoint transaction already sorts and reindexes these rows, but Edit
Line formerly patched a single local row back at its original index. The
selected cue, Save-to-file output, video overlay, and Next/Previous behavior
could consequently disagree with Isar's committed order.

A new `EditLineCommittedCue` result now holds the selected persisted cue and
the entire committed row order. The transaction tracks the edited or newly
inserted cue's object identity through sorting and reindexing, rather than
guessing identity from text/timestamps or a stale index. Existing boolean
repository interfaces remain in place; new resolved methods return this
stronger result.

The common Edit Line draft-save service returns the committed result and
records the post-sort index as the session's last-edited index. The screen
replaces its entire local cue list and selected index after a successful
save, regenerates player subtitle data, and exports the committed ordering.
Next/Previous navigation computes the adjacent index after autosave.

No Isar schema, portable `.msone`, file-system API, theme, media engine or
desktop-preview changes.

## New regression tests

- Timing change moves a cue after an existing cue: persisted order and
  history validation agree with selected index.
- Identical text and timestamp cues remain distinguishable by committed
  identity/metadata.
- An inserted early cue receives its actual first position even when
  inserted at the end of the working list.
- Pure service regression verifies the persisted index is used for session
  last-edited position, not the old index.
- Existing blank cue, encoding, parser, V2 history and UI tests remain.

## CI status

The batched Linux Flutter gate is triggered with this implementation. Final
counts and analyzer status will be appended after verification.
Windows/macOS platform file-host tests are not needed for a state-only change.
No native platform builds run in GitHub Actions.

## Remaining

CP90 remaining mixed Editor/controller/media ownership, CP91 visual checkpoint
history and mobile Edit Line UX, CP92 careful cleanup, CP93 real platform
smoke and project compatibility acceptance. The libmpv hot-restart crash is
tracked separately; waveform experiment and desktop preview stay isolated.
