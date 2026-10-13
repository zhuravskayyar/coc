"""Render the existing Blender builder as a transparent village sprite.

blender --background --python tools/render_builder_sprite.py
The editable T-pose source is left intact. Only this render uses a relaxed pose.
"""
from pathlib import Path
from math import radians, atan, sqrt
import json
import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets' / 'units' / 'builder'
OUT = ROOT / 'assets' / 'sprites' / 'units'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ASSET / 'builder.blend'))
model = bpy.data.collections['BUILDER | editable character']

# Articulated source parts permit a static resting pose without adding a rig.
arm_names = ('short linen sleeve', 'rolled linen cuff', 'rolled sleeve crease',
    'upper arm', 'forearm', 'leather gauntlet', 'gauntlet cuff edging',
    'gloved palm', 'open finger', 'finger joint', 'open thumb',
    'gripping finger', 'glove knuckle', 'gripping thumb')
for side, sign in (('L', -1), ('R', 1)):
    pivot = Vector((sign*.76*.32, .01*.32, 4.29*.32))
    rot = Matrix.Translation(pivot) @ Matrix.Rotation(sign*radians(64), 4, 'Y') @ Matrix.Translation(-pivot)
    for obj in model.objects:
        if obj.type == 'MESH' and any(obj.name.startswith(f'{side} {name}') for name in arm_names):
            obj.matrix_world = rot @ obj.matrix_world
        if side == 'R' and obj.type == 'MESH' and obj.name.startswith('Hammer'):
            obj.matrix_world = rot @ obj.matrix_world

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.view_settings.exposure = -.25
floor = bpy.data.objects.get('Studio ground')
if floor:
    floor.hide_render = True

try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'
    prefs.get_devices()
    for dev in prefs.devices:
        dev.use = dev.type == 'OPTIX'
    scene.cycles.device = 'GPU'
except Exception:
    scene.cycles.device = 'CPU'

cam = scene.camera
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.38
target = Vector((0, 0, 1.06))
# Equal X/Y directions, elevation atan(0.75*sqrt(2)): the map's 96:72 diamond.
cam.location = target + Vector((4, -4, 6))
cam.rotation_euler = (target-cam.location).to_track_quat('-Z', 'Y').to_euler()
bpy.context.view_layer.update()
foot = world_to_camera_view(scene, cam, Vector((0, 0, 0)))
anchor = [round(foot.x*512, 3), round((1-foot.y)*512, 3)]
scene.render.filepath = str(OUT / 'builder_idle.png')
bpy.ops.render.render(write_still=True)
metadata = {'texture': 'res://assets/sprites/units/builder_idle.png',
    'size': [512, 512], 'ground_anchor': anchor,
    'camera_elevation_degrees': atan(.75*sqrt(2))*180/3.141592653589793,
    'pose': 'static resting pose', 'source': 'assets/units/builder/builder.blend'}
(OUT / 'builder_idle.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
print('BUILDER_SPRITE_COMPLETE', json.dumps(metadata))
