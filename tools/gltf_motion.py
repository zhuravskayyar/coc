"""Lossless GLB motion editing, skin evaluation and two-link IK in glTF Y-up space."""
from copy import deepcopy
from pathlib import Path
import json
import struct
import numpy as np
from scipy.spatial.transform import Rotation

DTYPES = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTHS = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}


def unit(v):
    return np.asarray(v, dtype=float)/max(np.linalg.norm(v),1e-12)


def rotate_between(a,b):
    a,b=unit(a),unit(b)
    cross=np.cross(a,b)
    dot=np.clip(a@b,-1,1)
    if dot < -.999999:
        axis=unit(np.cross(a,[0,1,0] if abs(a[1])<.9 else [1,0,0]))
        return Rotation.from_rotvec(axis*np.pi).as_matrix()
    k=np.array([[0,-cross[2],cross[1]],[cross[2],0,-cross[0]],[-cross[1],cross[0],0]])
    return np.eye(3)+k+k@k/(1+dot)


def rot(x=0,y=0,z=0):
    return Rotation.from_euler('xyz',[x,y,z],degrees=True).as_matrix()


def slerp(a,b,t):
    a=np.asarray(a); b=np.asarray(b)
    dot=np.sum(a*b,axis=-1,keepdims=True)
    b=np.where(dot<0,-b,b); dot=np.abs(dot)
    theta=np.arccos(np.clip(dot,-1,1))
    den=np.maximum(np.sin(theta),1e-12)
    value=np.sin((1-t)*theta)/den*a+np.sin(t*theta)/den*b
    value=np.where(dot>.9995,(1-t)*a+t*b,value)
    return value/np.maximum(np.linalg.norm(value,axis=-1,keepdims=True),1e-12)


def trs(t=None,q=None,s=None):
    m=np.eye(4)
    m[:3,:3]=Rotation.from_quat(q if q is not None else [0,0,0,1]).as_matrix()@np.diag(s if s is not None else [1,1,1])
    m[:3,3]=[0,0,0] if t is None else t
    return m


def decompose(m):
    scale=np.linalg.norm(m[:3,:3],axis=0)
    rotation=m[:3,:3]/scale
    if np.linalg.det(rotation)<0:
        scale[0]*=-1; rotation[:,0]*=-1
    return m[:3,3].copy(),Rotation.from_matrix(rotation).as_quat(),scale


class GLB:
    def __init__(self,path):
        data=Path(path).read_bytes()
        assert data[:4]==b'glTF'
        count=struct.unpack_from('<I',data,12)[0]
        self.doc=json.loads(data[20:20+count])
        self.bin=bytearray(data[28+count:])
        self.cache={}

    def accessor(self,index):
        if index in self.cache: return self.cache[index].copy()
        a=self.doc['accessors'][index]; width=WIDTHS[a['type']]
        dtype=np.dtype(DTYPES[a['componentType']])
        value=np.zeros((a['count'],width),dtype=dtype)
        if 'bufferView' in a:
            view=self.doc['bufferViews'][a['bufferView']]
            offset=view.get('byteOffset',0)+a.get('byteOffset',0)
            value=np.ndarray(value.shape,dtype,buffer=self.bin,offset=offset,strides=(view.get('byteStride',dtype.itemsize*width),dtype.itemsize)).copy()
        if 'sparse' in a:
            sp=a['sparse']; ind=sp['indices']; val=sp['values']
            iv=self.doc['bufferViews'][ind['bufferView']]; vv=self.doc['bufferViews'][val['bufferView']]
            ids=np.frombuffer(self.bin,DTYPES[ind['componentType']],count=sp['count'],offset=iv.get('byteOffset',0)+ind.get('byteOffset',0))
            patch=np.frombuffer(self.bin,dtype,count=sp['count']*width,offset=vv.get('byteOffset',0)+val.get('byteOffset',0)).reshape(-1,width)
            value[ids]=patch
        if a.get('normalized') and a['componentType']!=5126:
            value=value.astype(float)/np.iinfo(dtype).max
        self.cache[index]=value
        return value.copy()

    def add(self,data,kind,component=5126):
        data=np.asarray(data,dtype=DTYPES[component]).reshape(-1,WIDTHS[kind])
        while len(self.bin)%4:self.bin.append(0)
        vi=len(self.doc['bufferViews'])
        self.doc['bufferViews'].append({'buffer':0,'byteOffset':len(self.bin),'byteLength':data.nbytes})
        self.bin.extend(data.tobytes())
        a={'bufferView':vi,'componentType':component,'count':len(data),'type':kind}
        if kind=='SCALAR':a.update(min=[float(data.min())],max=[float(data.max())])
        ai=len(self.doc['accessors']); self.doc['accessors'].append(a)
        return ai

    def local(self):
        return [np.array(n['matrix']).reshape(4,4).T if 'matrix' in n else trs(n.get('translation'),n.get('rotation'),n.get('scale')) for n in self.doc['nodes']]

    def globals(self,local):
        parents={child:i for i,n in enumerate(self.doc['nodes']) for child in n.get('children',[])}
        out={}
        def solve(i):
            if i not in out:out[i]=solve(parents[i])@local[i] if i in parents else local[i]
            return out[i]
        return np.array([solve(i) for i in range(len(local))])

    def sample(self,animation,time):
        local=self.local(); components={}
        for channel in animation['channels']:
            node=channel['target']['node']; path=channel['target']['path']
            if path=='weights':continue
            sampler=animation['samplers'][channel['sampler']]
            times=self.accessor(sampler['input']).ravel(); values=self.accessor(sampler['output'])
            i=max(0,min(len(times)-2,np.searchsorted(times,time,side='right')-1))
            if len(times)==1: v=values[0]
            else:
                t=np.clip((time-times[i])/max(times[i+1]-times[i],1e-9),0,1)
                v=values[i] if sampler.get('interpolation')=='STEP' else slerp(values[i],values[i+1],t) if path=='rotation' else (1-t)*values[i]+t*values[i+1]
            if node not in components: components[node]=list(decompose(local[node]))
            components[node][{'translation':0,'rotation':1,'scale':2}[path]]=v
        for i,parts in components.items():local[i]=trs(*parts)
        return self.globals(local)

    def bake(self,name,times,global_frames,joints,extra=None):
        time_index=self.add(np.asarray(times),'SCALAR')
        animation={'name':name,'samplers':[],'channels':[]}
        parents={c:i for i,n in enumerate(self.doc['nodes']) for c in n.get('children',[])}
        for node in joints:
            matrices=[np.linalg.inv(g[parents[node]])@g[node] if node in parents else g[node] for g in global_frames]
            parts=list(zip(*(decompose(m) for m in matrices)))
            for path,values in [('translation',parts[0]),('rotation',parts[1])]:
                values=np.asarray(values)
                if path=='rotation':
                    for i in range(1,len(values)):
                        if values[i]@values[i-1]<0:values[i]*=-1
                output=self.add(values,'VEC4' if path=='rotation' else 'VEC3')
                si=len(animation['samplers'])
                animation['samplers'].append({'input':time_index,'output':output,'interpolation':'LINEAR'})
                animation['channels'].append({'sampler':si,'target':{'node':node,'path':path}})
        for node,path,values,interp in extra or []:
            si=len(animation['samplers'])
            animation['samplers'].append({'input':time_index,'output':self.add(values,'SCALAR' if path=='weights' else 'VEC3'),'interpolation':interp})
            animation['channels'].append({'sampler':si,'target':{'node':node,'path':path}})
        self.doc.setdefault('animations',[]).append(animation)

    def save(self,path):
        # Compact live accessors/views, retaining embedded images and sparse morphs.
        old=self.doc; views=old['bufferViews']; accessors=old['accessors']; new_bin=bytearray(); new_views=[]; new_acc=[]
        vm={}; am={}
        def view(i):
            if i not in vm:
                while len(new_bin)%4:new_bin.append(0)
                obj=deepcopy(views[i]); start=obj.get('byteOffset',0)
                block=self.bin[start:start+obj['byteLength']]
                obj['byteOffset']=len(new_bin); obj['buffer']=0
                new_bin.extend(block);vm[i]=len(new_views);new_views.append(obj)
            return vm[i]
        def acc(i):
            if i not in am:
                obj=deepcopy(accessors[i])
                if 'bufferView' in obj:obj['bufferView']=view(obj['bufferView'])
                if 'sparse' in obj:
                    for key in ['indices','values']:obj['sparse'][key]['bufferView']=view(obj['sparse'][key]['bufferView'])
                am[i]=len(new_acc);new_acc.append(obj)
            return am[i]
        doc=deepcopy(old)
        for mesh in doc.get('meshes',[]):
            for p in mesh['primitives']:
                p['attributes']={k:acc(v) for k,v in p['attributes'].items()}
                if 'indices' in p:p['indices']=acc(p['indices'])
                for target in p.get('targets',[]):
                    for key in target:target[key]=acc(target[key])
        for skin in doc.get('skins',[]):skin['inverseBindMatrices']=acc(skin['inverseBindMatrices'])
        for image in doc.get('images',[]):
            if 'bufferView' in image:image['bufferView']=view(image['bufferView'])
        for animation in doc.get('animations',[]):
            for sampler in animation['samplers']:
                sampler['input']=acc(sampler['input']);sampler['output']=acc(sampler['output'])
        doc['accessors']=new_acc;doc['bufferViews']=new_views;doc['buffers']=[{'byteLength':len(new_bin)}]
        encoded=json.dumps(doc,separators=(',',':')).encode()
        encoded+=b' '*((-len(encoded))%4);new_bin+=b'\0'*((-len(new_bin))%4)
        Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(new_bin))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(new_bin),b'BIN\0')+new_bin)


class Rig:
    def __init__(self,glb):
        self.glb=glb;self.joints=glb.doc['skins'][0]['joints']
        self.names={glb.doc['nodes'][i]['name'].replace('mixamorig:',''):i for i in self.joints}
        self.parent={c:i for i,n in enumerate(glb.doc['nodes']) for c in n.get('children',[])}
        self.rest=glb.globals(glb.local())
        ibm=glb.accessor(glb.doc['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        self.ibm=ibm
        meshnode=next(i for i,n in enumerate(glb.doc['nodes']) if n.get('skin')==0)
        for i,matrix in zip(self.joints,ibm):self.rest[i]=self.rest[meshnode]@np.linalg.inv(matrix)
        self.order=[]
        def walk(i):
            if i in self.joints:self.order.append(i)
            for c in glb.doc['nodes'][i].get('children',[]):walk(c)
        for i in range(len(glb.doc['nodes'])):
            if i not in self.parent:walk(i)
        self.posed=self.rest.copy()
        self.meshnode=meshnode
        self.skin_data=[]
        for p in glb.doc['meshes'][glb.doc['nodes'][meshnode]['mesh']]['primitives']:
            attr=p['attributes']; pos=glb.accessor(attr['POSITION'])
            self.skin_data.append((p,pos,glb.accessor(attr['JOINTS_0']).astype(int),glb.accessor(attr['WEIGHTS_0'])))

    def index(self,name):return self.names[name]
    def point(self,name):return self.posed[self.index(name),:3,3].copy()
    def anchor(self,i):
        p=self.parent.get(i)
        return (self.posed[p]@np.linalg.inv(self.rest[p])@self.rest[i])[:3,3] if p is not None else self.rest[i,:3,3].copy()
    def inherit(self,i):
        p=self.parent.get(i)
        self.posed[i]=self.posed[p]@np.linalg.inv(self.rest[p])@self.rest[i] if p is not None else self.rest[i].copy()
    def place(self,name,rotation=np.eye(3),point=None):
        i=self.index(name) if isinstance(name,str) else name
        self.posed[i,:3,:3]=rotation@self.rest[i,:3,:3]
        self.posed[i,:3,3]=self.anchor(i) if point is None else point
    def descendants(self,i):
        for c in self.glb.doc['nodes'][i].get('children',[]):
            if c in self.joints:self.inherit(c)
            self.descendants(c)
    def limb(self,first,second,end_name,target,pole):
        a,b,c=[self.index(n) for n in [first,second,end_name]]
        head=self.anchor(a);target=np.asarray(target);axis=target-head
        la=np.linalg.norm(self.rest[b,:3,3]-self.rest[a,:3,3]);lb=np.linalg.norm(self.rest[c,:3,3]-self.rest[b,:3,3])
        d=np.clip(np.linalg.norm(axis),1e-6,la+lb-1e-6);direction=unit(axis)
        error=abs(float(np.linalg.norm(axis)-d))
        if error>getattr(self,'max_ik_error',0.0):
            self.max_ik_error=error;self.max_ik_context={'bone':first,'target':target.tolist(),'head':head.tolist()}
        bend=np.asarray(pole)-head;bend=unit(bend-direction*(bend@direction))
        along=(la*la-lb*lb+d*d)/(2*d)
        knee=head+direction*along+bend*np.sqrt(max(0,la*la-along*along));end=head+direction*d
        for i,j,h,t in [(a,b,head,knee),(b,c,knee,end)]:self.place(i,rotate_between(self.rest[j,:3,3]-self.rest[i,:3,3],t-h),h)
        return end
    def deform(self,subset=None):
        transforms=self.posed[self.joints]@self.ibm
        results=[];offset=0
        for _,positions,joints,weights in self.skin_data:
            mask=slice(None) if subset is None else subset[offset:offset+len(positions)]
            offset+=len(positions)
            pos=positions[mask]; ids=joints[mask];w=weights[mask]
            points=np.column_stack([pos,np.ones(len(pos))])
            out=np.zeros((len(pos),3))
            for k in range(4):out+=np.einsum('nij,nj->ni',transforms[ids[:,k]],points)[:,:3]*w[:,k,None]
            results.append(out)
        return np.concatenate(results)

    def bake_rest_nodes(self):
        for i in self.joints:
            p=self.parent.get(i);matrix=np.linalg.inv(self.rest[p])@self.rest[i] if p is not None else self.rest[i]
            t,q,s=decompose(matrix)
            node=self.glb.doc['nodes'][i];node.pop('matrix',None)
            node.update(translation=t.tolist(),rotation=q.tolist(),scale=s.tolist())
