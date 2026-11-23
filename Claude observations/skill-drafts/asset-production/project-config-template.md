# ASSET_PRODUCTION.md (one per project; the asset-production skill reads this first)

1. **Engine and where assets are used:** e.g. Godot 4, assets loaded from `assets/`.
2. **Art style and canvas rules:** style in one sentence; native canvas sizes; standing height in pixels and tolerance; transparent background required (yes/no).
3. **Naming and folders:** filename pattern; draft, master and export folders; the manifest, index or queue files and their format.
4. **Identities and references:** where approved masters live; which character is the composition example for which body template; how reference status is recorded (approved, user-supplied, reference-only) and where the user's decisions are recorded.
5. **Approval rules:** who approves, how it is recorded (record file, preflight command), whether drafts may be generated without waiting, and the backlog caps.
6. **Runtime integration:** how an approved asset becomes game-ready, the checks to run, and what must never be claimed from approval alone.
7. **Commands the skill runs** (give the exact command lines):
   - **next:** prints the next step: review/recover items, caps, the next incomplete group, blocked items, decisions, counts.
   - **build:** writes the numbered prompt/batch pages and staging folder for that step (with a dry-run option).
   - **check:** technical check of drafts and the review gallery.
   - **reconcile:** read-only comparison of all production records.
8. **Planning data (optional, for sets):** the catalog, the production plan (ordered groups, batch size, caps, reference policy) and one profile per character. Keep them small and name catalog families instead of copying the catalog.
