# 04 — Evolution families

Status: planned. Branch: `codex/evolution-chains`. Depends on fixed-layout detail paging.

## Experience

Add an Evolution detail tab for the selected species. Show its family, highlight the current species and let the user open any member. Linear families show all stages. Branching families must expose every branch, including all eight Eevee evolutions, through explicit pages rather than a horizontally scrolling strip.

Represent the family as stage/branch pages: a parent context and up to three outgoing evolution rows per page, each with species name, cached thumbnail and a condition summary. Previous/next controls include page position. A stage selector/breadcrumb exposes earlier and later stages; no branch is silently dropped. The compact layout may show fewer rows while retaining the same traversal. A standalone species shows “No known evolutions.”

Selecting a species uses the existing entry-loading path, then highlights it within the family. Leave the previous selection visible on a failed load and offer Retry. Merely browsing family pages does not trigger speech or replace the selected Pokémon.

## Data and conditions

Extend `Species` with the optional `evolution_chain` reference and default variety information as needed. Decode the referenced chain recursively, including all `evolves_to` children and evolution details. Resolve species to its default Pokémon API identifier rather than assuming every species name is a Pokémon endpoint name.

Use `DexAPI` and its persistent cache. Load family data when the Evolution tab is first requested; keep core entry display independent of this request. Guard completion with the current species/request token. Cache by chain ID so selecting another member does not refetch the same family unnecessarily.

Render multiple evolution-detail records as alternative methods; combine requirements within one record. Handle level, item, trade, held item, friendship, affection/beauty, time, gender, location, known move/type, party species/type, relative attack/defense, rain and device-specific conditions when supplied. Unknown fields must not become a false generic “Level up” claim. Use a concise “Additional conditions” summary with a paged text detail view when a method cannot fit or cannot be fully represented.

The scope is the family and conditions supplied by PokéAPI. Explain that conditions may vary by game; do not claim a game-specific exhaustive guide. Regional/form restrictions must be shown when supplied, or marked as not resolved. Mega transformations and other temporary forms are outside this family view.

## States and acceptance

Provide loading, loaded, standalone and retryable unavailable states. If an uncached chain is unavailable offline, keep Info/Stats usable and explain that family data needs a connection. Cached chains remain browsable offline. Missing thumbnails use a placeholder without blocking selection.

Tests cover a three-stage family, Eevee's eight branches, a branching multi-stage family, no evolution, multiple alternative methods, compound requirements, default-form mapping, unknown conditions, stale responses and failure retry. Use committed JSON fixtures, not image fixtures.

UI tests confirm every Eevee branch is reachable, a middle-stage selection keeps its family context, candidate entry loading uses the correct API identifier, and long conditions fit through paging on the smallest landscape layout. Search, scanner and fold regressions still pass.

## Source

[PokéAPI v2 documentation](https://pokeapi.co/docs/v2/#evolution-chains) defines chain links and evolution details; [species resources](https://pokeapi.co/docs/v2/#pokemon-species) link species to families and varieties. Paging and failure behavior are DexDuo requirements.
