"""Assemble Blender-rendered RGBA frames into the builder's 8-way atlases."""
from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / '.godot/builder_animation_frames'
OUT = ROOT / 'assets/sprites/units'
metadata = json.loads((FRAMES / 'metadata.json').read_text(encoding='utf-8'))
diagnostics = json.loads((FRAMES / 'pose_diagnostics.json').read_text(encoding='utf-8'))
assert diagnostics['max_ik_target_error_m'] < .002
assert diagnostics['max_grip_error_m'] < .002
assert diagnostics['min_sole_height_m'] > -.002
assert diagnostics['run_flight_frames'] > 0
size = metadata['frame_size'][0]
for clip, info in metadata['clips'].items():
    assert info['fps'] >= 30 and abs(info['frames']/info['fps']-info['duration']) < .00001
    columns = info['columns']
    rows = info['rows_per_direction']
    sheet = Image.new('RGBA', (size*columns, size*metadata['directions']*rows))
    assert max(sheet.size) <= 8192, 'Atlas exceeds the supported texture size'
    for direction in range(metadata['directions']):
        hashes = set()
        for frame in range(info['frames']):
            im = Image.open(FRAMES / f'{clip}_{direction}_{frame:02d}.png').convert('RGBA')
            assert im.size == (size,size)
            assert im.getbbox() and all(0 < v < size for v in im.getbbox()), 'Pose is cropped by the camera'
            hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
            sheet.paste(im, ((frame%columns)*size, (direction*rows+frame//columns)*size))
        assert len(hashes) == info['frames'], f'{clip}/{direction} contains duplicate rendered frames'
    sheet.save(OUT / f'builder_{clip}_sheet.png', optimize=True)
(OUT / 'builder_animations.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
preview = Image.new('RGBA', (size*4, size*2), (48,54,63,255))
for column, clip in enumerate(metadata['clips']):
    for row, direction in enumerate((1,5)):
        frame = int(metadata['clips'][clip]['frames'] * (.60 if clip == 'hammer' else .33))
        im = Image.open(FRAMES / f'{clip}_{direction}_{frame:02d}.png').convert('RGBA')
        preview.alpha_composite(im, (column*size,row*size))
preview.save(ROOT / 'docs/builder-animation-poses.png')
print('Builder animation atlases packed: 30 unique frames/second, all eight views, no cropped poses.')
