# Task 1 Rehearsal

This branch is only for a pre-submission rehearsal. It is **not** the workspace to upload to the crowdsourcing platform.

Run from a fresh clone of this branch:

```bash
./tools/run_task1_rehearsal.sh
```

The script runs Claude Code in non-interactive print mode, saves the full stream-json transcript under `.rehearsal/`, and counts unique `tool_use` blocks.

The official upload baseline remains:

`workspace/doubao-visual-production`

Do not copy any rehearsal changes back into that baseline before the formal evaluation.
