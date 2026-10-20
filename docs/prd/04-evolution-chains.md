# 04 — Evolution families and scrollable details

Status: implemented in [PR #7](https://github.com/harshulkuhar/dexduo/pull/7); iPhone 18 Pro and Duo Simulator validation passed. Original branch: `codex/evolution-chains`. The vertical chart and inline requirements follow-up is [PR #10](https://github.com/harshulkuhar/dexduo/pull/10), branch `codex/evolution-inline-requirements`. Concise labels and distinct form outcomes are delivered in [PR #11](https://github.com/harshulkuhar/dexduo/pull/11), branch `codex/evolution-branches`.

## Experience

Add EVO beside Info, Stats and Types on the right. Use official-artwork thumbnails, national numbers, compact badges from the shared palette and a cyan outline for the selected species. Tapping a member loads it into the left panel while retaining EVO and the family context.

Info, Stats and Evolution scroll vertically inside the green LCD. Tabs, toolbar, artwork and casing remain fixed. Info shows the entire entry and then height/weight. Stats shows six values, total and abilities. Types keeps all 18 cells visible without scrolling. Search/scanner result paging is independent. Accessibility retains the full-width Details presentation.

All families use a vertical chart with full-width member cards and readable requirements between stages. Condition text wraps to the available width and grows vertically; there are no narrow arrow columns. Branching families are one continuous connected tree with shared ancestors shown once. All eight Eevee branches are reachable by scrolling; there are no branch or stage pages. Family scroll context survives selecting a member and reopening the view. A new family initially reveals the selected member.

Each distinct outcome has its own arrow and card, including regional forms of the same species. Labels contain only the requirement, such as “Thunder Stone”, “Thunder Stone (Alola)”, “Level 30” or “Dawn Stone (female)”. Gender, time, location and required source form stay visible when necessary. No introduction versions, redundant source/result-form prose or instructions appear. Use default methods for each outcome when supplied, otherwise retain available methods; deduplicate identical labels. Multiple methods for the same outcome share a compact label, rather than duplicating its card. Unknown requirements remain explicit.

Kirlia has separate Gardevoir (Level 30) and Gallade (Dawn Stone, male) arrows. Snorunt has separate Glalie (Level 42) and Froslass (Dawn Stone, female) arrows. Pikachu has separate Raichu (Thunder Stone) and Alolan Raichu (Thunder Stone in Alola) arrows. A form-specific continuation attaches to the correct parent form: ordinary Graveler leads to Golem, Alolan Graveler to Alolan Golem, and only Galarian Mr. Mime leads to Mr. Rime. Standalone species show “No known evolutions.”

## Data and lifecycle

Decode species chains and their recursive methods through PokéAPI. Resolve ordinary nodes through the default variety and supplied form outcomes through the Pokémon-form endpoint, preserving the form’s artwork and types. Cards and the left panel use National Dex numbers; previous/next navigation follows that sequence. Source-form restrictions route continuations to the correct form. The chart covers supplied evolution outcomes, not comprehensive cosmetic-form browsing or Mega transformations.

A scene-owned evolution model loads lazily on opening EVO, coalesces metadata requests through the repository and reuses persistent data/artwork caching. Thumbnail loading never replaces the selected artwork. Missing thumbnails use placeholders. Cached families remain usable offline; unavailable uncached data offers Retry.

Generation guards reject obsolete loads and selections after closure, folding or replacement. Completed family data, thumbnails and the visible member anchor survive reopening. Member selection uses the existing entry path with inline error reporting; a failed load preserves the previous Pokémon and offers Retry inside EVO. Info/Stats restart at the top for a new Pokémon.

## Acceptance

Use committed JSON fixtures with provenance, not image fixtures. Cross-check all 19 branching-species parents from the official species CSV against the projected trees. Cover Pikachu’s separate regional outcomes, Kirlia and Snorunt gender restrictions, Geodude’s form routes, Gastly’s reference, Eevee’s eight concise default requirements, Wurmple, Applin’s uneven depth, standalone species, default-form identifiers, compound and regional requirements, unknown conditions, stale results, failure retry and offline cache reuse.

Run iPhone 18 Pro Simulator interactions for all tabs, complete content, tree traversal, member selection, concise labels, separate outcome arrows, exact-form selection, national-number navigation, fixed left artwork/tabs and both landscape directions. Render compact/notched/accessibility configurations. Run existing search, recognition, type-grid, retained-artwork and Duo orientation regressions; record actual fold cycles separately.

Deliver one feature PR and synchronize remaining branches after merging. Screenshots and captures remain outside Git.

## Source

[PokéAPI v2](https://pokeapi.co/docs/v2/#evolution-chains) defines chains and evolution requirements. JSON snapshots record source URLs and retrieval date in `Tests/Fixtures/Evolution.json`.
