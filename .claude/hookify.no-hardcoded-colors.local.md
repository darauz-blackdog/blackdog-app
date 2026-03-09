---
name: warn-hardcoded-colors
enabled: true
event: file
pattern: Color\(0x|Colors\.\w+(?!\.transparent|\.white|\.black)
action: warn
---

**Hardcoded color detected in a widget/screen file.**

Per project rules, use `AppColors` or `Theme.of(context).colorScheme` instead of raw `Color(0x...)` or `Colors.xyz`.

Allowed exceptions:
- `Colors.transparent`, `Colors.white`, `Colors.black` (universal)
- `Colors.grey.shade400` for subtle UI elements (drag handles)
- Inside `app_theme.dart` where theme colors are defined
