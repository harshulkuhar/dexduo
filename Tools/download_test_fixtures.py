"""Fetch local-only test images using the benchmark manifest's checksums."""
import hashlib, json, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = {Path(row["file"]).name: row for row in json.loads((root / "Evaluation/fixtures.json").read_text())}
for source, target in [("artwork-25.png", "pikachu.png"), ("artwork-196.png", "espeon.png"), ("card-5640.jpeg", "kadabra-card.jpeg")]:
    row = rows[source]
    destination = root / "Tests/Fixtures" / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--max-time", "120", row["source"], "--output", str(destination)], check=True)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != row["sha256"]:
        raise SystemExit(f"Checksum mismatch: {destination}")
print("Verified three local-only test images; Git ignores them.")
