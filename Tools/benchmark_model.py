"""Evaluate local labeled fixtures and verify Core ML/PyTorch numerical parity."""
import argparse, hashlib, json, time
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps
import coremltools as ct
import torch
from transformers import ViTForImageClassification

def probabilities(logits):
    x = np.asarray(logits, dtype=np.float64).reshape(-1)
    weights = np.exp(x - x.max())
    return weights / weights.sum()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, required=True, help="JSON rows: file, expectedSpeciesID/null, kind, source, sha256")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    rows = json.loads(args.fixtures.read_text())
    assert len([r for r in rows if r['expectedSpeciesID'] is not None]) >= 60
    assert len([r for r in rows if r['expectedSpeciesID'] is None]) >= 30
    labels = json.loads((args.model_dir / "PokemonLabels.json").read_text())
    species = [r['speciesID'] for r in labels]
    torch.set_num_threads(4)
    reference = ViTForImageClassification.from_pretrained(str(args.source), attn_implementation="eager").eval()
    start = time.perf_counter()
    model = ct.models.MLModel(str(args.model_dir / "PokemonClassifier.mlpackage"))
    loading = time.perf_counter()-start
    results=[]; parity=[]
    for i, row in enumerate(rows):
        path=args.fixtures.parent / row['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], path
        # Match Hugging Face processor; normalize through Core ML ImageType metadata.
        image=ImageOps.exif_transpose(Image.open(path)).convert("RGB").resize((224,224),Image.Resampling.BILINEAR)
        start=time.perf_counter(); output=model.predict({"image":image})['logits']; duration=time.perf_counter()-start
        p=probabilities(output); order=np.argsort(-p)
        entry=dict(file=row['file'],kind=row['kind'],expectedSpeciesID=row['expectedSpeciesID'],
                   top3=[species[int(j)] for j in order[:3]],probability=float(p[order[0]]),
                   margin=float(p[order[0]]-p[order[1]]),seconds=duration)
        results.append(entry)
        if i % 3 == 0:
            pixels=(np.asarray(image,dtype=np.float32)/127.5-1).transpose(2,0,1)[None]
            with torch.no_grad(): expected=reference(pixel_values=torch.from_numpy(pixels)).logits.numpy()
            q=probabilities(expected)
            parity.append(dict(file=row['file'],top1Matches=int(p.argmax())==int(q.argmax()),maximumProbabilityDifference=float(np.max(np.abs(p-q)))))
        print(f"{i+1}/{len(rows)} {row['file']} -> {entry['top3'][0]} ({entry['probability']:.3f})",flush=True)
    assert len(parity)>=30
    parity_pass=all(p['top1Matches'] and p['maximumProbabilityDifference']<=0.01 for p in parity)
    positives=[r for r in results if r['expectedSpeciesID'] is not None]
    negatives=[r for r in results if r['expectedSpeciesID'] is None]
    def summarize(rows):
        return dict(count=len(rows),top1=sum(r['top3'][0]==r['expectedSpeciesID'] for r in rows),
                    top3=sum(r['expectedSpeciesID'] in r['top3'] for r in rows))
    def automatic(threshold,margin):
        chosen=[r for r in positives if r['probability']>=threshold and r['margin']>=margin]
        wrong=sum(r['top3'][0]!=r['expectedSpeciesID'] for r in chosen)
        false=sum(r['probability']>=threshold and r['margin']>=margin for r in negatives)
        return dict(minimumProbability=threshold,minimumMargin=margin,positiveLookups=len(chosen),wrongLookups=wrong,
                    accuracy=(len(chosen)-wrong)/len(chosen) if chosen else None,falseNegativeSetLookups=false,
                    passes=len(chosen)>=5 and wrong/len(chosen)<=0.05 and false==0)
    trials=[automatic(t,m) for t in [0.9,0.95,0.97,0.99,0.995,0.999] for m in [0.2,0.3,0.4,0.5]]
    passing=[t for t in trials if t['passes']]
    selected=max(passing,key=lambda t:(t['positiveLookups'],-t['minimumProbability'],-t['minimumMargin'])) if passing else trials[0]
    report=dict(conversionParity=dict(passed=parity_pass,inputs=len(parity),maximumProbabilityDifference=max(p['maximumProbabilityDifference'] for p in parity),results=parity),
                positives=summarize(positives),negatives=len(negatives),
                byKind={kind:summarize([r for r in positives if r['kind']==kind]) for kind in sorted(set(r['kind'] for r in positives))},
                automaticLookup=dict(enabled=bool(passing) and parity_pass,selected=selected,initial=trials[0],trials=trials),
                timings=dict(platform="Mac Core ML; not iPhone performance",modelLoadSeconds=loading,firstPredictionSeconds=results[0]['seconds'],
                             warmMedianSeconds=float(np.median([r['seconds'] for r in results[1:]]))),
                limitations=["Small exploratory benchmark, not an independent held-out accuracy certification.",
                             "Reference artwork may overlap upstream training data.",
                             "CIFAR10 negatives are only 32x32 and do not represent all real camera backgrounds.",
                             "Model scores are uncalibrated; no guaranteed Pokémon-presence detector.",
                             "Three app screenshots reuse two species; mixed public references are not all screenshots.",
                             "Physical iPhone latency, memory, camera capture and fold behavior require hardware testing."],
                results=results)
    args.report.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({k:v for k,v in report.items() if k not in ['results','conversionParity','automaticLookup']},indent=2),flush=True)
    if not parity_pass: raise SystemExit("Conversion parity failed. Do not integrate this export.")
    manifest_path=args.model_dir/'ModelManifest.json'; manifest=json.loads(manifest_path.read_text())
    manifest['policy'].update(automaticLookupEnabled=bool(passing), minimumProbability=selected['minimumProbability'], minimumMargin=selected['minimumMargin'],
                              reason="Passed exploratory 60-positive/30-negative benchmark." if passing else "Automatic lookup disabled: exploratory benchmark acceptance gate failed.")
    manifest['benchmarkReportSHA256']=hashlib.sha256(args.report.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest,indent=2)+"\n")
    print('parity passed; automatic lookup:',bool(passing),flush=True)

if __name__=='__main__': main()
