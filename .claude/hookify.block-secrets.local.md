---
name: block-secrets-commit
enabled: true
event: bash
pattern: git\s+(add|commit).*\.(env|pem|key|p12|jks|keystore)
action: block
---

**BLOCKED: Attempting to commit sensitive files.**

Files matching `.env`, `.pem`, `.key`, `.p12`, `.jks`, `.keystore` must NEVER be committed to the repository. These may contain API keys, certificates, or secrets.

If you need to reference these files, add them to `.gitignore` instead.
