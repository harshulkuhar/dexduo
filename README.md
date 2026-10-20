# DexDuo

Native SwiftUI Pokémon companion inspired by Ash's original red handheld. Open `DexDuo.xcodeproj` in Xcode 27.1 or later and run the `DexDuo` scheme on an iOS 17+ device or Simulator. No API keys or third-party iOS runtime packages are required.

Planned features and acceptance criteria: [release PRD](docs/PRD.md). Branch status and verification still needed: [delivery checkpoint](docs/DELIVERY.md).

## Implemented

- Text-free red cover on the closed display; automatic cover/interior switching through the iOS 27.1 hinge API. Ordinary iPhones launch into a landscape cover; tap anywhere to open, or use Cover to close without losing the selection.
- Ordinary iPhones support both landscape directions, with a compact toolbar, equal artwork/details panels and a fixed app shell. Info, Stats and Evolution scroll vertically inside the right LCD; the toolbar, tabs and artwork stay fixed. Accessibility sizes use full-width Artwork/Details pages; all 18 types remain visible. Search temporarily replaces the panels with paged autocomplete results while the keyboard is open.
- Duo retains its fixed UIKit orientation, automatic cover switching and retained artwork. A temporary missing hinge update does not change its device profile.
- PokéAPI autocomplete, official artwork, types, English DexDuo entries, height, weight, abilities, six base stats and base stat total.
- Local robotic narration of the selected name and complete English entry. Info has Read/Stop and Audio settings; Auto-read defaults on for explicit selections and is remembered. Launch, cover opening and foregrounding stay silent. Folding, closing the cover, opening the scanner, backgrounding or an audio interruption stops playback. VoiceOver suppresses Auto-read while manual Read remains available.
- Responsive 18-type defensive grid with combined dual-type multipliers, reference colors and matching sprite type badges. Chart data is bundled for offline use; abilities/items are excluded.
- Evolution families with official-artwork thumbnails, colored type badges, a selected-member highlight and tappable evolution methods. Straight families use a horizontal chart when readable; branching families scroll as one connected tree. Cached families work offline, and failed member selections retain the current Pokémon with Retry. Form and game conditions are shown when supplied; this is not an exhaustive game-specific evolution guide.
- Previous/next controls, request ordering protection, cached JSON and artwork. Selected artwork remains loaded through folding.
- Rear camera capture on physical iPhones and photo import in Simulator. The phone scanner uses a full-screen landscape preview/results layout, including candidate confirmation, Retry and an always-reachable Done button. Apple camera/Photos screens retain their system presentation.
- Fully local visual classification of 1,025 species using a bundled Core ML model. **No OCR or text recognition is used.** High-scoring results automatically load the entry; uncertain results show up to three candidates. Failed data lookups remain retryable in the scanner.

## Model and current accuracy

Source: [skshmjn/Pokemon-classifier-gen9-1025](https://huggingface.co/skshmjn/Pokemon-classifier-gen9-1025), pinned revision `9e8d54de136b99afc212322eae13ddc07a6fd779`. The model card specifies Apache-2.0. Species labels, default-form PokéAPI identifiers, source checksums, export settings and the automatic-lookup policy are recorded in `DexDuo/Models/ModelManifest.json` and `PokemonLabels.json`.

The Core ML package is approximately 176 MB; most weights/linear computation use FP16, with sensitive attention/normalization and final classification in FP32. It supports iOS 17. No model download is needed at runtime. The simulator uses CPU inference; real devices use Core ML's available compute units.

The exploratory visual benchmark achieved 46/60 top-one matches. It performed well on clean artwork, but poorly on full card photos and full-scene screenshots. Keep one Pokémon prominent in the image. The initial automatic threshold (score >=0.90, margin >=0.20) made 42 correct automatic lookups and no lookups on the 30 negative examples. Scores are not calibrated confidence, and the model is not a guaranteed Pokémon-presence detector. See [the full benchmark and limits](Evaluation/README.md).

Separate regional/Mega/other form recognition, live camera inference, object detection, crop editing and a custom app icon are not implemented.

Narration uses an installed English system voice, a restrained 70 Hz ring-modulation effect and local audio playback. With an English voice installed, narration needs no network connection. Missing English text disables Read; unavailable voices or audio output show retry guidance. Temporary PCM files are deleted after playback/cancellation, and decoded playback is bounded to about two seconds. Physical-device voice audition and speaker/headphone checks remain pending; native pronunciation of some Pokémon names may be imperfect.

## App identity

The app, Xcode project, shared scheme and Swift module are named `DexDuo`. The app bundle identifier is `com.harshulkuhar.dexduo`. This identity change installs DexDuo as a separate app from earlier builds; their sandboxed caches and permissions do not transfer automatically.

## Type chart data

The chart is generated from pinned PokéAPI CSV snapshots in `Tools/TypeChartSources`; the upstream license is retained and included in the app bundle. Run `python3 Tools/generate_type_chart.py --check` to verify all 324 relationships offline, or omit `--check` to regenerate. Updating the source requires an explicit `--refresh --revision <full-commit-sha>`. The Types tab displays all 18 types without scrolling; neutral cells are blank as explained by the legend.

## Clone and model storage

Install Git LFS before cloning or run these commands in an existing clone:

```sh
git lfs install
git lfs pull
```

Core ML package weight binaries use Git LFS. Source PyTorch weights, Python environments, build outputs and raw evaluation images are excluded from Git. The application code's MIT license and the pretrained model's Apache-2.0 provenance are separate; Pokémon names/artwork belong to their respective owners.

## Rebuild the model

Use an isolated Python 3.12 environment on an Apple silicon Mac:

```sh
python3 -m venv .venv-model
source .venv-model/bin/activate
pip install -r Tools/model-requirements-lock.txt
python Tools/convert_model.py --output DexDuo/Models --cache .model-cache
```

The script downloads the pinned Safetensors checkpoint, verifies all species labels against PokéAPI, exports the logits graph, and generates the package/manifest. A new export defaults to **automatic lookup disabled** until `Tools/benchmark_model.py` passes the documented gates. Benchmark before replacing the shipped validated artifact. Conversion never substitutes another model on failure.

## Device testing

Select your signing team under Signing & Capabilities, connect an iPhone, enable Developer Mode and run. Camera permission is requested only when Camera is tapped. Import uses the system Photos picker. Images remain on your device; only Pokémon data/artwork requests use the network. Offline recognition works immediately, but an uncached DexDuo entry requires internet.

## Tests and manual checks

The shared DexDuo scheme contains `DexDuoTests` and `DexDuoUITests`. Unit tests cover ranking, thresholds, label mapping, whole-image preprocessing/orientation, native model inference, obsolete-result cancellation, duplicate lookup prevention and retry behavior. Phone tests additionally cover device-profile latching, orientation policy, safe-area/keyboard capacity, contained detail scrolling, retained text-field identity, component rendering and all 18 type colors at compact/notched/large sizes. Test attachments stay in Xcode result bundles outside Git.

For UI tests, use an ordinary iPhone simulator (or unfold Duo) and add only the Espeon fixture to Photos (or select it as the first photo in the picker):

```sh
python3 Tools/download_test_fixtures.py
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl addmedia 'DexDuo iPhone 18 Pro' Tests/Fixtures/espeon.png
xcodebuild -project DexDuo.xcodeproj -scheme DexDuo -destination 'platform=iOS Simulator,name=DexDuo iPhone 18 Pro' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

The primary test destination is iPhone 18 Pro, named `DexDuo iPhone 18 Pro` locally; substitute your simulator name if needed. Phone UI tests cover both landscape directions, cover/background state, typing/selection, scanner import, evolution traversal and accessibility scrolling. They explicitly skip the legacy Duo/tablet presentation. The separate Duo presentation test checks the latched device profile and fixed UIKit orientation; it skips ordinary phones.

Manual checks: search a full name and clear/retype; import artwork without text; verify an uncertain/no-match image; retry with the network unavailable; dismiss/fold during recognition and confirm no late lookup or dismissal. Reopen to confirm artwork remains cached and orientation remains fixed. Simulator camera directs you to Import; physical camera denial/cancellation and performance require an actual iPhone.

## Sources

- [PokéAPI](https://pokeapi.co/docs/v2/): Pokémon data and artwork links.
- [Model source](https://huggingface.co/skshmjn/Pokemon-classifier-gen9-1025): checkpoint and license metadata.
- [Core ML conversion](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch-workflow.html).
- [Original device design reference](https://archives.bulbagarden.net/wiki/File:Ash_Original_Pok%C3%A9dex.png): visual reference.

Unofficial fan prototype.
