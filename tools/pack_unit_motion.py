"""Validate distinct real renders, losslessly crop and pack 8-direction atlases."""
from pathlib import Path
from io import BytesIO
import hashlib,json
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/sprites/units'


def save_png(im,path):
    buffer=BytesIO();im.save(buffer,format='PNG',compress_level=6)
    data=buffer.getvalue()
    with Image.open(BytesIO(data)) as check:check.verify()
    temporary=path.with_suffix('.packing')
    temporary.write_bytes(data)
    assert hashlib.sha256(temporary.read_bytes()).digest()==hashlib.sha256(data).digest()
    temporary.replace(path)


def pack(kind):
    folder=ROOT/'.godot/unit_motion'/kind
    metadata=json.loads((folder/'metadata.json').read_text())
    if kind=='archer':
        old=json.loads((OUT/'archer_animations.json').read_text())
        for key in ['weapon_attachments','bone_names']:
            metadata[key]=old[key]
    bounds=[];total=0
    for clip,info in metadata['clips'].items():
        assert info['fps']>=30
        assert abs(info['frames']/info['fps']-info['duration'])<1e-6
        for direction in range(8):
            hashes=set()
            for frame in range(info['frames']):
                with Image.open(folder/f'{clip}_{direction}_{frame:03d}.png') as source:
                    im=source.convert('RGBA');bbox=im.getchannel('A').getbbox()
                    assert bbox and min(bbox[:2])>0 and max(bbox[2:])<256,(kind,clip,direction,frame,'cropped pose')
                    bounds.append(bbox);hashes.add(hashlib.sha256(im.tobytes()).digest())
            assert len(hashes)==info['frames'],(kind,clip,direction,'duplicate rendered poses',len(hashes),info['frames'])
            total+=info['frames']
    x0=max(0,(min(b[0] for b in bounds)-2)//8*8);y0=max(0,(min(b[1] for b in bounds)-2)//8*8)
    x1=min(256,((max(b[2] for b in bounds)+9)//8)*8);y1=min(256,((max(b[3] for b in bounds)+9)//8)*8)
    crop=(x0,y0,x1,y1);width=x1-x0;height=y1-y0
    metadata['frame_size']=[width,height]
    metadata['ground_anchor']=[metadata['ground_anchor'][0]-x0,metadata['ground_anchor'][1]-y0]
    for clip,info in metadata['clips'].items():
        sheet=Image.new('RGBA',(width*info['columns'],height*info['rows_per_direction']*8))
        assert max(sheet.size)<=8192
        for direction in range(8):
            for frame in range(info['frames']):
                with Image.open(folder/f'{clip}_{direction}_{frame:03d}.png') as im:
                    sheet.paste(im.convert('RGBA').crop(crop),((frame%info['columns'])*width,(direction*info['rows_per_direction']+frame//info['columns'])*height))
        save_png(sheet,OUT/f'{kind}_{clip}_sheet.png')
        if 'muzzle_positions' in info:
            info['muzzle_positions']=[[[x-x0,y-y0] for x,y in row] for row in info['muzzle_positions']]
        if 'impact_positions' in info:info['impact_positions']=[[x-x0,y-y0] for x,y in info['impact_positions']]
        if clip in ['walk','run']:
            info['source_license']='CC0-1.0 / Quaternius Universal Animation Library'
            info['motion_reference']='Walk_Loop' if clip=='walk' else 'Jog_Fwd_Loop'
        if clip=='attack' and kind=='militia':info['release_frame']=18
    with Image.open(folder/'idle_1_000.png') as portrait:save_png(portrait.convert('RGBA'),OUT/f'{kind}_portrait.png')
    if kind=='archer':
        arrows=Image.new('RGBA',(256*8,256))
        for direction in range(8):
            with Image.open(folder/f'arrow_{direction}.png') as im:arrows.paste(im,(direction*256,0))
        save_png(arrows,OUT/'archer_arrow_sheet.png')
    (OUT/f'{kind}_animations.json').write_text(json.dumps(metadata,indent=2))
    # Front, side and game view key poses are actual source renders.
    try:font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)
    except OSError:font=ImageFont.load_default()
    review=Image.new('RGB',(256*6,284*4),(35,41,50));draw=ImageDraw.Draw(review)
    for row,(clip,info) in enumerate(metadata['clips'].items()):
        draw.text((12,row*284+5),f'{kind} / {clip} / {info["fps"]} FPS',font=font,fill=(242,235,219))
        for col,(direction,phase) in enumerate([(2,.0),(2,.35),(2,.6),(0,.35),(1,.35),(1,.6)]):
            with Image.open(folder/f'{clip}_{direction}_{int(info["frames"]*phase):03d}.png') as im:
                review.paste(im,(col*256,row*284+28),im)
    review.save(ROOT/f'docs/{kind}-motion-review.jpg',quality=92)
    print(kind,total,'unique real frames',metadata['frame_size'],flush=True)
    return total


if __name__=='__main__':
    import sys
    total=sum(pack(kind) for kind in (sys.argv[1:] or ['archer','militia','builder']))
    print('Packed total',total)
