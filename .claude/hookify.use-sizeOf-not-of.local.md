---
name: warn-mediaquery-of
enabled: true
event: file
pattern: MediaQuery\.of\(context\)\.size
action: warn
---

**Use `MediaQuery.sizeOf(context)` instead of `MediaQuery.of(context).size`.**

Per project rules, `MediaQuery.sizeOf(context)` is more efficient because it only triggers rebuilds when the size actually changes, not when any MediaQuery property changes (like keyboard visibility, padding, etc.).

Replace: `MediaQuery.of(context).size` -> `MediaQuery.sizeOf(context)`
