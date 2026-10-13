"""Create the builder's editable skeleton, animation clips and 8-way renders.

Run with Blender --background --python tools/rig_builder.py. The original
T-pose is preserved; builder_rigged.blend and builder_animated.glb are outputs.
Then use pack_builder_animations.py to assemble the game textures.
"""
from pathlib import Path
from math import pi, sin, cos, radians, sqrt, ceil
import json
import hashlib
import argparse
import sys
import bpy
from mathutils import Vector, Quaternion, Matrix
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets/units/builder'
parser = argparse.ArgumentParser()
parser.add_argument('--preview', action='store_true', help='Render Run/Hammer in two views before producing game assets')
parser.add_argument('--review-keys', action='store_true', help='Render only six key poses per clip for a quick correction review')
parser.add_argument('--bake-only', action='store_true', help='Bake and validate the skeleton without rendering')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
FRAMES = ROOT / ('.godot/builder_animation_review' if args.preview else '.godot/builder_animation_frames')
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ASSET / 'builder.blend'))
model = bpy.data.collections['BUILDER | editable character']
root = bpy.data.objects['Builder']
meshes = [o for o in model.objects if o.type == 'MESH']

bpy.ops.object.select_all(action='DESELECT')
armature = bpy.data.armatures.new('Builder skeleton')
rig = bpy.data.objects.new('BuilderRig', armature)
model.objects.link(rig)
rig.parent = root
rig.show_in_front = True
armature.display_type = 'OCTAHEDRAL'
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')

def bone(name, head, tail, parent=None):
    b = armature.edit_bones.new(name)
    b.head = Vector(head) * .32
    b.tail = Vector(tail) * .32
    if parent:
        b.parent = armature.edit_bones[parent]
    return b

bone('Root', (0, 0, 0), (0, 0, .5))
bone('Hips', (0, 0, 2.75), (0, 0, 3.25), 'Root')
bone('Spine', (0, 0, 3.25), (0, 0, 4.65), 'Hips')
bone('Neck', (0, 0, 4.65), (0, 0, 4.96), 'Spine')
bone('Head', (0, 0, 4.96), (0, 0, 6.28), 'Neck')
for side, sign in (('L', -1), ('R', 1)):
    bone('UpperArm.' + side, (sign*.76, .01, 4.29), (sign*1.92, .01, 4.29), 'Spine')
    bone('Forearm.' + side, (sign*1.92, .01, 4.29), (sign*2.67, .01, 4.29), 'UpperArm.' + side)
    bone('Hand.' + side, (sign*2.67, .01, 4.29), (sign*3.15, .01, 4.29), 'Forearm.' + side)
    bone('Thigh.' + side, (sign*.39, 0, 2.75), (sign*.60, .025, 1.73), 'Hips')
    bone('Shin.' + side, (sign*.60, .025, 1.73), (sign*.63, .025, .58), 'Thigh.' + side)
    bone('Foot.' + side, (sign*.63, .025, .58), (sign*.63, -.53, .24), 'Shin.' + side)
bone('Hammer', (3.075, -.025, 4.29), (3.075, -.025, 5.05), 'Hand.R')
bpy.ops.object.mode_set(mode='OBJECT')

# Articulated details stay rigid; cloth blends over the knees and elbows.
arm_parts = ('short linen sleeve', 'rolled linen cuff', 'rolled sleeve crease',
    'upper arm', 'forearm', 'leather gauntlet', 'gauntlet cuff edging',
    'gloved palm', 'open finger', 'finger joint', 'open thumb',
    'gripping finger', 'glove knuckle', 'gripping thumb', 'linen shoulder')
leg_parts = ('trouser leg', 'outer trouser seam', 'cloth fold', 'boot ',
    'sole ', 'protective toe', 'toe cap', 'front tread', 'side tread',
    'knee ', 'folded boot cuff', 'cuff ', 'strap stud')

def default_bone(obj):
    name = obj.name
    if name.startswith('Hammer'):
        return 'Hammer'
    if name[:2] in ('L ', 'R '):
        side, part = name[0], name[2:]
        if part.startswith(arm_parts):
            if part.startswith(('gloved', 'open finger', 'finger joint', 'open thumb',
                    'gripping', 'glove knuckle')):
                return 'Hand.' + side
            if part.startswith(('forearm', 'leather gauntlet', 'gauntlet')):
                return 'Forearm.' + side
            return 'UpperArm.' + side
        if part.startswith(leg_parts):
            if part.startswith(('boot shaft', 'folded boot cuff', 'cuff')):
                return 'Shin.' + side
            if part.startswith(('boot', 'sole', 'protective toe', 'toe cap',
                    'front tread', 'side tread', 'folded boot cuff', 'cuff', 'strap stud')):
                return 'Foot.' + side
            return 'Shin.' + side
    if 'pouch' in name.lower() or name.startswith(('Belt', 'Leather waist',
            'Chisel', 'Side pencil', 'Carpenter pencil', 'Pencil wood', 'Overalls hip')):
        return 'Hips'
    if name == 'Neck':
        return 'Neck'
    # Facial pieces and hardhat are entirely above the neck.
    center = obj.matrix_world @ (sum((Vector(c) for c in obj.bound_box), Vector()) / 8)
    return 'Head' if center.z > 1.52 else 'Spine'

for obj in meshes:
    primary = default_bone(obj)
    if 'trouser leg' in obj.name:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        subdiv = obj.modifiers.new('Joint support topology', 'SUBSURF')
        subdiv.subdivision_type = 'SIMPLE'
        subdiv.levels = 2
        bpy.ops.object.modifier_apply(modifier=subdiv.name)
    obj.vertex_groups.clear()
    groups = {primary: obj.vertex_groups.new(name=primary)}
    cloth_leg = any(part in obj.name for part in ('trouser leg', 'outer trouser seam', 'cloth fold'))
    boot_shaft = obj.name.endswith('boot shaft')
    torso_cloth = obj.name in ('Linen shirt torso', 'Overalls front bib')
    limb_skin = obj.name.endswith('upper arm') or obj.name.endswith('forearm')
    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        weights = {primary: 1.0}
        if cloth_leg:
            side = obj.name[0]
            thigh = max(0.0, min(1.0, (co.z/.32 - 1.50) / .46))
            hip = max(0.0, min(.65, (co.z/.32 - 2.48) / .40))
            weights = {'Thigh.'+side: thigh*(1-hip), 'Shin.'+side: (1-thigh)*(1-hip), 'Hips': hip}
        elif limb_skin:
            side = obj.name[0]
            forearm = max(0.0, min(1.0, (abs(co.x)/.32 - 1.72) / .4))
            weights = {'UpperArm.'+side: 1-forearm, 'Forearm.'+side: forearm}
        elif boot_shaft:
            shin = max(0.0, min(1.0, (co.z/.32-.42)/.38))
            weights = {'Foot.'+obj.name[0]: 1-shin, 'Shin.'+obj.name[0]: shin}
        elif torso_cloth:
            spine = max(0.0, min(1.0, (co.z/.32-3.0)/.48))
            weights = {'Spine': spine, 'Hips': 1-spine}
        for name, weight in weights.items():
            if weight <= 0:
                continue
            if name not in groups:
                groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([v.index], weight, 'REPLACE')
    mod = obj.modifiers.new('Builder skeletal deformation', 'ARMATURE')
    mod.object = rig
    mod.use_deform_preserve_volume = True
    obj.parent = rig

rest = {b.name: b.matrix_local.copy() for b in armature.bones}
posed = {}
diagnostics = {'max_ik_target_error_m': 0.0, 'max_grip_error_m': 0.0,
    'min_sole_height_m': 1.0, 'run_flight_frames': 0, 'source_fps': 30}

def rotation(x=0, y=0, z=0):
    return (Matrix.Rotation(radians(z), 3, 'Z') @
        Matrix.Rotation(radians(y), 3, 'Y') @ Matrix.Rotation(radians(x), 3, 'X'))

def anchor(name):
    parent = armature.bones[name].parent
    if parent:
        return posed[parent.name] @ rest[parent.name].inverted() @ rest[name].translation
    return rest[name].translation.copy()

def place(name, delta_rotation, head=None):
    """Set an armature-space pose, resolving the parent's current transform.

    This avoids applying world Euler angles in a moving parent's local space.
    """
    desired = (delta_rotation @ rest[name].to_3x3()).to_4x4()
    desired.translation = anchor(name) if head is None else Vector(head)
    parent = armature.bones[name].parent
    basis = rest[name].inverted()
    if parent:
        basis = basis @ rest[parent.name] @ posed[parent.name].inverted()
    pb = rig.pose.bones[name]
    pb.rotation_mode = 'QUATERNION'
    pb.matrix_basis = basis @ desired
    posed[name] = desired

def interpolate(t, values):
    for (ta, va), (tb, vb) in zip(values, values[1:]):
        if t <= tb:
            u = max(0.0, min(1.0, (t-ta)/(tb-ta)))
            u = u*u*(3-2*u)
            return va + (vb-va)*u
    return values[-1][1]

def solve_limb(first, second, endpoint, pole):
    """Two-link IK: the hand/foot controls placement, the knee/elbow follows."""
    head = anchor(first)
    target = Vector(endpoint)
    axis = target-head
    length1 = armature.bones[first].length
    length2 = armature.bones[second].length
    distance = max(.001, min(axis.length, length1+length2-.0001))
    direction = axis.normalized()
    bend = Vector(pole)-head
    bend = (bend-direction*bend.dot(direction)).normalized()
    along = (length1*length1-length2*length2+distance*distance)/(2*distance)
    height = sqrt(max(0, length1*length1-along*along))
    joint = head+direction*along+bend*height
    actual_end = head+direction*distance
    error = (actual_end-target).length
    if error > diagnostics['max_ik_target_error_m']:
        diagnostics['max_ik_target_error_m'] = error
        diagnostics['worst_target'] = {'bone': first, 'clip': current_clip, 'phase': current_phase}
    for name, start, end in ((first, head, joint), (second, joint, actual_end)):
        original = armature.bones[name].tail_local-armature.bones[name].head_local
        delta = original.normalized().rotation_difference((end-start).normalized()).to_matrix()
        place(name, delta, start)
    return actual_end

sole_points = {}
for side in ('L', 'R'):
    ankle = rest['Foot.'+side].translation
    sole_points[side] = [obj.matrix_world @ Vector(c)-ankle
        for obj in meshes if obj.name.startswith((side+' boot sole', side+' front tread', side+' side tread'))
        for c in obj.bound_box]

def foot(side, x, y, clearance=0, pitch=0):
    delta = rotation(x=pitch)
    lowest = min((delta @ p).z for p in sole_points[side])
    target = Vector((x, y, -lowest+clearance))
    actual = solve_limb('Thigh.'+side, 'Shin.'+side, target,
        (x, -.9, .55))
    place('Foot.'+side, delta, actual)
    diagnostics['min_sole_height_m'] = min(diagnostics['min_sole_height_m'], actual.z+lowest)
    return actual.z+lowest

def arm(side, wrist, pole, hand_rotation=None):
    actual = solve_limb('UpperArm.'+side, 'Forearm.'+side, wrist, pole)
    if hand_rotation is None:
        hand_rotation = posed['Forearm.'+side].to_3x3() @ rest['Forearm.'+side].to_3x3().inverted()
    place('Hand.'+side, hand_rotation, actual)

def carry_hammer(grip, tilt=0, twist=0):
    # Original X is the striking axis, +Z is the handle. Rotate that axis
    # toward -Y (the character's forward), then swing in a vertical arc.
    delta = rotation(x=tilt) @ rotation(z=-90+twist)
    offset = rest['Hammer'].translation-rest['Hand.R'].translation
    wrist = Vector(grip)-delta @ offset
    arm('R', wrist, (.73, .14, 1.16), delta)
    place('Hammer', delta)
    diagnostics['max_grip_error_m'] = max(diagnostics['max_grip_error_m'],
        (posed['Hammer'].translation-Vector(grip)).length)

def gait_foot(side, t, running):
    u = (t+(0 if side == 'L' else .5)) % 1
    stance = .20 if running else .62
    front, back = (-.28, .30) if running else (-.24, .24)
    if u < stance:
        y = front+(back-front)*u/stance
        lift = 0
        pitch = interpolate(u/stance, [(0,-12),(.24,0),(.64,0),(1,27 if running else 18)])
    else:
        s = (u-stance)/(1-stance)
        # Match backward ground speed at toe-off and the next landing.
        tangent = (back-front)/stance*(1-stance)
        y = ((2*s**3-3*s*s+1)*back + (s**3-2*s*s+s)*tangent
            + (-2*s**3+3*s*s)*front + (s**3-s*s)*tangent)
        lift = .36*sin(pi*s)**.85 if running else .085*sin(pi*s)**1.4
        pitch = interpolate(s, [(0,27 if running else 18),(.27,52 if running else 23),(.68,-18),(1,-12)])
    return foot(side, (-1 if side == 'L' else 1)*(.205 if running else .20), y, lift, pitch)

def pose(clip, t):
    global current_clip, current_phase
    current_clip, current_phase = clip, t
    posed.clear()
    phase = 2*pi*t
    root_z = 0
    hip_x = 0
    hip_twist = 0
    lean, twist = 2, 0
    if clip == 'Run':
        root_z = interpolate((t % .5)*2, [(0,-.075),(.17,-.13),(.42,-.06),(.70,.035),(1,-.075)])
        lean, twist = 12, 5*sin(phase)
        hip_twist = -4*sin(phase)
    elif clip == 'Walk':
        root_z = -.065-.017*cos(phase*2)
        hip_x = .012*sin(phase)
        lean, twist = 3, 3*sin(phase)
        hip_twist = -3*sin(phase)
    elif clip == 'Hammer':
        root_z = interpolate(t, [(0,-.040),(.43,-.035),(.60,-.076),(.68,-.068),(1,-.040)])
        hip_x = interpolate(t, [(0,0),(.43,.034),(.60,-.036),(.73,-.022),(1,0)])
        hip_twist = interpolate(t, [(0,0),(.43,4),(.60,-5),(1,0)])
        lean = interpolate(t, [(0,5),(.43,-5),(.60,16),(.70,13),(1,5)])
        twist = interpolate(t, [(0,-2),(.43,8),(.60,-10),(1,-2)])
    else:
        root_z = -.020+.004*sin(phase)
        lean = 1+.6*sin(phase)
    place('Root', rotation(), (0,0,root_z))
    hip_head = anchor('Hips')+Vector((hip_x,0,0))
    place('Hips', rotation(z=hip_twist), hip_head)
    place('Spine', rotation(x=lean, z=twist))
    place('Neck', rotation(x=lean*.45, z=twist*.5))
    head_nod = interpolate(t, [(0,5),(.45,1),(.64,12),(.73,8),(1,5)]) if clip == 'Hammer' else (4 if clip == 'Run' else 1+.35*cos(phase) if clip == 'Idle' else 1)
    place('Head', rotation(x=head_nod, z=twist*.25))
    if clip in ('Run', 'Walk'):
        grounded = [gait_foot(side,t,clip == 'Run') for side in ('L','R')]
        if clip == 'Run' and min(grounded) > .015:
            diagnostics['run_flight_frames'] += 1
        swing = sin(phase-.35)
        running = clip == 'Run'
        grip = (.43, -.24+(.12 if running else .075)*swing,
            1.12+root_z+(.035 if running else .012)*cos(phase))
        carry_hammer(grip, 5+(-9 if running else -5)*swing)
        wrist = (-.40,-.19-(.16 if running else .085)*swing,
            1.10+root_z+.025*cos(phase))
        arm('L', wrist, (-.70,.16,1.12+root_z))
    elif clip == 'Hammer':
        foot('L',-.22,-.11)
        foot('R',.22,.12)
        gx = interpolate(t, [(0,.40),(.43,.42),(.60,.34),(1,.40)])
        gy = interpolate(t, [(0,-.30),(.26,-.15),(.43,-.035),(.60,-.47),(.65,-.49),(.78,-.37),(1,-.30)])
        gz = interpolate(t, [(0,1.15),(.26,1.37),(.43,1.55),(.60,1.00),(.65,.985),(.78,1.10),(1,1.15)])
        tilt = interpolate(t, [(0,30),(.26,-10),(.43,-50),(.60,85),(.65,88),(.78,62),(1,30)])
        carry_hammer((gx,gy,gz),tilt)
        arm('L',(-.42+hip_x,-.28,1.045+root_z),(-.65,.05,1.10+root_z))
    else:
        foot('L',-.20,0)
        foot('R',.20,0)
        carry_hammer((.43,-.24,1.105+root_z),10)
        arm('L',(-.40,-.17,1.045+root_z),(-.67,.08,1.10+root_z))

# One distinct sample for each 1/30 second. The endpoint is for seamless
# source/GLB looping and is excluded from the rendered sprite frames.
clips = {'Idle': (60,60,30), 'Walk': (30,30,30), 'Run': (18,18,30), 'Hammer': (36,36,30)}
actions = {}
scene = bpy.context.scene
scene.render.fps = 30
for name, (duration, count, fps) in clips.items():
    rig.animation_data_create()
    rig.animation_data.action = None
    previous_rotations = {}
    pose_hashes = set()
    start_pose = None
    for frame in range(duration+1):
        pose(name, frame/duration)
        values = [round(v,6) for matrix in posed.values() for row in matrix for v in row]
        if frame < duration:
            pose_hashes.add(hashlib.sha256(json.dumps(values).encode()).hexdigest())
        if start_pose is None:
            start_pose = values
        if frame == duration:
            assert max(abs(a-b) for a,b in zip(start_pose,values)) <= .000002, name+' does not close its loop'
        for pb in rig.pose.bones:
            if pb.name in previous_rotations and pb.rotation_quaternion.dot(previous_rotations[pb.name]) < 0:
                pb.rotation_quaternion.negate()
            previous_rotations[pb.name] = pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion', frame=frame+1)
            pb.keyframe_insert(data_path='location', frame=frame+1)
    action = rig.animation_data.action
    assert len(pose_hashes) == duration, name+' contains duplicate skeletal poses'
    action.name = name
    action.use_fake_user = True
    for slot in action.slots:
        for layer in action.layers:
            for strip in layer.strips:
                for fcurve in strip.channelbag(slot).fcurves:
                    for key in fcurve.keyframe_points:
                        key.interpolation = 'LINEAR'
                    fcurve.modifiers.new(type='CYCLES')
    actions[name] = action
print('BUILDER_POSE_DIAGNOSTICS', json.dumps(diagnostics), flush=True)
assert diagnostics['max_ik_target_error_m'] < .002, 'A limb cannot reach its intended contact target'
assert diagnostics['max_grip_error_m'] < .002, 'The hammer slips out of the hand'
assert diagnostics['min_sole_height_m'] > -.002, 'A boot penetrates the floor'
assert diagnostics['run_flight_frames'] > 0, 'The run has no airborne phase'
rig.animation_data.action = actions['Idle']
scene.frame_start = 1
scene.frame_end = 61
scene.frame_set(1)
root['description'] = '18-bone builder with Idle, Walk, Run and Hammer skeletal clips.'
rig['clips'] = 'Idle / Walk / Run / Hammer; planted-foot IK, 30 fps'
rig['game_forward'] = '-Y in Blender / +Z in glTF'
bpy.ops.wm.save_as_mainfile(filepath=str((FRAMES / 'builder_review.blend') if args.preview else (ASSET / 'builder_rigged.blend')))

# Export skinned meshes by material, preserving vertex groups and the skeleton.
bpy.ops.object.select_all(action='DESELECT')
export_collection = bpy.data.collections.new('EXPORT | skinned meshes')
scene.collection.children.link(export_collection)
by_material = {}
for obj in meshes:
    cp = obj.copy()
    cp.data = obj.data.copy()
    export_collection.objects.link(cp)
    cp.parent = rig
    by_material.setdefault(cp.data.materials[0].name, []).append(cp)
export_meshes = []
for material, copies in by_material.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in copies:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    joined = copies[0]
    joined.name = 'Builder | ' + material
    export_meshes.append(joined)
rig.animation_data.action = None
for name, action in actions.items():
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    track.mute = True
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig, *export_meshes]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
export_props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
options = dict(filepath=str((FRAMES / 'builder_review.glb') if args.preview else (ASSET / 'builder_animated.glb')), export_format='GLB',
    use_selection=True, export_animations=True, export_skins=True, export_extras=True)
if 'export_animation_mode' in export_props:
    options['export_animation_mode'] = 'ACTIONS'
if 'export_all_influences' in export_props:
    options['export_all_influences'] = True
if 'export_anim_slide_to_zero' in export_props:
    options['export_anim_slide_to_zero'] = True
bpy.ops.export_scene.gltf(**options)
for obj in export_meshes:
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.data.collections.remove(export_collection)
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)

# Consistent orthographic framing and foot origin across every clip/direction.
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
size = 512 if args.preview else 256
scene.render.resolution_x = size
scene.render.resolution_y = size
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.view_settings.exposure = -.25
bpy.data.objects['Studio ground'].hide_render = True
cam = scene.camera
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.9
target = Vector((0, 0, 1.08))
cam.location = target + Vector((4, -4, 6))
cam.rotation_euler = (target-cam.location).to_track_quat('-Z', 'Y').to_euler()
bpy.context.view_layer.update()
projected_origin = world_to_camera_view(scene, cam, Vector((0,0,0)))
metadata = {'frame_size': [size,size],
    'ground_anchor': [round(projected_origin.x*size,3), round((1-projected_origin.y)*size,3)],
    'world_scale': 2.9/2.38*.4, 'directions': 8, 'clips': {},
    'pixels_per_metre': size/2.9, 'ground_projection_y': 6/sqrt(68),
    'source': 'assets/units/builder/builder_rigged.blend',
    'direction_order': 'E, SE, S, SW, W, NW, N, NE',
    'skeleton_bones': len(armature.bones)}

# Screen angle zero is east. Projection of 3D forward uses the same map diamond.
for clip, (duration, count, fps) in clips.items():
    rig.animation_data.action = actions[clip]
    metadata['clips'][clip.lower()] = {'frames': count, 'fps': fps,
        'duration': duration/30, 'columns': ceil(count/3), 'rows_per_direction': 3,
        'texture': f'res://assets/sprites/units/builder_{clip.lower()}_sheet.png'}
    if clip in ('Run','Walk'):
        metadata['clips'][clip.lower()]['ground_speed_mps'] = .58/(.20*.6) if clip == 'Run' else .48/.62
    if clip == 'Hammer':
        metadata['clips'][clip.lower()]['impact_phase'] = .60
        metadata['clips'][clip.lower()]['impact_local_m'] = [.34,.71,.91]
    if args.bake_only or (args.preview and clip not in ('Run','Hammer')):
        continue
    for direction in ((1,3) if args.preview else range(8)):
        # Camera is at +X,-Y: east-facing is Blender +X,+Y.
        root.rotation_euler.z = pi*.75 - direction*pi*.25
        indices = sorted(set(int(count*t) for t in (0,.17,.33,.5,.66,.83))) if args.review_keys else range(count)
        for index in indices:
            scene.frame_set(1+round(duration*index/count))
            scene.render.filepath = str(FRAMES / f'{clip.lower()}_{direction}_{index:02d}.png')
            bpy.ops.render.render(write_still=True)
        print(f'BUILDER_ANIMATION_DIRECTION {clip} {direction}', flush=True)
root.rotation_euler.z = 0
rig.animation_data.action = actions['Idle']
scene.frame_set(1)
scene.frame_end = 61
(FRAMES / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
# Save useful rig view, with all animation actions retained.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
(FRAMES / 'pose_diagnostics.json').write_text(json.dumps(diagnostics,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str((FRAMES / 'builder_review.blend') if args.preview else (ASSET / 'builder_rigged.blend')))
print('BUILDER_RIG_COMPLETE', json.dumps(metadata), flush=True)
