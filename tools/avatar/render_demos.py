"""Demostraciones animadas de MAGRA: el maniquí de avatar.py hace cada
ejercicio de anims.json (exportado desde la app) y se renderiza en mujer y
hombre, en tres vistas fijas, como hojas de cuadros WebP con transparencia.

  venv/bin/python render_demos.py SALIDA [--only slug1,slug2] [--sex f|m]
                                         [--views f,l,b] [--samples 24]

Salida: SALIDA/<slug>_<f|m>_<f|l|b>.webp y SALIDA/thumbs/<slug>_<f|m>.webp.
Se puede cortar y retomar: salta las hojas que ya existen.
"""
import argparse
import json
import math
import os
import shutil
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import avatar as A  # noqa: E402

FRAME = int(os.environ.get('DEMO_FRAME', '576'))
COLS = 4
CYAN, CORAL = (0.12, 0.75, 0.9), (1.0, 0.36, 0.22)
RED, ORANGE = (1.0, 0.035, 0.08), (1.0, 0.32, 0.05)
VIEWS = {'f': 0.0, 'l': -65.0, 'b': 180.0}

# ------------------------------------------------------------ poses de la app


def d2b(x, y, z):
    """Marco del maniquí de la app (y arriba, z adelante) → Blender."""
    return Vector((x, -z, y))


def seg_dir(seg, sign, trunk=None):
    f, a = math.radians(seg['flex']), math.radians(seg['abd'])
    x, y, z = sign * math.sin(a), -math.cos(f) * math.cos(a), math.sin(f) * math.cos(a)
    if trunk is not None:
        t = math.radians(trunk)
        y, z = y * math.cos(t) - z * math.sin(t), y * math.sin(t) + z * math.cos(t)
    return d2b(x, y, z).normalized()


class Solver:
    """Pose del esqueleto sin evaluar la escena (rápido)."""

    def __init__(self, rig):
        self.rig = rig
        bones = rig.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.length = {b.name: b.length for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        order, seen = [], set()

        def visit(n):
            if n in seen:
                return
            p = self.parent[n]
            if p:
                visit(p)
            seen.add(n)
            order.append(n)

        for b in bones:
            visit(b.name)
        self.order = order
        self.rest_dir = {n: (m.to_3x3() @ Vector((0, 1, 0))).normalized() for n, m in self.rest.items()}
        h = lambda n: self.rest[n].translation  # noqa: E731
        self.rest_torso = (h('neck01') - h('spine05')).normalized()
        self._grip_signs()

    def _grip_signs(self):
        """Hacia dónde se cierran los dedos (y el pulgar) de cada mano."""
        w0, _ = self.solve({})
        self.flex = {}
        for s in 'LR':
            k2, k5 = head(w0, f'finger2-1.{s}'), head(w0, f'finger5-1.{s}')
            d = (tail(w0, self, f'finger3-3.{s}') - head(w0, f'finger3-1.{s}')).normalized()
            n = -(d.cross(k5 - k2)).normalized()
            if s == 'R':
                n = -n
            signs = []
            for f, ax in (('finger3', 'Z'), ('finger1', 'X')):
                ex = {f'{f}-{j}.{s}': Matrix.Rotation(math.radians(40), 4, ax) for j in (1, 2, 3)}
                w1, _ = self.solve({}, extra=ex)
                mv = tail(w1, self, f'{f}-3.{s}') - tail(w0, self, f'{f}-3.{s}')
                signs.append(1.0 if mv.dot(n) > 0 else -1.0)
            self.flex[s] = tuple(signs)

    def grip(self, sides, amount=1.0):
        """Rotaciones locales que cierran la mano alrededor de un mango."""
        ex = {}
        for s in sides:
            fs, ts = self.flex[s]
            for k in (2, 3, 4, 5):
                for j, ang in ((1, 62), (2, 88), (3, 58)):
                    ex[f'finger{k}-{j}.{s}'] = Matrix.Rotation(fs * math.radians(ang * amount), 4, 'Z')
        return ex

    def thumbs(self, world, sides, targets):
        """Apunta el pulgar por encima de las falanges del índice y el medio
        (agarre de fuerza), con los dedos ya cerrados en [world]."""
        tg = dict(targets)
        for s in sides:
            pts = [head(world, f'finger{k}-{j}.{s}') for k in (2, 3, 4, 5) for j in (1, 2, 3)]
            fist = sum(pts, Vector((0, 0, 0))) / len(pts)
            base = head(world, f'finger1-2.{s}')
            q1 = head(world, f'finger2-2.{s}')
            q2 = (head(world, f'finger2-3.{s}') + head(world, f'finger3-2.{s}')) / 2
            q1 = q1 + (q1 - fist).normalized() * 0.012
            q2 = q2 + (q2 - fist).normalized() * 0.012
            d1 = (q1 - base).normalized()
            tg[f'finger1-2.{s}'] = d1
            mid = base + d1 * self.length[f'finger1-2.{s}']
            tg[f'finger1-3.{s}'] = (q2 - mid).normalized()
        return tg

    def solve(self, targets, twist=None, extra=None):
        world, basis = {}, {}
        twist = twist or {}
        extra = extra or {}
        for n in self.order:
            R = self.rest[n]
            p = self.parent[n]
            base = world[p] @ self.rest[p].inverted() @ R if p else R.copy()
            M = base
            if n in targets:
                cur = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
                q = cur.rotation_difference(targets[n])
                M = Matrix.Translation(M.translation) @ (q.to_matrix() @ M.to_3x3()).to_4x4()
            if n in twist:
                M = M @ Matrix.Rotation(twist[n], 4, 'Y')
            if n in extra:
                M = M @ extra[n]
            world[n] = M
            basis[n] = base.inverted() @ M
        return world, basis

    def apply(self, basis):
        for n, B in basis.items():
            pb = self.rig.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = B.to_quaternion()
            pb.location = (0, 0, 0)


def targets_for(pose, solver):
    """Direcciones de los huesos de MakeHuman para una pose de la app."""
    t, sd = math.radians(pose['trunk']), math.radians(pose['side'])
    torso = d2b(math.sin(sd), math.cos(t) * math.cos(sd), math.sin(t) * math.cos(sd)).normalized()
    q = solver.rest_torso.rotation_difference(torso)
    tg = {}
    for n in ('spine05', 'spine04', 'spine03', 'spine02', 'spine01', 'neck01', 'neck02', 'neck03', 'head'):
        tg[n] = q @ solver.rest_dir[n]
    trunk = pose['trunk'] if pose['armsWithTrunk'] else None
    # En la app, 'l' está en −x y 'r' en +x; en MakeHuman .L está en +x.
    for app_side, mh, sign in (('l', 'R', -1.0), ('r', 'L', 1.0)):
        ua = seg_dir(pose[f'{app_side}UpperArm'], sign, trunk)
        fa = seg_dir(pose[f'{app_side}Forearm'], sign, trunk)
        th = seg_dir(pose[f'{app_side}Thigh'], sign)
        sh = seg_dir(pose[f'{app_side}Shin'], sign)
        tg[f'upperarm01.{mh}'] = tg[f'upperarm02.{mh}'] = ua
        tg[f'lowerarm01.{mh}'] = tg[f'lowerarm02.{mh}'] = fa
        tg[f'wrist.{mh}'] = fa
        tg[f'upperleg01.{mh}'] = tg[f'upperleg02.{mh}'] = th
        tg[f'lowerleg01.{mh}'] = tg[f'lowerleg02.{mh}'] = sh
        fwd = Vector((0, -1, 0))
        toe = (fwd - sh * fwd.dot(sh))
        toe = toe.normalized() if toe.length > 1e-3 else fwd
        tg[f'foot.{mh}'] = (toe * 0.9 + sh * 0.35).normalized()
    tw = math.radians(pose['twist'])
    return tg, {'spine02': tw / 2, 'spine01': tw / 2}


# ------------------------------------------------------------------ geometría


def head(world, n):
    return world[n].translation.copy()


def tail(world, solver, n):
    return world[n] @ Vector((0, solver.length[n], 0))


def make_samples(ctx, solver):
    """Puntos del cuerpo y de la suela atados a su hueso principal, para
    apoyar en el suelo y encuadrar sin evaluar las mallas."""
    out = []
    for ob, margin, step in ((ctx['body'], 0.0, 7), (ctx['shoes'], 0.026, 2)):
        names = {g.index: g.name for g in ob.vertex_groups}
        for v in list(ob.data.vertices)[::step]:
            gs = [(g.weight, names[g.group]) for g in v.groups if names[g.group] in solver.rest]
            if not gs:
                continue
            _, b = max(gs)
            local = solver.rest[b].inverted() @ v.co
            out.append((b, local, margin))
    return out


class Placement:
    def __init__(self, pitch, loc):
        self.pitch = pitch
        self.R = Matrix.Rotation(math.radians(pitch), 4, 'X')
        self.loc = loc

    def w(self, p):
        return (self.R @ p) + self.loc


def place(pose, world, solver, samples, hip_h):
    R = Matrix.Rotation(math.radians(pose['pitch']), 4, 'X')
    pts = [(R @ (world[b] @ l), m) for b, l, m in samples]
    hips = (head(world, 'upperleg01.L') + head(world, 'upperleg01.R')) / 2
    hips_r = R @ hips
    if pose['rootY'] is not None:
        z = pose['rootY'] / 92.0 * hip_h - hips_r.z
    else:
        z = -min(p.z - m for p, m in pts)
    ank = [R @ head(world, f'foot.{s}') for s in 'LR']
    cx = (ank[0].x + ank[1].x) / 2
    cy = (ank[0].y + ank[1].y + 2 * hips_r.y) / 4
    return Placement(pose['pitch'], Vector((-cx, -cy, z)))


# ------------------------------------------------------------- tinte muscular


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def zones(ctx, co, n):
    """Pertenencia (0–1) de un punto en reposo a cada zona muscular."""
    z = co.z
    hip, waist, neck, knee, ank = ctx['hip_z'], ctx['waist_z'], ctx['neck_z'], ctx['knee_z'], ctx['ankle_z']
    shz = (ctx['sh']['L'].z + ctx['sh']['R'].z) / 2
    shx = abs(ctx['sh']['L'].x)
    f, b, side = -n.y, n.y, abs(n.x)
    out = {}
    t_arm = ctx['on_arm'](co)
    if t_arm is not None:
        out['shoulders'] = 1 - smooth(0.25, 0.45, t_arm)
        out['biceps'] = smooth(0.0, 0.45, f) * smooth(0.2, 0.4, t_arm)
        out['triceps'] = smooth(0.0, 0.45, b) * smooth(0.2, 0.4, t_arm)
        return out
    if ctx['on_forearm'](co):
        out['forearms'] = 1.0
        return out
    if z > hip - 0.02 and abs(co.x) < shx + 0.02:
        out['chest'] = smooth(0.25, 0.6, f) * smooth(waist + 0.1, waist + 0.15, z) * (1 - smooth(neck - 0.04, neck, z))
        out['abs'] = smooth(0.35, 0.7, f) * smooth(hip, hip + 0.04, z) * (1 - smooth(waist + 0.1, waist + 0.15, z))
        out['obliques'] = smooth(0.55, 0.85, side) * (1 - smooth(waist + 0.08, waist + 0.14, z))
        out['lats'] = smooth(0.2, 0.6, b + side * 0.4) * smooth(waist, waist + 0.05, z) * (1 - smooth(shz - 0.1, shz - 0.05, z))
        out['midBack'] = smooth(0.5, 0.85, b) * smooth(waist + 0.08, waist + 0.13, z) * (1 - smooth(shz - 0.04, shz, z))
        out['traps'] = smooth(-0.1, 0.4, b + 0.2) * smooth(shz - 0.05, shz, z) * (1 - smooth(neck + 0.03, neck + 0.07, z))
        out['lowerBack'] = smooth(0.5, 0.85, b) * smooth(hip - 0.02, hip + 0.02, z) * (1 - smooth(waist + 0.02, waist + 0.07, z))
        out['shoulders'] = smooth(0.55, 0.9, side) * smooth(shz - 0.06, shz - 0.02, z) * smooth(shx - 0.07, shx - 0.03, abs(co.x))
    if z < hip + 0.06:
        out['glutes'] = smooth(0.25, 0.6, b) * smooth(hip - 0.16, hip - 0.1, z) * (1 - smooth(hip + 0.02, hip + 0.06, z))
        inner = -n.x * (1 if co.x > 0 else -1)
        legband = smooth(knee + 0.02, knee + 0.06, z) * (1 - smooth(hip - 0.06, hip - 0.02, z))
        out['quads'] = smooth(-0.1, 0.4, f) * legband
        out['hamstrings'] = smooth(0.1, 0.5, b) * legband
        out['adductors'] = smooth(0.4, 0.8, inner) * legband
        out['calves'] = smooth(0.1, 0.5, b) * smooth(ank + 0.06, ank + 0.1, z) * (1 - smooth(knee - 0.04, knee, z))
    return out


def apply_tint(ctx, primary, secondary):
    for key in ('body', 'shirt', 'pants'):
        ob = ctx[key]
        me = ob.data
        attr = me.color_attributes.get('tint') or me.color_attributes.new('tint', 'FLOAT_COLOR', 'POINT')
        # Normales hacia afuera: el frente de la cadera debe mirar a −y.
        ys = [v.co.y for v in me.vertices]
        cy = sum(ys) / len(ys)
        front = [v.normal.y for v in me.vertices
                 if abs(v.co.z - ctx['hip_z']) < 0.12 and v.co.y < cy - 0.04 and abs(v.co.x) < 0.12]
        sgn = -1 if front and sum(front) / len(front) > 0 else 1
        for v in me.vertices:
            zs = zones(ctx, v.co, v.normal * sgn)
            p = max([zs.get(m, 0.0) for m in primary] + [0.0])
            s = max([zs.get(m, 0.0) for m in secondary] + [0.0])
            if p > 0.02:
                c = (*RED, 0.8 * p)
            elif s > 0.02:
                c = (*ORANGE, 0.7 * s)
            else:
                c = (0, 0, 0, 0)
            attr.data[v.index].color = c


# ------------------------------------------------------------------ implementos


def unit_cyl(name, mat, radius=1.0, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=1.0)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def set_between(o, a, b, radius=None):
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    r = radius if radius is not None else 1.0
    o.matrix_world = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((r, r, d.length, 1))


def unit_box(name, mat):
    bpy.ops.mesh.primitive_cube_add(size=2.0)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    bev = o.modifiers.new('bev', 'BEVEL')
    bev.width = 0.008
    bev.segments = 2
    return o


def set_box(o, c, ax, ay, az):
    m = Matrix((
        (ax.x, ay.x, az.x, c.x),
        (ax.y, ay.y, az.y, c.y),
        (ax.z, ay.z, az.z, c.z),
        (0, 0, 0, 1),
    ))
    o.matrix_world = m


def _bumped(m, scale, strength, kind='noise'):
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    coord = nt.nodes.new('ShaderNodeTexCoord')
    if kind == 'wave':
        t = nt.nodes.new('ShaderNodeTexWave')
        t.inputs['Distortion'].default_value = 3
        t.inputs['Detail'].default_value = 3
    else:
        t = nt.nodes.new('ShaderNodeTexNoise')
        t.inputs['Detail'].default_value = 4
    t.inputs['Scale'].default_value = scale
    nt.links.new(coord.outputs['Object'], t.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = strength
    nt.links.new(t.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m


def _wood():
    m = A.mat('wood', (0.5, 0.36, 0.22), rough=0.6, spec=0.4)
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    coord = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Z'
    wave.inputs['Scale'].default_value = 9
    wave.inputs['Distortion'].default_value = 5
    wave.inputs['Detail'].default_value = 4
    nt.links.new(coord.outputs['Object'], wave.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.46, 0.32, 0.19, 1)
    ramp.color_ramp.elements[1].color = (0.62, 0.47, 0.3, 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.1
    nt.links.new(wave.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m


def mk_cyl(name, m, r, depth, verts=32, bevel=0.0, rot=0.0):
    """Cilindro de tamaño real a lo largo de Z (centrado)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, rotation=(0, 0, rot))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    if bevel:
        bv = o.modifiers.new('bev', 'BEVEL')
        bv.width = bevel
        bv.segments = 3
        bv.limit_method = 'ANGLE'
    _smooth_by_angle(o)
    return o


def mk_box(name, m, sx, sy, sz, bevel=0.0, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(m)
    if bevel:
        bv = o.modifiers.new('bev', 'BEVEL')
        bv.width = bevel
        bv.segments = segments
        bv.limit_method = 'ANGLE'
    _smooth_by_angle(o)
    return o


def _smooth_by_angle(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))


def _sized(o, M, sx, sy, sz):
    """Escala la malla (no el objeto, así el bisel no se deforma) y ubica."""
    o.data.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    o.matrix_world = M


def orient(o, c, z, x=None, zscale=1.0):
    """Ubica [o] con su eje Z a lo largo de [z] (y X hacia [x] si se da)."""
    z = z.normalized()
    if x is None:
        x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    o.matrix_world = Matrix((
        (x.x, y.x, z.x * zscale, c.x),
        (x.y, y.y, z.y * zscale, c.y),
        (x.z, y.z, z.z * zscale, c.z),
        (0, 0, 0, 1),
    ))


def span(o, a, b, x=None):
    """Objeto de largo 1 en Z estirado de [a] a [b] (cables, bandas)."""
    orient(o, (a + b) / 2, b - a, x, (b - a).length)


class Props:
    """Implementos con materiales reales: mancuernas hexagonales con mango
    moleteado, barra olímpica con discos, bancos tapizados sobre estructura
    de acero, cajón de madera, poleas con cable de acero y bandas de goma."""

    def __init__(self, names, accent, slug=''):
        self.names = names
        self.objs = []
        self.parts = {}
        chrome = A.mat('chrome', (0.8, 0.81, 0.83), rough=0.14, metal=1.0)
        knurl = _bumped(A.mat('knurl', (0.72, 0.73, 0.75), rough=0.32, metal=1.0), 2600, 0.7)
        rubber = _bumped(A.mat('rubber', (0.024, 0.025, 0.028), rough=0.72, spec=0.35), 700, 0.06)
        frame = _bumped(A.mat('frame', (0.05, 0.053, 0.058), rough=0.42, metal=0.55), 1500, 0.05)
        vinyl = _bumped(A.mat('vinyl', (0.032, 0.033, 0.037), rough=0.48, sheen=0.25, coat=0.15), 1800, 0.08)
        board = A.mat('board', (0.02, 0.02, 0.022), rough=0.6)
        cable = A.mat('cable', (0.42, 0.43, 0.45), rough=0.3, metal=1.0)
        band = A.mat('bandm', tuple(c * 0.7 for c in accent), rough=0.55, spec=0.4)
        mat_m = _bumped(A.mat('matp', (0.05, 0.055, 0.06), rough=0.85), 900, 0.15)
        wall = _bumped(A.mat('wallp', (0.07, 0.073, 0.08), rough=0.9), 300, 0.08)
        plate_steel = _bumped(A.mat('pstl', (0.3, 0.31, 0.33), rough=0.35, metal=1.0), 400, 0.3, 'wave')
        is_band = 'banda' in slug
        self.bands = set()

        def add(key, o):
            self.parts.setdefault(key, []).append(o)
            self.objs.append(o)

        for p in names:
            if p in ('barbellBack', 'barbellHands'):
                add(p, mk_cyl('shaft', knurl, 0.014, 1.31, 24))
                for sgn in (1, -1):
                    add(p, mk_cyl('sleeve', chrome, 0.025, 0.42, 32))
                    add(p, mk_cyl('collar', chrome, 0.026, 0.03, 32, 0.002))
                    add(p, mk_cyl('bumper', rubber, 1.0, 1.0, 64))  # escala variable
                    add(p, mk_cyl('hub', chrome, 0.062, 0.058, 48, 0.003))
                    add(p, mk_cyl('bumper2', rubber, 0.2, 0.04, 64, 0.006))
                    add(p, mk_cyl('clamp', frame, 0.036, 0.026, 32, 0.004))
            elif p in ('dumbbells', 'dumbbellRight', 'goblet'):
                n = 2 if p == 'dumbbells' else 1
                for k in range(n):
                    add(p, mk_cyl('dh', knurl, 0.0165, 0.13, 24))
                    for sgn in (1, -1):
                        add(p, mk_cyl('dc', chrome, 0.024, 0.012, 32, 0.002))
                        add(p, mk_cyl('dw', rubber, 0.06, 0.075, 6, 0.008, math.radians(30)))
                        add(p, mk_cyl('de', chrome, 0.022, 0.006, 32, 0.0015))
            elif p == 'bar':
                add(p, mk_cyl('pbar', knurl, 0.015, 1.2, 24))
                for sgn in (1, -1):
                    add(p, mk_cyl('grip', rubber, 0.02, 0.14, 24, 0.003))
                if 'cableHigh' not in names:
                    for sgn in (1, -1):
                        add(p, mk_box('upright', frame, 0.07, 0.07, 1.0, 0.004))
            elif p in ('bench', 'benchUnderHands', 'benchBack'):
                add(p, mk_box('pad', vinyl, 1, 1, 0.06, 0.018, 5))
                add(p, mk_box('board', board, 1, 1, 0.014))
                add(p, mk_box('spine', frame, 1, 0.07, 0.05, 0.004))
                for k in range(2):
                    add(p, mk_box('post', frame, 0.06, 0.06, 1.0, 0.004))
                    add(p, mk_box('foot', frame, 0.07, 1, 0.045, 0.006))
                    add(p, mk_box('cap', rubber, 0.075, 0.05, 0.02, 0.004))
            elif p == 'box':
                add(p, mk_box('box', _wood(), 1, 1, 1, 0.01, 3))
            elif p == 'footPlate':
                add(p, mk_box('plate', plate_steel, 1, 1, 1, 0.006))
                for sgn in (1, -1):
                    add(p, mk_cyl('rail', chrome, 0.022, 1.0, 24))
                    add(p, mk_box('sledside', frame, 0.05, 0.05, 0.5, 0.004))
                add(p, mk_box('backpad', vinyl, 1, 1, 0.07, 0.02, 5))
            elif p == 'wall':
                add(p, mk_box('wall', wall, 1, 1, 1, 0.004))
            elif p == 'floorMat':
                add(p, mk_box('mat', mat_m, 1, 1, 1, 0.003))
            elif p in ('cableForward', 'cableHigh', 'cableSide', 'band'):
                if p == 'band' or (p == 'cableHigh' and is_band):
                    self.bands.add(p)
                    for k in range(2):
                        add(p, mk_box('band', band, 0.032, 0.004, 1.0))
                    continue
                add(p, mk_cyl('cable', cable, 0.0028, 1.0, 12))
                add(p, mk_cyl('pulley', frame, 0.055, 0.03, 40, 0.004))
                add(p, mk_cyl('pulleyc', chrome, 0.018, 0.034, 24))
                if p != 'cableHigh':
                    add(p, mk_cyl('handle', rubber, 0.018, 0.13, 24, 0.003))
                    add(p, mk_box('column', frame, 0.12, 0.12, 1.0, 0.006))
                else:
                    add(p, mk_box('column', frame, 0.12, 0.12, 1.0, 0.006))
                    add(p, mk_box('beam', frame, 0.1, 0.1, 1.0, 0.006))

    def remove(self):
        for o in self.objs:
            bpy.data.objects.remove(o, do_unlink=True)

    def update(self, J, first, static_done):
        """J: puntos del cuerpo en el mundo para este cuadro; first: los del
        primer cuadro (para implementos fijos)."""
        lat, up, fwd = J['lat'], J['up'], J['fwd']
        zup = Vector((0, 0, 1))
        for p, objs in self.parts.items():
            if p in ('barbellBack', 'barbellHands'):
                if p == 'barbellBack':
                    c, bl = J['neck'] - fwd * 0.08 - up * 0.02, lat
                else:
                    c, bl = (J['fistL'] + J['fistR']) / 2, (J['fistL'] - J['fistR']).normalized()
                orient(objs[0], c, bl)
                r = min(0.225, max(0.12, c.z))
                for k, sgn in enumerate((1, -1)):
                    o = objs[1 + 6 * k:7 + 6 * k]
                    d = bl * sgn
                    orient(o[0], c + d * 0.895, d)
                    orient(o[1], c + d * 0.67, d)
                    o[2].matrix_world = Matrix.Translation(c + d * 0.7375) @ (
                        d.to_track_quat('Z', 'Y').to_matrix().to_4x4()) @ Matrix.Diagonal((r, r, 0.055, 1))
                    orient(o[3], c + d * 0.7375, d)
                    orient(o[4], c + d * 0.787, d)
                    o[4].scale = (min(1.0, (r - 0.02) / 0.2),) * 2 + (1,)
                    orient(o[5], c + d * 0.825, d)
            elif p in ('dumbbells', 'dumbbellRight', 'goblet'):
                if p == 'goblet':
                    centers = [((J['fistL'] + J['fistR']) / 2 - fwd * 0.03, up)]
                elif p == 'dumbbellRight':
                    centers = [(J['fistL'], J['haxL'])]
                else:
                    centers = [(J['fistL'], J['haxL']), (J['fistR'], J['haxR'])]
                for k, (c, ax) in enumerate(centers):
                    o = objs[7 * k:7 * k + 7]
                    orient(o[0], c, ax)
                    for j, sgn in enumerate((1, -1)):
                        d = ax * sgn
                        orient(o[1 + 3 * j], c + d * 0.071, d, zup)
                        orient(o[2 + 3 * j], c + d * 0.1145, d, zup)
                        orient(o[3 + 3 * j], c + d * 0.155, d, zup)
            elif p == 'bar':
                c = (J['fistL'] + J['fistR']) / 2
                bl = (J['fistL'] - J['fistR']).normalized()
                orient(objs[0], c, bl)
                orient(objs[1], J['fistL'], bl)
                orient(objs[2], J['fistR'], bl)
                if len(objs) > 3 and not static_done:
                    for k, sgn in enumerate((1, -1)):
                        e = c + bl * sgn * 0.62
                        orient(objs[3 + k], Vector((e.x, e.y, (e.z + 0.05) / 2)), zup, None, e.z + 0.05)
            elif p in ('cableForward', 'cableHigh', 'cableSide', 'band'):
                h = (J['fistL'] + J['fistR']) / 2
                if p in self.bands:
                    if p == 'band':
                        # Banda tensa por delante del pecho.
                        mid = J['neck'] - up * 0.16 + fwd * 0.16
                        mid = (mid + (J['fistL'] + J['fistR']) / 2) / 2 + fwd * 0.04
                        span(objs[0], J['fistL'], mid, up)
                        span(objs[1], mid, J['fistR'], up)
                    else:
                        anchor = Vector((h.x, h.y - 0.35, 2.3))
                        span(objs[0], J['fistL'], anchor, lat)
                        span(objs[1], J['fistR'], anchor, lat)
                    continue
                if p == 'cableForward':
                    pul = Vector((h.x, h.y - 1.1, 0.32))
                elif p == 'cableHigh':
                    pul = Vector((h.x, h.y, 2.55))
                else:
                    pul = Vector((h.x + 1.1, h.y, h.z))
                span(objs[0], h, pul)
                dirc = (pul - h).normalized()
                side_ax = dirc.cross(zup) if abs(dirc.z) < 0.9 else Vector((1, 0, 0))
                orient(objs[1], pul, side_ax)
                orient(objs[2], pul, side_ax)
                if p != 'cableHigh':
                    orient(objs[3], h, (J['fistL'] - J['fistR']) if p == 'cableForward' else J['haxL'])
                    if not static_done:
                        top = 2.1 if p == 'cableSide' else 0.42
                        base = pul + dirc * 0.08
                        orient(objs[4], Vector((base.x, base.y, top / 2)), zup, None, top)
                elif not static_done:
                    col = Vector((pul.x + 0.7, pul.y + 0.45, 0))
                    orient(objs[3], Vector((col.x, col.y, 1.35)), zup, None, 2.7)
                    a_, b_ = Vector((col.x, col.y, 2.62)), Vector((pul.x, pul.y, 2.62))
                    span(objs[4], a_, b_)
            elif not static_done:
                self._static(p, objs, first)

    def _static(self, p, objs, F):
        upz = Vector((0, 0, 1))
        body_axis = F['neck'] - F['hips']
        flat = Vector((body_axis.x, body_axis.y, 0))
        along = flat.normalized() if flat.length > 0.1 else Vector((0, 1, 0))
        across = Vector((-along.y, along.x, 0))
        if p == 'bench':
            c = (F['hips'] + F['neck']) / 2
            top = min(F['hips'].z, F['neck'].z) - 0.11
            self._bench(objs, Vector((c.x, c.y, 0)), top, along, 0.55, across, 0.15)
        elif p == 'benchUnderHands':
            l, r = F['gripL'], F['gripR']
            both = abs(l.z - r.z) < 0.04
            c = (l + r) / 2 if both else (l if l.z < r.z else r)
            self._bench(objs, Vector((c.x, c.y, 0)), c.z - 0.03, Vector((1, 0, 0)), 0.45 if both else 0.32,
                        Vector((0, 1, 0)), 0.15)
        elif p == 'benchBack':
            c = F['neck'] + (F['waist'] - F['neck']) * 0.3
            self._bench(objs, Vector((c.x, c.y, 0)), c.z - 0.11, across, 0.55, along, 0.16)
        elif p == 'box':
            c = F['hips'] - F['fwd'] * 0.1
            h = max(0.2, F['hips'].z - 0.1)
            _sized(objs[0], Matrix.Translation(Vector((c.x, c.y, h / 2))), 0.4, 0.34, h)
        elif p == 'footPlate':
            c = (F['ankL'] + F['ankR']) / 2
            n = ((F['kneeL'] + F['kneeR']) / 2 - c).normalized()
            s = F['lat']
            v = n.cross(s).normalized()
            pc = c - n * 0.06
            _sized(objs[0], Matrix((
                (s.x, v.x, n.x, pc.x), (s.y, v.y, n.y, pc.y), (s.z, v.z, n.z, pc.z), (0, 0, 0, 1),
            )), 0.54, 0.5, 0.026)
            for k, sgn in enumerate((1, -1)):
                a_ = pc - n * 0.05 + s * sgn * 0.3
                b_ = a_ - n * 1.1
                span(objs[1 + 2 * k], a_, b_)
                orient(objs[2 + 2 * k], pc - n * 0.04 + s * sgn * 0.3, v, s)
            # Respaldo inclinado de la máquina detrás de la espalda.
            d = F['neck'] - F['hips']
            ln = d.length
            d.normalize()
            back = -F['fwd']
            bc = (F['hips'] + F['neck']) / 2 + back * 0.135 + d * 0.02
            x_ = d
            y_ = F['lat']
            z_ = x_.cross(y_).normalized()
            _sized(objs[5], Matrix((
                (x_.x, y_.x, z_.x, bc.x), (x_.y, y_.y, z_.y, bc.y), (x_.z, y_.z, z_.z, bc.z), (0, 0, 0, 1),
            )), ln * 1.15, 0.36, 1)
        elif p == 'wall':
            hy = min(F['gripL'].y, F['gripR'].y) - 0.04
            _sized(objs[0], Matrix.Translation(Vector((0, hy - 0.03, 1.1))), 1.2, 0.06, 2.2)
        elif p == 'floorMat':
            c = F['hips']
            ax = along if flat.length > 0.1 else Vector((0, 1, 0))
            ac = Vector((-ax.y, ax.x, 0))
            _sized(objs[0], Matrix((
                (ac.x, ax.x, 0, c.x), (ac.y, ax.y, 0, c.y), (0, 0, 1, 0.004), (0, 0, 0, 1),
            )), 0.62, 1.8, 0.008)

    def _bench(self, objs, c, top, ax, half_len, ac, half_w):
        """Banco plano: tapiz sobre tabla, viga central, dos patas con pie."""
        upz = Vector((0, 0, 1))
        L, W = 2 * half_len, 2 * half_w

        def put(o, center, sx, sy, sz):
            _sized(o, Matrix((
                (ax.x, ac.x, 0, center.x), (ax.y, ac.y, 0, center.y), (0, 0, 1, center.z), (0, 0, 0, 1),
            )), sx, sy, sz)
        pad, board, spine = objs[0], objs[1], objs[2]
        put(pad, Vector((c.x, c.y, top - 0.03)), L, W, 1)
        put(board, Vector((c.x, c.y, top - 0.067)), L * 0.94, W * 0.9, 1)
        put(spine, Vector((c.x, c.y, top - 0.1)), L * 0.8, 1, 1)
        h = max(0.05, top - 0.1)
        for k, sgn in enumerate((1, -1)):
            post, foot, cap = objs[3 + 3 * k:6 + 3 * k]
            e = c + ax * sgn * L * 0.36
            put(post, Vector((e.x, e.y, h / 2)), 1, 1, h)
            put(foot, Vector((e.x, e.y, 0.0225)), 1, W * 1.5 + 0.1, 1)
            put(cap, Vector((e.x, e.y, 0.01)), 1, (W * 1.5 + 0.12) / 0.05, 1)


# ---------------------------------------------------------------- escena


def scene_setup(samples):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.device = 'CPU'
    sc.render.resolution_x = sc.render.resolution_y = FRAME
    sc.render.film_transparent = True
    sc.render.use_persistent_data = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.view_settings.exposure = -0.2
    world = bpy.data.worlds.new('w')
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.012, 0.013, 0.016, 1)
    bpy.ops.mesh.primitive_plane_add(size=30)
    floor = bpy.context.active_object
    floor.is_shadow_catcher = True
    bpy.ops.object.empty_add(location=(0, 0, 0))
    rigl = bpy.context.active_object
    rigl.name = 'lights'
    lights = {}

    def area(name, loc, rot, size, energy, color=(1, 1, 1)):
        bpy.ops.object.light_add(type='AREA', location=loc, rotation=[math.radians(r) for r in rot])
        l = bpy.context.active_object
        l.data.size = size
        l.data.energy = energy
        l.data.color = color
        l.parent = rigl
        lights[name] = l
    # Principal más direccional (sombras que dibujan el relieve) y relleno suave.
    area('key', (-2.2, -3.0, 3.2), (55, 0, -35), 1.4, 480)
    area('fill', (2.8, -2.6, 1.8), (70, 0, 45), 3.0, 110, (0.9, 0.95, 1.0))
    area('rim_l', (-1.6, 1.4, 2.2), (-60, 0, -150), 1.0, 170)
    area('rim_r', (1.6, 1.4, 2.2), (-60, 0, 150), 1.0, 170)
    area('top', (0, -0.5, 4.2), (0, 0, 0), 3.0, 90)
    area('front', (0, -3.2, 1.7), (90, 0, 0), 2.0, 70, (1.0, 0.96, 0.92))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.lens = 60
    sc.camera = cam
    return cam, rigl, lights


def rings(accent):
    out = []
    for r, s in ((0.36, 1.2), (0.5, 0.35)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.004, location=(0, 0, 0.004),
                                         major_segments=128, minor_segments=8)
        t = bpy.context.active_object
        t.data.materials.append(A.mat('ring', accent, emit=(accent, s)))
        out.append(t)
    return out


def frame_camera(cam, pts, yaw_deg, elev_deg):
    """Cámara fija para toda la animación en esta vista."""
    yaw, el = math.radians(yaw_deg), math.radians(elev_deg)
    back = Matrix.Rotation(yaw, 3, 'Z') @ Vector((0, -math.cos(el), math.sin(el)))
    fwd = -back
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd).normalized()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    xs = [(p - center).dot(right) for p in pts]
    ys = [(p - center).dot(up) for p in pts]
    ds = [(p - center).dot(fwd) for p in pts]
    half = max(max(abs(v) for v in xs), max(abs(v) for v in ys)) * 1.06 + 0.03
    shift = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2))
    target = center + right * shift.x + up * shift.y
    tan = (cam.data.sensor_width / 2) / cam.data.lens
    dist = half / tan + 0.6 * max(abs(v) for v in ds)
    cam.location = target + back * dist
    cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()


# ----------------------------------------------------------------- principal


# Implementos que se toman con la mano (lado de MakeHuman: L = derecha de la app).
GRIP = {'barbellHands': 'LR', 'barbellBack': 'LR', 'dumbbells': 'LR', 'dumbbellRight': 'L', 'goblet': 'LR',
        'bar': 'LR', 'cableForward': 'LR', 'cableHigh': 'LR', 'cableSide': 'LR', 'band': 'LR'}


def joints(world, solver, P):
    w = P.w
    J = {
        'neck': w(head(world, 'neck01')),
        'waist': w(head(world, 'spine03')),
        'hips': w((head(world, 'upperleg01.L') + head(world, 'upperleg01.R')) / 2),
        'ankL': w(head(world, 'foot.L')), 'ankR': w(head(world, 'foot.R')),
        'kneeL': w(head(world, 'lowerleg01.L')), 'kneeR': w(head(world, 'lowerleg01.R')),
    }
    for s in 'LR':
        wr0, wr1 = head(world, f'wrist.{s}'), tail(world, solver, f'wrist.{s}')
        d = (wr1 - wr0).normalized()
        J[f'grip{s}'] = w(wr1 + d * 0.04)
        # Centro del puño (dentro de los dedos cerrados) y eje del mango.
        pts = []
        for k in (2, 3, 4, 5):
            pts += [head(world, f'finger{k}-{j}.{s}') for j in (1, 2, 3)] + [tail(world, solver, f'finger{k}-3.{s}')]
        c = Vector((0, 0, 0))
        for p_ in pts:
            c += p_
        J[f'fist{s}'] = w(c / len(pts))
        ax = head(world, f'finger5-1.{s}') - head(world, f'finger2-1.{s}')
        J[f'hax{s}'] = (P.R.to_3x3() @ ax).normalized()
    lat = (w(head(world, 'upperarm01.L')) - w(head(world, 'upperarm01.R'))).normalized()
    up = (J['neck'] - w(head(world, 'spine05'))).normalized()
    J['lat'], J['up'], J['fwd'] = lat, up, lat.cross(up).normalized()
    return J


def render_sex(sex, anims, out, views, samples, tmp, pick=None):
    from PIL import Image

    A.clear_scene()
    cam, light_rig, lights = scene_setup(samples)
    accent = CYAN if sex == 'f' else CORAL
    for k in ('rim_l', 'rim_r'):
        lights[k].data.color = tuple(0.45 + 0.55 * c for c in accent)
    ctx = A.make_avatar('female' if sex == 'f' else 'male', 0.0, 0.0, accent, standing=False)
    rig = ctx['rig']
    solver = Solver(rig)
    samples_pts = make_samples(ctx, solver)
    body_z = [v.co.z for v in ctx['body'].data.vertices]
    hip_h = (solver.rest['upperleg01.L'].translation.z - min(body_z))
    ring_objs = rings(accent)
    os.makedirs(os.path.join(out, 'thumbs'), exist_ok=True)

    for name, a in anims.items():
        slug = a['slug']
        ext = 'png' if pick is not None else 'webp'
        todo = [v for v in views if not os.path.exists(os.path.join(out, f'{slug}_{sex}_{v}.{ext}'))]
        if not todo:
            continue
        print(f'== {sex} {slug} {todo}', flush=True)
        apply_tint(ctx, a['primary'], a['secondary'])
        props = Props(a['props'], accent, slug)
        # Pase 1: poses y encuadre.
        frames = []
        pts = []
        first = None
        held = [GRIP.get(p, '') for p in a['props']]
        sides = ''.join(sorted(set(''.join(held))))
        cupped = 'goblet' in a['props']
        grip = solver.grip(sides, 0.55 if cupped else 1.0)
        for pose in a['frames']:
            tg, tw = targets_for(pose, solver)
            world, basis = solver.solve(tg, tw, extra=grip)
            if sides:
                world, basis = solver.solve(solver.thumbs(world, sides, tg), tw, extra=grip)
            P = place(pose, world, solver, samples_pts, hip_h)
            J = joints(world, solver, P)
            if first is None:
                first = J
            frames.append((basis, P, J))
            pts += [P.w(world[b] @ l) for b, l, _ in samples_pts[::3]]
            pts += [J['gripL'], J['gripR']]
            if any(p in a['props'] for p in ('barbellBack', 'barbellHands')):
                c = J['neck'] if 'barbellBack' in a['props'] else (J['gripL'] + J['gripR']) / 2
                pts += [c + J['lat'] * 0.7 + J['up'] * 0.15, c - J['lat'] * 0.7 - J['up'] * 0.15]
        pts += [Vector((0.4, 0.4, 0)), Vector((-0.4, -0.4, 0))]
        props.update(first, first, False)
        close = os.environ.get('CLOSE')
        if close:
            # Revisión de detalle: encuadre cercano de manos o pies.
            J0 = frames[-1 if not a['loop'] else len(frames) // 2][2]
            keys = ('gripL', 'gripR') if close == 'hands' else ('ankL', 'ankR')
            pts = [J0[k] + Vector(d) * 0.13 for k in keys for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
        for v in todo:
            frame_camera(cam, pts, VIEWS[v], a['elevation'])
            light_rig.rotation_euler = (0, 0, math.radians(VIEWS[v]))
            files = []
            for k, (basis, P, J) in enumerate(frames):
                if pick is not None and k != (len(frames) - 1 if not a['loop'] else len(frames) // 2):
                    continue
                solver.apply(basis)
                rig.rotation_euler = (math.radians(P.pitch), 0, 0)
                rig.location = P.loc
                props.update(J, first, True)
                bpy.context.view_layer.update()
                f = os.path.join(tmp, f'{slug}_{sex}_{v}_{k:02d}.png')
                bpy.context.scene.render.filepath = f
                bpy.ops.render.render(write_still=True)
                files.append(f)
            if pick is not None:
                shutil.move(files[0], os.path.join(out, f'{slug}_{sex}_{v}.png'))
                continue
            n = len(files)
            rows = (n + COLS - 1) // COLS
            sheet = Image.new('RGBA', (FRAME * COLS, FRAME * rows), (0, 0, 0, 0))
            for k, f in enumerate(files):
                sheet.paste(Image.open(f), ((k % COLS) * FRAME, (k // COLS) * FRAME))
            sheet.save(os.path.join(out, f'{slug}_{sex}_{v}.webp'), 'WEBP', quality=62, alpha_quality=45, method=6)
            if v == thumb_view(a['yaw']):
                k = (n - 1) if not a['loop'] else n // 2
                Image.open(files[k]).resize((160, 160), Image.LANCZOS).save(
                    os.path.join(out, 'thumbs', f'{slug}_{sex}.webp'), 'WEBP', quality=82, method=6)
            for f in files:
                os.remove(f)
        props.remove()
    for r in ring_objs:
        bpy.data.objects.remove(r, do_unlink=True)


def thumb_view(yaw):
    y = (yaw % 360 + 360) % 360
    if 135 <= y <= 225:
        return 'b'
    return 'l' if 45 <= y <= 315 else 'f'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--only', default='')
    ap.add_argument('--sex', default='f,m')
    ap.add_argument('--views', default='f,l,b')
    ap.add_argument('--samples', type=int, default=10)
    ap.add_argument('--preview', action='store_true', help='solo un cuadro por vista, en PNG')
    args = ap.parse_args()
    anims = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'anims.json')))
    if args.only:
        keep = set(args.only.split(','))
        anims = {k: v for k, v in anims.items() if v['slug'] in keep}
    os.makedirs(args.out, exist_ok=True)
    tmp = tempfile.mkdtemp()
    try:
        for sex in args.sex.split(','):
            render_sex(sex, anims, args.out, args.views.split(','), args.samples, tmp,
                       pick=True if args.preview else None)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
