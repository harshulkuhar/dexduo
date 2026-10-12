# Exploratory visual recognition benchmark

`benchmark-report.json` records the actual source-model/Core ML comparison and all predictions. This evaluates visual appearance only; OCR is not part of recognition.

## Results

- 60 Pokémon images: 46 top-one correct (76.7%), 48 top-three correct (80%).
- 40 clean official artworks: 40 top-one correct.
- 12 full real card photographs: 2 top-one and 3 top-three correct.
- 5 mixed public reference images: 4 top-one correct.
- 3 user app screenshots: 0 top-one and 1 top-three correct.
- At probability >=0.90 and top-two margin >=0.20: 42 automatic lookups, all correct; zero automatic lookups on 30 CIFAR10 negative images.
- 30 identical PyTorch/Core ML inputs: all top-one predictions match; maximum probability difference 0.00118443 (required <=0.01).
- On this Mac: model load 2.39s, first prediction 1.72s, warm median prediction 0.0229s. This is not an iPhone performance measurement.

The converted package is approximately 176 MB (168 MiB). Transformer linear layers use FP16; attention, normalization and the final classifier retain FP32 to pass the numerical parity gate. Full FP16 had a top-one disagreement on a near-tied low-confidence card image.

## Limits

This is a small exploratory set, with unknown overlap with upstream training. Clean artwork dominates the successful automatic lookups. The real-card subset contains several photos of the same species; the three app screenshots contain only Pikachu and Espeon. CIFAR10 negatives are small 32x32 photos and cannot establish broad rejection of real camera backgrounds. These results do not certify accuracy across all species or real-world scenes.

Full-scene screenshots and full card photos are currently difficult; the Pokémon should occupy most of the input. Automatic lookup is enabled because the requested sample gate passed, not because scores are calibrated confidence. Uncertain images require confirmation or report no match. Separate forms and multiple-Pokémon detection are not supported.

## Reproduce

Raw images are in ignored `Evaluation/Images/`. `fixtures.json` contains labels, provenance and checksums. Public examples can be fetched with `python Tools/download_evaluation.py`; the three user-provided screenshots must already be present or be supplied locally. For a fresh independent benchmark, create a manifest with your own images and ground truth using the same row schema.

After installing `Tools/model-requirements.txt` and downloading the pinned source checkpoint, run:

```sh
python Tools/benchmark_model.py --model-dir Pokedex/Models --source .model-cache/source --fixtures Evaluation/fixtures.json --report Evaluation/benchmark-report.json
```

The script requires at least 60 positive and 30 negative images, checks parity on every third input (at least 30), and disables automatic lookup if no tested threshold passes >=95% automatic accuracy with zero negative automatic lookups. It requires at least five positive automatic lookups to avoid an empty-set pass. It updates `ModelManifest.json` only after conversion parity passes.

Physical iPhone cold/warm latency, memory, camera permissions/capture, and actual foldable hardware behavior remain to be measured. The Simulator runs the model on CPU because this Duo runtime's GPU backend produced incompatible MPSGraph errors and zero logits during validation.
