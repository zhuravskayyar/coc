"""Verify the saved archer source without saving it or rendering images.

Blender --background --python-exit-code 1 --python tools/verify_archer_animation.py
The JSON records the actual skinned mesh, fixed contact vertices and weapon rig.
"""
from pathlib import Path
from math import degrees
import argparse
import json
import sys

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--blend', type=Path, default=ROOT / 'assets/units/archer/archer_animated.blend')
parser.add_argument('--output', type=Path, default=ROOT / '.godot/archer_source_verification.json')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
bpy.ops.wm.open_mainfile(filepath=str(args.blend))
scene = bpy.context.scene
rig = bpy.data.objects['ArcherRig']
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers))
bow = bpy.data.objects['Bow']
arrow = bpy.data.objects['HeldArrow']
bow_offset = bpy.data.objects['BowOffset']
attachment = bpy.data.objects['LeftHandAttachment']
keys = bow.data.shape_keys
grip = Vector((0, -.045, .0432625))
nock = bpy.data.objects['ArrowNock']
prefix = 'mixamorig:'
failures = []
report = {'blend': str(args.blend), 'fps': scene.render.fps, 'checks': {}, 'clips': {}}


def check(name, passed, details):
    report['checks'][name] = {'passed': bool(passed), **details}
    if not passed:
        failures.append(name)


def activate(name):
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = next(s for s in action.slots if s.target_id_type == 'OBJECT')
    keys.animation_data.action = action
    keys.animation_data.action_slot = next(s for s in action.slots if s.target_id_type == 'KEY')
    arrow.animation_data.action = bpy.data.actions['HeldArrow ' + ('Attack' if name == 'archer_shoot' else name)]
    return round(action.frame_range.y - action.frame_range.x)


def set_frame(index):
    scene.frame_set(index + 1)
    bpy.context.view_layer.update()


def mesh_positions():
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.to_mesh()
    # Rig space removes the saved facing yaw, while preserving real skin deformation.
    transform = rig.matrix_world.inverted() @ evaluated.matrix_world
    result = [transform @ v.co for v in data.vertices]
    evaluated.to_mesh_clear()
    return result


sole_ids = {side: [v.index for v in mesh.data.vertices if v.co.z < .12 and (v.co.x > 0) == (side == 'Left')]
            for side in ('Left', 'Right')}
check('skeleton', len(rig.data.bones) == 65 and scene.render.fps == 30,
      {'bone_count': len(rig.data.bones), 'fps': scene.render.fps})
check('bow_parenting', attachment.parent == rig and attachment.parent_type == 'BONE'
      and attachment.parent_bone == prefix + 'LeftHand' and bow.parent == bow_offset
      and bow_offset.parent == attachment,
      {'bone': attachment.parent_bone, 'attachment': attachment.name, 'offset': bow_offset.name})

# This fixed palm socket is expressed in the hand's rest-local coordinates.
# It is independent of the bow's evaluated transform and must follow the hand.
rest_orientation = Matrix.Rotation(-1.5707963267948966, 3, 'Z') @ rig.data.bones[prefix + 'LeftHand'].matrix_local.to_3x3()
palm_socket = rest_orientation.inverted() @ Vector((0, -.043, 0))
original_offset = bow_offset.matrix_basis.copy()
original_bow_basis = bow.matrix_basis.copy()
grip_errors, transform_errors = [], []

diagnostics = json.loads((ROOT / '.godot/archer_animation_frames/diagnostics.json').read_text(encoding='utf-8'))
speeds = {name: v['ground_speed_mps'] for name, v in diagnostics['locomotion_source'].items()}
contacts = {'Walk': {'Left': (6, 15), 'Right': (26, 35)},
            'Run': {'Left': (3, 5), 'Right': (17, 19)}}

for clip in ('Idle', 'Walk', 'Run', 'archer_shoot'):
    count = activate(clip)
    frames = []
    arrow_visibility = []
    arrow_states_valid = []
    heights = {side: [] for side in sole_ids}
    for index in range(count):
        set_frame(index)
        expected_arrow = clip == 'archer_shoot' and index < 15
        arrow_visibility.append(not arrow.hide_render)
        check_scale = Vector((1, 1, 1)) if expected_arrow else Vector((.0001, .0001, .0001))
        arrow_states_valid.append((not arrow.hide_render) == expected_arrow
                                  and (arrow.scale - check_scale).length <= .000001)
        positions = mesh_positions()
        frames.append(positions)
        for side, indices in sole_ids.items():
            heights[side].append(min(positions[i].z for i in indices))
        hand_matrix = rig.matrix_world @ rig.pose.bones[prefix + 'LeftHand'].matrix
        grip_errors.append(((bow.matrix_world @ grip) - (hand_matrix @ palm_socket)).length)
        transform_errors.append(max(abs(a - b) for original, current in
                                    ((original_offset, bow_offset.matrix_basis), (original_bow_basis, bow.matrix_basis))
                                    for row_a, row_b in zip(original, current) for a, b in zip(row_a, row_b)))
    info = {'frames': count, 'sole_min_z_m': {s: min(v) for s, v in heights.items()},
            'sole_max_z_m': {s: max(v) for s, v in heights.items()}}
    check(clip + '_floor', all(min(v) >= -.001 for v in heights.values()),
          {'min_z_m': min(min(v) for v in heights.values()), 'tolerance_m': -.001})
    if clip in contacts:
        info['ground_speed_mps'] = speeds[clip]
        info['planted_contacts'] = {}
        for side, (first, last) in contacts[clip].items():
            # Select once, then retain exactly the same vertex IDs for the interval.
            positions = frames[first]
            low = min(positions[i].z for i in sole_ids[side])
            set_frame(first)
            ball = rig.pose.bones[prefix + side + 'ToeBase'].head
            candidates = [i for i in sole_ids[side] if positions[i].z <= low + .002]
            pivot_id = min(candidates, key=lambda i: (positions[i].xy - ball.xy).length_squared)
            pivot = positions[pivot_id]
            fixed_ids = [i for i in candidates if (positions[i] - pivot).length < .007]
            trajectory = []
            for index in range(first, last + 1):
                point = sum((frames[index][i] for i in fixed_ids), Vector()) / len(fixed_ids)
                point += Vector((0, -speeds[clip] * (index - first) / 30, 0))
                trajectory.append(point)
            xy_drift = max((p.xy - trajectory[0].xy).length for p in trajectory)
            z_span = max(p.z for p in trajectory) - min(p.z for p in trajectory)
            contact_minimums = heights[side][first:last + 1]
            details = {'first_frame': first, 'last_frame': last, 'fixed_vertex_ids': fixed_ids,
                       'world_xy_drift_m': xy_drift, 'fixed_point_z_span_m': z_span,
                       'sole_min_z_m': min(contact_minimums), 'sole_max_z_m': max(contact_minimums),
                       'trajectory_m': [list(p) for p in trajectory]}
            info['planted_contacts'][side] = details
            check(clip + '_' + side + '_plant', xy_drift <= .01
                  and min(contact_minimums) >= -.001 and max(contact_minimums) <= .003,
                  {'world_xy_drift_m': xy_drift, 'sole_max_z_m': max(contact_minimums),
                   'drift_tolerance_m': .01, 'height_tolerance_m': .003})
    info['held_arrow_visible'] = arrow_visibility
    check(clip + '_held_arrow_visibility', all(arrow_states_valid),
          {'visible_frames': sum(arrow_visibility), 'total_frames': count})
    report['clips'][clip] = info

check('bow_grip_socket', max(grip_errors) <= .001 and max(transform_errors) <= 1e-7,
      {'max_grip_error_m': max(grip_errors), 'max_local_transform_error': max(transform_errors),
       'socket_in_hand_m': list(palm_socket)})

basis, draw = keys.key_blocks['Basis'], keys.key_blocks['StringDraw']
changed, changed_outside = [], []
endpoint_delta = 0.0
center_ids = []
for i, vertex in enumerate(basis.data):
    point = vertex.co
    delta = (draw.data[i].co - point).length
    is_string = abs(point.x) < .374 and .148 < point.y < .162 and .051 < point.z < .063
    if delta > 1e-7:
        changed.append(i)
        if not is_string:
            changed_outside.append(i)
    if abs(point.x) >= .374:
        endpoint_delta = max(endpoint_delta, delta)
    if is_string and abs(point.x) < .002:
        center_ids.append(i)
check('string_only_deformation', bool(changed) and not changed_outside and endpoint_delta <= 1e-7,
      {'changed_vertices': len(changed), 'outside_string_vertices': changed_outside,
       'max_endpoint_delta_m': endpoint_delta})

activate('archer_shoot')
full_draw = []
for index in (12, 13, 14):
    set_frame(index)
    evaluated = bow.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.to_mesh()
    center = sum((data.vertices[i].co for i in center_ids), Vector()) / len(center_ids)
    center_world = evaluated.matrix_world @ center
    evaluated.to_mesh_clear()
    nock_world = nock.matrix_world.translation
    upper = rig.pose.bones[prefix + 'LeftArm']
    fore = rig.pose.bones[prefix + 'LeftForeArm']
    elbow_bend = degrees((upper.tail - upper.head).angle(fore.tail - fore.head))
    left_wrist = rig.pose.bones[prefix + 'LeftHand'].head
    right_elbow = rig.pose.bones[prefix + 'RightForeArm'].head
    right_hand = rig.pose.bones[prefix + 'RightHand'].head
    head = rig.pose.bones[prefix + 'Head'].head
    full_draw.append({'frame': index, 'string_nock_error_m': (center_world - nock_world).length,
                      'left_elbow_bend_degrees': elbow_bend, 'left_shoulder_m': list(upper.head),
                      'left_wrist_m': list(left_wrist),
                      'left_arm_reach_m': upper.length + fore.length,
                      'left_shoulder_wrist_distance_m': (left_wrist - upper.head).length,
                      'right_elbow_z_m': right_elbow.z,
                      'right_hand_z_m': right_hand.z, 'head_z_m': head.z,
                      'string_value': draw.value})
report['full_draw'] = full_draw
check('full_draw_alignment', all(v['string_nock_error_m'] <= .004 for v in full_draw),
      {'max_string_nock_error_m': max(v['string_nock_error_m'] for v in full_draw), 'tolerance_m': .004})
check('full_draw_pose', all(v['left_elbow_bend_degrees'] <= 25
                          and v['right_elbow_z_m'] <= v['right_hand_z_m'] + .015
                          and v['right_hand_z_m'] < v['head_z_m'] for v in full_draw),
      {'max_left_elbow_bend_degrees': max(v['left_elbow_bend_degrees'] for v in full_draw),
       'max_right_elbow_above_hand_m': max(v['right_elbow_z_m'] - v['right_hand_z_m'] for v in full_draw)})
report['failures'] = failures
report['passed'] = not failures
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('ARCHER_SOURCE_VERIFICATION', json.dumps({'passed': not failures, 'failures': failures,
                                             'output': str(args.output)}), flush=True)
if failures:
    raise RuntimeError('Archer source checks failed: ' + ', '.join(failures))
