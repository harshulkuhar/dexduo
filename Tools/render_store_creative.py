#!/usr/bin/env python3
"""Render App Store header/search artwork from genuine Duo captures, outside Git."""
import argparse
import hashlib
import json
import pathlib
from PIL import Image, ImageDraw
from render_showcase import background, hardware, load, text


def compose(size, cover, interior, search=False):
    canvas = background(size)
    draw = ImageDraw.Draw(canvas)
    width, height = size
    scale = width / 3840
    if search:
        text(draw, (width*.07, height*.075), 'DexDuo', 236*scale, True)
        text(draw, (width*.07, height*.20), 'Your Pokémon companion.', 90*scale, color='#D1D8DD')
        text(draw, (width*.07, height*.255), 'Search · Scan · Listen', 64*scale, color='#77DBE9')
        hardware(canvas, cover, (width*.07, height*.37), round(width*.23))
        hardware(canvas, interior, (width*.31, height*.30), round(width*.62), duo=True)
    else:
        wide = width / height > 2
        text(draw, (width*.06, height*(.23 if wide else .22)), 'DexDuo', 236*scale, True)
        text(draw, (width*.06, height*(.47 if wide else .39)), 'Open a world\nof Pokémon.', 110*scale, color='#D1D8DD', spacing=18*scale)
        text(draw, (width*.06, height*(.76 if wide else .65)), 'Search · Scan · Listen', 56*scale, color='#77DBE9')
        hardware(canvas, cover, (width*.365, height*(.31 if wide else .33)), round(width*.16))
        hardware(canvas, interior, (width*.445, height*(.09 if wide else .17)), round(width*.495), duo=True)
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', type=pathlib.Path, required=True, help='Existing raw/duo capture directory')
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output == repo or repo in output.parents:
        parser.error('Keep marketing images outside the repository.')
    output.mkdir(parents=True, exist_ok=True)
    sources = [args.raw/'06-cover.png', args.raw/'01-open.png']
    cover, interior = [load(path) for path in sources]
    specs = [('header-3840x1646.png', (3840,1646), False),
             ('search-results-3840x2560.png', (3840,2560), True),
             ('universal-5244x2950.png', (5244,2950), False)]
    manifest = {'specifications':'https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications',
                'inputs':{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}, 'exports':[]}
    previews = []
    for name, size, search in specs:
        image = compose(size, cover, interior, search)
        assert image.mode == 'RGB' and image.size == size
        image.save(output/name)
        manifest['exports'].append({'path':name,'size':size,'mode':image.mode})
        thumbnail = image.copy(); thumbnail.thumbnail((900,600), Image.Resampling.LANCZOS)
        previews.append((name,thumbnail))
    sheet = background((1800,1280)); draw = ImageDraw.Draw(sheet)
    for (name,image), (x,y) in zip(previews, [(0,65),(900,65),(0,720)]):
        text(draw,(x+24,y-45),name,25,color='#77DBE9')
        sheet.paste(image,(x+(900-image.width)//2,y))
    text(draw,(970,820),'App Store creative assets',40,True)
    text(draw,(970,900),'Genuine Duo cover + interior.\nOpaque RGB PNGs.\nNo captured media committed.',28,color='#BFC7CC',spacing=14)
    sheet.save(output/'preview.png')
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Header, search results and universal PNGs exported to '+str(output))


if __name__ == '__main__': main()
