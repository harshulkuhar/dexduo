"""Reproducible, pinned export. Run with Tools/model-requirements.txt installed."""
import argparse, hashlib, json, platform, subprocess, urllib.request, urllib.error
from pathlib import Path

MODEL_ID = "skshmjn/Pokemon-classifier-gen9-1025"
REVISION = "9e8d54de136b99afc212322eae13ddc07a6fd779"

EXPECTED_SOURCE_SHA256 = {'model.safetensors': '2da26f20523f4f09a74e277fb5d0a336fddf8b53f5b8eaefc7f8f063d9d0699a', 'config.json': '3a9be67d93a5cc307742eeb63ca85753ba1622ca1c54588dbef345a9c2dcdc0f', 'README.md': '362b9acc268fe53298b43c748fd311c08922d000905aaa4b2857a3ac89ebbb23', 'preprocessor_config.json': 'a34861a24e781942424ad790b82bc99348404a2e64ea882de88c40905851698d'}

def fetch(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pokedex-duo/1.0"}), timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError:
        # Some API/CDN configurations reject Python user agents but serve curl.
        response = subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--max-time", "120", url],
                                  check=True, capture_output=True)
        return json.loads(response.stdout)

def normalize(value):
    import unicodedata
    value = value.lower().replace("♀", "f").replace("♂", "m")
    return "".join(c for c in unicodedata.normalize("NFKD", value) if c.isalnum())

def main():
    import coremltools as ct
    import numpy as np
    import torch
    import transformers
    from huggingface_hub import snapshot_download
    from transformers import ViTForImageClassification
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--source", type=Path, help="Already-downloaded pinned source files")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.source or Path(snapshot_download(MODEL_ID, revision=REVISION, cache_dir=str(args.cache),
                                  allow_patterns=["config.json", "preprocessor_config.json", "model.safetensors", "README.md"]))
    for filename, expected in EXPECTED_SOURCE_SHA256.items():
        assert hashlib.sha256((source / filename).read_bytes()).hexdigest() == expected, "Pinned source checksum mismatch: " + filename
    config = json.loads((source / "config.json").read_text())
    def index(file, url):
        return json.loads((source / file).read_text()) if (source / file).exists() else fetch(url)
    species = index("species-index.json", "https://pokeapi.co/api/v2/pokemon-species?limit=2000")["results"]
    pokemon = index("pokemon-index.json", "https://pokeapi.co/api/v2/pokemon?limit=2000")["results"]
    by_id = {int(p["url"].rstrip("/").split("/")[-1]): p["name"] for p in pokemon}
    species_by_id = {int(p["url"].rstrip("/").split("/")[-1]): p["name"] for p in species}
    labels = []
    for i in range(1025):
        name = config["id2label"][str(i)]
        assert normalize(name) == normalize(species_by_id[i+1]), (i, name, species_by_id[i+1])
        labels.append(dict(index=i, speciesID=i+1, name=name, apiName=by_id[i+1]))
    (args.output / "PokemonLabels.json").write_text(json.dumps(labels, indent=2, ensure_ascii=False)+"\n")
    torch.set_num_threads(4)
    model = ViTForImageClassification.from_pretrained(str(source), attn_implementation="eager").eval()
    class Logits(torch.nn.Module):
        def __init__(self, backbone):
            super().__init__(); self.backbone = backbone
        def forward(self, image):
            return self.backbone(pixel_values=image).logits
    wrapper = Logits(model).eval()
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, torch.zeros(1, 3, 224, 224), strict=False)
    converted = ct.convert(traced, convert_to="mlprogram", minimum_deployment_target=ct.target.iOS17,
                           # Pinned trace names: linear_72 is the final classifier.
                           # FP32 attention/norm and classifier resolve near-tie parity failures.
                           compute_precision=ct.transform.FP16ComputePrecision(op_selector=lambda op:
                               op.op_type == "linear" and op.name != "linear_72"),
                           inputs=[ct.ImageType(name="image", shape=(1,3,224,224), scale=1/127.5, bias=[-1,-1,-1])],
                           outputs=[ct.TensorType(name="logits")])
    converted.author = "skshmjn; Core ML conversion by Pokédex Duo"
    converted.license = "Apache-2.0 (upstream model card)"
    converted.short_description = "1,025-species Generation 9 Pokémon classifier. Scores are not calibrated confidence."
    converted.user_defined_metadata["source_revision"] = REVISION
    converted.save(str(args.output / "PokemonClassifier.mlpackage"))
    checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.iterdir() if p.is_file()}
    manifest = dict(source=MODEL_ID, revision=REVISION, license="Apache-2.0", sourceChecksums=checksums,
                    conversion=dict(torch=torch.__version__, transformers=transformers.__version__, coremltools=ct.__version__,
                                    python=platform.python_version(), precision="FP16 transformer linear weights/compute; FP32 attention, normalization and final classifier", minimumIOS="17.0"),
                    input=dict(width=224, height=224, resize="bilinear, stretch entire upright RGB image", scale=1/127.5, bias=[-1,-1,-1]),
                    labelCount=1025,
                    policy=dict(automaticLookupEnabled=False, minimumProbability=0.9, minimumMargin=0.2, candidateMinimumProbability=0.35,
                                reason="Disabled until representative card/photo/screenshot and negative benchmarks pass."))
    manifest["packageChecksums"] = {str(p.relative_to(args.output)):hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in (args.output / "PokemonClassifier.mlpackage").rglob("*") if p.is_file()}
    (args.output / "ModelManifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    print("Exported model and verified all 1,025 species/default-form mappings", flush=True)

if __name__ == "__main__": main()
