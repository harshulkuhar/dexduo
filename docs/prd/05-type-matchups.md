# 05 — Weaknesses and resistances

Status: planned. Branch: `codex/type-matchups`. Depends on fixed-layout detail paging.

## Experience

Add a Types detail tab showing incoming damage multipliers for the selected Pokémon. Present Weaknesses, Resistances, Immunities and Neutral groups, with attacking type names and explicit multipliers. Color supplements text rather than carrying meaning alone.

Show the combined result for both defending types. Display values as 4×, 2×, 1×, ½×, ¼× and 0×. A fixed grid shows up to nine type chips per page, or fewer when required by text size/available height. Group selection and previous/next page controls make every type reachable without scrolling. Empty groups have an explicit “None” state.

Keep a visible “Type-only damage” explanation: abilities, items, weather, move exceptions, temporary transformations and battle state are excluded. An ability such as Levitate must not be presented as a type immunity. This release is a defensive chart for the selected Pokémon, not a full battle calculator or a tiny unreadable 18×18 matrix.

## Data and calculation

Bundle a versioned JSON chart for all 18 standard types, generated reproducibly from PokéAPI's current damage relations. Record source URLs, retrieval date, source revision where available and checksums. Do not fetch the chart on every selection; it must work on first launch offline.

For each attacking type, multiply its relation against each defending type. Immunity takes precedence through multiplication by zero. Treat a single defending type once; reject unknown/missing defending types with an unavailable state rather than silently assuming neutral damage. Ignore nonstandard API type categories. Historical `past_damage_relations` are outside this modern chart.

Keep the calculator pure and independent of SwiftUI/networking. Group the computed results in a stable type order, and reset the page appropriately when the selected Pokémon changes. Type data has no effect on recognition predictions.

## Acceptance and tests

- Verify all 18 attacking and defending types, diagonal values and every bundled source relation against the generator snapshot.
- Pikachu: Ground 2×. Charizard: Rock 4×, Grass ¼×, Ground 0×. Scizor: Fire 4×. Normal/Ghost defensive combinations correctly retain immunities.
- Test dual-type multiplication, duplicate-input rejection/normalization, unknown types, stable grouping and complete pagination.
- The screen updates after search, scan, previous/next and evolution selection. No stale chart remains attached to a new species.
- All names and multipliers remain readable in compact landscape and with supported accessibility text sizes. Offline operation needs no cached API chart request.

Commit the chart, provenance and text-based tests only. Runtime downloaded artwork remains excluded from Git.

## Source

[PokéAPI type resources](https://pokeapi.co/docs/v2/#types) expose damage relations and historical relations. The combined defensive calculation and UI scope above are DexDuo decisions.
