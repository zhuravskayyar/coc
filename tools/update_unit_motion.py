"""Bake fitted CC0 locomotion and corrected unit actions at 60 FPS into GLB.

Run: python3 tools/update_unit_motion.py. NumPy/SciPy are authoring tools only.
Geometry, UVs, materials, bind matrices and bone hierarchy stay intact.
"""
from pathlib import Path
from copy import deepcopy
import json
import numpy as np
from scipy.spatial.transform import Rotation
from gltf_motion import GLB,Rig,rot,slerp

ROOT=Path(__file__).resolve().parents[1]
SOURCE=GLB(ROOT/'assets/animations/quaternius/UAL1_Standard.glb')
SR=Rig(SOURCE)
MAP={'Hips':'pelvis','Spine':'spine_01','Spine1':'spine_02','Spine2':'spine_03','Neck':'neck_01','Head':'Head','HeadTop_End':'Head'}
for side,suffix in [('Left','l'),('Right','r')]:
    MAP.update({side+target:source+'_'+suffix for target,source in [('Shoulder','clavicle'),('Arm','upperarm'),('ForeArm','lowerarm'),('Hand','hand'),('UpLeg','thigh'),('Leg','calf'),('Foot','foot'),('ToeBase','ball'),('Toe_End','ball_leaf')]})
    for finger in ['Index','Middle','Ring','Pinky','Thumb']:
        for j in range(1,5):MAP[side+'Hand'+finger+str(j)]=finger.lower()+('_04_leaf_' if j==4 else f'_0{j}_')+suffix


def curve(t,keys):
    for (a,va),(b,vb) in zip(keys,keys[1:]):
        if t<=b:
            u=np.clip((t-a)/(b-a),0,1);u=u*u*(3-2*u)
            return np.asarray(va)*(1-u)+np.asarray(vb)*u
    return np.asarray(keys[-1][1])


def foot_masks(r):
    p=np.concatenate([d[1] for d in r.skin_data]);j=np.concatenate([d[2] for d in r.skin_data]);w=np.concatenate([d[3] for d in r.skin_data])
    masks={}
    for side in ['Left','Right']:
        names=[side+n for n in ['Foot','ToeBase','Toe_End']] if 'LeftFoot' in r.names else [n+('_l' if side=='Left' else '_r') for n in ['foot','ball','ball_leaf']]
        ids=[r.joints.index(r.index(n)) for n in names]
        masks[side]=(np.sum(w*np.isin(j,ids),axis=1)>.35)&(p[:,1]<p[:,1].min()+.14)
        assert masks[side].sum()>8
    return masks


def fit_feet(r,masks,desired):
    for _ in range(3):
        for side,mask in masks.items():
            error=desired[side]-r.deform(mask)[:,1].min()
            if abs(error)<.00005:continue
            rotations={part:r.posed[r.index(side+part),:3,:3]@np.linalg.inv(r.rest[r.index(side+part),:3,:3]) for part in ['Foot','ToeBase','Toe_End']}
            target=r.point(side+'Foot');target[1]+=error
            knee=r.point(side+'Leg');knee[2]+=.04
            end=r.limb(side+'UpLeg',side+'Leg',side+'Foot',target,knee)
            r.place(side+'Foot',rotations['Foot'],end)
            for part in ['ToeBase','Toe_End']:r.place(side+part,rotations[part])


def idle(r,phase,builder=False):
    r.posed=r.rest.copy();a=2*np.pi*phase
    hips=r.rest[r.index('Hips'),:3,3]+[.002*np.sin(a),-.020+.0025*np.sin(a),0]
    r.place('Hips',rot(y=.7*np.sin(a)),hips)
    for name in ['Spine','Spine1','Spine2']:r.place(name,rot(x=-1.2-.3*np.sin(a),y=.5*np.sin(a)))
    r.place('Neck',rot(y=.5*np.cos(a)))
    r.place('Head',rot(x=.35*np.sin(a),y=1.1*np.cos(a)))
    r.descendants(r.index('Head'))
    for side,sign in [('Left',1),('Right',-1)]:
        r.place(side+'Shoulder',rot(x=-1.2-.3*np.sin(a),y=.5*np.sin(a)))
        target=[sign*(.18 if builder else .16),(.485 if builder else .48)+.002*np.sin(a),.08 if side=='Left' and builder else .10]
        if builder and side=='Right':target=[-.18,.51+.002*np.sin(a),.07]
        end=r.limb(side+'Arm',side+'ForeArm',side+'Hand',target,[sign*.31,.49,-.06])
        delta=rot(y=-40,z=-75) if side=='Left' and builder else r.posed[r.index(side+'ForeArm'),:3,:3]@np.linalg.inv(r.rest[r.index(side+'ForeArm'),:3,:3])
        r.place(side+'Hand',delta,end);r.descendants(r.index(side+'Hand'))
        target=r.rest[r.index(side+'Foot'),:3,3].copy();target[2]+=.015
        end=r.limb(side+'UpLeg',side+'Leg',side+'Foot',target,[sign*.12,.22,.24])
        r.place(side+'Foot',np.eye(3),end);r.descendants(r.index(side+'Foot'))


class AuthoredMotion:
    def __init__(self,r):
        self.r=r
        self.scale=np.linalg.norm(r.rest[r.index('LeftUpLeg'),:3,3]-r.rest[r.index('LeftLeg'),:3,3])+np.linalg.norm(r.rest[r.index('LeftLeg'),:3,3]-r.rest[r.index('LeftFoot'),:3,3])
        self.scale/=np.linalg.norm(SR.rest[SR.index('thigh_l'),:3,3]-SR.rest[SR.index('calf_l'),:3,3])+np.linalg.norm(SR.rest[SR.index('calf_l'),:3,3]-SR.rest[SR.index('foot_l'),:3,3])
        self.masks=foot_masks(SR)
    def apply(self,name,time,builder=False):
        r=self.r;animation=next(a for a in SOURCE.doc['animations'] if a['name']==name)
        SR.posed=SOURCE.sample(animation,time);source=SR.posed
        r.posed=r.rest.copy()
        for i in r.order:
            short=r.glb.doc['nodes'][i]['name'].replace('mixamorig:','')
            source_name=MAP.get(short)
            if not source_name or (builder and 'Hand' in short and short not in ['LeftHand','RightHand']):r.inherit(i);continue
            si=SR.index(source_name)
            delta=source[si,:3,:3]@np.linalg.inv(SR.rest[si,:3,:3])
            head=r.rest[i,:3,3]+(source[si,:3,3]-SR.rest[si,:3,3])*self.scale if short=='Hips' else None
            if head is not None:head[1]-=.014
            r.place(i,delta,head)
        if name in ['Walk_Loop','Jog_Fwd_Loop']:
            stride=.9 if name=='Walk_Loop' else .6
            for side in ['Left','Right']:
                origin=SR.rest[SR.index(MAP[side+'UpLeg']),:3,3]
                base=r.rest[r.index(side+'UpLeg'),:3,3]
                ankle=base+(source[SR.index(MAP[side+'Foot']),:3,3]-origin)*self.scale
                ankle[2]=base[2]+(ankle[2]-base[2])*stride;ankle[1]-=.014
                knee=base+(source[SR.index(MAP[side+'Leg']),:3,3]-origin)*self.scale
                end=r.limb(side+'UpLeg',side+'Leg',side+'Foot',ankle,knee)
                for part in ['Foot','ToeBase','Toe_End']:
                    si=SR.index(MAP[side+part]);delta=source[si,:3,:3]@np.linalg.inv(SR.rest[si,:3,:3])
                    r.place(side+part,delta,end if part=='Foot' else None)
        if builder:
            # Preserve the supplied closed glove and keep the hammer in a carrying grip.
            target=r.point('LeftHand');target[2]=np.clip(target[2],-.06,.12)
            target[0]=max(target[0],.14);target[1]=max(target[1],.46)
            end=r.limb('LeftArm','LeftForeArm','LeftHand',target,[.32,.49,-.08])
            r.place('LeftHand',rot(y=-40,z=-75,x=4*np.sin(time*2*np.pi)),end);r.descendants(r.index('LeftHand'))
        return {side:max(0,SR.deform(mask)[:,1].min())*self.scale for side,mask in self.masks.items()}


def hammer(r,phase):
    idle(r,phase,True)
    # Slow windup, quick impact, follow-through, then recovery; reachable wrist targets.
    wrist=curve(phase,[(0,[.18,.485,.08]),(.18,[.15,.70,.05]),(.42,[.14,.755,-.015]),(.60,[.13,.55,.15]),(.69,[.14,.535,.14]),(.82,[.16,.55,.10]),(1,[.18,.485,.08])])
    angles=curve(phase,[(0,[0,-40,-75]),(.18,[-25,-90,0]),(.42,[-65,-90,12]),(.60,[60,-90,-20]),(.69,[80,-90,-20]),(.82,[40,-90,-20]),(1,[0,-40,-75])])
    lean=float(curve(phase,[(0,0),(.42,-2),(.60,3),(.69,2),(1,0)]))
    for name in ['Spine','Spine1','Spine2']:r.place(name,rot(x=-1.2-lean,y=.5*np.sin(2*np.pi*phase)))
    r.place('Neck',rot(x=-lean*.2,y=.5*np.cos(2*np.pi*phase)))
    r.place('Head',rot(x=.35*np.sin(2*np.pi*phase)-lean*.15,y=1.1*np.cos(2*np.pi*phase)));r.descendants(r.index('Head'))
    for side in ['Left','Right']:
        r.place(side+'Shoulder',rot(x=-1.2-lean))
    end=r.limb('LeftArm','LeftForeArm','LeftHand',wrist,[.34,.60,-.10])
    r.place('LeftHand',rot(*angles),end);r.descendants(r.index('LeftHand'))
    right=curve(phase,[(0,[-.18,.51,.07]),(.18,[-.15,.52,.08]),(.82,[-.15,.52,.08]),(1,[-.18,.51,.07])])
    end=r.limb('RightArm','RightForeArm','RightHand',right,[-.29,.49,-.04])
    r.place('RightHand',r.posed[r.index('RightForeArm'),:3,:3]@np.linalg.inv(r.rest[r.index('RightForeArm'),:3,:3]),end);r.descendants(r.index('RightHand'))


def bake_unit(kind):
    source=ROOT/f'assets/units/{kind}/{kind}_source.glb'
    g=GLB(source);r=Rig(g);masks=foot_masks(r);motion=AuthoredMotion(r)
    if kind=='builder':
        p,pos,ids,weights=r.skin_data[0]
        fixed=((pos[:,0]>.365)&(pos[:,1]>.49))|((pos[:,0]>.345)&(pos[:,1]>.705))
        hand=r.joints.index(r.index('LeftHand'))
        ids[fixed]=[hand,0,0,0];weights[fixed]=[1,0,0,0]
        p['attributes']['JOINTS_0']=g.add(ids,'VEC4',5123);p['attributes']['WEIGHTS_0']=g.add(weights,'VEC4')
        g.doc['nodes'][65]['name']='Builder | supplied skinned mesh'
        marker=np.linalg.inv(r.rest[r.index('LeftHand')])@np.array([.487,.770,-.005,1])
        mi=len(g.doc['nodes']);g.doc['nodes'].append({'name':'HammerImpact','translation':marker[:3].tolist()})
        g.doc['nodes'][r.index('LeftHand')].setdefault('children',[]).append(mi)
        # Rig was constructed before the marker; append its bind transform for baking.
        r.rest=np.concatenate([r.rest,(r.rest[r.index('LeftHand')]@np.array([[1,0,0,marker[0]],[0,1,0,marker[1]],[0,0,1,marker[2]],[0,0,0,1]]))[None]])
        r.posed=r.rest.copy()
        print('Builder rigid glove/hammer vertices',int(fixed.sum()),flush=True)
    g.doc['animations']=[]
    clips={'Idle':(2.,60),'Walk':(80/60,80),'Run':(56/60,56),'Hammer' if kind=='builder' else 'Attack':(1.2 if kind=='builder' else 1.,72 if kind=='builder' else 60)}
    stats={}
    for name,(duration,count) in clips.items():
        r.max_ik_error=0.0;r.max_ik_context={}
        frames=[];heights=[]
        for i in range(count+1):
            phase=i/count
            if name=='Idle':idle(r,phase,kind=='builder');desired={'Left':.0003,'Right':.0003}
            elif name in ['Walk','Run']:desired=motion.apply('Walk_Loop' if name=='Walk' else 'Jog_Fwd_Loop',0 if i==count else i/60,kind=='builder')
            elif name=='Hammer':hammer(r,phase);desired={'Left':.0003,'Right':.0003}
            else:
                idle(r,phase);base=r.posed.copy()
                motion.apply('Punch_Cross',phase);target=r.posed.copy()
                blend=float(curve(phase,[(0,0),(.15,1),(.78,1),(1,0)]))
                for j in r.order:
                    q=slerp(Rotation.from_matrix(base[j,:3,:3]).as_quat(),Rotation.from_matrix(target[j,:3,:3]).as_quat(),blend)
                    delta=Rotation.from_quat(q).as_matrix()@np.linalg.inv(r.rest[j,:3,:3])
                    r.place(j,delta,(1-blend)*base[j,:3,3]+blend*target[j,:3,3] if j==r.index('Hips') else None)
                for side in ['Left','Right']:
                    end=r.limb(side+'UpLeg',side+'Leg',side+'Foot',base[r.index(side+'Foot'),:3,3],[.12 if side=='Left' else -.12,.25,.3])
                    r.place(side+'Foot',np.eye(3),end);r.descendants(r.index(side+'Foot'))
                # A subtle head adjustment also keeps the brief held guard alive.
                r.place('Head',rot(y=.18*np.sin(2*np.pi*phase)));r.descendants(r.index('Head'))
                desired={'Left':.0003,'Right':.0003}
            fit_feet(r,masks,desired)
            frames.append(r.posed.copy());heights.append(float(r.deform()[:,1].min()))
        g.bake(name,np.linspace(0,duration,count+1),frames,r.joints)
        stats[name]={'frames':count,'fps':count/duration,'duration':duration,'min_sole_m':min(heights),'max_ik_error_m':r.max_ik_error,'worst_ik_target':r.max_ik_context}
        assert len({np.round(f[r.joints],8).tobytes() for f in frames[:-1]})==count,(kind,name,'duplicate pose')
        assert np.max(np.abs(frames[0][r.joints]-frames[-1][r.joints]))<.00001,(kind,name,'loop seam')
        print(kind,name,stats[name],flush=True)
    r.bake_rest_nodes()
    g.save(ROOT/f'assets/units/{kind}/{kind}_animated.glb')
    return stats


def bake_archer():
    path=ROOT/'assets/units/archer/archer_animated.glb';g=GLB(path);r=Rig(g);masks=foot_masks(r)
    reference=ROOT/'assets/units/archer/archer_motion_reference.npz'
    if not reference.exists():
        records={}
        for a in g.doc['animations']:
            duration=max(float(g.accessor(s['input'])[-1,0]) for s in a['samplers'])
            count=round(duration*60)
            records[a['name']]=np.array([g.sample(a,i/60) for i in range(count+1)])
        np.savez_compressed(reference,**records)
    records=np.load(reference)
    originals=deepcopy(g.doc['animations']);g.doc['animations']=[];stats={}
    for old in originals:
        name=old['name'];original=records[name];count=len(original)-1;frames=[];heights=[]
        for i,pose in enumerate(original):
            r.posed=pose.copy();phase=i/count
            # Choose elbow planes anatomically while retaining both wrist world poses.
            for side in ['Left','Right']:
                hand=r.posed[r.index(side+'Hand')].copy()
                shoulder=r.point(side+'Arm')
                draw=float(curve(i/60,[(0,0),(.17,0),(.32,1),(.55,1),(.8,0),(.9,0)])) if name=='archer_shoot' else 0.
                old_pole=r.point(side+'ForeArm')
                goal=np.array([shoulder[0]+(.16 if side=='Left' else -.06),hand[1,3]-.004 if side=='Right' else hand[1,3]-.025,hand[2,3]-.25 if side=='Right' else hand[2,3]-.05])
                pole=old_pole*(1-draw)+goal*draw
                end=r.limb(side+'Arm',side+'ForeArm',side+'Hand',hand[:3,3],pole)
                assert np.linalg.norm(end-hand[:3,3])<.002
                r.posed[r.index(side+'Hand')]=hand
            desired={side:.0003 if name in ['Idle','archer_shoot'] else max(0,r.deform(mask)[:,1].min()) for side,mask in masks.items()}
            fit_feet(r,masks,desired)
            frames.append(r.posed.copy());heights.append(float(r.deform()[:,1].min()))
        g.bake(name,np.arange(count+1)/60,frames,r.joints)
        new=g.doc['animations'][-1]
        for c in old['channels']:
            if c['target']['node'] in r.joints:continue
            channel=deepcopy(c);channel['sampler']=len(new['samplers'])
            new['samplers'].append(deepcopy(old['samplers'][c['sampler']]));new['channels'].append(channel)
        stats[name]={'frames':count,'fps':60,'duration':count/60,'min_sole_m':min(heights)}
        print('archer',name,stats[name],flush=True)
    g.save(path)
    return stats


if __name__=='__main__':
    report={'archer':bake_archer(),'militia':bake_unit('militia'),'builder':bake_unit('builder')}
    (ROOT/'docs/unit-motion-validation.json').write_text(json.dumps(report,indent=2))
