# 05 — Responsive type grid

Status: implementation delivered through PR #4 on `codex/type-matchups`; Simulator regression checks pending runtime installation.

## Experience

Add a Types detail tab displaying all 18 incoming type matchups together. Each tile has a colored three-letter type header and an effectiveness cell beneath it. Preserve the supplied reference order: Normal, Fire, Water, Electric, Grass, Ice, Fighting, Poison, Ground, Flying, Psychic, Bug, Rock, Ghost, Dragon, Dark, Steel, Fairy.

Prefer 3 rows × 6 columns. Choose the first fitting arrangement in this order: 3×6, 2×9, 6×3, 9×2. Tiles require at least 44 points of width and 48 points of height, with 4-point gaps. No filtering, pagination or scrolling. If an unsupported widget size cannot contain any arrangement, explain the space requirement instead of clipping or omitting types.

Use the supplied type palette for both grid headers and the type badges beneath the sprite. Dual types retain two separately colored badges. Keep the green sprite-screen background unchanged. Type and multiplier labels use contrasting text; accessibility announces full type names and effectiveness, including neutral cells.

Effectiveness backgrounds: charcoal for 0×, darker red for ¼×, red for ½×, white for 1×, dark green for 2× and bright green for 4×. Neutral values remain blank with a visible “Blank = 1×” legend. Label the calculation “Type-only damage”; abilities, items and battle effects are excluded.

## Data and calculation

Bundle the modern 18-type matrix generated from a pinned PokeAPI/pokeapi source revision. Keep the upstream CSV snapshot, checksums, license and offline generator. The runtime never fetches a chart and does not depend on an API chart cache.

Multiply the two defending-type relations for each attacker. Immunity remains zero. Deduplicate repeated defending types; reject missing, unknown or more than two unique defending types instead of assuming neutrality. The calculator is independent of SwiftUI and networking. Calculate from the current Pokémon so search, scans and previous/next cannot leave a stale grid.

The feature fits the existing Duo detail panel. Ordinary-iPhone layout remains its own feature; this change does not modify orientation or the overall design-canvas sizing.

## Acceptance and tests

Verify every one of the 324 single-type relationships against the pinned source. Reproduce the complete Gyarados reference, including Electric 4× and Ground immunity. Test Charizard, Scizor, Normal/Ghost, all dual-type pairs, malformed charts, unknown inputs, stable ordering and the exact layout boundaries.

Build the app and test targets. In Simulator, verify the grid and badges after a selection change, all 18 tiles visible, offline behavior, search, scanner import/candidate lookup and repeated fold/unfold without orientation or artwork-cache regressions. Keep the reference and screenshots outside Git.

## Regeneration

`python3 Tools/generate_type_chart.py --check` verifies the bundled output offline. Without `--check`, the script regenerates it from the verified snapshot. Refreshing sources requires `--refresh --revision <full-commit-sha>` and must be reviewed as a data change. The manifest records the pinned URLs, retrieval time and SHA-256 checksums.

[PokéAPI type resources](https://pokeapi.co/docs/v2/#types) define the damage relations. The source snapshot is from [PokeAPI/pokeapi](https://github.com/PokeAPI/pokeapi); its license is retained and bundled.
