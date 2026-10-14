"""Meaningful source checks: mesh fidelity, planted soles, seams and rigid grip."""
from pathlib import Path
import json,subprocess
import numpy as np
from gltf_motion import GLB,Rig

ROOT=Path(__file__).resolve().parents[1]
results={};checks=0


def check(value,label):
    global checks
    assert value,label
    checks+=1


for kind in ['archer','militia','builder']:
    animated=GLB(ROOT/f'assets/units/{kind}/{kind}_animated.glb');r=Rig(animated)
    if kind=='archer':
        reference=ROOT/'.godot/unit_motion/original-archer.glb';reference.parent.mkdir(parents=True,exist_ok=True)
        reference.write_bytes(subprocess.check_output(['git','show','HEAD:assets/units/archer/archer_animated.glb'],cwd=ROOT))
        source=GLB(reference)
    else:source=GLB(ROOT/f'assets/units/{kind}/{kind}_source.glb')
    check(len(r.joints)==65,kind+' complete skeleton')
    check(animated.doc['materials']==source.doc['materials'],kind+' original materials')
    check(np.allclose(animated.accessor(animated.doc['skins'][0]['inverseBindMatrices']),source.accessor(source.doc['skins'][0]['inverseBindMatrices']),atol=1e-7),kind+' preserved bind matrices')
    for before,after in zip(source.doc['meshes'],animated.doc['meshes']):
        for a,b in zip(before['primitives'],after['primitives']):
            for key in ['POSITION','NORMAL','TEXCOORD_0']:
                check(np.array_equal(source.accessor(a['attributes'][key]),animated.accessor(b['attributes'][key])),kind+' original '+key)
            check(np.array_equal(source.accessor(a['indices']),animated.accessor(b['indices'])),kind+' original triangles')
            for ta,tb in zip(a.get('targets',[]),b.get('targets',[])):
                for key in ta:check(np.array_equal(source.accessor(ta[key]),animated.accessor(tb[key])),kind+' preserved sparse bow morph')
    report={}
    if kind=='builder':
        _,pos,ids,weights=r.skin_data[0]
        mask=((pos[:,0]>.365)&(pos[:,1]>.49))|((pos[:,0]>.345)&(pos[:,1]>.705))
        check(np.all(ids[mask,0]==r.joints.index(r.index('LeftHand')))&np.allclose(weights[mask,0],1), 'rigid hammer attached to gripping hand')
        baseline=np.linalg.norm(pos[mask][::10]-pos[mask][0],axis=1)
    for animation in animated.doc['animations']:
        duration=max(float(animated.accessor(s['input'])[-1,0]) for s in animation['samplers'])
        bone_sampler=next(animation['samplers'][c['sampler']] for c in animation['channels'] if c['target']['node'] in r.joints)
        times=animated.accessor(bone_sampler['input']).ravel()
        check(np.max(np.diff(times))<1/30+.00001,kind+' '+animation['name']+' source FPS')
        low=1.;rigid_error=0
        for time in np.linspace(0,duration,round(duration*120)+1):
            r.posed=animated.sample(animation,float(time));points=r.deform()
            low=min(low,float(points[:,1].min()))
            if kind=='builder':
                rigid_error=max(rigid_error,float(np.max(np.abs(np.linalg.norm(points[mask][::10]-points[mask][0],axis=1)-baseline))))
        check(low>-.002,kind+' '+animation['name']+' soles do not penetrate floor > 2mm')
        if animation['name'] not in ['archer_shoot']:
            a=animated.sample(animation,0);b=animated.sample(animation,duration)
            check(np.max(np.abs(a[r.joints]-b[r.joints]))<.00005,kind+' '+animation['name']+' loop seam')
        if kind=='builder':check(rigid_error<.000001,'hammer/glove does not stretch')
        report[animation['name']]={'duration':duration,'min_sole_m_at_120hz':low,'rigid_shape_error_m':rigid_error}
    results[kind]=report
    print(kind,report,flush=True)
(ROOT/'docs/unit-motion-source-checks.json').write_text(json.dumps({'checks_passed':checks,'units':results},indent=2))
print(checks,'source checks passed')
