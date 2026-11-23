# ASSET_PRODUCTION.md (one per project; the skill reads this first)

1. **Engine and where assets are used:** e.g. Godot 4, assets loaded from `assets/`.
2. **Art style and canvas rules:** style in one sentence; native canvas sizes; standing height in pixels and tolerance; transparent background required (yes/no).
3. **Naming and folders:** filename pattern, draft/master/export folders, manifest or queue files and their format.
4. **Identities and references:** where approved masters live, which approved asset is the composition reference for each kind of asset.
5. **Approval rules:** who approves, how it is recorded (record file, preflight command), whether drafts may be generated without waiting (and the backlog caps).
6. **Runtime integration:** how an approved asset becomes game-ready, the checks to run, and what must never be claimed from approval alone.

7. **Pose planning data (optional, for pose sets):** the catalog of poses, the production plan (ordered groups, batch sizes), one profile per character, and the planner or runner commands that read them and report next work and record conflicts. Keep them small and reference the catalog by family names instead of copying it.

Mansion Mystery example: Godot 4; rich anime-style 2D art shown at game scale; Char/Chris/Kwinn/Sarah Jo masters under `assets/characters/poses/<slug>/masters/`; queue in `queue.json` or prompt pack `prompts/pack-01/prompts.json`;
drafts in `drafts/`, approved in `exports/<direction>/`; approval record in `drafts/*/candidates.json` plus `tools/check_image_approval.py`; backlog caps 24 per character and 48 total; integration through
`case_actor_art.gd` and `assets/characters/poses/runtime-integration.json`.
