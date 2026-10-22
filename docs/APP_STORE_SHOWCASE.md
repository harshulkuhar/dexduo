# App Store showcase generation

Six original English concepts: Open your DexDuo; Recognize what you see; Let your Dex speak; Follow the evolution; Know the matchup; Made to unfold (phone variant: Made for landscape). Dark hardware frames surround genuine UI captures. Separate close-ups are labelled; they do not imply a portrait phone UI.

## Outputs

All captures and exports are outside Git at `/Users/nonu/Workspace/dexduo-artifacts/app-store/`:

- `duo/`: six 2007×2853 inner-display poster compositions.
- `duo-outer/06-cover.png`: native 1398×2034 folded cover.
- `iphone/`: six 1206×2622 portrait compositions from landscape phone UI.
- `iphone-landscape/`: six 2622×1206 landscape compositions.
- `iphone-large/`: six 1260×2736 large-display submission canvases, uniformly scaling the same compositions without changing the 18 Pro UI's aspect ratio. These are not separate Air hardware captures.
- `contact-sheet.png`: Duo-first overview; `manifest.json`: input hashes, export dimensions and rendering dependencies.

PNG exports are opaque RGB. Dimensions were checked against [Apple’s screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). These assets do not replace iPad screenshots if iPad support remains enabled.

## Reproduce

Use macOS with Xcode/iOS Simulators, the system Helvetica font and Python with `pip install -r Tools/showcase-requirements.txt`. The manifest records Python/Pillow versions and the font checksum. Restore ignored recognition fixtures with `python3 Tools/download_test_fixtures.py`; never commit them.

Boot an iPhone 18 Pro and an unfolded Duo. Find their UUIDs with `xcrun simctl list devices`. Run for each, substituting its UUID and an outside-Git derived directory:

```sh
python3 Tools/capture_showcase.py --device PHONE_UUID --kind iphone --output /Users/nonu/Workspace/dexduo-artifacts/app-store/raw/iphone --derived /tmp/DexDuoShowcasePhone
python3 Tools/capture_showcase.py --device DUO_UUID --kind duo --output /Users/nonu/Workspace/dexduo-artifacts/app-store/raw/duo --derived /tmp/DexDuoShowcaseDuo
```

The tool creates a temporary project, registers `Tools/CaptureShowcase.swift` only there, and captures the actual displays with simctl at verified UI checkpoints. It changes neither the app nor normal test targets. It imports the ignored Espeon fixture, waits for actual recognition candidates, waits for actual speech playback, reveals Kirlia’s branches and checks Gyarados’s Electric 4×/Ground immunity. Launch-only preference overrides suppress unrelated tip prompts/automatic narration. They do not create results. No live-camera image is fabricated.

After the Duo capture run, open DexDuo again in Device Hub and fold it using Closed. Verify the actual red cover, then capture its outer display:

```sh
xcrun simctl io DUO_UUID screenshot --display=1 /Users/nonu/Workspace/dexduo-artifacts/app-store/raw/duo/06-cover.png
python3 Tools/render_showcase.py --raw /Users/nonu/Workspace/dexduo-artifacts/app-store/raw --output /Users/nonu/Workspace/dexduo-artifacts/app-store
```

Do not substitute XCTest screen attachments for raw display captures: current landscape/Duo attachment metadata can select or orient the wrong display. Inspect the contact sheet and full-size outputs after regenerating. Recognition copy describes local image processing; uncached entry retrieval still needs internet. Content rights, App Store account configuration and hardware validation remain owner checks in [submission setup](APP_STORE_SETUP.md).

## Header and search-result creative assets

Use the additional images in `/Users/nonu/Workspace/dexduo-artifacts/app-store/creative/`:

- Header slot: `header-3840x1646.png` (3840×1646).
- Search Results slot: `search-results-3840x2560.png` (3840×2560).
- Shared alternative for either slot: `universal-5244x2950.png` (5244×2950).
- `preview.png` is a contact sheet for review, not an upload asset.

These original compositions reuse genuine folded/open Duo captures and the existing dark hardware style. All three upload files are opaque RGB PNGs. Sizes follow [Apple’s creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications), checked October 22, 2026. Use App Store Connect’s Preview to confirm the placement-specific crop before publishing. They contain no pricing, awards, URLs or download claims added to the artwork.

Regenerate with the same Pillow environment used above:

```sh
python3 Tools/render_store_creative.py --raw /Users/nonu/Workspace/dexduo-artifacts/app-store/raw/duo --output /Users/nonu/Workspace/dexduo-artifacts/app-store/creative
```

The tool reuses `render_showcase.py` composition helpers and writes input checksums/export metadata to the creative directory’s `manifest.json`. No new capture, app change or App Store upload is performed by this feature.
