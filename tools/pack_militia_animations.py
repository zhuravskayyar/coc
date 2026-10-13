"""Pack the exact 30 FPS source samples and encode a multi-angle review film."""
from pathlib import Path
import json, hashlib, argparse, subprocess
from PIL import Image, ImageDraw, ImageFont
from unit_sprite_grade import grade_vibrant

ROOT=Path(__file__).resolve().parents[1]
FRAMES=ROOT/'.godot/militia_animation_frames'
OUT=ROOT/'assets/sprites/units'
metadata=json.loads((FRAMES/'metadata.json').read_text(encoding='utf-8'))
parser=argparse.ArgumentParser()
parser.add_argument('--review',action='store_true')
args=parser.parse_args()
size=metadata['frame_size'][0]
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
for clip,info in metadata['clips'].items():
    keys=sorted({int(info['frames']*p) for p in (0,.17,.30,.48,.67,.83)})
    canvas=Image.new('RGBA',(size*6,(size+24)*3),(43,51,62,255))
    draw=ImageDraw.Draw(canvas)
    for row,direction in enumerate((1,3,5)):
        for col,index in enumerate(keys):
            im=grade_vibrant(Image.open(FRAMES/f'{clip}_{direction}_{index:02d}.png'),saturation=1.15,contrast=1.08,brightness=1.02,accent_hues=(130,195),accent_saturation=1.75)
            canvas.alpha_composite(im,(col*size,row*(size+24)))
            draw.text((col*size+8,row*(size+24)+size),f'{clip} / view {direction} / pose {index}',font=font,fill='white')
    canvas.convert('RGB').save(ROOT/f'docs/militia-{clip}-keyposes.jpg',quality=94)
if args.review:
    print('Key pose review sheets produced.')
    raise SystemExit()

cache={}
for clip,info in metadata['clips'].items():
    assert info['fps']>=30
    assert abs(info['frames']/info['fps']-info['duration'])<.00001
    columns,rows=info['columns'],info['rows_per_direction']
    sheet=Image.new('RGBA',(size*columns,size*rows*8))
    assert max(sheet.size)<=8192
    for direction in range(8):
        hashes=set()
        for index in range(info['frames']):
            im=grade_vibrant(Image.open(FRAMES/f'{clip}_{direction}_{index:02d}.png'),saturation=1.15,contrast=1.08,brightness=1.02,accent_hues=(130,195),accent_saturation=1.75)
            bounds=im.getbbox()
            assert bounds and all(0<v<size for v in bounds),f'Cropped {clip}/{direction}/{index}'
            hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
            sheet.paste(im,((index%columns)*size,(direction*rows+index//columns)*size))
            if direction in (1,3,5):
                cache[clip,direction,index]=im.resize((256,256),Image.Resampling.LANCZOS)
        assert len(hashes)==info['frames'],f'Duplicate frame: {clip}/{direction}'
    sheet.save(OUT/f'militia_{clip}_sheet.png',optimize=True)
(OUT/'militia_animations.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
# Portrait comes directly from the provided model's animated idle pose.
portrait=cache['idle',1,0]
portrait.save(OUT/'militia_portrait.png')
video_frames=ROOT/'.godot/militia_animation_video'
video_frames.mkdir(exist_ok=True)
for frame in range(360):
    slow=frame>=180
    seconds=(frame-180)/30*.25 if slow else frame/30
    canvas=Image.new('RGBA',(1024,900),(43,51,62,255))
    draw=ImageDraw.Draw(canvas)
    draw.text((16,12),'Militia / 30 FPS / '+('0.25x slow motion' if slow else '1x normal speed'),font=font,fill='white')
    for col,(clip,info) in enumerate(metadata['clips'].items()):
        index=int(seconds*info['fps'])%info['frames']
        for row,direction in enumerate((1,3,5)):
            x,y=col*256,55+row*278
            canvas.alpha_composite(cache[clip,direction,index],(x,y))
            draw.text((x+8,y+256),f'{clip.title()} / view {direction}',font=font,fill='white')
    canvas.convert('RGB').save(video_frames/f'frame_{frame:03d}.png')
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','30','-i',str(video_frames/'frame_%03d.png'),
                '-frames:v','360','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
                str(ROOT/'docs/militia-animations-30fps.mp4')],check=True)
print('Packed 1120 distinct game frames across 8 views; review video encoded at 30 FPS.')
