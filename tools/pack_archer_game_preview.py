"""Encode actual map capture and a labelled crop from the same 30 FPS frames."""
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / '.godot/archer_game_preview_v2'
DETAIL = ROOT / '.godot/archer_game_detail_v2'
DOCS = ROOT / 'docs'
capture = json.loads((FOLDER / 'capture.json').read_text(encoding='utf-8'))
assert capture['fps'] >= 30 and capture['frame_count'] == len(capture['frames'])
assert len(capture['release_events']) == 2
assert all(capture['movement'][clip]['frames'] >= 3 * capture['fps'] for clip in ('walk', 'run'))
DETAIL.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 19)
rects = [frame['sprite_screen_rect'] for frame in capture['frames']]
left = min(r[0] for r in rects) - 20
top = min(r[1] for r in rects) - 20
right = max(r[0] + r[2] for r in rects) + 20
bottom = max(r[1] + r[3] for r in rects) + 20
width = max(240, int(right - left + 1))
height = max(180, int(bottom - top + 1))
width += width % 2
height += height % 2
cx, cy = (left + right) / 2, (top + bottom) / 2
box = (round(cx - width / 2), round(cy - height / 2), round(cx - width / 2) + width, round(cy - height / 2) + height)
assert box[0] >= 0 and box[1] >= 0 and box[2] <= capture['viewport_size'][0] and box[3] <= capture['viewport_size'][1]
for frame in capture['frames']:
    index = frame['index']
    image = Image.open(FOLDER / f'frame_{index:04d}.png').convert('RGB')
    crop = image.crop(box).resize((width * 4, height * 4), Image.Resampling.NEAREST)
    canvas = Image.new('RGB', (width * 4, height * 4 + 58), (24, 30, 37))
    canvas.paste(crop, (0, 58))
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 5), 'Actual gameplay / 30 FPS / 4x crop of original camera', font=font, fill='white')
    segment = next(s for s in capture['segments'] if s['first_frame'] <= index <= s['last_frame'])
    draw.text((12, 29), f"{segment['label']} / {index / capture['fps']:.2f}s", font=font, fill='white')
    canvas.save(DETAIL / f'frame_{index:04d}.png')

for folder, name in [(FOLDER, 'archer-in-game-30fps.mp4'), (DETAIL, 'archer-in-game-detail-30fps.mp4')]:
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', str(capture['fps']),
                    '-i', str(folder / 'frame_%04d.png'), '-frames:v', str(capture['frame_count']),
                    '-c:v', 'libx264', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                    str(DOCS / name)], check=True)
print(f"Encoded {capture['frame_count']} actual frames at {capture['fps']} FPS; camera {capture['camera_zoom']}; detail crop {box}.")
