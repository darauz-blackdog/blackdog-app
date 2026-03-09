---
name: filter-branches-by-status
enabled: true
event: file
pattern: branchListProvider|getBranches|\.from\('branches'\)|branch.*list|sorted.*branch
action: warn
---

⚠️ **Branch filtering required**

When listing or querying branches, ALWAYS filter by status flags:

- **is_active**: Hide inactive branches entirely (filter at provider/API level)
- **is_pickup_enabled**: Only show branches that support pickup when listing for pickup selection
- **is_delivery_enabled**: Only show branches that support delivery when listing for delivery selection

Never show all branches unfiltered in user-facing lists. Disabled branches should either be:
1. Hidden completely, OR
2. Shown as non-selectable with a clear explanation (e.g., "Delivery no disponible")

When switching delivery type, clear the selected branch if it doesn't support the new type.
