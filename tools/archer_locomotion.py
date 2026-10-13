"""Retarget Quaternius UAL's authored locomotion onto the supplied Mixamo rig.

No walking trajectory is generated here. Targets and rotations are sampled from
the licensed source animation, then fitted to the archer's leg proportions.
"""
from math import floor
from statistics import median
import bpy
from mathutils import Matrix, Vector

STRIDE = {'Walk': .9, 'Run': .6}
SOURCE_CLIPS = {'Walk': 'Walk_Loop', 'Run': 'Jog_Fwd_Loop'}
MAP = {'Hips': 'pelvis', 'Spine': 'spine_01', 'Spine1': 'spine_02',
       'Spine2': 'spine_03', 'Neck': 'neck_01', 'Head': 'Head'}
for side, suffix in [('Left', 'l'), ('Right', 'r')]:
    MAP.update({side + target: source + '_' + suffix for target, source in [
        ('UpLeg', 'thigh'), ('Leg', 'calf'), ('Foot', 'foot'),
        ('ToeBase', 'ball'), ('Toe_End', 'ball_leaf')]})


class Locomotion:
    def __init__(self, root, target_rig):
        before_objects, before_actions = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(root / 'assets/animations/quaternius/UAL1_Standard.glb'))
        objects = set(bpy.data.objects) - before_objects
        rig = next(o for o in objects if o.type == 'ARMATURE')
        source_mesh = next(o for o in objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers))
        sole_vertices = {side: [v.index for v in source_mesh.data.vertices
                               if v.co.z < .23 and (v.co.x > 0) == (side == 'Left')]
                         for side in ('Left', 'Right')}
        rest = {n: rig.data.bones[n].matrix_local.copy() for n in MAP.values()}
        source_leg = rig.data.bones['thigh_l'].length + rig.data.bones['calf_l'].length
        target_leg = sum(target_rig.data.bones['mixamorig:' + n].length for n in ('LeftUpLeg', 'LeftLeg'))
        self.scale = target_leg / source_leg
        self.rest = rest
        self.clips = {}
        # Four real samples per 30 FPS frame also provide honest slow-motion previews.
        for clip, name in SOURCE_CLIPS.items():
            action = next(a for a in set(bpy.data.actions) - before_actions if a.name == name)
            rig.animation_data.action = action
            count = round(action.frame_range.y - action.frame_range.x)
            samples = []
            soles = []
            for index in range(count * 4 + 1):
                frame = action.frame_range.x + index / 4
                bpy.context.scene.frame_set(floor(frame), subframe=frame % 1)
                bpy.context.view_layer.update()
                samples.append({target: (rig.pose.bones[source].head.copy(),
                                (rig.pose.bones[source].matrix.to_3x3() @ rest[source].to_3x3().inverted()).to_quaternion())
                                for target, source in MAP.items()})
                evaluated = source_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
                evaluated_mesh = evaluated.to_mesh()
                soles.append({side: max(0.0, min(evaluated_mesh.vertices[i].co.z for i in indices))
                              for side, indices in sole_vertices.items()})
                evaluated.to_mesh_clear()
            # Measure the planted sole, rather than trusting the pack's root-motion distance.
            velocities = []
            for side in ('Left', 'Right'):
                name = side + 'ToeBase'
                key_samples = samples[::4]
                lowest = min(s[name][0].z for s in key_samples)
                for a, b in zip(key_samples, key_samples[1:]):
                    if max(a[name][0].z, b[name][0].z) < lowest + .003:
                        velocity = (b[name][0].y - a[name][0].y) * 30
                        if velocity > .2:
                            velocities.append(velocity)
            self.clips[clip] = {'frames': count, 'samples': samples,
                                'soles': soles, 'source_speed': median(velocities), 'source_clip': SOURCE_CLIPS[clip]}
        for obj in objects:
            bpy.data.objects.remove(obj, do_unlink=True)
        for action in set(bpy.data.actions) - before_actions:
            bpy.data.actions.remove(action)

    def sample(self, clip, phase):
        data = self.clips[clip]
        value = (phase % 1) * data['frames'] * 4
        index, blend = floor(value), value % 1
        a, b = data['samples'][index:index + 2]
        return {n: (a[n][0].lerp(b[n][0], blend), a[n][1].slerp(b[n][1], blend)) for n in a}

    def speed(self, clip):
        return self.clips[clip]['source_speed'] * self.scale * STRIDE[clip]

    def apply(self, clip, phase, rest, place, limb):
        sample = self.sample(clip, phase)
        hip_delta = (sample['Hips'][0] - self.rest['pelvis'].translation) * self.scale
        # Preserve source weight transfer. The target's feet have a different sole height.
        hips = rest['mixamorig:Hips'].translation + hip_delta + Vector((0, 0, -.014))
        place('Hips', sample['Hips'][1].to_matrix(), hips)
        for name in ('Spine', 'Spine1', 'Spine2', 'Neck', 'Head'):
            place(name, sample[name][1].to_matrix())
        place('HeadTop_End', sample['Head'][1].to_matrix())
        for side in ('Left', 'Right'):
            source = self.rest[MAP[side + 'UpLeg']].translation
            target = rest['mixamorig:' + side + 'UpLeg'].translation
            ankle = target + (sample[side + 'Foot'][0] - source) * self.scale
            ankle.y = target.y + (ankle.y - target.y) * STRIDE[clip]
            ankle.z -= .014
            knee = target + (sample[side + 'Leg'][0] - source) * self.scale
            end = limb(side + 'UpLeg', side + 'Leg', ankle, knee)
            for part in ('Foot', 'ToeBase', 'Toe_End'):
                name = side + part
                place(name, sample[name][1].to_matrix(), end if part == 'Foot' else None)
        return hip_delta

    def fit_soles(self, clip, phase, mesh, posed, place, limb):
        """Fit the real skinned boots to the source's measured contact plane."""
        data = self.clips[clip]
        value = (phase % 1) * data['frames'] * 4
        index, blend = floor(value), value % 1
        sample = self.sample(clip, phase)
        if not hasattr(self, 'target_soles'):
            self.target_soles = {side: [v.index for v in mesh.data.vertices
                                      if v.co.z < .12 and (v.co.x > 0) == (side == 'Left')]
                                for side in ('Left', 'Right')}
        desired = {side: ((1 - blend) * data['soles'][index][side] + blend * data['soles'][index + 1][side]) * self.scale
                   for side in ('Left', 'Right')}
        for attempt in range(3):
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            evaluated_mesh = evaluated.to_mesh()
            errors = {side: desired[side] - min(evaluated_mesh.vertices[i].co.z for i in indices)
                      for side, indices in self.target_soles.items()}
            evaluated.to_mesh_clear()
            for side, error in errors.items():
                ankle = posed['mixamorig:' + side + 'Foot'].translation.copy()
                ankle.z += error
                knee = posed['mixamorig:' + side + 'Leg'].translation.copy()
                end = limb(side + 'UpLeg', side + 'Leg', ankle, knee)
                for part in ('Foot', 'ToeBase', 'Toe_End'):
                    name = side + part
                    place(name, sample[name][1].to_matrix(), end if part == 'Foot' else None)
        return desired
