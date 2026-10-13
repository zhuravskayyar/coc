"""Render front, side and gameplay views at twice each game clip's pose rate."""
from pathlib import Path
from mathutils import Vector
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.godot/archer_review_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'assets/units/archer/archer_animated.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['ArcherRig']
root = bpy.data.objects['Archer']
arrow = bpy.data.objects['HeldArrow']
bow_keys = bpy.data.objects['Bow'].data.shape_keys
camera = scene.camera
game_position, game_rotation = camera.location.copy(), camera.rotation_euler.copy()
target = Vector((0, -.03, .49))
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
for clip in ('Walk', 'Run', 'Attack'):
    if '--run-only' in sys.argv and clip != 'Run':
        continue
    action = bpy.data.actions['archer_shoot' if clip == 'Attack' else clip]
    rig.animation_data.action = action
    rig.animation_data.action_slot = next(slot for slot in action.slots if slot.target_id_type == 'OBJECT')
    bow_keys.animation_data.action = action
    bow_keys.animation_data.action_slot = next(slot for slot in action.slots if slot.target_id_type == 'KEY')
    arrow.animation_data.action = bpy.data.actions['HeldArrow ' + clip]
    count = round(action.frame_range.y - action.frame_range.x)
    samples_per_frame = 4 if clip == 'Run' else 2
    views = ('front', 'side', 'game1', 'game5') if clip == 'Attack' else ('front', 'side', 'game1')
    for view in views:
        root.rotation_euler.z = 0
        if view.startswith('game'):
            camera.location, camera.rotation_euler = game_position, game_rotation
            root.rotation_euler.z = root['direction_yaws'][int(view[-1])]
        else:
            camera.location = target + Vector((0, -4, 0) if view == 'front' else (4, 0, 0))
            camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        for index in range(count * samples_per_frame):
            source_frame = 1 + index / samples_per_frame
            scene.frame_set(int(source_frame), subframe=source_frame % 1)
            scene.render.filepath = str(OUT / f'{clip.lower()}_{view}_{index:03d}.png')
            bpy.ops.render.render(write_still=True)
        print('ARCHER_REVIEW_VIEW', clip, view, flush=True)
print('ARCHER_SLOW_REVIEW_COMPLETE', flush=True)
