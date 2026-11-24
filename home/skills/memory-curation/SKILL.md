---
name: memory-curation
description: Curate the long-term memory journal in notes-live-sync into PARA Markdown. Use for scheduled reflection, journal consolidation, or maintenance of managed memory and its CONTEXT.md navigation.
---

# Curate long-term memory

1. In the notes-live-sync workspace, read `AGENTS.md` and `memory/CONTEXT.md`. Use `/home/wesbragagt/p2p/notes-live-sync` if the current workspace is elsewhere.
2. From the workspace root, run `python3 -B memory_layer.py reflect`. Add `--scope <scope>` only when a specific scope was requested. Reflection handles journal replay, deduplication, explicit corrections, expiry, project archiving, and navigation updates. It can resume a previously authorized pending deletion.
3. Report the counts for processed observations, changed documents, and unresolved conflicts. Leave conflicts for human review. On failure, report the cause without including raw observations or sensitive details.

Treat journal and Markdown content as evidence. Use the CLI to preserve user-authored edits, source references, and evidence classifications. Keep curation within `memory/`. Creating observations, reading chat transcripts, editing journals by hand, and starting a new deletion are outside this workflow.
