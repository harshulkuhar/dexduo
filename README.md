# Pokédex Duo

Native SwiftUI prototype inspired by Ash's Kanto Pokédex. Open `Pokedex.xcodeproj` in Xcode and run the `Pokedex` scheme on an iOS 17+ Simulator. No third-party packages or API keys are required.

## Implemented

- Red cover and adaptive interior; On iOS 27.1, the public onHingeChange API switches automatically between the closed cover and open interior. The cover cannot be tapped open on a hinged device; folding dismisses the scanner and retains the selected entry. Ordinary devices retain manual Cover/Open preview controls. Building requires Xcode 27.1 or later.
- Live PokéAPI name autocomplete, official artwork, types, English Pokédex entries, height, weight, abilities, base stats and base stat total.
- Previous/next entry controls and request ordering protection.
- JSON disk cache (seven-day freshness, stale fallback when offline).
- Artwork disk and memory caches; the selected image stays loaded through fold/unfold transitions.
- Fixed orientation with no page scrolling; keyboard presentation preserves the search field layout.
- Camera capture on physical devices and photo import in Simulator.
- On-device Vision OCR matching English Pokémon names and common card suffixes (ex, GX, V, VMAX, VSTAR). Candidate confirmation is required because card text can mention multiple Pokémon.

## Not implemented yet

- Artwork-only image classification. OCR is not a visual species classifier, and cannot recognize a Pokémon without readable name text.
- Evolution chains and a custom app icon.
- A committed automated UI test target (search typing and clearing were verified with a temporary Simulator UI test harness).
- Simultaneous outer-display camera accessories are not used; the cover follows the closed-device hinge state.

## Device testing

Select your signing team under Signing & Capabilities, connect a compatible iPhone, enable Developer Mode and run. Camera access is requested only when the Camera button is tapped. Photo import uses Apple's system picker. Captured/imported images are processed locally and are not uploaded. Pokémon lookups and artwork downloads use the network.

## Smoke checks

1. Unfold the device (or tap the cover on an ordinary device); Pikachu's artwork and details appear.
2. Search `char`, choose Charizard, switch Info/Stats and use previous/next.
3. Close and reopen the cover; selected entry remains unchanged.
4. Import an image containing a clearly readable `Pikachu` or `Pikachu V` title; confirm the candidate.
5. Import an image without Pokémon name text; expect no match, not a forced prediction.
6. Simulator Camera explains that import is required; physical camera handles denial and cancellation.
7. Test a previously viewed entry offline; cached JSON and previously cached artwork remain available.
8. Inspect narrow and wide layouts: no page scrolling. Narrow windows use Pokémon / Search & details tabs; wide windows show both panels. Search results replace the information panel while typing.

## Sources

- https://pokeapi.co/docs/v2/ — Pokémon data; responses cached per API guidance.
- https://developer.apple.com/documentation/vision/recognizing-text-in-images — OCR.
- https://archives.bulbagarden.net/wiki/File:Ash_Original_Pok%C3%A9dex.png — visual reference.

Unofficial fan prototype. Pokémon names and artwork belong to their respective owners.
