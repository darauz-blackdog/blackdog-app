---
name: warn-fixed-height-with-text
enabled: true
event: file
pattern: height:\s*\d+\.?\d*
action: warn
---

**Fixed height detected in a widget file.**

Review if this container holds dynamic text content. Per project rules:
- Use `Flexible`, `Expanded`, `IntrinsicHeight`, or `minHeight` constraints instead of fixed `height:` for containers with Text children.
- Fixed heights on text containers cause overflow on different screen sizes and font scales.
- Exception: `SizedBox(height:)` for spacing and `SizedBox(height:)` wrapping horizontal lists are OK.
