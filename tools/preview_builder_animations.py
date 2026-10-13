"""Render review films/contact sheets from the actual, fully packed poses.

The normal-speed part contains 30 distinct source samples per second.
The explicitly labelled slow-motion part holds each sample for four frames.
"""
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / '.godot/builder_animation_frames'
OUT = ROOT / '.godot/builder_animation_video'
OUT.mkdir(exist_ok=True)
metadata = json.loads((FRAMES / 'metadata.json').read_text(encoding='utf-8'))
size = metadata['frame_size'][0]
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 16)
cache = {}
for clip in ('run','hammer'):
    for direction in (1,5):
        for index in range(metadata['clips'][clip]['frames']):
            cache[clip,direction,index] = Image.open(FRAMES / f'{clip}_{direction}_{index:02d}.png').convert('RGBA')

for index in range(360):
    slow = index >= 180
    tick = (index-180)//4 if slow else index
    canvas = Image.new('RGBA',(768,848),(44,51,62,255))
    draw = ImageDraw.Draw(canvas)
    draw.text((20,8),'Builder / 30 FPS / '+('0.25x slow motion' if slow else '1x normal speed'),font=font,fill='white')
    for column, clip in enumerate(('run','hammer')):
        for row, direction in enumerate((1,5)):
            frame = tick % metadata['clips'][clip]['frames']
            im = cache[clip,direction,frame].resize((384,384),Image.Resampling.LANCZOS)
            x, y = column*384, 54+row*396
            canvas.alpha_composite(im,(x,y))
            draw.text((x+14,y+4),clip.title()+' / '+('front' if row == 0 else 'back'),font=small,fill=(188,201,220))
    canvas.convert('RGB').save(OUT / f'frame_{index:03d}.png')

subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','30',
    '-i',str(OUT / 'frame_%03d.png'),'-frames:v','360','-c:v','libx264','-crf','18',
    '-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT / 'docs/builder-animations-30fps.mp4')],check=True)

for clip in ('run','hammer'):
    count = metadata['clips'][clip]['frames']
    phases = (0,.17,.33,.50,.67,.83) if clip == 'run' else (0,.25,.43,.60,.68,.85)
    canvas = Image.new('RGBA',(size*6,size*2+48),(44,51,62,255))
    draw = ImageDraw.Draw(canvas)
    for row,direction in enumerate((0,4)):
        for column,phase in enumerate(phases):
            frame = min(count-1,round(phase*count))
            im = Image.open(FRAMES / f'{clip}_{direction}_{frame:02d}.png').convert('RGBA')
            canvas.alpha_composite(im,(column*size,row*(size+24)))
            draw.text((column*size+8,row*(size+24)+size),f'{clip} {frame}/{count} dir {direction}',font=small,fill='white')
    canvas.convert('RGB').save(ROOT / f'docs/builder-{clip}-keyposes.jpg',quality=94)
print('Builder 30 FPS film and opposite-side key pose sheets encoded.')
