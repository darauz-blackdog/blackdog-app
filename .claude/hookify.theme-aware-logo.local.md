---
name: theme-aware-logo
enabled: true
event: file
conditions:
  - field: new_text
    operator: regex_match
    pattern: (logo_dark\.png|logo\.png|assets/images/logo)
---

**Theme-aware logo required!**

The BlackDog app has two logo variants that must be used based on theme brightness:

- **Light theme** → `assets/images/logo_dark.png` (dark logo on light background)
- **Dark theme** → `assets/images/logo.png` (light logo on dark background)

Always check `Theme.of(context).brightness` or equivalent and select the correct variant. Never hardcode a single logo file.

Example:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final logo = isDark ? 'assets/images/logo.png' : 'assets/images/logo_dark.png';
```
