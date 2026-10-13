"""Export bone and bowstring action slots from the saved archer source.

Blender --background --python-exit-code 1 --python tools/export_archer.py
No rendering or pose changes are performed, and the .blend is not saved.
"""
from pathlib import Path
import argparse
import sys

import bpy


ROOT = Path(__file__).resolve().parents[1]
CLIPS = ('Idle', 'Walk', 'Run', 'archer_shoot')


def export_archer(output):
    rig = bpy.data.objects['ArcherRig']
    bow = bpy.data.objects['Bow']
    keys = bow.data.shape_keys
    arrow = bpy.data.objects['HeldArrow']
    root = bpy.data.objects['Archer']
    root.rotation_euler.z = 0
    # ACTIONS evaluates the explicit OBJECT/KEY slot before sampling. The
    # Blender 5.2 NLA_TRACKS path currently emits a zero-only shape sampler.
    # Matching track names merge the correctly sampled slots into four clips.
    for owner, slot_type in ((rig, 'OBJECT'), (keys, 'KEY'), (arrow, 'OBJECT')):
        animation = owner.animation_data_create()
        animation.action = None
        animation.use_nla = True
        for old_track in list(animation.nla_tracks):
            animation.nla_tracks.remove(old_track)
        for name in CLIPS:
            action_name = 'HeldArrow ' + ('Attack' if name == 'archer_shoot' else name) if owner == arrow else name
            action = bpy.data.actions[action_name]
            track = animation.nla_tracks.new()
            track.name = name
            strip = track.strips.new(name, 1, action)
            strip.action_slot = next(slot for slot in action.slots if slot.target_id_type == slot_type)
        # Tracks name the clips for export; they must not all evaluate over the resting pose.
        animation.use_nla = False
    arrow.scale = (.0001, .0001, .0001)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (root, rig, bow, bpy.data.objects['HeldArrow'],
                bpy.data.objects['LeftHandAttachment'], bpy.data.objects['RightHandAttachment'],
                bpy.data.objects['BowOffset'], bpy.data.objects['ArrowOffset'],
                bpy.data.objects['BowMuzzle'], bpy.data.objects['ArrowNock'], bpy.data.objects['ArrowTip']):
        obj.select_set(True)
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and any(mod.type == 'ARMATURE' and mod.object == rig for mod in obj.modifiers):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
                             export_animations=True, export_skins=True,
                             export_animation_mode='ACTIONS', export_merge_animation='NLA_TRACK',
                             export_anim_single_armature=False,
                             export_anim_slide_to_zero=True, export_extras=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--blend', type=Path, default=ROOT / 'assets/units/archer/archer_animated.blend')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/units/archer/archer_animated.glb')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    bpy.ops.wm.open_mainfile(filepath=str(args.blend))
    export_archer(args.output)
    print('ARCHER_EXPORT_COMPLETE', str(args.output), flush=True)
