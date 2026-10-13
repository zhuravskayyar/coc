"""Rig the supplied archer and bow, then render eight-way 30/60 FPS clips.

Blender --background --python tools/animate_archer.py -- --review
Blender --background --python tools/animate_archer.py
"""
from pathlib import Path
from math import pi, sin, cos, sqrt, radians, ceil, atan2, floor
import argparse, sys, json, hashlib, bmesh
import bpy
from mathutils import Vector, Matrix, Quaternion
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from archer_locomotion import Locomotion
ASSET = ROOT / 'assets/units/archer'
FRAMES = ROOT / '.godot/archer_animation_review'
if '--review' not in sys.argv:
    FRAMES = ROOT / '.godot/archer_animation_frames'
FRAMES.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument('--review', action='store_true')
parser.add_argument('--attack-only', action='store_true')
parser.add_argument('--run-only', action='store_true')
parser.add_argument('--prepare-only', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])

for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(ASSET / 'archer_source.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.name = 'ArcherRig'
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers))
mesh.name = 'Archer | supplied skinned mesh'
# Keep the supplied skinned character; exclude any unrelated scene primitives.
for obj in list(bpy.data.objects):
    if obj.type == 'MESH' and obj != mesh:
        bpy.data.objects.remove(obj, do_unlink=True)
scene = bpy.context.scene
scene.render.fps = 30
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
prefix = 'mixamorig:'
required_bones = ['LeftHand', 'RightHand', 'LeftForeArm', 'RightForeArm',
                  'LeftArm', 'RightArm', 'Spine', 'Spine1', 'Spine2', 'Head']
assert all(prefix + name in rest for name in required_bones), 'Source skeleton is missing a required bone'
print('ARCHER_BONES', json.dumps(list(rest)), flush=True)
RELEASE_FRAME = 15  # Zero-based game frame; release at 0.5 seconds.
ATTACK_FRAMES = 27
posed = {}
diagnostics = {'source_fps': 30, 'max_ik_target_error_m': 0.0, 'max_bow_grip_error_m': 0.0,
               'min_sole_height_m': 1.0, 'run_flight_frames': 0, 'unique_poses': {}}
active_pose = ('', 0.0)

def bone(name):
    return prefix + name

def rot(x=0, y=0, z=0):
    return Matrix.Rotation(radians(z), 3, 'Z') @ Matrix.Rotation(radians(y), 3, 'Y') @ Matrix.Rotation(radians(x), 3, 'X')

def anchor(short):
    b = rig.data.bones[bone(short)]
    return posed[b.parent.name] @ rest[b.parent.name].inverted() @ b.head_local if b.parent else b.head_local.copy()

def place(short, delta=None, head=None):
    n = bone(short)
    b = rig.data.bones[n]
    if delta is None:
        delta = Matrix.Identity(3)
    matrix = (delta @ rest[n].to_3x3()).to_4x4()
    matrix.translation = anchor(short) if head is None else Vector(head)
    basis = rest[n].inverted()
    if b.parent:
        basis = basis @ rest[b.parent.name] @ posed[b.parent.name].inverted()
    pb = rig.pose.bones[n]
    pb.rotation_mode = 'QUATERNION'
    pb.matrix_basis = basis @ matrix
    posed[n] = matrix

def curve(t, keys):
    for (a, va), (b, vb) in zip(keys, keys[1:]):
        if t <= b:
            u = max(0.0, min(1.0, (t-a)/(b-a)))
            return va+(vb-va)*u*u*(3.0-2.0*u)
    return keys[-1][1]

def limb(first, second, target, pole):
    head = anchor(first)
    target = Vector(target)
    axis = target-head
    a, b = rig.data.bones[bone(first)].length, rig.data.bones[bone(second)].length
    distance = max(.001, min(axis.length, a+b-.00001))
    direction = axis.normalized()
    bend = Vector(pole)-head
    bend = (bend-direction*bend.dot(direction)).normalized()
    along = (a*a-b*b+distance*distance)/(2.0*distance)
    joint = head+direction*along+bend*sqrt(max(0.0, a*a-along*along))
    end = head+direction*distance
    error=(end-target).length
    if error>diagnostics['max_ik_target_error_m']:
        diagnostics['max_ik_target_error_m']=error
        diagnostics['max_ik_target_case']={'clip':active_pose[0],'t':active_pose[1],'limb':first,'target':list(target),'start':list(head),'length_limit':a+b,'distance':axis.length}
    for short, h, tail in ((first, head, joint), (second, joint, end)):
        rb = rig.data.bones[bone(short)]
        delta = (rb.tail_local-rb.head_local).normalized().rotation_difference((tail-h).normalized()).to_matrix()
        place(short, delta, h)
    return end

def foot(side, x, y, lift=0.0, pitch=0.0):
    sign = 1 if side == 'Left' else -1
    ankle = .071 + lift
    target = (x, y, ankle)
    end = limb(side+'UpLeg', side+'Leg', target, (x, -.42, .23))
    # Keep the supplied boot aligned with the support plane while its toe rolls at push-off.
    place(side+'Foot', rot(x=pitch), end)
    place(side+'ToeBase', rot(x=pitch))
    place(side+'Toe_End', rot(x=pitch))
    diagnostics['min_sole_height_m'] = min(diagnostics['min_sole_height_m'], end.z-.071)
    return lift

def hand(side, wrist, pole, tilt=0.0, opening=0.0):
    end = limb(side+'Arm', side+'ForeArm', wrist, pole)
    # Orient both palms along the arrow, independently of elbow bend.
    delta = rot(x=tilt) @ rot(z=-90 if side == 'Left' else 90)
    place(side+'Hand', delta, end)
    # Curl three fingers around the supplied bow/string while leaving the thumb opposed.
    for finger in ('Index', 'Middle', 'Ring', 'Pinky', 'Thumb'):
        for segment in range(1, 5):
            short = side+'Hand'+finger+str(segment)
            n = bone(short)
            b = rig.data.bones[n]
            parent = posed[b.parent.name] @ rest[b.parent.name].inverted()
            desired = parent @ rest[n]
            if finger == 'Thumb':
                bend = 27 if segment == 1 else 9 if segment == 2 else 0
            else:
                bend = (46 if segment == 1 else 55 if segment == 2 else 28 if segment == 3 else 0)
                if side == 'Right' and finger in ('Index', 'Middle'):
                    bend = int(bend * .6)
                if side == 'Right':
                    bend *= 1.0 - opening
            axis = (b.tail_local-b.head_local).normalized().cross(Vector((0, 0, -1)))
            if axis.length_squared < 1e-8:
                axis = Vector((1, 0, 0))
            local_axis = rest[n].to_3x3().inverted() @ axis.normalized()
            desired = desired @ Matrix.Rotation(radians(bend), 4, local_axis)
            pb = rig.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis = rest[n].inverted() @ rest[b.parent.name] @ posed[b.parent.name].inverted() @ desired
            posed[n] = desired

# Split the supplied disconnected arrow from the bow without inventing geometry.
# The gap between the arrow (y < -.10) and the bow (y > -.08) was inspected.
before_bow = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ASSET / 'bow_source.glb'))
bow_mesh = next(o for o in set(bpy.data.objects)-before_bow if o.type == 'MESH')
source_faces = len(bow_mesh.data.polygons)
source_shape = sorted(tuple(round(v, 7) for v in vertex.co) for vertex in bow_mesh.data.vertices)
def surface_signature(obj):
    uv = obj.data.uv_layers.active.data
    return sorted(tuple(sorted((tuple(round(v, 7) for v in obj.data.vertices[obj.data.loops[i].vertex_index].co),
                                tuple(round(v, 7) for v in uv[i].uv)) for i in face.loop_indices))
                  for face in obj.data.polygons)
source_surface = surface_signature(bow_mesh)
bpy.ops.object.select_all(action='DESELECT')
bow_mesh.select_set(True)
bpy.context.view_layer.objects.active = bow_mesh
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_mode(type='FACE')
bpy.ops.mesh.select_all(action='DESELECT')
split_bm = bmesh.from_edit_mesh(bow_mesh.data)
for face in split_bm.faces:
    ys = [vertex.co.y for vertex in face.verts]
    assert max(ys) < -.09 or min(ys) > -.09, 'A face crosses the inspected separation gap'
    face.select_set(max(ys) < -.09)
bmesh.update_edit_mesh(bow_mesh.data)
bpy.ops.mesh.separate(type='SELECTED')
bpy.ops.object.mode_set(mode='OBJECT')
arrow = next(o for o in bpy.context.selected_objects if o != bow_mesh)
bow_mesh.name = 'Bow'
arrow.name = 'HeldArrow'
assert len(bow_mesh.data.polygons) > 0 and len(arrow.data.polygons) > 0
assert len(bow_mesh.data.polygons) + len(arrow.data.polygons) == source_faces
split_shape = sorted(tuple(round(v, 7) for v in vertex.co)
                     for obj in (bow_mesh, arrow) for vertex in obj.data.vertices)
assert split_shape == source_shape, 'Splitting changed the supplied vertex coordinates'
assert sorted(surface_signature(bow_mesh) + surface_signature(arrow)) == source_surface, 'Splitting changed polygons or UV coordinates'
assert list(bow_mesh.data.materials) == list(arrow.data.materials), 'Splitting changed materials'
diagnostics['preserved_weapon_faces'] = source_faces
diagnostics['bow_faces'] = len(bow_mesh.data.polygons)
diagnostics['arrow_faces'] = len(arrow.data.polygons)
diagnostics['bones'] = list(rest)
diagnostics['bowstring'] = 'Original string vertices, animated shape key; original tips, polygons and UVs preserved'

# Bone attachments and editable transform offsets live in the Blender source.
def attachment(name, short):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    obj.parent_type = 'BONE'
    obj.parent_bone = bone(short)
    obj.matrix_parent_inverse = Matrix.Translation((0, -rig.data.bones[bone(short)].length, 0))
    obj.matrix_basis = Matrix.Identity(4)
    return obj

def offset(name, parent, child):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    child.parent = obj
    child.matrix_parent_inverse = Matrix.Identity(4)
    child.matrix_basis = Matrix.Identity(4)
    return obj

left_attachment = attachment('LeftHandAttachment', 'LeftHand')
right_attachment = attachment('RightHandAttachment', 'RightHand')
bow_offset = offset('BowOffset', left_attachment, bow_mesh)
arrow_offset = offset('ArrowOffset', right_attachment, arrow)
WEAPON_SCALE = .67
BOW_GRIP = Vector((0, -.045, .0432625))
ARROW_NOCK = Vector((.2449, -.141, .045))
ARROW_TIP = Vector((-.334, -.141, .045))
bow_rotation = Matrix.Rotation(-pi / 2, 4, 'Y')
arrow_rotation = Matrix.Rotation(pi / 2, 4, 'Z')
# Initial hand orientations are used only to convert world alignment to local offsets.
left_orientation = rot(z=-90) @ rest[bone('LeftHand')].to_3x3()
right_orientation = rot(z=90) @ rest[bone('RightHand')].to_3x3()
bow_local = Matrix.Translation((0, -.043, 0)) @ bow_rotation @ Matrix.Scale(WEAPON_SCALE, 4) @ Matrix.Translation(-BOW_GRIP)
arrow_local = Matrix.Translation((-.012, -.055, 0)) @ arrow_rotation @ Matrix.Scale(WEAPON_SCALE, 4) @ Matrix.Translation(-ARROW_NOCK)
bow_offset.matrix_basis = left_orientation.inverted().to_4x4() @ bow_local
arrow_offset.matrix_basis = right_orientation.inverted().to_4x4() @ arrow_local
muzzle = bpy.data.objects.new('BowMuzzle', None)
bpy.context.collection.objects.link(muzzle)
muzzle.parent = bow_mesh
muzzle.location = Vector((0, -.063, .0567))
arrow_nock = bpy.data.objects.new('ArrowNock', None)
bpy.context.collection.objects.link(arrow_nock)
arrow_nock.parent = arrow
arrow_nock.location = ARROW_NOCK
arrow_tip = bpy.data.objects.new('ArrowTip', None)
bpy.context.collection.objects.link(arrow_tip)
arrow_tip.parent = arrow
arrow_tip.location = ARROW_TIP


# Deform only the supplied string. Bow limbs, topology, material and UVs stay intact.
# The inspected string occupies the thin strip between the two native end fittings.
string_basis = bow_mesh.shape_key_add(name='Basis')
string_draw = bow_mesh.shape_key_add(name='StringDraw')
string_draw.slider_min = -.2
string_draw.slider_max = 1.2
string_vertices = []
for v in bow_mesh.data.vertices:
    if abs(v.co.x) < .374 and .148 < v.co.y < .162 and .051 < v.co.z < .063:
        weight = max(0.0, 1.0 - abs(v.co.x) / .374)
        string_draw.data[v.index].co.y += .34 * weight
        string_vertices.append(v.index)
assert len(string_vertices) > 2000
string_actions = {}
string_slots = {}


locomotion = Locomotion(ROOT, rig)


def pose(clip, t):
    posed.clear()
    phase = 2*pi*t
    walking = clip in ('Walk', 'Run')
    running = clip == 'Run'
    vertical = -.045
    lean = 0.0
    twist = -35.0
    if clip == 'Walk':
        vertical -= .005*cos(2*phase)
        twist += 2.5*sin(phase)
    elif running:
        vertical += curve((t % .5)*2, [(0, -.025), (.18, -.040), (.48, -.01), (.75, .008), (1, -.025)])
        lean = 5.0
        twist += 4.0*sin(phase)
    elif clip == 'Attack':
        twist = curve(t * ATTACK_FRAMES, [(0, -35), (5, -84), (12, -88), (19, -88), (27, -35)])
    elif clip == 'Idle':
        twist += .8*sin(phase)
        lean = .4*cos(phase)
    hips = rest[bone('Hips')].translation + Vector((0, 0, vertical + .001*sin(phase)))
    place('Hips', rot(z=-15), hips)
    for short, factor in (('Spine', .45), ('Spine1', .75), ('Spine2', 1.0)):
        place(short, rot(x=lean*factor, z=twist*factor))
    place('Neck', rot(z=-8))
    place('Head', rot(x=.25*cos(phase) if clip == 'Idle' else 0, z=0))
    place('HeadTop_End')
    for side in ('Left', 'Right'):
        place(side+'Shoulder', rot(x=lean*.2, z=twist))
    if walking:
        hip_delta = locomotion.apply(clip, t, rest, place, limb)
        locomotion.fit_soles(clip, t, mesh, posed, place, limb)
        vertical = hip_delta.z - .014
        for side in ('Left', 'Right'):
            place(side+'Shoulder', rot(z=-8))
    else:
        # Feet stay at the same world positions through draw, release and recovery.
        foot('Left', .075, -.080)
        foot('Right', -.075, -.080)
    ready_left = Vector((.17, -.12, .635+vertical))
    ready_right = Vector((-.12, -.105, .575+vertical))
    bow_wrist = ready_left.copy()
    string_wrist = ready_right.copy()
    tilt = 12.0
    opening = .35 if clip != 'Attack' else 0.0
    if clip == 'Attack':
        f = t * ATTACK_FRAMES
        raise_hand = curve(f, [(0, 0), (5, 1), (19, 1), (27, 0)])
        draw = curve(f, [(0, 0), (5, 0), (12, 1), (19, 1), (27, 0)])
        follow = curve(f, [(0, 0), (15, 0), (17, 1), (19, 1), (27, 0)])
        bow_wrist = ready_left.lerp(Vector((-.015, -.335, .815+vertical)), raise_hand)
        bow_wrist.y += .030 * (1-draw) * raise_hand
        nocked = Vector((-.0117, -.1883, .815+vertical))
        anchor_hand = Vector((-.0117, .035, .815+vertical))
        string_wrist = ready_right.lerp(nocked.lerp(anchor_hand, draw), raise_hand)
        string_wrist.y += .030 * (1-draw) * raise_hand
        string_wrist += Vector((0, .035, -.004))*follow
        tilt = 12*(1-raise_hand)
        opening = follow
    elif walking:
        bow_wrist.z += .005*sin(phase)
        string_wrist.y += .016*sin(phase)
    hand('Left', bow_wrist, (.16, -.15, .68+vertical), tilt)
    right_pole = Vector((-.13, .20, .69+vertical))
    if clip == 'Attack':
        right_pole = right_pole.lerp(Vector((-.075, .17, .72)), raise_hand)
    hand('Right', string_wrist, right_pole, tilt, opening)
    # String center follows the nock while drawing; bow's object transform stays rigid.
    string_draw.value = 0.0
    if clip == 'Attack':
        if 5 <= f < RELEASE_FRAME:
            bow_matrix = posed[bone('LeftHand')] @ bow_offset.matrix_basis
            arrow_matrix = posed[bone('RightHand')] @ arrow_offset.matrix_basis
            nock_local = bow_matrix.inverted() @ arrow_matrix @ ARROW_NOCK
            string_draw.value = max(0.0, (nock_local.y - .156) / .34)
        elif RELEASE_FRAME <= f < 18:
            string_draw.value = curve(f, [(15, .12), (16, -.06), (17, .025), (18, 0)])
    # Weapon offsets follow real bones; they have no independent world motion.
    left_head = posed[bone('LeftHand')].translation
    diagnostics['max_bow_grip_error_m'] = max(diagnostics['max_bow_grip_error_m'], (left_head-bow_wrist).length)
    held_arrow_visible = clip == 'Attack' and t * ATTACK_FRAMES < RELEASE_FRAME
    arrow.hide_render = not held_arrow_visible
    # glTF has no animated hide_render, so export a stepped visibility marker.
    # Nonzero hidden scale keeps glTF/Godot transform decomposition valid.
    # Blender hides the mesh; the Godot import hook restores explicit visibility.
    arrow.scale = (1, 1, 1) if held_arrow_visible else (.0001, .0001, .0001)
    return string_wrist


clip_fps = {'Idle': 30, 'Walk': 30, 'Run': 60, 'Attack': 30}
counts={'Idle':60,'Walk':locomotion.clips['Walk']['frames'],'Run':locomotion.clips['Run']['frames'] * 2,'Attack':ATTACK_FRAMES}
actions={}
arrow_actions={}
for clip,count in counts.items():
    rig.animation_data_create(); rig.animation_data.action=None
    arrow.animation_data_clear()
    bow_mesh.data.shape_keys.animation_data_clear()
    hashes=set(); first=None; previous={}
    for index in range(count+1):
        t=index/count
        key_frame = 1 + index * scene.render.fps / clip_fps[clip]
        active_pose=(clip,t)
        draw_hand=pose(clip,t)
        values = [round(v, 6) for m in posed.values() for row in m for v in row]
        if index < count:
            hashes.add(hashlib.sha256(json.dumps(values).encode()).hexdigest())
        if index == 0:
            first = values
        if index == count:
            assert len(values) == len(first) and max(abs(a-b) for a,b in zip(first, values)) < .00001, clip+' loop seam'
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name]) < 0:
                pb.rotation_quaternion.negate()
            previous[pb.name] = pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion', frame=key_frame)
            pb.keyframe_insert(data_path='location', frame=key_frame)
        arrow.keyframe_insert(data_path='hide_render', frame=key_frame)
        arrow.keyframe_insert(data_path='scale', frame=key_frame)
        if index == 0:
            shape_animation = bow_mesh.data.shape_keys.animation_data_create()
            shape_animation.action = rig.animation_data.action
            string_slots[clip] = rig.animation_data.action.slots.new(id_type='KEY', name='BowString')
            shape_animation.action_slot = string_slots[clip]
        string_draw.keyframe_insert(data_path='value', frame=key_frame)
        scene.frame_set(floor(key_frame), subframe=key_frame % 1)
    action=rig.animation_data.action; action.name='archer_shoot' if clip == 'Attack' else clip; action.use_fake_user=True
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation='LINEAR'
                    fc.modifiers.new('CYCLES')
    arrow.animation_data.action.name = 'HeldArrow '+clip
    arrow.animation_data.action.use_fake_user = True
    for layer in arrow.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:
                        key.interpolation = 'CONSTANT'
    string_action = bow_mesh.data.shape_keys.animation_data.action
    string_action.use_fake_user = True
    string_actions[clip] = string_action
    actions[clip] = action
    arrow_actions[clip] = arrow.animation_data.action
    assert len(hashes)==count,clip+' has repeated source poses'
    diagnostics['unique_poses'][clip]=len(hashes)
rig.animation_data.action = actions['Idle']
arrow.animation_data.action = arrow_actions['Idle']
bow_mesh.data.shape_keys.animation_data.action = string_actions['Idle']
bow_mesh.data.shape_keys.animation_data.action_slot = string_slots['Idle']
scene.frame_set(1)
bpy.context.view_layer.update()
print('ARCHER_DIAGNOSTICS',json.dumps(diagnostics),flush=True)
assert diagnostics['max_ik_target_error_m']<.003
assert diagnostics['max_bow_grip_error_m']<.003
assert diagnostics['min_sole_height_m']>-.002
diagnostics['locomotion_source'] = {clip: {'source': data['source_clip'], 'scale': locomotion.scale, 'ground_speed_mps': locomotion.speed(clip)} for clip, data in locomotion.clips.items()}

# Render actual supplied textures with transparent backgrounds.
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=256; scene.render.resolution_y=256; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'; scene.render.film_transparent=True
scene.world.use_nodes = True
world_background = next(node for node in scene.world.node_tree.nodes if node.type == 'BACKGROUND')
world_background.inputs['Color'].default_value = (.050876, .050876, .050876, 1)
world_background.inputs['Strength'].default_value = .3
scene.view_settings.view_transform='Khronos PBR Neutral'; scene.view_settings.exposure=0.0
for material in set(mesh.data.materials) | set(bow_mesh.data.materials):
    material.diffuse_color = (1, 1, 1, 1)
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Base Color'].default_value = (1, 1, 1, 1)
            node.inputs['Emission Strength'].default_value = 0.0
target=Vector((0,-.03,.49))
for title,loc,power,size in [('Key',(1.6,-2.3,1.8),162,2),('Fill',(-1.8,-1.0,1.0),58.5,1.6),('Rim',(1.0,1.8,1.5),99,1.6)]:
    bpy.ops.object.light_add(type='AREA',location=target+Vector(loc)); lamp=bpy.context.object; lamp.name='Archer studio '+title
    lamp.data.energy=power; lamp.data.shape='DISK'; lamp.data.size=size; lamp.rotation_euler=(target-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(); cam=bpy.context.object; scene.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=1.48; cam.location=target+Vector((3,-4,4)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects.new('Archer',None); bpy.context.collection.objects.link(root)
rig.parent=root; rig.matrix_parent_inverse=root.matrix_world.inverted()
root['description']='Archer using supplied fantasy archer and ornate wooden bow; full draw, release and follow-through at 30 FPS'
bpy.context.view_layer.update()
origin=world_to_camera_view(scene,cam,Vector((0,0,0)))
ground_anchor=[round(origin.x*256,3),round((1-origin.y)*256,3)]
metadata={'frame_size':[256,256],'ground_anchor':ground_anchor,'world_scale':.50,'directions':8,'pixels_per_metre':256/1.48,
          'ground_projection_y':4/sqrt(41),'source':'assets/units/archer/archer_animated.blend','skeleton_bones':len(rig.data.bones),
          'direction_order':'E, SE, S, SW, W, NW, N, NE','clips':{}}
metadata['weapon_attachments'] = {'bow_bone': bone('LeftHand'), 'arrow_bone': bone('RightHand'),
                                'offsets': ['BowOffset', 'ArrowOffset'], 'bowstring_deformation': True}
metadata['bone_names'] = list(rest)

def direction_yaw(direction):
    angle = direction * pi / 4
    # Project the rig's forward vector onto the existing map's 0.75 isometric axes.
    ground_angle = atan2(sin(angle) * .75 / metadata['ground_projection_y'], cos(angle))
    return atan2(4, -3) - ground_angle

metadata['direction_yaws'] = [direction_yaw(d) for d in range(8)]
metadata['direction_ground_projection'] = []
for direction in range(8):
    forward = Vector((sin(direction_yaw(direction)), -cos(direction_yaw(direction)), 0))
    a = world_to_camera_view(scene, cam, Vector((0, 0, 0)))
    b = world_to_camera_view(scene, cam, forward)
    metadata['direction_ground_projection'].append(Vector((b.x-a.x, b.y-a.y)).length * 256 / metadata['pixels_per_metre'])
root['direction_yaws'] = metadata['direction_yaws']


def screen_point(obj):
    point = world_to_camera_view(scene, cam, obj.matrix_world.translation)
    return [round(point.x*256, 4), round((1-point.y)*256, 4)]
scene.render.filepath=str(FRAMES/'preview.png')
for clip,count in counts.items():
    info={'frames':count,'fps':clip_fps[clip],'duration':count/clip_fps[clip],'columns':ceil(count/3),'rows_per_direction':3}
    info['ground_speed_mps']=locomotion.speed(clip) if clip in locomotion.clips else 0.0
    if clip in locomotion.clips:
        info['source_animation'] = locomotion.clips[clip]['source_clip']
        info['source_license'] = 'CC0-1.0 / Quaternius Universal Animation Library'
    info['texture']=f'res://assets/sprites/units/archer_{clip.lower()}_sheet.png'
    info['held_arrow_visible'] = [clip == 'Attack' and i < RELEASE_FRAME for i in range(count)]
    if clip == 'Attack':
        info['release_frame'] = RELEASE_FRAME
        info['source_animation'] = 'archer_shoot'
        info['muzzle_positions'] = [[] for _ in range(8)]
        info['held_arrow_visible'] = [i < RELEASE_FRAME for i in range(count)]
    metadata['clips'][clip.lower()]=info
if args.run_only:
    metadata['clips']['attack']['muzzle_positions'] = json.loads((ROOT/'assets/sprites/units/archer_animations.json').read_text(encoding='utf-8'))['clips']['attack']['muzzle_positions']
for clip,count in counts.items():
    if args.prepare_only or (args.attack_only and clip!='Attack') or (args.run_only and clip!='Run'):
        continue
    rig.animation_data.action=actions[clip]
    arrow.animation_data.action = arrow_actions[clip]
    bow_mesh.data.shape_keys.animation_data.action = string_actions[clip]
    bow_mesh.data.shape_keys.animation_data.action_slot = string_slots[clip]
    for direction in ((1,3,5) if args.review else range(8)):
        root.rotation_euler.z=direction_yaw(direction)
        indices=([0, 5, 9, 13, 15, 18, 25] if clip=='Attack' else [round(count*p/8) for p in range(8)]) if args.review else range(count)
        for index in indices:
            render_frame = 1 + index * scene.render.fps / clip_fps[clip]
            scene.frame_set(floor(render_frame), subframe=render_frame % 1)
            bpy.context.view_layer.update()
            if clip == 'Attack':
                metadata['clips']['attack']['muzzle_positions'][direction].append(screen_point(muzzle))
            scene.render.filepath=str(FRAMES/f'{clip.lower()}_{direction}_{index:02d}.png')
            bpy.ops.render.render(write_still=True)
        print('ARCHER_DIRECTION',clip,direction,flush=True)
# Projectile art and flight behavior are outside this pose/locomotion correction.
metadata['projectile'] = json.loads((ROOT/'assets/sprites/units/archer_animations.json').read_text(encoding='utf-8'))['projectile']
if not args.prepare_only:
    (FRAMES/'metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
(FRAMES/'diagnostics.json').write_text(json.dumps(diagnostics,indent=2),encoding='utf-8')
root.rotation_euler.z=0; rig.animation_data.action=actions['Idle']; arrow.animation_data.action=arrow_actions['Idle']; bow_mesh.data.shape_keys.animation_data.action=string_actions['Idle']; bow_mesh.data.shape_keys.animation_data.action_slot=string_slots['Idle']; scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(ASSET/'archer_animated.blend'))
from export_archer import export_archer
export_archer(ASSET / 'archer_animated.glb')
print('ARCHER_COMPLETE',flush=True)
