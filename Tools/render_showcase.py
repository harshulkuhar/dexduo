#!/usr/bin/env python3
"""Compose original App Store posters around genuine, unaltered Simulator UI captures (Pillow)."""
import argparse
import hashlib
import json
import pathlib
import sys
import PIL
from PIL import Image, ImageDraw, ImageFont

SCENES = [
    ('01-open', 'Open your\nDexDuo.', 'Search a name.\nExplore its entry.', 'SEARCH & ENTRIES'),
    ('02-recognition', 'Recognize\nwhat you see.', 'Import a picture.\nChoose a match.', 'ON-DEVICE RECOGNITION'),
    ('03-speech', 'Let your\nDex speak.', 'Robotic spoken entries.\nA lens that follows the voice.', 'SPOKEN ENTRIES'),
    ('04-evolution', 'Follow the\nevolution.', 'Every branch.\nIts own requirement.', 'EVOLUTION FAMILIES'),
    ('05-matchup', 'Know the\nmatchup.', 'See type weaknesses,\nresistances and immunities.', 'TYPE-ONLY DAMAGE'),
    ('06-cover', 'Made to\nunfold.', 'Cover outside.\nA whole Dex inside.', 'COVER & INTERIOR'),
]
FONT = '/System/Library/Fonts/Helvetica.ttc'


def font(size, bold=False):
    return ImageFont.truetype(FONT, round(size), index=1 if bold else 0)


def background(size):
    width, height = size
    image = Image.new('RGB', size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / height
        draw.line((0, y, width, y), fill=(round(9 + 12*t), round(15 - 4*t), round(21 - 4*t)))
    return image


def text(draw, xy, copy, size, bold=False, color='#F6F4E9', spacing=None):
    face = font(size, bold)
    draw.multiline_text(xy, copy, font=face, fill=color, spacing=round(spacing if spacing is not None else size*.1))


def load(path):
    # simctl outputs pixels already in display orientation; do not apply XCTest EXIF transforms.
    with Image.open(path) as image:
        return image.convert('RGB')


def hardware(canvas, capture, xy, width, duo=False):
    height = round(width * capture.height / capture.width)
    border = max(10, round(width*.018))
    x, y = map(round, xy)
    radius = round(min(width, height)*.075)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x-border-3, y-border-3, x+width+border+3, y+height+border+3), radius+border, fill='#55595D')
    draw.rounded_rectangle((x-border, y-border, x+width+border, y+height+border), radius+border, fill='#080A0C')
    shot = capture.resize((round(width), height), Image.Resampling.LANCZOS)
    mask = Image.new('L', shot.size); ImageDraw.Draw(mask).rounded_rectangle((0,0,shot.width-1,shot.height-1), radius, fill=255)
    canvas.paste(shot, (x,y), mask)
    if duo:
        center = x + width//2
        for edge in [y-border, y+height]:
            draw.line((center, edge, center, edge+border), fill='#55595D', width=max(2,border//6))


def poster(kind, scene, raw):
    key, title, subtitle, label = scene
    duo = kind == 'duo'
    canvas = background((2007,2853) if duo else (1206,2622))
    draw = ImageDraw.Draw(canvas)
    margin = 130 if duo else 90
    scale = 1.65 if duo else 1
    text(draw,(margin,105*scale),'DEXDUO',23*scale,True,color='#77DBE9')
    if not duo and key=='06-cover':
        title,subtitle,label='Made for\nlandscape.','Your familiar Dex.\nRoom to explore.','LANDSCAPE IPHONE'
    text(draw,(margin,210*scale),title,108*scale,True,spacing=0)
    text(draw,(margin,485*scale),subtitle,35*scale,color='#BFC7CC',spacing=13*scale)
    if duo and key=='06-cover':
        hardware(canvas,load(raw/'06-cover.png'),(160,1070),640)
        hardware(canvas,load(raw/'06-interior.png'),(470,1640),1390,True)
    else:
        shot=load(raw/(key+'.png'))
        width=1747 if duo else 1060
        y=1140 if duo else 870
        hardware(canvas,shot,(margin if duo else 73,y),width,duo)
        if not duo:
            if key=='06-cover':
                text(draw,(margin,1500),'OPEN TO EXPLORE',23,True,color='#77DBE9')
                hardware(canvas,load(raw/'01-open.png'),(73,1640),1060)
            else:
                # A separately framed, clearly labelled close-up of the same genuine capture.
                text(draw,(margin,1510),'A CLOSER LOOK',23,True,color='#77DBE9')
                crop=shot.crop((round(shot.width*.51),round(shot.height*.15),round(shot.width*.925),round(shot.height*.925)))
                crop.thumbnail((1000,720),Image.Resampling.LANCZOS)
                hardware(canvas,crop,((canvas.width-crop.width)//2,1640),crop.width)
    footer_y=2690 if duo else 2460
    text(draw,(margin,footer_y),label,25*scale,True,color='#77DBE9')
    note='Entry data needs internet when uncached.' if key=='02-recognition' else ('Unofficial fan project.' if key=='01-open' else 'Captured in Simulator.')
    text(draw,(margin,footer_y+65),note,22*scale,color='#89949C')
    return canvas


def landscape(scene, raw):
    key,title,subtitle,label=scene
    canvas=background((2622,1206)); draw=ImageDraw.Draw(canvas)
    if key=='06-cover': title,subtitle='Made for\nlandscape.','Your familiar Dex.\nRoom to explore.'
    text(draw,(90,95),'DEXDUO',27,True,color='#77DBE9')
    text(draw,(90,230),title,91,True,spacing=0)
    text(draw,(90,490),subtitle,31,color='#BFC7CC',spacing=12)
    text(draw,(90,1010),label if key!='06-cover' else 'LANDSCAPE IPHONE',22,True,color='#77DBE9')
    shot=load(raw/(key+'.png'))
    hardware(canvas,shot,(840,240),1680)
    return canvas


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw',type=pathlib.Path,required=True,help='Directory containing iphone/ and duo/ captures')
    parser.add_argument('--output',type=pathlib.Path,required=True)
    args=parser.parse_args(); repo=pathlib.Path(__file__).resolve().parents[1]
    output=args.output.resolve()
    if output==repo or repo in output.parents: parser.error('Exports must be outside Git.')
    output.mkdir(parents=True,exist_ok=True)
    manifest={'renderer':{'python':sys.version.split()[0],'pillow':PIL.__version__,'font_sha256':hashlib.sha256(pathlib.Path(FONT).read_bytes()).hexdigest()},'source':'Genuine iPhone 18 Pro / Duo Simulator captures','dimensions_source':'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications','inputs':{},'exports':[]}
    for path in sorted(args.raw.glob('*/*.png')):
        manifest['inputs'][str(path.relative_to(args.raw))]=hashlib.sha256(path.read_bytes()).hexdigest()
    thumbnails=[]
    for kind in ['duo','iphone']:
        folder=output/kind;folder.mkdir(exist_ok=True)
        for scene in SCENES:
            image=poster(kind,scene,args.raw/kind)
            destination=folder/(scene[0]+'.png');image.save(destination)
            manifest['exports'].append({'path':str(destination.relative_to(output)),'size':image.size,'mode':image.mode})
            thumb=image.copy();thumb.thumbnail((320,470));thumbnails.append((kind,scene[0],thumb))
    # Large-display submission canvas; preserve the genuine 18 Pro UI's aspect ratio.
    folder=output/'iphone-large';folder.mkdir(exist_ok=True)
    for scene in SCENES:
        source=poster('iphone',scene,args.raw/'iphone')
        image=background((1260,2736))
        factor=min(image.width/source.width,image.height/source.height)
        source=source.resize((round(source.width*factor),round(source.height*factor)),Image.Resampling.LANCZOS)
        image.paste(source,((image.width-source.width)//2,(image.height-source.height)//2))
        destination=folder/(scene[0]+'.png');image.save(destination)
        manifest['exports'].append({'path':str(destination.relative_to(output)),'size':image.size,'mode':image.mode})
    folder=output/'iphone-landscape';folder.mkdir(exist_ok=True)
    for scene in SCENES:
        image=landscape(scene,args.raw/'iphone');destination=folder/(scene[0]+'.png');image.save(destination)
        manifest['exports'].append({'path':str(destination.relative_to(output)),'size':image.size,'mode':image.mode})
    outer=output/'duo-outer';outer.mkdir(exist_ok=True)
    image=load(args.raw/'duo/06-cover.png')
    if image.size != (1398,2034): raise SystemExit('Expected native Duo outer display 1398×2034, without resizing.')
    image.save(outer/'06-cover.png')
    manifest['exports'].append({'path':'duo-outer/06-cover.png','size':image.size,'mode':image.mode})
    sheet=background((1920,1080));draw=ImageDraw.Draw(sheet)
    for index,(kind,key,thumb) in enumerate(thumbnails):
        x=(index%6)*320+(320-thumb.width)//2;y=(index//6)*540+45
        sheet.paste(thumb,(x,y));text(draw,(index%6*320+12,(index//6)*540+12),kind+' · '+key,16)
    sheet.save(output/'contact-sheet.png')
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Exported {len(manifest["exports"])} RGB PNGs and contact sheet to {output}')


if __name__=='__main__':main()
