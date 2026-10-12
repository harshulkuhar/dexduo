"""Fetch pinned public benchmark inputs; local screenshots must be supplied separately."""
import argparse, concurrent.futures, hashlib, json, subprocess, urllib.request
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--fixtures',type=Path,default=Path('Evaluation/fixtures.json'))
args=parser.parse_args(); rows=json.loads(args.fixtures.read_text())
cifar=None
if any(r['source'].startswith('hf://uoft-cs/cifar10') and not (args.fixtures.parent/r['file']).exists() for r in rows):
    with urllib.request.urlopen('https://datasets-server.huggingface.co/rows?dataset=uoft-cs%2Fcifar10&config=plain_text&split=test&offset=0&length=30') as response:
        cifar={r['row_idx']:r['row']['img']['src'] for r in json.load(response)['rows']}
def download(row):
    file=args.fixtures.parent/row['file']; file.parent.mkdir(parents=True,exist_ok=True)
    if not file.exists():
        source=row['source']
        if source.startswith('hf://'): source=cifar[int(source.rsplit('/',1)[1])]
        if not source.startswith('https://'):
            raise RuntimeError(f'{file}: supply the corresponding local screenshot or create your own labeled fixture manifest')
        subprocess.run(['curl','--fail','--location','--retry','3','--max-time','120',source,'--output',str(file)],check=True,capture_output=True)
    if hashlib.sha256(file.read_bytes()).hexdigest()!=row['sha256']:
        raise RuntimeError(f'Checksum mismatch: {file}; do not silently change benchmark inputs')
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool: list(pool.map(download,rows))
print('Verified',len(rows),'benchmark inputs')
