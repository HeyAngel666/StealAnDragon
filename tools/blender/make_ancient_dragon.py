"""Dragão Ancião: modelo detalhado com textura pintada (escamas), juba de espinhos,
chifres grandes, barba, dentes, garras e olhos brilhantes.

Uso:  python tools/blender/make_ancient_dragon.py   (ou blender --background --python ...)
Saída: assets/models/Dragon_Ancient.fbx (+ texturas .png e imagens de prévia)

Partes: Body (corpo+cabeça), Horns (chifres/espinhos/dentes/garras), Wings, Eyes, Pupils.
Ossos com os mesmos nomes dos outros dragões (o jogo anima asas, cauda e cabeça).
"""

import importlib.util
import math
import os
import random
import sys

import bpy  # noqa: E402  (precisa vir antes de bmesh/mathutils)
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("make_dragons", os.path.join(HERE, "make_dragons.py"))
md = importlib.util.module_from_spec(spec)
spec.loader.exec_module(md)

OUT = md.OUT
TEX = 1024
rng = random.Random(42)


# ------------------------------------------------------------------ espinhos curvos

def curved_spike(bm, base, direction, length, radius, bend, sides=7, rings=6, ridges=0.0, flat=1.0, thin=None, colors=None):
    """Espinho/chifre curvo dentro de um bmesh. bend = vetor de curvatura na ponta.
    flat < 1 achata o espinho numa placa; thin = direção em que a placa fica fina."""
    direction = direction.normalized()
    tip = base + direction * length + bend
    ctrl = base + direction * (length * 0.55)
    # base ortonormal ao longo da curva
    prev_ring = None
    first_ring = None
    up = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    for i in range(rings + 1):
        t = i / rings
        p = (1 - t) ** 2 * base + 2 * (1 - t) * t * ctrl + t ** 2 * tip
        d = (2 * (1 - t) * (ctrl - base) + 2 * t * (tip - ctrl)).normalized()
        if thin is not None:
            side = (thin - d * thin.dot(d)).normalized()
        else:
            side = d.cross(up).normalized()
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        up2 = side.cross(d).normalized()
        r = radius * (1 - t) ** 0.9
        if ridges:
            r *= 1 + ridges * math.sin(t * math.pi * 10)
        ring = []
        if i == rings:
            v = bm.verts.new(p)
            ring = [v]
        else:
            for k in range(sides):
                a = k / sides * math.pi * 2
                v = bm.verts.new(p + (side * math.cos(a) * flat + up2 * math.sin(a)) * max(r, 0.004))
                ring.append(v)
        if colors is not None:
            for v in ring:
                colors[v] = t
        if prev_ring is not None:
            if len(ring) == 1:
                for k in range(sides):
                    bm.faces.new((prev_ring[k], prev_ring[(k + 1) % sides], ring[0]))
            else:
                for k in range(sides):
                    bm.faces.new((prev_ring[k], prev_ring[(k + 1) % sides], ring[(k + 1) % sides], ring[k]))
        else:
            first_ring = ring
        prev_ring = ring
    bm.faces.new(list(reversed(first_ring)))


def spikes_object(name, specs, gradient):
    """Cria um objeto com vários espinhos e pinta por altura (cor por vértice -> textura)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    tvals = {}
    for s in specs:
        curved_spike(bm, *s, colors=tvals)
    # cor por vértice ao longo do espinho
    layer = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for loop in f.loops:
            t = tvals.get(loop.vert, 0.0)
            loop[layer] = gradient(t)
    bm.to_mesh(me)
    bm.free()
    obj = md.link(bpy.data.objects.new(name, me))
    md.shade_smooth(obj)
    return obj


def scale_about_center(obj, scale):
    me = obj.data
    c = sum((v.co for v in me.vertices), Vector()) / max(len(me.vertices), 1)
    for v in me.vertices:
        d = v.co - c
        v.co = c + Vector((d.x * scale[0], d.y * scale[1], d.z * scale[2]))


def lerp_color(stops, t):
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            f = (t - t0) / max(t1 - t0, 1e-6)
            return tuple(c0[i] + (c1[i] - c0[i]) * f for i in range(3)) + (1.0,)
    return tuple(stops[-1][1]) + (1.0,)


CREST = [(0.0, (0.5, 0.06, 0.08)), (0.4, (0.82, 0.14, 0.18)), (0.75, (0.62, 0.2, 0.55)), (1.0, (0.96, 0.86, 0.82))]
BONE = [(0.0, (0.93, 0.86, 0.72)), (0.8, (0.78, 0.68, 0.52)), (1.0, (0.3, 0.24, 0.2))]
CLAW = [(0.0, (0.25, 0.2, 0.18)), (1.0, (0.06, 0.05, 0.05))]
BEARD = [(0.0, (0.75, 0.6, 0.45)), (0.6, (0.9, 0.85, 0.78)), (1.0, (0.95, 0.93, 0.9))]


# ------------------------------------------------------------------ corpo (modelo novo, por seções)

def superellipse(theta, n):
    c, s = math.cos(theta), math.sin(theta)
    return (math.copysign(abs(c) ** (2 / n), c), math.copysign(abs(s) ** (2 / n), s))


def loft(name, stations, sides=28, cap=True):
    """Superfície "costurada" por seções ao longo de um caminho.
    station = (centro, meia_largura, meia_altura, expoente, extra(theta)->raio_extra, deslocamento_vertical)
    """
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    pts = [Vector(st[0]) for st in stations]
    for i, st in enumerate(stations):
        c, w, h, n, extra = Vector(st[0]), st[1], st[2], st[3], st[4]
        taper = st[5] if len(st) > 5 else 0.0  # >0: mais largo em cima (cabeça em cunha)
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        fwd = (b - a).normalized()
        up = Vector((0, 0, 1))
        side = fwd.cross(up)
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(fwd).normalized()
        ring = []
        for k in range(sides):
            th = k / sides * math.pi * 2
            x, y = superellipse(th, n)
            r = 1 + (extra(th) if extra else 0)
            ring.append(bm.verts.new(c + side * (x * w * r * (1 + taper * y)) + up * (y * h * r)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    if cap:
        for ring, flip in ((rings[0], True), (rings[-1], False)):
            c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
            for k in range(sides):
                f = (ring[k], ring[(k + 1) % sides], c)
                bm.faces.new(tuple(reversed(f)) if flip else f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = md.link(bpy.data.objects.new(name, me))
    return obj


def bump(center_deg, width_deg, amount):
    c = math.radians(center_deg)
    wdt = math.radians(width_deg)

    def f(th):
        d = math.atan2(math.sin(th - c), math.cos(th - c))
        return amount * math.exp(-(d / wdt) ** 2)
    return f


def combine(*fs):
    return lambda th: sum(f(th) for f in fs)


def catmull(points, n):
    """Interpola pontos de controle (centro, w, h) suavemente em n estações."""
    out = []
    P = [Vector(p[0]) for p in points]
    for i in range(n):
        t = i / (n - 1) * (len(points) - 1)
        k = min(int(t), len(points) - 2)
        f = t - k
        p0, p1, p2, p3 = P[max(k - 1, 0)], P[k], P[k + 1], P[min(k + 2, len(P) - 1)]
        pos = 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)
        a, b = points[k], points[k + 1]
        lerp = lambda x, y: x + (y - x) * f
        ta, tb = (a[5] if len(a) > 5 else 0.0), (b[5] if len(b) > 5 else 0.0)
        out.append((pos, lerp(a[1], b[1]), lerp(a[2], b[2]), lerp(a[3], b[3]), a[4] if f < 0.5 else b[4], lerp(ta, tb)))
    return out


def build():
    md.reset_scene()
    keel = bump(90, 25, 0.12)  # crista no alto das costas
    belly_flat = bump(270, 50, -0.08)
    brow = combine(bump(52, 15, 0.3), bump(128, 15, 0.3))  # sobrancelhas pesadas
    nasal = bump(90, 22, 0.1)  # osso do nariz
    cheek = combine(bump(-20, 25, 0.12), bump(200, 25, 0.12))
    torso = combine(keel, belly_flat)

    # coluna: ponta da cauda -> tronco -> pescoço -> cabeça (dragão olha para -Y)
    ctrl = [
        ((0.9, 10.5, 0.7), 0.07, 0.07, 2.0, None),
        ((0.6, 8.5, 1.0), 0.22, 0.25, 2.0, keel),
        ((0.1, 6.3, 1.5), 0.42, 0.48, 2.0, keel),
        ((0, 4.2, 2.1), 0.65, 0.72, 2.2, keel),
        ((0, 2.4, 2.6), 0.95, 1.05, 2.3, torso),
        ((0, 0.8, 2.9), 1.25, 1.35, 2.3, torso),
        ((0, -0.8, 3.15), 1.35, 1.5, 2.3, torso),
        ((0, -2.1, 3.7), 1.0, 1.15, 2.2, torso),
        ((0, -3.0, 4.5), 0.78, 0.92, 2.2, keel),
        ((0, -3.7, 5.2), 0.7, 0.8, 2.3, keel),
        ((0, -4.3, 5.62), 0.84, 0.82, 3.0, brow, 0.14),        # nuca / fundo do crânio
        ((0, -4.95, 5.6), 0.92, 0.72, 3.4, combine(brow, cheek), 0.3),  # sobrancelhas
        ((0, -5.6, 5.36), 0.68, 0.56, 3.2, combine(cheek, nasal), 0.3),
        ((0, -6.3, 5.15), 0.5, 0.42, 3.0, nasal, 0.25),        # focinho em cunha
        ((0, -6.95, 5.0), 0.38, 0.33, 2.8, nasal, 0.2),
        ((0, -7.35, 4.92), 0.24, 0.22, 2.4, None, 0.1),       # ponta do nariz
    ]
    stations = catmull(ctrl, 70)
    spine = loft("Spine", [(s[0], s[1], s[2], s[3], s[4], s[5]) for s in stations])
    centers = [s[0] for s in stations]

    # mandíbula separada (boca levemente aberta)
    jaw_ctrl = [
        ((0, -4.4, 4.85), 0.6, 0.38, 2.4, None),
        ((0, -5.3, 4.55), 0.55, 0.3, 2.6, None),
        ((0, -6.2, 4.42), 0.42, 0.24, 2.6, None),
        ((0, -6.9, 4.38), 0.3, 0.18, 2.4, None),
    ]
    jaw = loft("Jaw", [(s[0], s[1], s[2], s[3], s[4]) for s in catmull(jaw_ctrl, 20)], sides=20)

    # pernas musculosas (traseiras com joelho invertido) e dedos
    limbs = []
    toe_tips = []
    for sx in (1, -1):
        back = [
            ((1.05 * sx, 1.0, 2.6), 0.8, 0.95, 2.2, None),
            ((1.25 * sx, 1.5, 1.7), 0.62, 0.7, 2.2, None),
            ((1.3 * sx, 2.1, 1.0), 0.38, 0.42, 2.0, None),
            ((1.3 * sx, 1.6, 0.42), 0.28, 0.3, 2.0, None),
            ((1.3 * sx, 1.1, 0.2), 0.32, 0.16, 2.4, None),
        ]
        front = [
            ((1.05 * sx, -1.0, 2.9), 0.7, 0.85, 2.2, None),
            ((1.3 * sx, -0.8, 1.9), 0.5, 0.55, 2.2, None),
            ((1.35 * sx, -1.0, 1.05), 0.34, 0.36, 2.0, None),
            ((1.35 * sx, -1.35, 0.4), 0.26, 0.28, 2.0, None),
            ((1.35 * sx, -1.75, 0.2), 0.3, 0.15, 2.4, None),
        ]
        for name, pts in (("Back", back), ("Front", front)):
            limbs.append(loft(f"Leg{name}{sx}", [(s[0], s[1], s[2], s[3], s[4]) for s in catmull(pts, 18)], sides=18))
            foot = Vector(pts[-1][0])
            for k in (-1, 0, 1):
                tip = foot + Vector((k * 0.2, -0.45, -0.08))
                toe = [((foot.x + k * 0.12, foot.y + 0.1, 0.22), 0.11, 0.1, 2, None), ((tip.x, tip.y, 0.13), 0.07, 0.06, 2, None)]
                limbs.append(loft(f"Toe{name}{sx}{k}", toe, sides=10))
                toe_tips.append(tip)

    # une tudo numa malha só e alisa
    body = md.join([spine] + limbs, "Body")
    rem = body.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = 0.045
    md.apply_modifiers(body)
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 8
    sm.use_only_smooth = True
    md.apply_modifiers(body)
    # músculos e escamas em relevo
    tex_m = bpy.data.textures.new("Muscle", "CLOUDS")
    tex_m.noise_scale = 0.7
    d1 = body.modifiers.new("Muscle", "DISPLACE")
    d1.texture = tex_m
    d1.strength = 0.09
    tex_s = bpy.data.textures.new("Scales", "VORONOI")
    tex_s.noise_scale = 0.09
    d2 = body.modifiers.new("Scales", "DISPLACE")
    d2.texture = tex_s
    d2.strength = 0.03
    md.apply_modifiers(body)
    md.shade_smooth(body)
    md.shade_smooth(jaw)

    depsgraph = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(body, depsgraph)

    def at_station(y):
        best = min(centers, key=lambda c: abs(c.y - y))
        return best

    crest, horns_specs, beard, claws, teeth = [], [], [], [], []
    skull = at_station(-4.4)
    browc = at_station(-4.95)
    snout = at_station(-6.3)

    # chifres: dois grandes varrendo para trás + secundários
    for sx in (1, -1):
        base = md.surface(tree, skull + Vector((0.55 * sx, 0.1, 0.2)), (0.7 * sx, 0.3, 0.7))
        horns_specs.append((base, Vector((0.45 * sx, 1.0, 0.35)), 3.0, 0.3, Vector((0.6 * sx, 0.6, -0.9)), 10, 16, 0.07, 1.0))
        base2 = md.surface(tree, skull + Vector((0.75 * sx, 0.0, -0.15)), (sx, 0.2, 0.0))
        horns_specs.append((base2, Vector((1.0 * sx, 0.8, -0.1)), 1.4, 0.15, Vector((0.1 * sx, 0.4, -0.3)), 8, 10, 0.05, 1.0))
        # crista óssea pesada sobre o olho (placa saliente)
        b = md.surface(tree, browc + Vector((0.62 * sx, 0.1, 0.25)), (0.6 * sx, 0, 0.8))
        horns_specs.append((b, Vector((0.35 * sx, 1.0, 0.25)), 1.2, 0.24, Vector((0.15 * sx, 0.25, 0.2)), 8, 7, 0.0, 0.45, Vector((0.3 * sx, 0, 1))))
        b = md.surface(tree, browc + Vector((0.6 * sx, -0.35, 0.2)), (0.6 * sx, -0.2, 0.8))
        horns_specs.append((b, Vector((0.6 * sx, 0.6, 0.35)), 0.55, 0.12, Vector((0.05 * sx, 0.1, 0.05)), 7, 5, 0.0, 0.6))

    # juba: placas largas e achatadas em leque, várias camadas, do crânio até o meio do pescoço
    for layer in range(3):
        for i, y in enumerate([-4.55, -4.15, -3.75, -3.35, -2.95, -2.55]):
            p = at_station(y)
            n_fan = 7 - layer
            for kf in range(n_fan):
                a = (kf / max(n_fan - 1, 1) - 0.5) * (2.7 - layer * 0.3) + rng.uniform(-0.1, 0.1)
                dirn = Vector((math.sin(a), 0.15, math.cos(a)))
                base = md.surface(tree, p, dirn) - dirn.normalized() * 0.1
                fade = max(0.4, 1.0 - i * 0.11)
                length = (2.3 - layer * 0.5) * fade * rng.uniform(0.85, 1.1)
                back = Vector((math.sin(a) * 0.7, 1.0 + layer * 0.2, math.cos(a) * 0.45 - layer * 0.08))
                tangent = Vector((math.cos(a), 0.0, -math.sin(a)))
                crest.append((base, back, length, 0.32 * (1 - layer * 0.15), Vector((0, 0.35, -0.5)) * length, 8, 8, 0.0, 0.2, tangent))
    # espinhos laterais da bochecha (leque)
    for sx in (1, -1):
        for k in range(6):
            t = k / 5
            p = Vector((0, -4.5 - t * 1.2, 4.8 - t * 0.2))
            base = md.surface(tree, p, (sx, 0.4, -0.3))
            crest.append((base, Vector((0.9 * sx, 0.9, -0.3)), 1.1 - t * 0.5, 0.17, Vector((0.15 * sx, 0.25, -0.15)), 7, 6, 0.0, 0.25, Vector((0, 0, 1))))
    # barba de espinhos claros sob a mandíbula (duas fileiras)
    jaw_tree = BVHTree.FromObject(jaw, depsgraph)
    for k in range(9):
        t = k / 8
        p = Vector((0, -4.6 - t * 1.9, 4.45 - t * 0.1))
        for sx in (-0.5, 0.5):
            base = md.surface(jaw_tree, p + Vector((sx * 0.4, 0, 0)), (sx, 0.1, -1))
            beard.append((base, Vector((sx * 0.5, 0.7, -1.0)), 1.0 * (1.15 - t * 0.55) * rng.uniform(0.85, 1.1), 0.1, Vector((0, 0.3, 0.1)), 6, 6, 0.0, 0.35, Vector((1, 0, 0))))
    # espinhos das costas (fileira dupla de placas) até a cauda
    for i in range(len(centers)):
        c = centers[i]
        if c.y < -2.2 or c.y > 10.2 or i % 2:
            continue
        size = max(0.2, 1.1 - max(0.0, c.y + 1.0) * 0.09)
        for sx in (-0.25, 0.25):
            dirn = Vector((sx, 0.15, 1))
            base = md.surface(tree, c, dirn) - Vector((0, 0, 0.06))
            crest.append((base, Vector((sx * 0.5, 0.8, 1.0)), size, 0.24 * size + 0.04, Vector((0, 0.3, -0.12)) * size, 7, 5, 0.0, 0.3, Vector((1, 0, 0))))
    # garras
    for tip in toe_tips:
        claws.append((tip + Vector((0, 0.05, 0.02)), Vector((0, -1, -0.4)), 0.32, 0.07, Vector((0, -0.04, -0.14)), 6, 5, 0.0, 1.0))
    # dentes presos no céu da boca e na mandíbula
    for sx in (1, -1):
        for k in range(10):
            t = k / 9
            y = -5.0 - t * 1.95
            up_p = md.surface(tree, Vector((0.3 * sx * (1 - t * 0.5), y, 4.95)), (0, 0, -1)) + Vector((0, 0, 0.04))
            big = k in (6, 7)
            teeth.append((up_p, Vector((0, -0.15, -1)), 0.2 + (0.14 if big else 0), 0.05, Vector((0, -0.04, 0)), 6, 3, 0.0, 1.0))
            lo_p = md.surface(jaw_tree, Vector((0.27 * sx * (1 - t * 0.5), y + 0.1, 4.4)), (0, 0, 1)) - Vector((0, 0, 0.03))
            teeth.append((lo_p, Vector((0, -0.05, 1)), 0.15, 0.04, Vector((0, -0.02, 0)), 6, 3, 0.0, 1.0))

    crest_obj = spikes_object("HornsCrest", crest, lambda t: lerp_color(CREST, t))
    horns_obj = spikes_object("HornsMain", horns_specs, lambda t: lerp_color(BONE, t))
    beard_obj = spikes_object("HornsBeard", beard, lambda t: lerp_color(BEARD, t))
    claws_obj = spikes_object("HornsClaws", claws + teeth, lambda t: lerp_color(BONE, t * 0.85))

    # olhos pequenos e fundos, vermelhos, com pupila em fenda (logo abaixo da sobrancelha)
    eyes, pupils = [], []
    for sx in (1, -1):
        normal = Vector((0.9 * sx, -0.4, 0.05)).normalized()
        c = md.surface(tree, browc + Vector((0.45 * sx, -0.3, -0.05)), normal) - normal * 0.05
        eyes.append(md.sphere(f"Eye{sx}", c - normal * 0.03, 0.11, 16))
        pup = md.sphere(f"Pupil{sx}", c + normal * 0.05, 0.075, 12)
        scale_about_center(pup, (0.55, 0.3, 1.25))
        pupils.append(pup)

    # asas
    wing_parts, wing_arm, wing_claws = [], [], []
    bones = {}
    for side, sx in (("L", 1), ("R", -1)):
        shoulder = Vector((0.9 * sx, -0.9, 4.1))
        elbow = shoulder + Vector((2.4 * sx, 0.6, 1.6))
        wrist = elbow + Vector((2.2 * sx, 1.0, 0.4))
        tips = [wrist + Vector((2.2 * sx, 1.4, -1.2)), wrist + Vector((1.3 * sx, 3.0, -2.2)), wrist + Vector((-0.3 * sx, 3.7, -2.9))]
        back = Vector((0.8 * sx, 2.3, 3.4))
        outline = [shoulder, elbow, wrist, tips[0]]
        seq = tips + [back]
        for a, b in zip(seq, seq[1:]):
            for k in (1, 2, 3, 4):
                t = k / 5
                outline.append(a.lerp(b, t).lerp(wrist, math.sin(t * math.pi) * 0.22))
            outline.append(b)
        me = bpy.data.meshes.new(f"Wing{side}")
        me.from_pydata([tuple(p) for p in outline], [], [list(range(len(outline)))])
        w = md.link(bpy.data.objects.new(f"Wing{side}", me))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
        bm.to_mesh(me)
        bm.free()
        sol = w.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = 0.07
        md.apply_modifiers(w)
        md.shade_smooth(w)
        wing_parts.append(w)
        arm_pts = [(tuple(shoulder), 0.3, 0.3, 2, None), (tuple(elbow), 0.2, 0.2, 2, None), (tuple(wrist), 0.15, 0.15, 2, None)]
        wing_arm.append(loft(f"WingArm{side}", [(s[0], s[1], s[2], s[3], s[4]) for s in catmull(arm_pts, 14)], sides=12))
        for t in tips:
            fp = [(tuple(wrist), 0.09, 0.09, 2, None), (tuple(wrist.lerp(t, 0.5) + Vector((0, 0, 0.1))), 0.06, 0.06, 2, None), (tuple(t), 0.02, 0.02, 2, None)]
            wing_arm.append(loft(f"Finger{side}", [(s[0], s[1], s[2], s[3], s[4]) for s in catmull(fp, 10)], sides=8))
        wing_claws.append((wrist, Vector((0.2 * sx, -0.6, 0.8)), 0.55, 0.09, Vector((0, -0.1, 0)), 6, 5, 0.0, 1.0))
        bones[f"Wing{side}1"] = (shoulder, elbow, "Chest")
        bones[f"Wing{side}2"] = (elbow, wrist, f"Wing{side}1")
        bones[f"Wing{side}3"] = (wrist, tips[1], f"Wing{side}2")
    for o in wing_arm:
        md.shade_smooth(o)

    body = md.join([body, jaw] + wing_arm, "Body")
    md.decimate_to(body, 19500)
    wings = md.join(wing_parts, "Wings")
    wing_claw_obj = spikes_object("HornsWingClaws", wing_claws, lambda t: lerp_color(BONE, t * 0.85))
    horns = md.join([crest_obj, horns_obj, beard_obj, claws_obj, wing_claw_obj], "Horns")
    md.decimate_to(horns, 19500)
    eyes_obj = md.join(eyes, "Eyes")
    pupils_obj = md.join(pupils, "Pupils")

    # ossos (mesmos nomes dos outros dragões)
    S = lambda y: at_station(y)
    bones["Root"] = (Vector((0, 0.2, 0.05)), Vector((0, 0.2, 0.7)), None)
    bones["Spine"] = (S(2.4), S(0.8), "Root")
    bones["Chest"] = (S(0.8), S(-0.8), "Spine")
    bones["Neck1"] = (S(-0.8), S(-2.6), "Chest")
    bones["Neck2"] = (S(-2.6), S(-3.9), "Neck1")
    bones["Head"] = (S(-3.9), S(-6.6), "Neck2")
    tail_ys = [3.6, 4.8, 6.0, 7.2, 8.3, 9.4, 10.4]
    prev, frm = "Root", S(2.4)
    for i, y in enumerate(tail_ys, 1):
        bones[f"Tail{i}"] = (frm, S(y), prev)
        prev, frm = f"Tail{i}", S(y)
    for s, sx in (("L", 1), ("R", -1)):
        bones[f"Thigh{s}"] = (Vector((1.05 * sx, 1.0, 2.6)), Vector((1.3 * sx, 2.1, 1.0)), "Spine")
        bones[f"Shin{s}"] = (Vector((1.3 * sx, 2.1, 1.0)), Vector((1.3 * sx, 1.6, 0.42)), f"Thigh{s}")
        bones[f"Foot{s}"] = (Vector((1.3 * sx, 1.6, 0.42)), Vector((1.3 * sx, 0.7, 0.15)), f"Shin{s}")
        bones[f"Arm{s}"] = (Vector((1.05 * sx, -1.0, 2.9)), Vector((1.35 * sx, -1.0, 1.05)), "Chest")
        bones[f"Forearm{s}"] = (Vector((1.35 * sx, -1.0, 1.05)), Vector((1.35 * sx, -1.35, 0.4)), f"Arm{s}")
        bones[f"Hand{s}"] = (Vector((1.35 * sx, -1.35, 0.4)), Vector((1.35 * sx, -2.2, 0.15)), f"Forearm{s}")

    parts = {"Body": body, "Horns": horns, "Wings": wings, "Eyes": eyes_obj, "Pupils": pupils_obj}
    return parts, bones


# ------------------------------------------------------------------ materiais e textura

def node(nt, kind, loc=(0, 0), **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def body_material():
    mat = bpy.data.materials.new("BodyPaint")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.65
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # escamas (voronoi: borda escura)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 9.0
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.0
    edge.inputs["From Max"].default_value = 0.08
    edge.inputs["To Min"].default_value = 0.4
    edge.inputs["To Max"].default_value = 1.0
    nt.links.new(vor.outputs["Distance"], edge.inputs["Value"])
    # manchas de cor (laranja / marrom)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    noise.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.36, 0.12, 0.04, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.86, 0.38, 0.08, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    # barriga clara (normal para baixo) e dorso avermelhado (normal para cima)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    belly_f = nt.nodes.new("ShaderNodeMapRange")
    belly_f.inputs["From Min"].default_value = -0.2
    belly_f.inputs["From Max"].default_value = -0.75
    nt.links.new(sep.outputs["Z"], belly_f.inputs["Value"])
    mix_belly = nt.nodes.new("ShaderNodeMix")
    mix_belly.data_type = "RGBA"
    mix_belly.inputs[7].default_value = (0.88, 0.66, 0.4, 1)
    nt.links.new(belly_f.outputs["Result"], mix_belly.inputs[0])
    nt.links.new(ramp.outputs["Color"], mix_belly.inputs[6])
    back_f = nt.nodes.new("ShaderNodeMapRange")
    back_f.inputs["From Min"].default_value = 0.55
    back_f.inputs["From Max"].default_value = 0.95
    back_f.inputs["To Max"].default_value = 0.7
    nt.links.new(sep.outputs["Z"], back_f.inputs["Value"])
    mix_back = nt.nodes.new("ShaderNodeMix")
    mix_back.data_type = "RGBA"
    mix_back.inputs[7].default_value = (0.45, 0.08, 0.06, 1)
    nt.links.new(back_f.outputs["Result"], mix_back.inputs[0])
    nt.links.new(mix_belly.outputs[2], mix_back.inputs[6])
    # aplica a borda das escamas
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(mix_back.outputs[2], mul.inputs[6])
    nt.links.new(edge.outputs["Result"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    return mat


def wing_material():
    mat = bpy.data.materials.new("WingPaint")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # membrana com veias (voronoi: borda escura) e manchas
    wave = nt.nodes.new("ShaderNodeTexVoronoi")
    wave.feature = "DISTANCE_TO_EDGE"
    wave.inputs["Scale"].default_value = 2.4
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.2, 0.03, 0.04, 1)
    ramp.color_ramp.elements[1].position = 0.06
    ramp.color_ramp.elements[1].color = (0.62, 0.16, 0.1, 1)
    nt.links.new(wave.outputs["Distance"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def vcol_material():
    mat = bpy.data.materials.new("SpikePaint")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    return mat


def bake_texture(obj, mat, name, ao_strength=0.55):
    """Desdobra UV, assa a cor + oclusão e troca o material pela textura."""
    md.select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    img = bpy.data.images.new(name, TEX, TEX)
    nt = mat.node_tree
    tex_node = nt.nodes.new("ShaderNodeTexImage")
    tex_node.image = img
    nt.nodes.active = tex_node
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.bake.margin = 4
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    import numpy as np
    color = np.empty(TEX * TEX * 4, dtype=np.float32)
    img.pixels.foreach_get(color)
    # oclusão de ambiente para dar profundidade (escurece frestas)
    ao_img = bpy.data.images.new(name + "_ao", TEX, TEX)
    tex_node.image = ao_img
    scene.cycles.samples = 32
    bpy.ops.object.bake(type="AO")
    ao = np.empty(TEX * TEX * 4, dtype=np.float32)
    ao_img.pixels.foreach_get(ao)
    a = (1 - ao_strength) + ao_strength * ao[0::4]
    out = color.copy()
    out[0::4] *= a
    out[1::4] *= a
    out[2::4] *= a
    out[3::4] = 1.0
    img.pixels.foreach_set(out)
    path = os.path.join(OUT, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    # material final: só a textura
    final = bpy.data.materials.new(name + "_mat")
    final.use_nodes = True
    fnt = final.node_tree
    fb = fnt.nodes["Principled BSDF"]
    ft = fnt.nodes.new("ShaderNodeTexImage")
    ft.image = bpy.data.images.load(path)
    fnt.links.new(ft.outputs["Color"], fb.inputs["Base Color"])
    fb.inputs["Roughness"].default_value = 0.6
    obj.data.materials.clear()
    obj.data.materials.append(final)
    return path


def flat_material(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    if emission:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emission
    return mat


# ------------------------------------------------------------------ prévia

def render(path, cam_loc, target, lens=35, size=(960, 720)):
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = size
    if not scene.world:
        world = bpy.data.worlds.new("W")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
        scene.world = world
    if "Sun" not in bpy.data.objects:
        sun = md.link(bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")))
        sun.data.energy = 3.5
        sun.rotation_euler = (math.radians(55), math.radians(5), math.radians(-35))
        fill = md.link(bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN")))
        fill.data.energy = 1.0
        fill.rotation_euler = (math.radians(70), 0, math.radians(150))
    cam = bpy.data.objects.get("Cam") or md.link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    cam.data.lens = lens
    cam.location = cam_loc
    cam.rotation_euler = (Vector(target) - Vector(cam_loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ principal

def main():
    parts, bones = build()
    arm = md.make_armature(bones)
    head_bones = ["Head"]
    wing_bones = [n for n in bones if n.startswith("Wing")] + ["Chest"]
    md.skin_to(parts["Body"], arm, bones)
    md.skin_to(parts["Wings"], arm, bones, allowed=wing_bones)
    md.skin_to(parts["Horns"], arm, bones)
    md.skin_to(parts["Eyes"], arm, bones, allowed=head_bones, rigid=head_bones)
    md.skin_to(parts["Pupils"], arm, bones, allowed=head_bones, rigid=head_bones)

    os.makedirs(OUT, exist_ok=True)
    print("triângulos:", {n: md.tri_count(o) for n, o in parts.items()})

    bake_texture(parts["Body"], body_material(), "Ancient_Body")
    bake_texture(parts["Wings"], wing_material(), "Ancient_Wings")
    bake_texture(parts["Horns"], vcol_material(), "Ancient_Horns", ao_strength=0.3)
    parts["Eyes"].data.materials.append(flat_material("EyeGlow", (0.85, 0.02, 0.01, 1), 2.0))
    parts["Pupils"].data.materials.append(flat_material("Pupil", (0.02, 0.01, 0.01, 1)))

    if md.RENDER_PREVIEW:
        bpy.ops.mesh.primitive_plane_add(size=60)
        ground = bpy.context.active_object
        ground.data.materials.append(flat_material("Ground", (0.35, 0.33, 0.32, 1)))
        render(os.path.join(OUT, "preview_Ancient.png"), (-12, -13, 8), (0, 0.5, 3))
        render(os.path.join(OUT, "preview_Ancient_head.png"), (-2.6, -9.6, 5.6), (0, -5.0, 4.9), lens=45)
        render(os.path.join(OUT, "preview_Ancient_side.png"), (-17, -1.5, 4.5), (0, 0.5, 3.2))
        render(os.path.join(OUT, "preview_Ancient_front.png"), (3.5, -13, 6.5), (0, -3, 4.2), lens=40)
        bpy.data.objects.remove(ground, do_unlink=True)

    md.select_only([arm] + list(parts.values()))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Dragon_Ancient.fbx"),
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        mesh_smooth_type="FACE",
        use_armature_deform_only=True,
        path_mode="COPY",
        embed_textures=True,
    )
    print("ok")


if __name__ == "__main__":
    main()
