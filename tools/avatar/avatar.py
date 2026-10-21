"""Avatar de MAGRA: maniquí 3D sin rostro, gris, a partir de MakeHuman (CC0),
renderizado en Blender. Vista previa:

  venv/bin/python avatar.py OUT.png [ancho alto muestras]   (VIEW=0|90|180)

render_demos.py usa make_avatar() para las demostraciones de la app.
Construye mujer y hombre adultos, vestidos (camiseta, calzas/jogger,
zapatillas), con pelo de hebras, en un estudio oscuro con aros de acento.
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector

MH = os.environ.get('MH_DATA', '/home/user/makehumancommunity/makehuman/makehuman/data')
_ARGS = sys.argv if __name__ == '__main__' else []
OUT = _ARGS[1] if len(_ARGS) > 1 else '/tmp/avatar.png'
W = int(_ARGS[2]) if len(_ARGS) > 2 else 1200
H = int(_ARGS[3]) if len(_ARGS) > 3 else 900
SAMPLES = int(_ARGS[4]) if len(_ARGS) > 4 else 64
SCALE = 0.1  # decímetros → metros
CLOSE = os.environ.get('CLOSE')

# ---------------------------------------------------------------- malla base


def load_obj(path):
    verts, faces = [], []  # faces: (grupo, [índices])
    group = None
    for line in open(path):
        if line.startswith('v '):
            _, x, y, z = line.split()[:4]
            verts.append([float(x), float(y), float(z)])
        elif line.startswith('g '):
            group = line.split(None, 1)[1].strip()
        elif line.startswith('f '):
            idx = [int(p.split('/')[0]) - 1 for p in line.split()[1:]]
            faces.append((group, idx))
    return verts, faces


def apply_target(verts, path, w):
    if w == 0:
        return
    for line in open(path):
        if not line.strip() or line.startswith('#'):
            continue
        p = line.split()
        i = int(p[0])
        verts[i][0] += float(p[1]) * w
        verts[i][1] += float(p[2]) * w
        verts[i][2] += float(p[3]) * w


def morphed(sex):
    verts, faces = load_obj(f'{MH}/3dobjs/base.obj')
    t = f'{MH}/targets/macrodetails'
    g = sex
    # Adulto joven, atlético y delgado (mezcla de músculo medio y alto).
    for name, w in [
        (f'universal-{g}-young-averagemuscle-averageweight', 0.45),
        (f'universal-{g}-young-maxmuscle-averageweight', 0.35),
        (f'universal-{g}-young-averagemuscle-minweight', 0.20),
    ]:
        apply_target(verts, f'{t}/{name}.target', w)
    for eth, w in [('caucasian', 0.5), ('african', 0.2), ('asian', 0.3)]:
        apply_target(verts, f'{t}/{eth}-{g}-young.target', w)
    apply_target(verts, f'{t}/proportions/{g}-young-averagemuscle-averageweight-idealproportions.target', 1.0)
    apply_target(verts, f'{t}/height/{g}-young-averagemuscle-averageweight-maxheight.target', 0.35 if g == 'male' else 0.25)
    return verts, faces


# ----------------------------------------------------------------- utilidades


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.5, sss=0.0, sheen=0.0, emit=None, spec=0.5, metal=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if sss:
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (1.0, 0.35, 0.2)
        b.inputs['Subsurface Scale'].default_value = 0.012
    if sheen:
        b.inputs['Sheen Weight'].default_value = sheen
        b.inputs['Sheen Roughness'].default_value = 0.4
    if coat:
        b.inputs['Coat Weight'].default_value = coat
    b.inputs['Specular IOR Level'].default_value = spec
    if emit:
        b.inputs['Emission Color'].default_value = (*emit[0], 1)
        b.inputs['Emission Strength'].default_value = emit[1]
    return m


def add_tint(m):
    """Mezcla el color base con el atributo 'tint' (músculos del ejercicio)."""
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    attr = nt.nodes.new('ShaderNodeAttribute')
    attr.attribute_name = 'tint'
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    links = list(b.inputs['Base Color'].links)
    if links:
        nt.links.new(links[0].from_socket, mix.inputs['A'])
    else:
        mix.inputs['A'].default_value = b.inputs['Base Color'].default_value
    nt.links.new(attr.outputs['Color'], mix.inputs['B'])
    nt.links.new(attr.outputs['Alpha'], mix.inputs['Factor'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    return m


def fabric(name, color, accent_scale=1.0):
    """Tela deportiva mate con trama fina."""
    m = mat(name, color, rough=0.72, sheen=0.12, spec=0.3)
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 900 * accent_scale
    tex.inputs['Detail'].default_value = 2
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.08
    nt.links.new(tex.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m


def skin(name, color):
    m = mat(name, color, rough=0.48, sss=0.25, spec=0.45)
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 400
    tex.inputs['Detail'].default_value = 6
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.05
    nt.links.new(tex.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    # Color: un poco más rosado en mejillas/labios vía variación suave.
    var = nt.nodes.new('ShaderNodeTexNoise')
    var.inputs['Scale'].default_value = 18
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*[c * 0.92 for c in color], 1)
    ramp.color_ramp.elements[1].color = (color[0] * 1.04, color[1] * 0.98, color[2] * 0.96, 1)
    nt.links.new(var.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    return m


def hair_mat(name, color):
    """Pelo peinado: tono castaño oscuro con mechones finos (bump)."""
    m = mat(name, color, rough=0.5, spec=0.35, sheen=0.05)
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Anisotropic'].default_value = 0.6
    coord = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Z'
    wave.inputs['Scale'].default_value = 180
    wave.inputs['Distortion'].default_value = 6
    wave.inputs['Detail'].default_value = 4
    nt.links.new(coord.outputs['Object'], wave.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.35
    nt.links.new(wave.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*[c * 0.55 for c in color], 1)
    ramp.color_ramp.elements[1].color = (*[c * 1.5 for c in color], 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    return m


# ------------------------------------------------------------------- esqueleto


def joint_pos(verts, skel, name):
    vs = skel['joints'][name]
    p = Vector((0, 0, 0))
    for i in vs:
        p += Vector(verts[i])
    return p / len(vs)


def to_blender(v):
    # MakeHuman: y arriba, z adelante → Blender: z arriba, -y adelante.
    return Vector((v[0] * SCALE, -v[2] * SCALE, v[1] * SCALE))


def build_armature(verts, skel, name):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bones = skel['bones']
    for bname, b in bones.items():
        eb = arm.edit_bones.new(bname)
        eb.head = to_blender(joint_pos(verts, skel, b['head']))
        eb.tail = to_blender(joint_pos(verts, skel, b['tail']))
        if (eb.tail - eb.head).length < 1e-4:
            eb.tail = eb.head + Vector((0, 0, 0.01))
    for bname, b in bones.items():
        if b['parent']:
            arm.edit_bones[bname].parent = arm.edit_bones[b['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def aim_bone(rig, bname, world_dir):
    """Gira el hueso para que apunte en [world_dir] (espacio del rig),
    respetando la pose del padre."""
    pb = rig.pose.bones[bname]
    bpy.context.view_layer.update()
    cur = (pb.tail - pb.head).normalized()
    q = cur.rotation_difference(Vector(world_dir).normalized())
    # Matriz del hueso en reposo respecto del padre ya posado.
    rest = pb.bone.matrix_local.to_quaternion()
    parent_q = pb.parent.matrix.to_quaternion() if pb.parent else Quaternion()
    parent_rest = pb.parent.bone.matrix_local.to_quaternion() if pb.parent else Quaternion()
    cur_world = pb.matrix.to_quaternion()
    new_world = q @ cur_world
    # pose_rot = rest⁻¹ · parent_rest · parent⁻¹ · new_world
    local = rest.inverted() @ parent_rest @ parent_q.inverted() @ new_world if pb.parent else rest.inverted() @ new_world
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = local
    bpy.context.view_layer.update()


def faceless(ob, ec):
    """Cara de maniquí: quita la cavidad de la boca, cierra ojos y boca y
    alisa el rostro difundiendo la distancia al centro de la cabeza."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    H = Vector((0, ec.y + 0.07, ec.z - 0.01))
    fz = ec.z - 0.03

    def weight(p):
        if p.y > ec.y + 0.06 or p.z < ec.z - 0.125:
            return 0.0
        e = (p.x / 0.072) ** 2 + ((p.z - fz) / (0.095 if p.z > fz else 0.085)) ** 2
        return max(0.0, min(1.0, (1.0 - e) / 0.35))

    # 1) Cavidades (caras que miran hacia adentro de la cabeza).
    cav = [f for f in bm.faces if weight(f.calc_center_median()) > 0
           and f.normal.dot(f.calc_center_median() - H) < -0.2 * (f.calc_center_median() - H).length]
    bmesh.ops.delete(bm, geom=cav, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    # 2) Cierra los agujeros de ojos y boca.
    bnd = [e for e in bm.edges if e.is_boundary and weight((e.verts[0].co + e.verts[1].co) / 2) > 0]
    if bnd:
        res = bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
        bmesh.ops.triangulate(bm, faces=res['faces'])
    # 3) Difusión del radio y de la dirección.
    vs = [v for v in bm.verts if weight(v.co) > 0]
    w = {v: weight(v.co) for v in vs}
    rad = {v: (v.co - H).length for v in bm.verts}
    dirs = {v: (v.co - H).normalized() for v in bm.verts}
    for _ in range(250):
        new = {}
        for v in vs:
            nb = [e.other_vert(v) for e in v.link_edges]
            if not nb:
                continue
            avg = sum(rad[n] for n in nb) / len(nb)
            new[v] = rad[v] + (avg - rad[v]) * 0.6 * w[v]
        rad.update(new)
    for _ in range(40):
        new = {}
        for v in vs:
            nb = [e.other_vert(v) for e in v.link_edges]
            if not nb:
                continue
            avg = Vector((0, 0, 0))
            for n in nb:
                avg += dirs[n]
            new[v] = dirs[v].lerp(avg.normalized(), 0.5 * w[v]).normalized()
        dirs.update(new)
    for v in vs:
        v.co = H + dirs[v] * rad[v]
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    vg = ob.vertex_groups.get('head')
    if vg:
        unweighted = [v.index for v in ob.data.vertices if not v.groups]
        vg.add(unweighted, 1.0, 'REPLACE')
    for poly in ob.data.polygons:
        poly.use_smooth = True


# ------------------------------------------------------------------ el avatar


def make_avatar(sex, offset_x, yaw_deg, accent, standing=True):
    verts, faces = morphed(sex)
    skel = json.load(open(f'{MH}/rigs/default.mhskel'))
    weights = json.load(open(f'{MH}/rigs/default_weights.mhw'))['weights']
    bverts = [to_blender(v) for v in verts]
    female = sex == 'female'

    rig = build_armature(verts, skel, f'rig_{sex}')

    # Huesos útiles para clasificar la ropa.
    def jp(b, end='head'):
        return to_blender(joint_pos(verts, skel, skel['bones'][b][end]))

    hip_z = jp('pelvis.L').z
    waist_z = jp('spine04').z
    ankle_z = (jp('foot.L').z + jp('foot.R').z) / 2
    neck_z = jp('neck01').z
    sh = {s: jp(f'upperarm01.{s}') for s in 'LR'}
    el = {s: jp(f'lowerarm01.{s}') for s in 'LR'}
    wr = {s: jp(f'wrist.{s}') for s in 'LR'}

    def on_forearm(c):
        for s in 'LR':
            a, b = el[s], wr[s]
            ab = b - a
            t = (c - a).dot(ab) / ab.length_squared
            if -0.1 < t < 1.6:
                d = (c - (a + ab * max(0, min(1, t)))).length
                if d < 0.065 and abs(c.x) > abs(a.x) - 0.03:
                    return True
        return False

    def on_arm(c):
        """Fracción a lo largo del brazo (0 hombro, 1 codo) o None."""
        best = None
        for s in 'LR':
            a, b = sh[s], el[s]
            ab = b - a
            t = (c - a).dot(ab) / ab.length_squared
            if -0.25 < t < 1.0:
                d = (c - (a + ab * max(0, min(1, t)))).length
                if d < 0.075 and (abs(c.x) > abs(a.x) - 0.012):
                    best = t
        return best

    groups = {}
    for gname, idx in faces:
        groups.setdefault(gname, []).append(idx)

    def make_obj(name, face_list, material_for=None, mats=()):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in bverts], [], [tuple(f) for f in face_list])
        me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        for m in mats:
            me.materials.append(m)
        if material_for:
            for poly in me.polygons:
                poly.material_index = material_for(poly)
        for poly in me.polygons:
            poly.use_smooth = True
        # Limpia vértices sueltos sin cambiar la piel ni los pesos.
        for bname, wl in weights.items():
            vg = ob.vertex_groups.new(name=bname)
            for vi, w in wl:
                vg.add([vi], w, 'REPLACE')
        bm = bmesh.new()
        bm.from_mesh(me)
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(me)
        bm.free()
        mod = ob.modifiers.new('rig', 'ARMATURE')
        mod.object = rig
        ob.parent = rig
        return ob

    eye_vs0 = {i for f in groups['helper-l-eye'] + groups['helper-r-eye'] for i in f}
    ec = Vector((0, 0, 0))
    for i in eye_vs0:
        ec += bverts[i]
    ec /= len(eye_vs0)

    gray = (0.13, 0.135, 0.145) if female else (0.12, 0.125, 0.135)
    m_skin = add_tint(mat(f'skin_{sex}', gray, rough=0.55, spec=0.4, sss=0.05))
    body = make_obj(f'body_{sex}', groups['body'], mats=[m_skin])
    faceless(body, ec)
    sub = body.modifiers.new('sub', 'SUBSURF')
    sub.levels = sub.render_levels = 1

    # Ropa: camiseta, pantalón y zapatillas a partir del traje ajustado.
    m_shirt = add_tint(fabric('shirt', (0.028, 0.03, 0.034)))
    m_pants = add_tint(fabric('pants', (0.022, 0.023, 0.026)))
    m_shoe = fabric('shoe', (0.03, 0.033, 0.04), 0.6)
    m_sole = mat('sole', (0.85, 0.86, 0.88), rough=0.6)
    m_acc = mat(f'accent_{sex}', accent, rough=0.4, emit=(accent, 0.6))
    tights = groups['helper-tights']
    shirt_f, pants_f, shoe_f = [], [], []

    def centroid(f):
        c = Vector((0, 0, 0))
        for i in f:
            c += bverts[i]
        return c / len(f)

    arm_faces = set()
    for k, f in enumerate(tights):
        c = centroid(f)
        t = on_arm(c)
        if t is None and on_forearm(c):
            continue
        if t is not None:
            if t < 0.75:
                shirt_f.append(f)
                arm_faces.add(tuple(f))
            continue
        if c.z < ankle_z + 0.035:
            shoe_f.append(f)
        if c.z > hip_z - 0.07 and c.z < neck_z + 0.04:
            shirt_f.append(f)
        if c.z < waist_z + 0.04 and c.z > ankle_z - 0.01:
            pants_f.append(f)

    def cut(ob, p0, n, only=None, delete=True):
        """Corta la malla con un plano y borra lo que queda del lado +n."""
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        n = n.normalized()
        geom = [g for g in bm.verts[:] + bm.edges[:] + bm.faces[:]
                if only is None or (isinstance(g, bmesh.types.BMFace) and only(g.calc_center_median()))
                or (not isinstance(g, bmesh.types.BMFace) and (only is None or any(only(f.calc_center_median()) for f in g.link_faces)))]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=p0, plane_no=n, clear_inner=False, clear_outer=False)
        kill = [f for f in bm.faces if delete and (f.calc_center_median() - p0).dot(n) > 0 and (only is None or only(f.calc_center_median()))]
        bmesh.ops.delete(bm, geom=kill, context='FACES')
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(me)
        bm.free()

    def accent_side(poly, ob):
        n = poly.normal
        c = poly.center
        side = abs(n.x) > 0.93 and abs(c.x) > 0.06
        return 1 if side else 0

    shirt = make_obj(f'shirt_{sex}', shirt_f, mats=[m_shirt, m_acc])
    pants = make_obj(f'pants_{sex}', pants_f, mats=[m_pants, m_acc])
    # Cuello redondo (más bajo adelante), mangas cortas, ruedo sobre la
    # pretina y bastas en el tobillo, con cortes limpios.
    nk = jp('neck01')
    neck_r = 0.072 if female else 0.083
    base_z = neck_z - 0.035
    for k in range(12):
        ang = 2 * math.pi * k / 12
        d = Vector((math.cos(ang), math.sin(ang), 0))
        # Delante (−y) el cuello baja un poco más.
        lift = 0.012 * max(0.0, -d.y)
        p0 = Vector((nk.x, nk.y, 0)) + d * neck_r
        cut(shirt, p0, -d, delete=False, only=lambda c, d=d: c.z > base_z - 0.04
            and (Vector((c.x - nk.x, c.y - nk.y, 0))).dot(d) > 0)
    def inside_neck(c):
        v = Vector((c.x - nk.x, c.y - nk.y, 0))
        lift = 0.012 * max(0.0, -v.normalized().y) if v.length > 0 else 0
        return c.z > neck_z + 0.004 or (v.length < neck_r - 0.001 and c.z > base_z - lift - 0.03)
    me = shirt.data
    bm = bmesh.new()
    bm.from_mesh(me)
    _neck = [f for f in bm.faces if inside_neck(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=_neck, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(me)
    bm.free()
    for s_ in 'LR':
        a_, b_ = sh[s_], el[s_]
        side = 1 if a_.x > 0 else -1
        cut(shirt, a_ + (b_ - a_) * 0.42, b_ - a_, only=lambda c, side=side: c.x * side > 0 and on_arm(c) is not None)
    cut(shirt, Vector((0, 0, hip_z + (0.015 if female else -0.05))), Vector((0, 0, -1)))
    cut(pants, Vector((0, 0, ankle_z + (0.03 if female else 0.045))), Vector((0, 0, -1)))

    def keep_main(ob, min_share=0.05):
        """Borra retazos sueltos (islas pequeñas) de la prenda."""
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        seen, islands = set(), []
        for f in bm.faces:
            if f.index in seen:
                continue
            stack, isl = [f], []
            seen.add(f.index)
            while stack:
                g = stack.pop()
                isl.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
            islands.append(isl)
        total = len(bm.faces)
        kill = [f for isl in islands if len(isl) < total * min_share for f in isl]
        bmesh.ops.delete(bm, geom=kill, context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(ob.data)
        bm.free()

    keep_main(shirt)
    keep_main(pants)
    # Vivos de acento: costados de la camiseta, raglán y costado del pantalón.
    vweights = {}
    for bname, wl in weights.items():
        for vi, w in wl:
            vweights.setdefault(vi, []).append((bname, w))
    tv = sorted({i for f in tights for i in f})
    vnorm = {}
    for f in tights:
        a_, b_, c_ = bverts[f[0]], bverts[f[1]], bverts[f[2]]
        n_ = (b_ - a_).cross(c_ - a_)
        for i in f:
            vnorm[i] = vnorm.get(i, Vector((0, 0, 0))) + n_
    for i in vnorm:
        vnorm[i] = vnorm[i].normalized()
    # La normal debe apuntar hacia afuera del cuerpo.
    cen = Vector((0, 0, 0))
    for i in tv:
        cen += bverts[i]
    cen /= len(tv)
    flip = sum((vnorm[i].dot(Vector((bverts[i].x, 0, 0)))) for i in tv if abs(bverts[i].x) > 0.12) < 0
    if flip:
        for i in vnorm:
            vnorm[i] = -vnorm[i]

    def side_path(sign, z0, z1, leg=False, step=0.012):
        idx = []
        z = z0
        while z < z1:
            cand = [i for i in tv if abs(bverts[i].z - z) < step * 0.6 and bverts[i].x * sign > 0.02
                    and on_arm(bverts[i]) is None]
            if leg:
                cand = [i for i in cand if abs(bverts[i].x) < 0.2]
            else:
                lim = abs(sh['L'].x) - 0.035
                cand = [i for i in cand if abs(bverts[i].x) < lim]
            if cand:
                best = max(cand, key=lambda i: bverts[i].x * sign)
                if not idx or idx[-1] != best:
                    idx.append(best)
            z += step
        return idx

    def line_path(a, b, n=16, front=True):
        idx = []
        for k in range(n + 1):
            p = a + (b - a) * (k / n)
            cand = [i for i in tv if (bverts[i].y < p.y + 0.02 if front else True) and on_arm(bverts[i]) is None]
            i = min(cand, key=lambda i: (bverts[i] - p).length)
            if not idx or idx[-1] != i:
                idx.append(i)
        return idx

    tedges = set()
    for f in tights:
        for k in range(len(f)):
            a_, b_ = f[k], f[(k + 1) % len(f)]
            tedges.add((min(a_, b_), max(a_, b_)))

    def plane_seam(sign, y0, z0, z1, xmax, xmin=0.0):
        """Línea exacta donde la prenda cruza el plano y = y0 (costado)."""
        hits = []
        for a_, b_ in tedges:
            pa, pb = bverts[a_], bverts[b_]
            yy = y0(0.5 * (pa.z + pb.z)) if callable(y0) else y0
            if (pa.y - yy) * (pb.y - yy) > 0 or pa.y == pb.y:
                continue
            t = (yy - pa.y) / (pb.y - pa.y)
            p = pa + (pb - pa) * t
            if not (z0 < p.z < z1) or p.x * sign < xmin or abs(p.x) > xmax or on_arm(p) is not None:
                continue
            n = (vnorm[a_] * (1 - t) + vnorm[b_] * t).normalized()
            if n.x * sign < 0:
                n = -n
            hits.append((p, n, a_ if t < 0.5 else b_))
        out, z = [], z0
        while z < z1:
            sl = [h for h in hits if abs(h[0].z - z) < 0.006]
            if sl:
                out.append(max(sl, key=lambda h: h[0].x * sign))
            z += 0.01
        # Descarta saltos al otro lado (la línea debe ser continua).
        clean = []
        for k, h in enumerate(out):
            near = [o[0].x * sign for o in out[max(0, k - 6):k + 7]]
            if h[0].x * sign >= max(near) - 0.025:
                clean.append(h)
        return clean

    def piping(name, pts, push, target=None):
        if len(pts) < 2:
            return
        verts_, faces_, ring_of = [], [], []
        seg = 6
        for k, (p, out, vi) in enumerate(pts):
            t = (pts[min(k + 1, len(pts) - 1)][0] - pts[max(k - 1, 0)][0]).normalized()
            u = t.cross(out).normalized()
            v = t.cross(u).normalized()
            c = p + out * push
            for j in range(seg):
                a = 2 * math.pi * j / seg
                verts_.append(c + (u * math.cos(a) + v * math.sin(a)) * 0.0016)
            ring_of.append(vi)
        for k in range(len(pts) - 1):
            for j in range(seg):
                a0, a1 = k * seg + j, k * seg + (j + 1) % seg
                faces_.append((a0, a1, a1 + seg, a0 + seg))
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts_, [], faces_)
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        me.materials.append(m_acc)
        for poly in me.polygons:
            poly.use_smooth = True
        for k, vi in enumerate(ring_of):
            for bname, w in vweights.get(vi, []):
                vg = ob.vertex_groups.get(bname) or ob.vertex_groups.new(name=bname)
                vg.add(list(range(k * seg, (k + 1) * seg)), w, 'REPLACE')
        mod = ob.modifiers.new('rig', 'ARMATURE')
        mod.object = rig
        ob.parent = rig
        if target is not None:
            # Pegado sobre la tela ya deformada (se ve en cualquier pose).
            sw = ob.modifiers.new('wrap', 'SHRINKWRAP')
            sw.target = target
            sw.wrap_method = 'NEAREST_SURFACEPOINT'
            sw.wrap_mode = 'OUTSIDE_SURFACE'
            sw.offset = 0.0015
        piping_objs.append((ob, target))

    piping_objs = []
    shirt_push = 0.005 if female else 0.01
    pants_push = 0.005 if female else 0.021
    torso_y = [bverts[i].y for i in tv if hip_z < bverts[i].z < sh['L'].z - 0.1 and abs(bverts[i].x) < 0.12]
    y_torso = sum(torso_y) / len(torso_y)
    for sign in (1, -1):
        s_ = 'L' if sh['L'].x * sign > 0 else 'R'
        arm_z = sh[s_].z - 0.085
        lim = abs(sh['L'].x) - 0.03
        piping(f'pip_side_{sex}_{sign}', plane_seam(sign, y_torso - 0.035, hip_z - 0.06, arm_z, lim, 0.05), shirt_push + 0.0065, shirt)
        armpit = max((bverts[i] for i in tv if abs(bverts[i].z - arm_z) < 0.01 and bverts[i].x * sign > 0
                      and on_arm(bverts[i]) is None), key=lambda p: p.x * sign)
        neckp = Vector((nk.x + sign * (0.055 if female else 0.065), nk.y - 0.05, neck_z - (0.03 if female else 0.055)))
        rag = []
        for i in line_path(armpit, neckp):
            n = vnorm[i]
            if n.dot(bverts[i] - Vector((0, y_torso, bverts[i].z))) < 0:
                n = -n
            rag.append((bverts[i], n, i))
        piping(f'pip_raglan_{sex}_{sign}', rag, shirt_push + 0.0065, shirt)
        def leg_center(z, sign=sign):
            ys = [bverts[i].y for i in tv if abs(bverts[i].z - z) < 0.015 and bverts[i].x * sign > 0.02
                  and abs(bverts[i].x) < 0.25]
            return (sum(ys) / len(ys) - 0.028) if ys else 0.0
        cache = {}
        def leg_y(z, f=leg_center):
            k = round(z, 2)
            if k not in cache:
                cache[k] = f(k)
            return cache[k]
        _ps = plane_seam(sign, leg_y, ankle_z + 0.06, hip_z - 0.06, 0.25, 0.04)
        sm = []
        for k in range(len(_ps)):
            win = _ps[max(0, k - 5):k + 6]
            pz = _ps[k][0].z
            px = sum(h[0].x for h in win) / len(win)
            py = sum(h[0].y for h in win) / len(win)
            nn = Vector((0, 0, 0))
            for h in win:
                nn += h[1]
            sm.append((Vector((px, py, pz)), nn.normalized(), _ps[k][2]))
        _ps = sm
        piping(f'pip_leg_{sex}_{sign}', _ps,
               pants_push + 0.011, pants)

    shoes = make_obj(f'shoes_{sex}', shoe_f, mats=[m_shoe])
    # Caña de la zapatilla: corte limpio, más alto atrás.
    cut(shoes, Vector((0, 0, ankle_z + 0.012)), Vector((0, 0.35, 1)))
    keep_main(shoes, 0.2)
    lowest = min(v.co.z for v in shoes.data.vertices)
    top_ = max(v.co.z for v in shoes.data.vertices)
    # Color por altura en reposo (sigue al pie cuando se mueve).
    nt = m_shoe.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'CONSTANT'
    sole_h = 0.028 / max(0.01, top_ - lowest + 0.034)
    el0 = ramp.color_ramp.elements
    el0[0].color = (0.85, 0.86, 0.88, 1)
    el0[1].position = sole_h
    el0[1].color = (*accent, 1)
    e2 = el0.new(sole_h + 0.03)
    e2.color = (0.03, 0.033, 0.04, 1)
    nt.links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    for ob, push, thick in [(shirt, 0.01 if not female else 0.005, 0.003), (pants, 0.004 if female else 0.012, 0.003),
                            (shoes, 0.02, 0.006)]:
        d = ob.modifiers.new('fit', 'DISPLACE')
        d.strength = push
        d.mid_level = 0
        if ob is pants:
            # Pretina ajustada bajo la camiseta; jogger holgado con puño.
            vg = ob.vertex_groups.new(name='loose')
            for v in ob.data.vertices:
                h = v.co.z - ankle_z
                w = 1.0
                if not female:
                    w = 0.35 if h < 0.07 else (0.35 + (h - 0.07) / 0.06 * 0.65 if h < 0.13 else 1.0)
                top = v.co.z - (hip_z - (0.03 if female else 0.1))
                if top > 0:
                    w *= max(0.15, 1 - top / 0.05)
                vg.add([v.index], min(1.0, w), 'REPLACE')
            d.vertex_group = 'loose'
            d.strength = 0.004 if female else 0.02
        if ob is shoes:
            so = ob.modifiers.new('thick', 'SOLIDIFY')
            so.thickness = thick
            so.offset = 1
        s2 = ob.modifiers.new('sub', 'SUBSURF')
        s2.levels = s2.render_levels = 1

    # Pelo: hebras sobre el casco de pelo.
    eye_c = Vector((0, 0, 0))
    eye_vs = {i for f in groups['helper-l-eye'] + groups['helper-r-eye'] for i in f}
    for i in eye_vs:
        eye_c += bverts[i]
    eye_c /= len(eye_vs)
    head_c = to_blender(joint_pos(verts, skel, skel['bones']['head']['tail']))
    # Pelo esculpido: la superficie de la cabeza con una línea de pelo
    # limpia (inclinada: alta en la frente, baja en la nuca) y volumen.
    head_f = [f for f in groups['body'] if centroid(f).z > eye_c.z - 0.1]
    cap = make_obj(f'hair_{sex}', head_f, mats=[mat('hair', (0.055, 0.057, 0.063), rough=0.38, spec=0.5)])
    yf, yb = eye_c.y - 0.02, eye_c.y + 0.15
    zf, zb = eye_c.z + (0.07 if female else 0.068), eye_c.z - (0.055 if female else 0.06)
    slope = (zb - zf) / (yb - yf)
    n_ = Vector((0, -slope, 1)).normalized()
    cut(cap, Vector((0, yf, zf)), -n_)
    # Sin pelo sobre las orejas ni las sienes bajas.
    for sgn in (1, -1):
        cut(cap, Vector((sgn * 0.068, 0, 0)), Vector((sgn, 0, 0)),
            only=lambda c: c.z < eye_c.z + 0.03)
    keep_main(cap, 0.3)
    cap_disp = cap.modifiers.new('in', 'DISPLACE')
    cap_disp.mid_level = 0
    cap_disp.strength = 0.008 if female else 0.007
    thick = cap.modifiers.new('thick', 'SOLIDIFY')
    thick.thickness = 0.004
    thick.offset = -1
    capsub = cap.modifiers.new('sub', 'SUBSURF')
    capsub.levels = capsub.render_levels = 2
    if female:
        # Moño atrás y arriba.
        top = max(v.co.z for v in cap.data.vertices)
        back = max(v.co.y for v in cap.data.vertices)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.047, location=(0, back - 0.005, top - 0.04), segments=48, ring_count=24)
        bun = bpy.context.active_object
        bun.name = 'bun'
        bun.data.materials.append(cap.data.materials[0])
        bun.data.materials.append(cap.data.materials[0])
        for poly in bun.data.polygons:
            poly.use_smooth = True
        bun.parent = rig
        vg = bun.vertex_groups.new(name='head')
        vg.add(list(range(len(bun.data.vertices))), 1.0, 'REPLACE')
        bm_ = bun.modifiers.new('rig', 'ARMATURE')
        bm_.object = rig
    else:
        bun = None

    ctx = dict(rig=rig, female=female, accent=accent, body=body, shirt=shirt, pants=pants, shoes=shoes,
               hair=cap, bun=bun, pipes=[o for o, _ in piping_objs], hip_z=hip_z, waist_z=waist_z,
               ankle_z=ankle_z, neck_z=neck_z, sh=sh, el=el, wr=wr, on_arm=on_arm, on_forearm=on_forearm,
               knee_z=(jp('lowerleg01.L').z + jp('lowerleg01.R').z) / 2, weights=weights, bverts=bverts)
    if not standing:
        return ctx

    # Pose de pie relajada: brazos al costado, levemente separados.
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='POSE')
    for s, sign in (('L', 1), ('R', -1)):
        aim_bone(rig, f'upperarm01.{s}', (sign * 0.16, 0.02, -1))
        aim_bone(rig, f'upperarm02.{s}', (sign * 0.16, 0.02, -1))
        aim_bone(rig, f'lowerarm01.{s}', (sign * 0.08, -0.12, -1))
        aim_bone(rig, f'lowerarm02.{s}', (sign * 0.08, -0.12, -1))
        aim_bone(rig, f'wrist.{s}', (sign * 0.05, -0.08, -1))
        aim_bone(rig, f'upperleg01.{s}', (sign * 0.07, 0, -1))
        aim_bone(rig, f'upperleg02.{s}', (sign * 0.07, 0, -1))
        aim_bone(rig, f'lowerleg01.{s}', (sign * 0.03, 0, -1))
        aim_bone(rig, f'lowerleg02.{s}', (sign * 0.03, 0, -1))
    bpy.ops.object.mode_set(mode='OBJECT')

    rig.location = (offset_x, 0, 0)
    rig.rotation_euler = (0, 0, math.radians(yaw_deg))
    # Apoya en el piso.
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    ev = shoes.evaluated_get(deps)
    low = min((shoes.matrix_world @ v.co).z for v in ev.data.vertices)
    rig.location.z -= low
    return ctx


def studio():
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.view_settings.exposure = -0.2
    world = bpy.data.worlds.new('w')
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.012, 0.013, 0.016, 1)
    # Piso y fondo curvo oscuro.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.data.materials.append(mat('floor', (0.02, 0.022, 0.026), rough=0.35, spec=0.4))
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 9, 5), rotation=(math.radians(90), 0, 0))
    wall = bpy.context.active_object
    wall.data.materials.append(mat('wall', (0.025, 0.027, 0.032), rough=0.9))
    # Luces: principal suave, relleno, contraluces con acento.
    def area(name, loc, rot, size, energy, color=(1, 1, 1)):
        bpy.ops.object.light_add(type='AREA', location=loc, rotation=[math.radians(r) for r in rot])
        l = bpy.context.active_object
        l.data.size = size
        l.data.energy = energy
        l.data.color = color
        return l
    area('key', (-2.2, -3.0, 3.2), (55, 0, -35), 2.5, 420)
    area('fill', (2.8, -2.6, 1.8), (70, 0, 45), 3.0, 110, (0.9, 0.95, 1.0))
    area('rim_l', (-1.6, 1.4, 2.2), (-60, 0, -150), 1.0, 160, (0.55, 0.9, 1.0))
    area('rim_r', (1.6, 1.4, 2.2), (-60, 0, 150), 1.0, 160, (1.0, 0.65, 0.5))
    area('top', (0, -0.5, 4.2), (0, 0, 0), 3.0, 80)
    area('face', (0, -3.2, 1.7), (90, 0, 0), 2.0, 70, (1.0, 0.96, 0.92))


def ring(x, color):
    for r, s in ((0.36, 2.5), (0.5, 0.6)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.004, location=(x, 0, 0.004),
                                         major_segments=128, minor_segments=8)
        t = bpy.context.active_object
        t.data.materials.append(mat('ring', color, emit=(color, s)))


def camera():
    bpy.ops.object.camera_add(location=(0, -5.0, 0.98), rotation=(math.radians(89), 0, 0))
    cam = bpy.context.active_object
    cam.data.lens = 50
    if CLOSE:
        cam.location = (-0.6 if CLOSE not in ('m', 'l') else 0.6, -1.2, {'w': 1.0, 'l': 0.55}.get(CLOSE, 1.55))
        cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = cam


if __name__ == '__main__':
    clear_scene()
    studio()
    cyan, coral = (0.12, 0.75, 0.9), (1.0, 0.36, 0.22)
    view = float(os.environ.get('VIEW', '0'))
    make_avatar('female', -0.6, view, cyan)
    make_avatar('male', 0.6, view, coral)
    ring(-0.6, cyan)
    ring(0.6, coral)
    camera()
    bpy.context.scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print('OK', OUT)
