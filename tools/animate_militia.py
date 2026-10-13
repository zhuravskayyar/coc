"""Animate the supplied, already skinned militia; render 30 FPS eight-way sprites.

Blender --background --python tools/animate_militia.py [-- --review]
The imported mesh, texture, skeleton and original GLB are preserved.
"""
from pathlib import Path
from math import pi, sin, cos, sqrt, radians, ceil
import argparse, sys, json, hashlib
import bpy
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets/units/militia'
FRAMES = ROOT / '.godot/militia_animation_frames'
ASSET.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument('--review', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(ASSET / 'militia_source.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
rig.name = 'MilitiaRig'
mesh.name = 'Militia | original textured mesh'
scene = bpy.context.scene
scene.render.fps = 30
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
posed = {}
diagnostics = {'source_fps': 30, 'max_target_error': 0., 'min_sole_height': 1., 'run_flight_frames': 0, 'unique_poses': {}}
prefix = 'mixamorig:'
def name(short):
    return prefix + short
def rot(x=0, y=0, z=0):
    return Matrix.Rotation(radians(z), 3, 'Z') @ Matrix.Rotation(radians(y), 3, 'Y') @ Matrix.Rotation(radians(x), 3, 'X')
def anchor(short):
    b = rig.data.bones[name(short)]
    return posed[b.parent.name] @ rest[b.parent.name].inverted() @ b.head_local if b.parent else b.head_local.copy()
def place(short, delta, head=None):
    n = name(short)
    b = rig.data.bones[n]
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
            u = max(0., min(1., (t-a)/(b-a)))
            return va + (vb-va)*u*u*(3-2*u)
    return keys[-1][1]
def limb(first, second, target, pole):
    head = anchor(first)
    target = Vector(target)
    axis = target-head
    a, b = rig.data.bones[name(first)].length, rig.data.bones[name(second)].length
    distance = max(.001, min(axis.length, a+b-.00001))
    direction = axis.normalized()
    bend = Vector(pole)-head
    bend = (bend-direction*bend.dot(direction)).normalized()
    along = (a*a-b*b+distance*distance)/(2*distance)
    joint = head+direction*along+bend*sqrt(max(0., a*a-along*along))
    end = head+direction*distance
    diagnostics['max_target_error'] = max(diagnostics['max_target_error'], (end-target).length)
    for short, h, tail in ((first,head,joint),(second,joint,end)):
        bone = rig.data.bones[name(short)]
        delta = (bone.tail_local-bone.head_local).normalized().rotation_difference((tail-h).normalized()).to_matrix()
        place(short, delta, h)
    return end

# Evaluate the original bind pose: glTF's raw mesh bounds are not the skinned bounds.
bpy.context.view_layer.update()
evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
source_points = [mesh.matrix_world @ v.co for v in evaluated.vertices]
ground = min(p.z for p in source_points)
height = max(p.z for p in source_points)-ground
sole = {}
for side in ('Left','Right'):
    ids = {g.index for g in mesh.vertex_groups if g.name in {name(side+'Foot'),name(side+'ToeBase'),name(side+'Toe_End')}}
    ankle = rest[name(side+'Foot')].translation
    sole[side] = [source_points[v.index]-ankle for v in mesh.data.vertices
                  if sum(g.weight for g in v.groups if g.group in ids) > .5 and source_points[v.index].z < ground+.045]
    assert sole[side], 'No weighted sole vertices found'
mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
print('MILITIA_SOURCE', json.dumps({'height':height,'ground':ground,'vertices':len(source_points)}), flush=True)

def foot(side, x, y, lift=0, pitch=0):
    sign = 1 if side == 'Left' else -1
    delta = rot(x=pitch,z=-sign*19)
    low = min((delta @ p).z for p in sole[side])
    target = (x,y,ground-low+lift)
    end = limb(side+'UpLeg',side+'Leg',target,(x,-.45,.25))
    place(side+'Foot',delta,end)
    # Toe flex happens at toe-off; the rest of the foot remains rigid.
    place(side+'ToeBase',delta)
    place(side+'Toe_End',delta)
    diagnostics['min_sole_height'] = min(diagnostics['min_sole_height'],end.z+low-ground)
    return lift
def hand(side, wrist, pole, fist=False):
    end = limb(side+'Arm',side+'ForeArm',wrist,pole)
    delta = posed[name(side+'ForeArm')].to_3x3() @ rest[name(side+'ForeArm')].to_3x3().inverted()
    place(side+'Hand',delta,end)
    # Curl using each finger's local flexion axis, preserving the supplied skin weights.
    for finger in ('Index','Middle','Ring','Pinky','Thumb'):
        for segment in range(1,5):
            short = side+'Hand'+finger+str(segment)
            n = name(short)
            b = rig.data.bones[n]
            parent = posed[b.parent.name] @ rest[b.parent.name].inverted()
            desired = parent @ rest[n]
            bend = ((45,70,60,0)[segment-1] if finger!='Thumb' else (30,35,25,0)[segment-1]) if fist else (7 if segment<3 else 0)
            direction=(b.tail_local-b.head_local).normalized()
            curl_axis=direction.cross(Vector((0,0,-1))).normalized()
            local_axis=rest[n].to_3x3().inverted() @ curl_axis
            desired = desired @ Matrix.Rotation(radians(bend),4,local_axis)
            pb = rig.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis = rest[n].inverted() @ rest[b.parent.name] @ posed[b.parent.name].inverted() @ desired
            posed[n] = desired

def gait(side,t,running):
    u=(t+(0 if side=='Left' else .5)) % 1
    stance=.30 if running else .62
    front,back=(-.205,.055) if running else (-.165,.035)
    if u < stance:
        s=u/stance
        y=front+(back-front)*s
        lift=0
        pitch=curve(s,[(0,-8),(.18,0),(.7,0),(1,23 if running else 16)])
    else:
        s=(u-stance)/(1-stance)
        tangent=(back-front)/stance*(1-stance)
        y=(2*s**3-3*s*s+1)*back+(s**3-2*s*s+s)*tangent+(-2*s**3+3*s*s)*front+(s**3-s*s)*tangent
        lift=(.15 if running else .04)*sin(pi*s)**(1.0 if running else 1.4)
        pitch=curve(s,[(0,23 if running else 16),(.32,40 if running else 20),(.72,-12),(1,-8)])
    return foot(side,(1 if side=='Left' else -1)*.09,y,lift,pitch)

def pose(clip,t):
    posed.clear()
    phase=2*pi*t
    drop=-.018+.0025*sin(phase)
    lean=1+.4*sin(phase)
    hip_x=.002*sin(phase)
    twist=0
    if clip=='Walk':
        drop=-.027-.006*cos(2*phase)
        lean=3
        hip_x=.004*sin(phase)
        twist=3*sin(phase)
    elif clip=='Run':
        drop=curve((t%.5)*2,[(0,-.035),(.18,-.052),(.48,-.02),(.75,.012),(1,-.035)])
        lean=11
        hip_x=.003*sin(phase)
        twist=5*sin(phase)
    elif clip=='Attack':
        drop=curve(t,[(0,-.024),(.30,-.035),(.48,-.032),(.62,-.025),(1,-.024)])
        lean=curve(t,[(0,3),(.30,-3),(.48,12),(.62,8),(1,3)])
        twist=curve(t,[(0,-5),(.30,15),(.48,-17),(.62,-10),(1,-5)])
        hip_x=curve(t,[(0,0),(.3,-.01),(.48,.01),(1,0)])
    hips=rest[name('Hips')].translation+Vector((hip_x,0,drop))
    place('Hips',rot(z=-twist*.35),hips)
    for short,factor in (('Spine',.4),('Spine1',.7),('Spine2',1)):
        place(short,rot(x=lean*factor,z=twist*factor))
    place('Neck',rot(x=lean*.35,z=twist*.3))
    look=.8*cos(phase) if clip=='Idle' else 0
    place('Head',rot(x=lean*.2,z=twist*.15+look))
    place('HeadTop_End',rot(x=lean*.2,z=twist*.15+look))
    for side in ('Left','Right'):
        place(side+'Shoulder',rot(x=lean,z=twist))
    if clip in ('Walk','Run'):
        lifts=[gait(side,t,clip=='Run') for side in ('Left','Right')]
        if clip=='Run' and min(lifts)>.008:
            diagnostics['run_flight_frames']+=1
        for side,sign in (('Left',1),('Right',-1)):
            running=clip=='Run'
            swing=sin(phase-.15)*sign
            hand(side,(sign*.16,-.13+(.10 if running else .065)*swing,(.57 if running else .50)+drop+.008*cos(phase)),
                 (sign*.30,.05,(.52 if running else .46)+drop))
    elif clip=='Attack':
        foot('Left',.09,-.12)
        foot('Right',-.09,.005)
        wrist_y=curve(t,[(0,-.19),(.30,-.08),(.48,-.302),(.55,-.29),(.75,-.2),(1,-.19)])
        wrist_x=curve(t,[(0,-.15),(.30,-.18),(.48,-.10),(.55,-.10),(1,-.15)])
        wrist_z=curve(t,[(0,.63),(.30,.65),(.48,.655),(.55,.65),(1,.63)])+drop
        hand('Right',(wrist_x,wrist_y,wrist_z),(-.29,.035,.58),True)
        hand('Left',(.15,-.19,.615+drop),(.29,.02,.55),True)
    else:
        foot('Left',.09,-.055)
        foot('Right',-.09,-.055)
        for side,sign in (('Left',1),('Right',-1)):
            hand(side,(sign*.16,-.11,.49+drop+.002*sin(phase)),(sign*.30,.025,.48+drop))

counts={'Idle':60,'Walk':30,'Run':20,'Attack':30}
actions={}
for clip,count in counts.items():
    rig.animation_data_create()
    rig.animation_data.action=None
    hashes=set()
    initial=None
    previous={}
    for index in range(count+1):
        pose(clip,index/count)
        values=[round(v,6) for m in posed.values() for row in m for v in row]
        if index<count:
            hashes.add(hashlib.sha256(json.dumps(values).encode()).hexdigest())
        if index==0:
            initial=values
        if index==count:
            assert max(abs(a-b) for a,b in zip(initial,values))<.000003, clip+' loop seam'
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name])<0:
                pb.rotation_quaternion.negate()
            previous[pb.name]=pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion',frame=index+1)
            pb.keyframe_insert(data_path='location',frame=index+1)
    action=rig.animation_data.action
    action.name=clip
    action.use_fake_user=True
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:
                        key.interpolation='LINEAR'
                    fc.modifiers.new('CYCLES')
    actions[clip]=action
    assert len(hashes)==count, clip+' duplicate source poses'
    diagnostics['unique_poses'][clip]=len(hashes)
print('MILITIA_DIAGNOSTICS',json.dumps(diagnostics),flush=True)
assert diagnostics['max_target_error']<.003, 'Unreachable limb target'
assert diagnostics['min_sole_height']>-.003, 'Sole penetrates ground'
assert diagnostics['run_flight_frames']>0, 'Run needs an airborne phase'

# Keep actual supplied texture; studio lighting only affects sprite rendering.
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=256
scene.render.resolution_y=256
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.world.color=(.3,.3,.3)
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=.2
target=Vector((0,-.04,ground+height*.5))
for title,loc,power,size in [('Key',(2,-3,4),750,4),('Fill',(-3,-1,2),450,3),('Rim',(1,3,3),650,3)]:
    bpy.ops.object.light_add(type='AREA',location=target+Vector(loc))
    lamp=bpy.context.object
    lamp.name='Studio '+title
    lamp.data.energy=power
    lamp.data.size=size
    lamp.rotation_euler=(target-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add()
cam=bpy.context.object
scene.camera=cam
cam.data.type='ORTHO'
cam.data.ortho_scale=1.52
cam.location=target+Vector((4,-4,6))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.empty_add(type='PLAIN_AXES')
root=bpy.context.object
root.name='Militia'
rig.parent=root
root['description']='Opolchenets; original 65-bone rig; Idle/Walk/Run/Attack at 30 FPS'
rig.animation_data.action=actions['Idle']
scene.frame_set(1)
scene.frame_end=61
bpy.ops.wm.save_as_mainfile(filepath=str(ASSET/'militia_animated.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in (root,rig,mesh):
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ASSET/'militia_animated.glb'),export_format='GLB',use_selection=True,
    export_animations=True,export_skins=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_extras=True)
bpy.context.view_layer.update()
origin=world_to_camera_view(scene,cam,Vector((0,0,ground)))
metadata={'frame_size':[256,256],'ground_anchor':[round(origin.x*256,3),round((1-origin.y)*256,3)],
          'world_scale':.50,'directions':8,'pixels_per_metre':256/1.52,'ground_projection_y':6/sqrt(68),
          'source':'assets/units/militia/militia_animated.blend','skeleton_bones':len(rig.data.bones),
          'direction_order':'E, SE, S, SW, W, NW, N, NE','clips':{}}
for clip,count in counts.items():
    key=clip.lower()
    metadata['clips'][key]={'frames':count,'fps':30,'duration':count/30,'columns':ceil(count/3),'rows_per_direction':3,
                            'texture':f'res://assets/sprites/units/militia_{key}_sheet.png'}
    if clip in ('Walk','Run'):
        metadata['clips'][key]['ground_speed_mps']=(.26/(.30*(count/30))) if clip=='Run' else .20/.62
    rig.animation_data.action=actions[clip]
    for direction in ((1,3,5) if args.review else range(8)):
        root.rotation_euler.z=pi*.75-direction*pi*.25
        indices=sorted({int(count*p) for p in (0,.17,.30,.48,.67,.83)}) if args.review else range(count)
        for index in indices:
            scene.frame_set(index+1)
            out=FRAMES/f'{key}_{direction}_{index:02d}.png'
            scene.render.filepath=str(out)
            bpy.ops.render.render(write_still=True)
        print('MILITIA_DIRECTION',clip,direction,flush=True)
(FRAMES/'metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
(FRAMES/'diagnostics.json').write_text(json.dumps(diagnostics,indent=2),encoding='utf-8')
root.rotation_euler.z=0
rig.animation_data.action=actions['Idle']
scene.frame_set(1)
print('MILITIA_COMPLETE',flush=True)
