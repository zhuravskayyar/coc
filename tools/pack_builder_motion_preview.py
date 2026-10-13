"""Encode the real Godot construction/return capture as a compact MP4."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
    '-framerate', '30', '-i', str(ROOT / '.godot/builder_motion_preview/frame_%03d.png'),
    '-frames:v', '1080',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '21', '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart', str(ROOT / 'docs/builder-work-cycle.mp4')], check=True)
print('Builder work cycle MP4 encoded.')
