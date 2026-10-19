"""Generate the bundled chart offline; refresh sources only with an explicit Git revision."""
import argparse
import csv
import hashlib
import io
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Tools/TypeChartSources"
OUTPUT = ROOT / "DexDuo/Resources/TypeChart.json"
TYPE_ORDER = "normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy".split()


def generate():
    manifest = json.loads((SOURCES / "manifest.json").read_text())
    for name, source in manifest["files"].items():
        if hashlib.sha256((SOURCES / name).read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError(f"Source checksum mismatch: {name}")
    names = {row["id"]: row["identifier"] for row in csv.DictReader(io.StringIO((SOURCES / "types.csv").read_text()))}
    matrix = {}
    for row in csv.DictReader(io.StringIO((SOURCES / "type_efficacy.csv").read_text())):
        attacker, defender = names[row["damage_type_id"]], names[row["target_type_id"]]
        if attacker not in TYPE_ORDER or defender not in TYPE_ORDER:
            continue
        factor = int(row["damage_factor"])
        if factor not in (0, 50, 100, 200) or (attacker, defender) in matrix:
            raise ValueError("Invalid or duplicate damage relation")
        matrix[attacker, defender] = factor
    if len(matrix) != 18 * 18:
        raise ValueError("Expected all 324 modern standard-type relationships")
    return json.dumps({"schemaVersion": 1, "sourceRevision": manifest["revision"], "types": TYPE_ORDER,
                       "damageFactors": [[matrix[a, d] for d in TYPE_ORDER] for a in TYPE_ORDER]}, indent=2) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="Download a new pinned source snapshot")
    parser.add_argument("--revision", help="Full 40-character PokeAPI/pokeapi Git commit for --refresh")
    parser.add_argument("--check", action="store_true", help="Verify the committed output without changing it")
    args = parser.parse_args()
    if args.refresh:
        if args.check or not args.revision or len(args.revision) != 40 or any(c not in "0123456789abcdef" for c in args.revision):
            parser.error("--refresh requires a full lowercase Git SHA and cannot be combined with --check")
        files = {}
        payloads = {}
        paths = {"types.csv": "data/v2/csv/types.csv", "type_efficacy.csv": "data/v2/csv/type_efficacy.csv", "LICENSE.md": "LICENSE.md"}
        for name, path in paths.items():
            url = f"https://raw.githubusercontent.com/PokeAPI/pokeapi/{args.revision}/{path}"
            request = urllib.request.Request(url, headers={"User-Agent": "DexDuo-type-chart"})
            with urllib.request.urlopen(request, timeout=60) as response:
                payloads[name] = response.read()
            files[name] = {"url": url, "sha256": hashlib.sha256(payloads[name]).hexdigest()}
        SOURCES.mkdir(parents=True, exist_ok=True)
        for name, payload in payloads.items():
            (SOURCES / name).write_bytes(payload)
        (SOURCES / "manifest.json").write_text(json.dumps({"repository": "https://github.com/PokeAPI/pokeapi",
            "revision": args.revision, "retrievedAt": datetime.now(timezone.utc).isoformat(), "files": files}, indent=2) + "\n")
    elif args.revision:
        parser.error("--revision requires --refresh")
    output = generate()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != output:
            raise SystemExit("Bundled type chart differs from the pinned source snapshot")
        print("Verified all 324 bundled type relationships against pinned sources.")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(output)
        print("Generated TypeChart.json from pinned sources.")


if __name__ == "__main__":
    main()
