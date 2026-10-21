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

FRAME = 384
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

    def solve(self, targets, twist=None):
        world, basis = {}, {}
        twist = twist or {}
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


class Props:
    def __init__(self, names, accent):
        self.names = names
        self.objs = []
        steel = A.mat('steel', (0.62, 0.64, 0.68), rough=0.28, metal=1.0)
        plate = A.mat('plate', (0.03, 0.032, 0.036), rough=0.5)
        self.m_pad = A.mat('pad', (0.03, 0.032, 0.038), rough=0.6)
        self.m_frame = A.mat('frame', (0.25, 0.26, 0.29), rough=0.35, metal=0.8)
        self.m_wall = A.mat('wallp', (0.05, 0.053, 0.06), rough=0.8)
        self.m_mat = A.mat('matp', (0.045, 0.048, 0.055), rough=0.75)
        self.m_cable = A.mat('cable', accent, emit=(accent, 2.5))
        self.steel, self.plate = steel, plate
        self.parts = {}

        def add(key, o):
            self.parts.setdefault(key, []).append(o)
            self.objs.append(o)

        for p in names:
            if p in ('barbellBack', 'barbellHands'):
                add(p, unit_cyl('bar', steel, verts=16))
                for k in range(4):
                    add(p, unit_cyl('pl', plate, verts=40))
            elif p in ('dumbbells', 'dumbbellRight', 'goblet'):
                n = 2 if p == 'dumbbells' else 1
                for k in range(n):
                    add(p, unit_cyl('dh', steel, verts=16))
                    add(p, unit_cyl('dw', plate, verts=8))
                    add(p, unit_cyl('dw', plate, verts=8))
            elif p == 'bar':
                add(p, unit_cyl('pbar', steel, verts=16))
            elif p in ('bench', 'benchUnderHands', 'benchBack'):
                add(p, unit_box('pad', self.m_pad))
                add(p, unit_box('base', self.m_frame))
            elif p == 'box':
                add(p, unit_box('box', self.m_pad))
            elif p == 'footPlate':
                add(p, unit_box('plate', self.m_frame))
            elif p == 'wall':
                add(p, unit_box('wall', self.m_wall))
            elif p == 'floorMat':
                add(p, unit_box('mat', self.m_mat))
            elif p in ('cableForward', 'cableHigh', 'cableSide', 'band'):
                add(p, unit_cyl('cable', self.m_cable, verts=8))

    def remove(self):
        for o in self.objs:
            bpy.data.objects.remove(o, do_unlink=True)

    def update(self, J, first, static_done):
        """J: puntos del cuerpo en el mundo para este cuadro; first: los del
        primer cuadro (para implementos fijos)."""
        lat, up, fwd = J['lat'], J['up'], J['fwd']
        for p, objs in self.parts.items():
            if p in ('barbellBack', 'barbellHands'):
                c = J['neck'] - fwd * 0.08 - up * 0.02 if p == 'barbellBack' else (J['gripL'] + J['gripR']) / 2
                set_between(objs[0], c - lat * 0.85, c + lat * 0.85, 0.013)
                for k, (a0, a1) in enumerate(((0.6, 0.64), (0.64, 0.67), (-0.6, -0.64), (-0.64, -0.67))):
                    r = 0.15 if k % 2 == 0 else 0.12
                    set_between(objs[1 + k], c + lat * a0, c + lat * a1, r)
            elif p in ('dumbbells', 'dumbbellRight', 'goblet'):
                if p == 'goblet':
                    centers = [((J['gripL'] + J['gripR']) / 2 - fwd * 0.01, up)]
                elif p == 'dumbbellRight':
                    centers = [(J['gripL'], lat)]
                else:
                    centers = [(J['gripL'], lat), (J['gripR'], lat)]
                for k, (c, ax) in enumerate(centers):
                    set_between(objs[3 * k], c - ax * 0.075, c + ax * 0.075, 0.016)
                    set_between(objs[3 * k + 1], c + ax * 0.065, c + ax * 0.125, 0.055)
                    set_between(objs[3 * k + 2], c - ax * 0.125, c - ax * 0.065, 0.055)
            elif p == 'bar':
                c = (J['gripL'] + J['gripR']) / 2
                set_between(objs[0], c - lat * 0.6, c + lat * 0.6, 0.015)
            elif p in ('cableForward', 'cableHigh', 'cableSide', 'band'):
                h = (J['gripL'] + J['gripR']) / 2
                if p == 'cableForward':
                    a, b = h, Vector((h.x, h.y - 1.3, J['hips'].z))
                elif p == 'cableHigh':
                    a, b = h, Vector((h.x, h.y, 2.6))
                elif p == 'cableSide':
                    a, b = h, Vector((h.x + 1.2, h.y, h.z))
                else:
                    a, b = J['gripL'], J['gripR']
                set_between(objs[0], a, b, 0.006 if p == 'band' else 0.004)
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
            self._bench(objs, Vector((c.x, c.y, 0)), top, along * 0.55, across * 0.15)
        elif p == 'benchUnderHands':
            l, r = F['gripL'], F['gripR']
            both = abs(l.z - r.z) < 0.04
            c = (l + r) / 2 if both else (l if l.z < r.z else r)
            self._bench(objs, Vector((c.x, c.y, 0)), c.z - 0.03, Vector((1, 0, 0)) * (0.45 if both else 0.2),
                        Vector((0, 1, 0)) * 0.15)
        elif p == 'benchBack':
            c = F['neck'] + (F['waist'] - F['neck']) * 0.3
            self._bench(objs, Vector((c.x, c.y, 0)), c.z - 0.11, across * 0.55, along * 0.16)
        elif p == 'box':
            c = F['hips'] - F['fwd'] * 0.1
            h = max(0.2, F['hips'].z - 0.1) / 2
            set_box(objs[0], Vector((c.x, c.y, h)), Vector((0.17, 0, 0)), Vector((0, 0.17, 0)), upz * h)
        elif p == 'footPlate':
            c = (F['ankL'] + F['ankR']) / 2
            n = ((F['kneeL'] + F['kneeR']) / 2 - c).normalized()
            s = F['lat']
            v = n.cross(s).normalized()
            set_box(objs[0], c - n * 0.06, s * 0.26, v * 0.24, n * 0.012)
        elif p == 'wall':
            hy = min(F['gripL'].y, F['gripR'].y) - 0.04
            set_box(objs[0], Vector((0, hy - 0.025, 1.0)), Vector((0.3, 0, 0)), Vector((0, 0.025, 0)), upz * 1.0)
        elif p == 'floorMat':
            c = F['hips']
            set_box(objs[0], Vector((c.x, c.y, 0.004)), along * 0.95 if flat.length > 0.1 else Vector((0, 0.95, 0)),
                    across * 0.35 if flat.length > 0.1 else Vector((0.35, 0, 0)), upz * 0.004)

    def _bench(self, objs, c, top, half_len, half_w):
        upz = Vector((0, 0, 1))
        set_box(objs[0], Vector((c.x, c.y, top - 0.03)), half_len, half_w, upz * 0.03)
        hb = max(0.02, (top - 0.06) / 2)
        set_box(objs[1], Vector((c.x, c.y, hb)), half_len * 0.8, half_w * 0.4, upz * hb)


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
    area('key', (-2.2, -3.0, 3.2), (55, 0, -35), 2.5, 420)
    area('fill', (2.8, -2.6, 1.8), (70, 0, 45), 3.0, 140, (0.9, 0.95, 1.0))
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
    half = max(max(abs(v) for v in xs), max(abs(v) for v in ys)) * 1.12 + 0.04
    shift = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2))
    target = center + right * shift.x + up * shift.y
    tan = (cam.data.sensor_width / 2) / cam.data.lens
    dist = half / tan + max(abs(v) for v in ds)
    cam.location = target + back * dist
    cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()


# ----------------------------------------------------------------- principal


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
        props = Props(a['props'], accent)
        # Pase 1: poses y encuadre.
        frames = []
        pts = []
        first = None
        for pose in a['frames']:
            tg, tw = targets_for(pose, solver)
            world, basis = solver.solve(tg, tw)
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
