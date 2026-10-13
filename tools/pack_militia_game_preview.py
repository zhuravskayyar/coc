"""Encode actual Godot captures at the same 30 FPS as their simulation steps."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
for folder, output in [('militia_game_preview','militia-training-30fps.mp4'),
                       ('militia_game_motion','militia-in-game-30fps.mp4')]:
    frames = ROOT / '.godot' / folder
    count = len(list(frames.glob('frame_*.png')))
    assert count > 0, f'Missing capture: {folder}'
    assert all((frames/f'frame_{i:04d}.png').exists() for i in range(count))
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','30',
                    '-i',str(frames/'frame_%04d.png'),'-frames:v',str(count),
                    '-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',
                    str(ROOT/'docs'/output)],check=True)
    print(f'{output}: {count} captured frames at 30 FPS')
