"""Create the builder reference study in Blender, plus a portable GLB and previews.

Run with: blender --background --factory-startup --python tools/create_builder.py
The character uses editable meshes and standard glTF materials; no external assets.
"""
from pathlib import Path
from math import sin, cos, pi
import json
import math
import bpy
import bmesh
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "units" / "builder"
OUT.mkdir(parents=True, exist_ok=True)
REFERENCE = Path(r"C:\Users\yarik\Downloads\18675696-0ed3-4c14-aadb-cb2de51d548d.png")
SCALE = 0.32

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in list(bpy.data.collections):
    if not coll.objects:
        bpy.data.collections.remove(coll)

model = bpy.data.collections.new("BUILDER | editable character")
studio = bpy.data.collections.new("STUDIO | preview only")
refs = bpy.data.collections.new("REFERENCE | packed front image")
for coll in (model, studio, refs):
    bpy.context.scene.collection.children.link(coll)

def mat(name, color, rough=.6, metal=0):
    # Palette values are sRGB; shader inputs are scene-linear.
    color=tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in color)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    return m

skin = mat("Skin | warm peach", (.86, .49, .26), .62)
skin_light = mat("Skin | cheek", (.92, .55, .30), .62)
blush = mat("Skin | nose and ears", (.87, .31, .18), .63)
hair = mat("Hair | walnut brown", (.255, .145, .085), .78)
hair_light = mat("Hair | warm highlights", (.285, .164, .097), .8)
hair_dark = mat("Hair | carved lines", (.175, .090, .047), .85)
cream = mat("Shirt | ivory linen", (.93, .85, .65), .86)
cream_shadow = mat("Shirt | folded edges", (.74, .64, .43), .85)
blue = mat("Overalls | work blue", (.075, .285, .55), .8)
blue_light = mat("Overalls | pocket and hems", (.10, .335, .62), .78)
blue_dark = mat("Overalls | seams", (.035, .135, .28), .8)
leather = mat("Leather | saddle tan", (.50, .245, .086), .72)
leather_light = mat("Leather | honey edges", (.67, .33, .105), .7)
glove = mat("Leather | work gloves", (.40, .205, .099), .8)
rubber = mat("Boots | charcoal sole", (.19, .15, .124), .87)
steel = mat("Metal | brushed steel", (.57, .60, .65), .38, .65)
steel_dark = mat("Metal | dark edge", (.33, .36, .40), .42, .65)
gold = mat("Helmet | construction yellow", (1., .57, .012), .4)
gold_light = mat("Helmet | raised ribs", (1., .69, .045), .42)
gold_dark = mat("Helmet | lower rim", (.74, .42, .022), .45)
thread = mat("Stitching | golden thread", (.74, .45, .15), .75)
white = mat("Eyes | ivory", (.97, .94, .79), .28)
iris = mat("Eyes | chestnut", (.21, .067, .020), .32)
black = mat("Eyes | pupil", (.008, .005, .003), .24)
mouth_mat = mat("Mouth | smile shadow", (.14, .030, .013), .8)

parts = []
def finish(obj, name, material, coll=model, smooth=True):
    obj.name = name
    if obj.data:
        obj.data.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if obj.type == 'MESH' and smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    if coll == model:
        parts.append(obj)
    return obj

def mesh(name, verts, faces, material, smooth=True):
    d = bpy.data.meshes.new(name)
    d.from_pydata(verts, [], faces)
    d.update()
    return finish(bpy.data.objects.new(name, d), name, material, smooth=smooth)

def sphere(name, loc, size, material, seg=24, rings=16, rotation=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = finish(bpy.context.object, name, material)
    o.scale = size
    if rotation:
        o.rotation_euler = rotation
    return o

def box(name, loc, size, material, bevel=.06, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = finish(bpy.context.object, name, material, smooth=False)
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        o.rotation_euler = rot
    if bevel:
        mod = o.modifiers.new("Soft crafted edges", 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        mod = o.modifiers.new("Weighted corner normals", 'WEIGHTED_NORMAL')
    return o

def curve(name, pts, radius, material, cyclic=False):
    d = bpy.data.curves.new(name, 'CURVE')
    d.dimensions = '3D'
    d.resolution_u = 12
    d.bevel_depth = radius
    d.bevel_resolution = 2
    s = d.splines.new('BEZIER')
    s.bezier_points.add(len(pts)-1)
    for b, pt in zip(s.bezier_points, pts):
        b.co = pt
        b.handle_left_type = b.handle_right_type = 'VECTOR' if cyclic else 'AUTO'
    s.use_cyclic_u = cyclic
    return finish(bpy.data.objects.new(name, d), name, material)

def pipe(name, a, b, radius, material, end_radius=None, vertices=16):
    a, b = Vector(a), Vector(b)
    delta = b-a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
        radius2=radius if end_radius is None else end_radius, depth=delta.length,
        location=(a+b)/2)
    o = finish(bpy.context.object, name, material)
    o.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return o

def loft(name, levels, material, n=32, power=2):
    # Each level: (center_x, center_y, z, radius_x, radius_y).
    verts=[]
    for x,y,z,rx,ry in levels:
        for i in range(n):
            t = 2*pi*i/n
            sx, sy = cos(t), sin(t)
            verts.append((x+rx*math.copysign(abs(sx)**(2/power), sx),
                          y+ry*math.copysign(abs(sy)**(2/power), sy), z))
    faces=[]
    for j in range(len(levels)-1):
        for i in range(n):
            faces.append((j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i))
    faces.extend([tuple(reversed(range(n))), tuple((len(levels)-1)*n+i for i in range(n))])
    return mesh(name, verts, faces, material)

def panel(name, polygon, y, depth, material, bevel=.025):
    # Extruded front-facing polygon in the X/Z plane.
    n=len(polygon)
    verts=[(x, yy, z) for yy in (y, y+depth) for x,z in polygon]
    faces=[tuple(reversed(range(n))), tuple(n+i for i in range(n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    o=mesh(name, verts, faces, material, smooth=False)
    if bevel:
        b=o.modifiers.new("Rounded panel border",'BEVEL')
        b.width=bevel; b.segments=3
        o.modifiers.new("Weighted panel normals",'WEIGHTED_NORMAL')
    return o

def stitching(name, pts, radius=.006, spacing=.060):
    # Short separated stitches rather than continuous painted lines.
    for j in range(len(pts)-1):
        a,b=Vector(pts[j]),Vector(pts[j+1]); length=(b-a).length
        count=max(1, int(length/spacing))
        for k in range(count):
            u=(k+.18)/count; v=(k+.68)/count
            pipe(f"{name} {j}.{k}", a.lerp(b,u), a.lerp(b,v), radius, thread, vertices=6)

def rivet(name, loc, radius=.045, material=steel):
    return sphere(name, loc, (radius, .021, radius), material, seg=12, rings=8)

# BODY: broad shoulders and a short, solid silhouette.
loft("Linen shirt torso", [(0,0,3.02,.61,.36),(0,0,3.25,.70,.42),
    (0,.015,3.78,.77,.43),(0,.02,4.26,.87,.43),(0,.01,4.47,.83,.38),
    (0,0,4.65,.45,.30)], cream)
sphere("Neck", (0,0,4.78), (.34,.32,.43), skin)
loft("Overalls hip block",[(0,0,2.47,.45,.27),(0,0,2.62,.70,.34),(0,0,2.74,.73,.405),
    (0,0,3.15,.73,.425),(0,0,3.29,.69,.41)], blue)

for s,side in ((-1,"L"),(1,"R")):
    # Pant legs splay slightly, and taper toward the boot cuffs.
    loft(f"{side} trouser leg",[(s*.63,.04,.98,.30,.29),
        (s*.63,.045,1.14,.38,.32),(s*.58,.055,1.38,.39,.34),
        (s*.55,.07,1.68,.36,.33),(s*.48,.07,2.05,.41,.37),
        (s*.42,.03,2.44,.43,.37),(s*.39,0,2.69,.36,.36)],blue,n=24)
    curve(f"{side} outer trouser seam",[(s*.91,.01,1.15),(s*.94,.02,1.58),
        (s*.89,.015,2.11),(s*.76,-.01,2.65)],.012,blue_dark)
    curve(f"{side} cloth fold upper",[(s*.32,-.333,2.3),(s*.53,-.327,2.21),
        (s*.7,-.264,2.18)],.014,blue_light)
    curve(f"{side} cloth fold ankle",[(s*.41,-.251,1.16),(s*.61,-.281,1.21),
        (s*.82,-.246,1.18)],.014,blue_light)
    # Soles and rounded leather boots.
    loft(f"{side} boot sole",[(s*.63,-.22,.035,.39,.68),
        (s*.63,-.22,.10,.405,.72),(s*.63,-.22,.205,.405,.72),
        (s*.63,-.22,.24,.37,.68)],rubber,n=32,power=3)
    loft(f"{side} sole welt",[(s*.63,-.22,.205,.408,.713),
        (s*.63,-.22,.245,.409,.715),(s*.63,-.22,.267,.38,.68)],leather_light,n=32,power=3)
    sphere(f"{side} boot foot",(s*.63,-.235,.40),(.38,.69,.30),leather_light)
    loft(f"{side} boot shaft",[(s*.63,.035,.38,.31,.31),
        (s*.63,.025,.60,.325,.30),(s*.63,.025,.91,.34,.305),
        (s*.63,.025,1.10,.37,.335)],leather,n=24)
    loft(f"{side} folded boot cuff",[(s*.63,.025,.86,.37,.34),
        (s*.63,.025,.90,.40,.36),(s*.63,.025,1.10,.40,.36),
        (s*.63,.025,1.14,.365,.335)],leather_light,n=24)
    # Steel toe follows only the front part of the boot.
    # A continuous ellipsoid patch gives the toe cap a clean curved boundary.
    vv=[]; ff=[]; nt=32; ny=10
    for j in range(ny+1):
        u=-1+.48*j/ny
        r=math.sqrt(max(0,1-u*u))
        for i in range(nt):
            t=2*pi*i/nt
            vv.append((s*.63+.387*r*cos(t),-.235+.705*u,.40+.307*r*sin(t)))
    for j in range(ny):
        for i in range(nt):
            ff.append((j*nt+i,(j+1)*nt+i,(j+1)*nt+(i+1)%nt,j*nt+(i+1)%nt))
    mesh(f"{side} protective toe cap",vv,ff,steel_dark)
    r=math.sqrt(1-.52**2)
    curve(f"{side} toe cap edge",[(s*.63+.387*r*cos(2*pi*i/nt),
        -.235-.705*.52,.40+.307*r*sin(2*pi*i/nt)) for i in range(nt)],.009,leather,True)
    for z,y in ((.56,-.53),(.63,-.42),(.71,-.30)):
        curve(f"{side} boot strap {z}",[(s*.36,y+.045,z-.035),
            (s*.63,y-.038,z+.023),(s*.90,y+.045,z-.035)],.048,leather)
        for x in (s*.365,s*.895):
            rivet(f"{side} strap stud",(x,y-.018,z),.025)
    box(f"{side} cuff tab",(s*.98,-.01,.977),(.11,.26,.24),leather,.025)
    rivet(f"{side} cuff tab rivet",(s*.967,-.157,.989),.042)
    for dx in (-.24,0,.24):
        box(f"{side} front tread",(s*.63+dx,-.91,.093),(.12,.065,.14),rubber,.012)
    for yy in (-.69,-.39,-.07,.25):
        for dx in (-.39,.39):
            box(f"{side} side tread",(s*.63+dx,yy,.10),(.04,.12,.135),rubber,.010)
    # Knee patches and four rivets.
    pad=box(f"{side} knee reinforcement",(s*.58,-.327,1.66),(.42,.093,.47),leather_light,.050,
            rot=(0,-s*.11,s*.04))
    for dx in (-.143,.143):
        for dz in (-.169,.169):
            rivet(f"{side} knee rivet",(s*.58+dx,-.39,1.66+dz),.035)
    stitching(f"{side} knee stitch",[(s*.58-.157,-.392,1.84),
        (s*.58-.16,-.393,1.49),(s*.58+.16,-.393,1.49),
        (s*.58+.157,-.392,1.84)],.0055)

# The bib is a shaped thick panel, not a floating cube.
panel("Overalls front bib",[(-.69,3.23),(.69,3.23),(.72,3.43),(.65,4.07),
      (-.65,4.07),(-.72,3.43)],-.443,.085,blue,.045)
curve("Bib top piping",[(-.65,-.489,4.045),(0,-.491,4.04),(.65,-.489,4.045)],.020,blue_light)
stitching("Bib top stitching",[(-.6,-.489,4.002),(.6,-.489,4.002)])
panel("Bib pentagonal chest pocket",[(-.28,3.80),(.28,3.80),(.28,3.45),
      (0,3.34),(-.28,3.45)],-.515,.055,blue_light,.018)
stitching("Chest pocket stitch",[(-.251,-.545,3.743),(-.249,-.545,3.48),
    (0,-.545,3.38),(.249,-.545,3.48),(.251,-.545,3.743)])
curve("Pocket opening",[(-.25,-.55,3.76),(0,-.557,3.77),(.25,-.55,3.76)],.015,blue_dark)
for s,side in ((-1,"L"),(1,"R")):
    rivet(f"{side} bib pocket brass rivet",(s*.25,-.556,3.78),.030,gold_light)
    # Leather suspenders follow the shoulders onto the back.
    x=s*.55
    curve(f"{side} shoulder suspender",[(s*.54,-.458,3.97),(s*.61,-.44,4.45),
        (s*.62,-.255,4.60),(s*.6,.02,4.59),(s*.58,.36,4.48),
        (s*.45,.448,3.31)],.078,leather)
    panel(f"{side} suspender front tab",[(x-.11,4.34),(x+.12,4.34),
        (x+.105,3.98),(x,3.91),(x-.10,3.98)],-.49,.062,leather_light,.024)
    # Square buckles with a clear open center.
    bx=s*.57
    curve(f"{side} suspender steel buckle",[(bx-.115,-.562,4.17),
        (bx-.115,-.562,4.41),(bx+.115,-.562,4.41),
        (bx+.115,-.562,4.17)],.027,steel,True)
    pipe(f"{side} buckle pin",(bx,-.587,4.45),(bx,-.587,4.32),.015,steel)
    # Open folded collar wings.
    panel(f"{side} shirt collar",[(s*.05,4.48),(s*.30,4.69),
        (s*.43,4.69),(s*.49,4.47),(s*.27,4.50),(s*.09,4.31)],-.375,.055,cream,.018)
    curve(f"{side} collar edge",[(s*.04,-.418,4.49),(s*.29,-.419,4.68),
        (s*.41,-.419,4.66),(s*.47,-.419,4.48)],.009,cream_shadow)
for pts in ([(-.115,-.438,4.33),(.11,-.449,4.22)],
            [(.115,-.438,4.33),(-.11,-.449,4.22)]):
    curve("Laced shirt cord",pts,.018,leather)
rivet("Linen shirt button",(0,-.467,4.14),.031,cream_shadow)

# ARMS and articulated glove fingers: both arms in a true T-pose.
for s,side in ((-1,"L"),(1,"R")):
    sleeve=loft(f"{side} short linen sleeve",[(0,0,0,.39,.36),
        (0,0,.23,.36,.35),(0,0,.62,.30,.31),(0,0,.71,.30,.31)],cream,n=24)
    sleeve.location=(s*.76,.01,4.29)
    sleeve.rotation_euler=(0,s*pi/2,0)
    sphere(f"{side} linen shoulder",(s*.79,.015,4.32),(.31,.33,.325),cream)
    cuff=loft(f"{side} rolled linen cuff",[(0,0,0,.32,.33),(0,0,.05,.35,.35),
        (0,0,.18,.34,.35),(0,0,.235,.31,.32)],cream,n=24)
    cuff.location=(s*1.29,.005,4.29)
    cuff.rotation_euler=(0,s*pi/2,0)
    for x in (1.34,1.46):
        curve(f"{side} rolled sleeve crease",[(s*x,-.32,4.43),
            (s*x,-.345,4.29),(s*x,-.319,4.12)],.011,cream_shadow)
    sphere(f"{side} upper arm",(s*1.75,.01,4.29),(.48,.258,.27),skin_light)
    sphere(f"{side} forearm",(s*2.13,.007,4.29),(.44,.235,.232),skin)
    # Glove cuff flares where it overlaps the forearm.
    cuff=loft(f"{side} leather gauntlet",[(0,0,0,.26,.265),(0,0,.05,.282,.29),
        (0,0,.15,.277,.283),(0,0,.27,.226,.23)],leather,n=24)
    cuff.location=(s*2.37,0,4.29)
    cuff.rotation_euler=(0,s*pi/2,0)
    for x in (2.415,2.52):
        curve(f"{side} gauntlet cuff edging",[(s*x,-.248,4.40),
            (s*x,-.273,4.29),(s*x,-.247,4.15)],.012,leather_light)
    sphere(f"{side} gloved palm",(s*2.81,-.006,4.29),(.29,.135,.195),glove)
    if s<0:
        # Open hand, four independent digits aligned toward the outside.
        for i,(yy,zz,ll) in enumerate(((-.10,4.36,.28),(-.035,4.39,.34),
                 (.036,4.385,.31),(.10,4.34,.24))):
            sphere(f"{side} open finger {i+1}",(s*(3.01+ll/2),yy,zz),(ll/2+.035,.045,.054),glove,16,10)
            curve(f"{side} finger joint {i+1}",[(s*3.13,yy-.039,zz+.02),
                (s*3.14,yy-.043,zz-.02)],.006,leather_light)
        sphere(f"{side} open thumb",(-2.91,-.148,4.135),(.19,.081,.090),glove,20,12,
               rotation=(0,-.28,-.22))
    else:
        # Four bent fingers wrap around a vertical mallet handle.
        for i in range(4):
            zz=4.455-i*.10
            sphere(f"{side} gripping finger {i+1}",(3.015,-.135,zz),(.16,.075,.051),glove,20,12)
            curve(f"{side} glove knuckle {i+1}",[(2.96,-.202,zz+.022),
                 (3.02,-.210,zz+.023),(3.09,-.197,zz+.018)],.007,leather_light)
        sphere(f"{side} gripping thumb",(2.91,-.213,4.46),(.17,.076,.091),glove,20,12,
               rotation=(0,-.25,.2))

# BELT, buckle, two tool pouches.
loft("Leather waist belt",[(0,0,2.965,.748,.458),(0,0,3.015,.766,.474),
    (0,0,3.205,.767,.473),(0,0,3.239,.746,.452)],leather,n=48)
curve("Belt upper seam",[(-.67,-.264,3.21),(-.36,-.428,3.21),
    (0,-.477,3.21),(.36,-.428,3.21),(.67,-.264,3.21)],.010,leather_light)
box("Belt leather tongue",(0,-.498,3.107),(.32,.064,.25),leather_light,.025)
curve("Belt square steel buckle",[(-.195,-.552,2.958),(-.195,-.552,3.261),
    (.195,-.552,3.261),(.195,-.552,2.958)],.036,steel,True)
pipe("Belt buckle prong",(-.185,-.595,3.10),(-.036,-.595,3.10),.020,steel)
for x in (.32,.44,.56):
    sphere("Belt adjustment hole",(x,-.443+max(0,x-.30)*.21,3.095),(.013,.009,.015),hair_dark,12,8)
for s,side in ((-1,"L"),(1,"R")):
    box(f"{side} tool pouch",(s*.80,-.242,2.84),(.40,.29,.61),leather_light,.059,
        rot=(0,-s*.06,s*.06))
    box(f"{side} pouch side gusset",(s*.80+s*.188,-.19,2.825),(.072,.26,.52),leather,.028)
    stitching(f"{side} pouch seam",[(s*.80-.153,-.401,3.07),
        (s*.80-.153,-.407,2.59),(s*.80+.153,-.407,2.59),
        (s*.80+.153,-.401,3.07)],.006)
    if s<0:
        panel(f"{side} pouch flap",[(-1.04,3.20),(-.585,3.20),(-.604,2.99),
            (-.83,2.92),(-1.017,3.002)],-.424,.053,leather,.026)
        rivet(f"{side} pouch snap",(-.82,-.474,3.026),.052)
    else:
        box("R open pouch rim",(.81,-.254,3.113),(.432,.337,.095),leather,.030)
        rivet("R pouch snap",(.81,-.434,2.995),.048)
        for j,x in enumerate((.71,.90)):
            box(f"Chisel {j+1} shaft",(x,-.17,3.30),(.065,.065,.43),steel_dark,.009,
                rot=(0,-.10,0))
            box(f"Chisel {j+1} steel head",(x-.019,-.17,3.49),(.10,.10,.17),steel,.016,
                rot=(0,-.10,0))
        box("Side pencil holster",(1.025,-.19,2.975),(.12,.17,.33),leather,.022)
        pipe("Carpenter pencil",(1.022,-.19,2.93),(1.022,-.19,3.39),.025,gold_light,vertices=6)
        pipe("Pencil wood tip",(1.022,-.19,3.39),(1.022,-.19,3.455),.025,cream,end_radius=.002,vertices=6)

# HEAD: broad expressive face, ears, smiling eyes and a carved beard.
sphere("Head",(0,.018,5.48),(.565,.447,.635),skin,32,24)
sphere("Back and sides hair",(0,.13,5.62),(.581,.404,.565),hair,28,20)
# Re-cover the front, leaving a real back-of-head hair silhouette.
sphere("Face sculpt",(0,-.126,5.56),(.523,.343,.528),skin,32,24)
sphere("Beard jaw volume",(0,.003,5.14),(.54,.418,.365),hair,32,20)
for s,side in ((-1,"L"),(1,"R")):
    sphere(f"{side} ear",(s*.585,.002,5.52),(.132,.103,.207),skin_light)
    sphere(f"{side} ear concha",(s*.623,-.082,5.522),(.071,.036,.137),blush)
    sphere(f"{side} ear inner fold",(s*.622,-.116,5.51),(.039,.018,.079),skin)
    sphere(f"{side} cheek",(s*.355,-.321,5.437),(.187,.145,.167),skin_light)
    sphere(f"{side} cheek warmth",(s*.372,-.449,5.454),(.073,.014,.048),blush,20,12)
    # Sideburns lean in toward the beard instead of floating beside the face.
    curve(f"{side} sideburn",[(s*.488,-.224,5.852),(s*.50,-.278,5.65),
        (s*.49,-.292,5.40),(s*.432,-.328,5.27)],.057,hair)
    sphere(f"{side} beard cheek",(s*.386,-.241,5.186),(.158,.208,.254),hair_light,
        rotation=(0,s*.17,0))
    sphere(f"{side} lower beard lobe",(s*.203,-.284,5.025),(.228,.15,.214),hair)
    # Eye whites and inset lids.
    sphere(f"{side} eye socket",(s*.235,-.416,5.676),(.153,.063,.148),skin_light)
    sphere(f"{side} eye white",(s*.235,-.461,5.683),(.121,.052,.113),white,28,18)
    sphere(f"{side} iris",(s*.232,-.509,5.679),(.069,.016,.077),iris,24,16)
    sphere(f"{side} pupil",(s*.232,-.532,5.679),(.038,.010,.057),black,20,12)
    sphere(f"{side} eye catchlight",(s*.232-.022,-.542,5.721),(.019,.008,.025),white,12,8)
    sphere(f"{side} secondary eye glint",(s*.232+.022,-.540,5.654),(.008,.004,.009),white,10,6)
    curve(f"{side} upper eyelid",[(s*.108,-.482,5.70),(s*.168,-.50,5.791),
        (s*.256,-.498,5.811),(s*.355,-.459,5.729)],.016,skin)
    curve(f"{side} lower eyelid",[(s*.117,-.480,5.637),(s*.229,-.5,5.571),
        (s*.35,-.462,5.638)],.012,skin_light)
    curve(f"{side} thick eyebrow",[(s*.111,-.462,5.822),(s*.171,-.468,5.870),
        (s*.284,-.442,5.862),(s*.365,-.397,5.830)],.039,hair)
    # Curving moustache halves sit above the grin.
    curve(f"{side} curled moustache",[(s*.045,-.561,5.384),(s*.14,-.568,5.346),
        (s*.268,-.519,5.354),(s*.312,-.480,5.391)],.059,hair)
    curve(f"{side} moustache ridge",[(s*.07,-.614,5.381),(s*.152,-.615,5.354),
        (s*.249,-.572,5.36)],.008,hair_light)
sphere("Beard central chin",(0,-.306,4.99),(.224,.159,.20),hair_light)
for x in (-.12,0,.12):
    curve("Chin beard groove",[(x,-.451,5.08),(x*.94,-.46,4.993),
        (x*.7,-.397,4.851)],.008,hair_dark)
panel("Friendly smiling mouth",[(-.235,5.294),(-.16,5.317),(0,5.316),
    (.16,5.317),(.235,5.294),(.166,5.213),(0,5.185),(-.166,5.213)],-.478,.025,mouth_mat,.026)
panel("Smile teeth",[(-.196,5.294),(0,5.301),(.196,5.294),
    (.151,5.250),(0,5.23),(-.151,5.250)],-.507,.014,white,.015)
curve("Lower smile lip",[(-.165,-.503,5.213),(0,-.515,5.181),(.165,-.503,5.213)],.020,skin_light)
sphere("Nose bridge",(0,-.419,5.571),(.101,.10,.194),skin_light)
sphere("Round red nose",(0,-.529,5.443),(.148,.142,.102),blush,28,18)
for s in (-1,1):
    sphere("Nose wing",(s*.112,-.484,5.426),(.058,.078,.050),skin_light)
    sphere("Nostril",(s*.083,-.555,5.402),(.026,.013,.014),leather,12,8)

# HELMET: open-bottom dome, brim, longitudinal ribs and riveted front plate.
def helmet_dome():
    n=48; m=14; verts=[]; faces=[]
    for j in range(m+1):
        a=(pi/2)*j/m
        for i in range(n):
            t=2*pi*i/n
            verts.append((.625*cos(a)*cos(t),.024+.506*cos(a)*sin(t),
                5.93+.615*sin(a)))
    for j in range(m):
        for i in range(n):
            faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    o=mesh("Yellow hard hat dome",verts,faces,gold)
    mod=o.modifiers.new("Helmet shell thickness",'SOLIDIFY'); mod.thickness=.035
    return o
helmet_dome()
loft("Helmet protective brim",[(0,-.027,5.908,.69,.585),
    (0,-.032,5.935,.724,.619),(0,-.032,5.982,.717,.612),
    (0,-.020,6.009,.654,.543)],gold_light,n=48)
loft("Helmet lower rim shadow",[(0,-.023,5.89,.653,.562),
    (0,-.026,5.92,.684,.578)],gold_dark,n=48)
for xx in (-.32,0,.32):
    # Great-circle arcs over the crown, leaving a readable helmet silhouette.
    pts=[]
    for k in range(11):
        a=pi*k/10
        rx=.625; ry=.514; rz=.623
        factor=math.sqrt(max(.001,1-(xx/rx)**2))
        pts.append((xx,.024-ry*factor*cos(a),5.934+rz*factor*sin(a)))
    curve("Helmet raised crown rib",pts,.040 if xx==0 else .023,gold_light)
for s in (-1,1):
    for t in (-1.0,-.71,-.44):
        x=s*.63*cos(t); y=.024+.52*sin(t)
        curve("Helmet side reinforcing rib",[(x,y,5.99),(x*.95,y*.94,6.105),
            (x*.90,y*.90,6.22)],.013,gold_light)
box("Helmet riveted front plate",(0,-.509,6.102),(.257,.055,.265),steel,.027,
    rot=(math.radians(-12),0,0))
for x in (-.083,.083):
    for z in (6.027,6.187):
        rivet("Helmet plate bolt",(x,-.547,z),.022,steel_dark)

# HAMMER: leather grip, wood shaft, beveled steel head and lighter striking ends.
pipe("Hammer wooden handle",(3.075,-.025,3.60),(3.075,-.025,5.05),.076,leather_light,vertices=12)
for k in range(8):
    z=3.68+k*.095
    loft(f"Hammer leather grip wrap {k}",[(3.075,-.025,z,.083,.083),
        (3.075,-.025,z+.064,.083,.083)],leather if k%2==0 else leather_light,n=12)
box("Hammer end cap",(3.075,-.025,3.59),(.20,.19,.115),leather,.020)
rivet("Hammer end cap rivet",(3.075,-.126,3.59),.033)
box("Hammer head core",(3.075,-.025,5.035),(.71,.32,.39),steel,.064)
for s in (-1,1):
    box("Hammer striking face",(3.075+s*.323,-.025,5.035),(.087,.341,.355),steel_dark,.037)
    box("Hammer striking face inset",(3.075+s*.362,-.025,5.035),(.023,.27,.28),steel,.022)
box("Hammer top wooden wedge",(3.075,-.025,5.243),(.13,.09,.026),leather,.006)
curve("Hammer face forged bevel",[(2.824,-.198,4.91),(2.784,-.198,4.995),
    (2.824,-.198,5.165),(3.309,-.198,5.165),(3.354,-.198,5.08)],.008,steel_dark)

# Convert generated curves, apply modifiers, and bake the size to ~2.1 metres.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.convert(target='MESH')
parts=list(model.objects)
for o in parts:
    bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    o.location*=SCALE
    o.scale*=SCALE
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

root=bpy.data.objects.new("Builder",None)
root.empty_display_size=.15
model.objects.link(root)
for o in parts:
    o.parent=root
root['description']='Stylized builder reference study. T-pose; static, no rig or animations.'
root['forward']='-Y in Blender; glTF uses Y up'
root['height_m']=round(6.57*SCALE,3)

# A packed image in its own collection makes the original reference available.
if REFERENCE.is_file():
    im=bpy.data.images.load(str(REFERENCE),check_existing=True)
    im.pack()
    ref=bpy.data.objects.new("Builder reference | front",None)
    ref.empty_display_type='IMAGE'; ref.data=im
    ref.empty_display_size=2.3; ref.location=(1.8,.7,1.06)
    ref.rotation_euler=(pi/2,0,0)
    refs.objects.link(ref); ref.hide_render=True
refs.hide_viewport=True
refs.hide_render=True

scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.cycles.preview_samples=24
try:
    pref=bpy.context.preferences.addons['cycles'].preferences
    pref.compute_device_type='OPTIX'
    pref.get_devices()
    for dev in pref.devices:
        dev.use=dev.type=='OPTIX'
    scene.cycles.device='GPU'
except Exception:
    scene.cycles.device='CPU'
scene.render.resolution_x=1400
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.world.color=(.21,.21,.21)
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.30,.39,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=-.25

def aim(obj, point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

floor_mat=mat("Studio | slate",(.32,.36,.41),.9)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0))
floor=finish(bpy.context.object,"Studio ground",floor_mat,coll=studio,smooth=False)
floor.hide_set(True)  # Visible in renders, unobtrusive in the modeling viewport.
for name,loc,energy,size,col in (
    ("Key softbox",(-2.6,-3.3,4.8),550,3.5,(1,.84,.67)),
    ("Fill softbox",(2.8,-2.0,2.8),270,3.0,(.68,.80,1)),
    ("Rim softbox",(1.4,2.0,3.8),620,2.4,(1,.82,.58)),
    ("Front face bounce",(0,-3.0,1.8),55,2.0,(1,.91,.81))):
    d=bpy.data.lights.new(name,'AREA'); d.energy=energy; d.shape='DISK'; d.size=size; d.color=col
    o=bpy.data.objects.new(name,d); studio.objects.link(o); o.location=loc; aim(o,(0,0,1.05)); o.hide_set(True)
d=bpy.data.cameras.new("Builder preview camera")
cam=bpy.data.objects.new("Builder preview camera",d); studio.objects.link(cam)
scene.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=2.70
cam.location=(3.1,-9,3.0); aim(cam,(0,-.02,1.075)); cam.hide_set(True)

# Save an uncluttered material-colored viewport focused on the actual asset.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type='SOLID'; space.shading.color_type='MATERIAL'
            space.shading.light='STUDIO'; space.shading.studiolight_rotate_z=.3
            space.shading.show_shadows=True; space.shading.show_cavity=True
            space.overlay.show_floor=False
            space.overlay.show_axis_x=False; space.overlay.show_axis_y=False
            space.overlay.show_relationship_lines=False
            space.overlay.show_extras=False
            space.overlay.show_overlays=False
            space.region_3d.view_distance=3.05
            space.region_3d.view_location=(0,0,1.05)
            space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            space.region_3d.view_perspective='ORTHO'
            space.clip_end=100

# Consolidate export copies by material; keep the Blender source parts editable.
export_coll=bpy.data.collections.new("TEMP | portable export")
scene.collection.children.link(export_coll)
groups={}
for original in parts:
    cp=original.copy(); cp.data=original.data.copy(); cp.parent=None
    export_coll.objects.link(cp); cp.matrix_world=original.matrix_world.copy()
    groups.setdefault(cp.data.materials[0].name,[]).append(cp)
export_parts=[]
for name,group in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:
        o.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    if len(group)>1:
        bpy.ops.object.join()
    o=bpy.context.object; o.name=name; o.parent=root
    export_parts.append(o)
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
for o in export_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'builder.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_animations=False,
    export_cameras=False,export_lights=False)
export_mesh_count=len(export_parts)
for o in export_parts:
    bpy.data.objects.remove(o,do_unlink=True)
bpy.data.collections.remove(export_coll)
for d in list(bpy.data.meshes):
    if d.users==0:
        bpy.data.meshes.remove(d)

bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=None
scene.render.filepath=str(OUT/'builder_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'builder.blend'))
bpy.ops.render.render(write_still=True)

cam.location=(0,-9,1.78); aim(cam,(0,0,1.06)); cam.data.ortho_scale=2.55
scene.render.filepath=str(OUT/'builder_front.png')
bpy.ops.render.render(write_still=True)

stats={'mesh_objects':len(parts),'glb_mesh_objects':export_mesh_count,'vertices':sum(len(o.data.vertices) for o in parts),
    'triangles':sum(len(p.vertices)-2 for o in parts for p in o.data.polygons),
    'materials':len({m.name for o in parts for m in o.data.materials}),
    'height_m':round(max((o.matrix_world@v.co).z for o in parts for v in o.data.vertices),3),
    'rigged':False,'animated':False,'orientation':'Blender Z-up, -Y forward; glTF Y-up',
    'files':['builder.blend','builder.glb','builder_preview.png','builder_front.png']}
(OUT/'model_info.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('BUILDER_COMPLETE',json.dumps(stats))
