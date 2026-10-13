"""Pack the actual 30 FPS render and review motion from three cameras."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / '.godot/archer_animation_frames'
OUT = ROOT / 'assets/sprites/units'
DOCS = ROOT / 'docs'
REVIEW = ROOT / '.godot/archer_review_v2'
metadata = json.loads((FRAMES / 'metadata.json').read_text(encoding='utf-8'))
size = metadata['frame_size'][0]
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 16)
if '--review-only' not in sys.argv:
    total = 0
    for clip, info in metadata['clips'].items():
        assert info['fps'] >= 30
        assert abs(info['frames'] / info['fps'] - info['duration']) < .00001
        columns, rows = info['columns'], info['rows_per_direction']
        sheet = Image.new('RGBA', (size * columns, size * rows * 8))
        assert max(sheet.size) <= 8192
        for direction in range(8):
            hashes = set()
            for index in range(info['frames']):
                # Correct light at source; preserve the rendered texture's colors.
                frame = Image.open(FRAMES / f'{clip}_{direction}_{index:02d}.png').convert('RGBA')
                bounds = frame.getbbox()
                assert bounds and min(bounds[:2]) > 0 and max(bounds[2:]) < size, f'Cropped frame: {clip}/{direction}/{index}'
                hashes.add(hashlib.sha256(frame.tobytes()).hexdigest())
                sheet.paste(frame, ((index % columns) * size, (direction * rows + index // columns) * size))
            assert len(hashes) == info['frames'], f'Duplicate frame: {clip}/{direction}'
        sheet.save(OUT / f'archer_{clip}_sheet.png', optimize=True)
        total += info['frames'] * 8
    (OUT / 'archer_animations.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    Image.open(FRAMES / 'idle_1_00.png').save(OUT / 'archer_portrait.png')
    # The existing projectile sheet and its flight metadata remain intact.
    idle_sheet = Image.new('RGBA', (size * 8, size + 28), (43, 51, 62, 255))
    idle_draw = ImageDraw.Draw(idle_sheet)
    for direction, label in enumerate(metadata['direction_order'].split(', ')):
        idle_sheet.alpha_composite(Image.open(FRAMES / f'idle_{direction}_00.png').convert('RGBA'), (direction * size, 0))
        idle_draw.text((direction * size + 8, size), f'Idle / {label}', font=font, fill='white')
    idle_sheet.convert('RGB').save(DOCS / 'archer-idle-keyposes.jpg', quality=94)
    # Show the carried weapon and the release visibility in actual game frames.
    states = [('Idle', 'idle', 0), ('Walk', 'walk', 10), ('Run', 'run', 14),
              ('Full draw', 'attack', 13), ('Release', 'attack', 15), ('Recovery', 'attack', 25)]
    state_sheet = Image.new('RGBA', (size * len(states), size + 28), (43, 51, 62, 255))
    state_draw = ImageDraw.Draw(state_sheet)
    for column, (label, clip, index) in enumerate(states):
        state_sheet.alpha_composite(Image.open(FRAMES / f'{clip}_1_{index:02d}.png').convert('RGBA'), (column * size, 0))
        state_draw.text((column * size + 8, size), label, font=font, fill='white')
    state_sheet.convert('RGB').save(DOCS / 'archer-arrow-visibility.jpg', quality=94)
if '--atlases-only' in sys.argv:
    print('Packed game atlases and metadata.')
    raise SystemExit(0)

cache = {}
for clip in ('walk', 'run', 'attack'):
    views = ('front', 'side', 'game1', 'game5') if clip == 'attack' else ('front', 'side', 'game1')
    for view in views:
        paths = [REVIEW / f'{clip}_{view}_{i:03d}.png' for i in range(metadata['clips'][clip]['frames'] * 2)]
        frames = [Image.open(path).convert('RGBA') for path in paths]
        assert all(a.tobytes() != b.tobytes() for a, b in zip(frames, frames[1:])), f'Repeated slow frame: {clip}/{view}'
        cache[clip, view] = frames

for clip in ('walk', 'run'):
    count = metadata['clips'][clip]['frames']
    canvas = Image.new('RGBA', (size * 8, 3 * (size + 28)), (43, 51, 62, 255))
    draw = ImageDraw.Draw(canvas)
    for row, view in enumerate(('front', 'side', 'game1')):
        for col in range(8):
            index = round(count * 2 * col / 8)
            canvas.alpha_composite(cache[clip, view][index], (col * size, row * (size + 28)))
            draw.text((col * size + 8, row * (size + 28) + size), f'{view} / {col * 12.5:g}%', font=font, fill='white')
    canvas.convert('RGB').save(DOCS / f'archer-{clip}-keyposes.jpg', quality=94)

phases = [('ready', 0), ('aim', 5), ('draw', 9), ('full draw', 13), ('release', 15), ('follow', 18), ('recovery', 25)]
canvas = Image.new('RGBA', (size * 7, 2 * (size + 28)), (43, 51, 62, 255))
draw = ImageDraw.Draw(canvas)
for row, view in enumerate(('game1', 'game5')):
    for col, (label, frame) in enumerate(phases):
        canvas.alpha_composite(cache['attack', view][frame * 2], (col * size, row * (size + 28)))
        draw.text((col * size + 8, row * (size + 28) + size), f'{view} / {label} / {frame}', font=font, fill='white')
canvas.convert('RGB').save(DOCS / 'archer-attack-keyposes.jpg', quality=94)

video_dir = ROOT / '.godot/archer_animation_video_v2'
video_dir.mkdir(exist_ok=True)
for index in range(360):
    slow = index >= 180
    timeline_index = index - 180 if slow else index
    canvas = Image.new('RGBA', (1152, 900), (43, 51, 62, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 12), 'Archer / 30 FPS / ' + ('0.5x, interpolated poses' if slow else 'normal speed'), font=font, fill='white')
    for col, clip in enumerate(('walk', 'run', 'attack')):
        for row, view in enumerate(('front', 'side', 'game1')):
            frames = cache[clip, view]
            source_index = round(timeline_index * metadata['clips'][clip]['fps'] / 30 * (1 if slow else 2))
            frame = frames[source_index % len(frames)]
            x, y = col * 384 + 64, row * 278 + 40
            canvas.alpha_composite(frame, (x, y))
            draw.text((col * 384 + 18, y + size), f'{clip.title()} / {view}', font=font, fill='white')
    canvas.convert('RGB').save(video_dir / f'frame_{index:03d}.png')
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '30',
                '-i', str(video_dir / 'frame_%03d.png'), '-frames:v', '360', '-c:v', 'libx264',
                '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                str(DOCS / 'archer-animations-30fps.mp4')], check=True)
print('Verified distinct game/slow poses; 30 FPS review includes true 0.5x interpolation.')
