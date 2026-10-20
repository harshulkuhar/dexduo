# 04 — Evolution families and scrollable details

Status: implemented in [PR #7](https://github.com/harshulkuhar/dexduo/pull/7); iPhone 18 Pro and Duo Simulator validation passed. Branch: `codex/evolution-chains`.

## Experience

Add EVO beside Info, Stats and Types on the right. Use official-artwork thumbnails, national numbers, compact badges from the shared palette and a cyan outline for the selected species. Tapping a member loads it into the left panel while retaining EVO and the family context.

Info, Stats and Evolution scroll vertically inside the green LCD. Tabs, toolbar, artwork and casing remain fixed. Info shows the entire entry and then height/weight. Stats shows six values, total and abilities. Types keeps all 18 cells visible without scrolling. Search/scanner result paging is independent. Accessibility retains the full-width Details presentation.

Straight chains use a horizontal chart with conditions between nodes where readable. Narrow and accessibility layouts use a vertical arrangement. Branching families are one continuous connected tree with shared ancestors shown once. All eight Eevee branches are reachable by scrolling; there are no branch or stage pages. Family scroll context survives selecting a member and reopening the view. A new family initially reveals the selected member.

Tapping an arrow opens complete evolution methods inside the LCD, with a fixed Back control and vertically scrolling content. Default methods are summarized on arrows when unambiguous. Alternatives, compound requirements, introduction version groups and supplied regional/form restrictions remain available. Unrecognized requirements are marked unresolved rather than guessed. Standalone species show “No known evolutions.”

## Data and lifecycle

Decode optional species chain/default-variety references and recursive links through PokéAPI. Resolve species to its default Pokémon API identifier. Regional/form requirements are displayed when supplied; comprehensive form browsing and Mega transformations are outside this view.

A scene-owned evolution model loads lazily on opening EVO, coalesces metadata requests through the repository and reuses persistent data/artwork caching. Thumbnail loading never replaces the selected artwork. Missing thumbnails use placeholders. Cached families remain usable offline; unavailable uncached data offers Retry.

Generation guards reject obsolete loads and selections after closure, folding or replacement. Completed family data, thumbnails and the visible member anchor survive reopening. Member selection uses the existing entry path with inline error reporting; a failed load preserves the previous Pokémon and offers Retry inside EVO. Info/Stats restart at the top for a new Pokémon.

## Acceptance

Use committed JSON fixtures with provenance, not image fixtures. Cover Gastly’s reference, Eevee’s eight branches and older alternatives, Wurmple, Applin’s uneven depth, standalone species, default-form identifiers, compound and regional requirements, unknown conditions, stale results, failure retry and offline cache reuse.

Run iPhone 18 Pro Simulator interactions for all tabs, complete content, tree traversal, member selection, method details, fixed left artwork/tabs and both landscape directions. Render compact/notched/accessibility configurations. Run existing search, recognition, type-grid, retained-artwork and Duo orientation regressions; record actual fold cycles separately.

Deliver one feature PR and synchronize remaining branches after merging. Screenshots and captures remain outside Git.

## Source

[PokéAPI v2](https://pokeapi.co/docs/v2/#evolution-chains) defines chains and evolution requirements. JSON snapshots record source URLs and retrieval date in `Tests/Fixtures/Evolution.json`.
