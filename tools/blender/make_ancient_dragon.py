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

def curved_spike(bm, base, direction, length, radius, bend, sides=7, rings=6, ridges=0.0, color_layer=None, colors=None):
    """Espinho/chifre curvo dentro de um bmesh. bend = vetor de curvatura na ponta."""
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
                v = bm.verts.new(p + (side * math.cos(a) + up2 * math.sin(a)) * max(r, 0.004))
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


# ------------------------------------------------------------------ corpo

def build():
    md.reset_scene()
    J = []
    E = []
    N = {}

    def j(key, pos, r):
        N[key] = len(J)
        J.append((pos, r))

    def e(a, b):
        E.append((N[a], N[b]))

    # tronco musculoso
    j("pelvis", (0, 1.3, 2.5), 1.05)
    j("belly", (0, 0.0, 2.7), 1.3)
    j("chest", (0, -1.35, 3.0), 1.4)
    e("pelvis", "belly")
    e("belly", "chest")
    # pescoço grosso e cabeça
    j("neck1", (0, -2.35, 3.75), 1.0)
    j("neck2", (0, -3.05, 4.45), 0.85)
    j("neck3", (0, -3.65, 4.95), 0.78)
    j("skull", (0, -4.3, 5.15), (0.85, 0.75))
    j("face", (0, -5.05, 5.0), (0.72, 0.62))
    j("snout", (0, -5.75, 4.8), 0.55)
    j("nose", (0, -6.35, 4.62), 0.42)
    for a, b in (("chest", "neck1"), ("neck1", "neck2"), ("neck2", "neck3"), ("neck3", "skull"), ("skull", "face"), ("face", "snout"), ("snout", "nose")):
        e(a, b)
    # mandíbula (um pouco aberta)
    j("jaw1", (0, -4.55, 4.55), 0.6)
    j("jaw2", (0, -5.45, 4.25), 0.45)
    j("jaw3", (0, -6.15, 4.15), 0.33)
    e("skull", "jaw1")
    e("jaw1", "jaw2")
    e("jaw2", "jaw3")
    # cauda longa
    prev = "pelvis"
    n_tail = 7
    for i in range(1, n_tail + 1):
        t = i / n_tail
        j(f"tail{i}", (math.sin(t * 2.2) * 0.6 * t, 1.3 + t * 8.5, max(0.45, 2.3 - t * 1.6 + math.sin(t * math.pi) * 0.3)), max(0.1, 0.95 * (1 - t) ** 1.1))
        e(prev, f"tail{i}")
        prev = f"tail{i}"
    # pernas (traseiras com joelho invertido)
    for side, sx in (("L", 1), ("R", -1)):
        j(f"hip{side}", (1.0 * sx, 1.35, 2.15), 0.85)
        j(f"knee{side}", (1.15 * sx, 2.0, 1.2), 0.55)
        j(f"ankle{side}", (1.15 * sx, 1.45, 0.48), 0.36)
        j(f"toe{side}", (1.15 * sx, 0.85, 0.2), (0.45, 0.24))
        e("pelvis", f"hip{side}")
        e(f"hip{side}", f"knee{side}")
        e(f"knee{side}", f"ankle{side}")
        e(f"ankle{side}", f"toe{side}")
        j(f"shoulder{side}", (1.0 * sx, -1.35, 2.55), 0.8)
        j(f"elbow{side}", (1.2 * sx, -1.1, 1.35), 0.5)
        j(f"wrist{side}", (1.2 * sx, -1.55, 0.42), 0.34)
        j(f"hand{side}", (1.2 * sx, -2.0, 0.2), (0.42, 0.22))
        e("chest", f"shoulder{side}")
        e(f"shoulder{side}", f"elbow{side}")
        e(f"elbow{side}", f"wrist{side}")
        e(f"wrist{side}", f"hand{side}")

    body = md.skin_mesh("Body", J, E, root_index=N["pelvis"], subdiv=3)
    # relevo: músculos (ruído grande) + escamas (voronoi pequeno)
    tex_m = bpy.data.textures.new("Muscle", "CLOUDS")
    tex_m.noise_scale = 0.9
    d1 = body.modifiers.new("Muscle", "DISPLACE")
    d1.texture = tex_m
    d1.strength = 0.12
    d1.mid_level = 0.5
    tex_s = bpy.data.textures.new("Scales", "VORONOI")
    tex_s.noise_scale = 0.11
    tex_s.distance_metric = "DISTANCE"
    d2 = body.modifiers.new("Scales", "DISPLACE")
    d2.texture = tex_s
    d2.strength = 0.035
    md.apply_modifiers(body)
    # deixa a cabeça mais angulosa (achatada em cima, focinho em cunha)
    head_c = Vector(J[N["face"]][0])
    for v in body.data.vertices:
        co = v.co
        if co.y < -3.9 and co.z > 3.6:
            t = min(1.0, (-3.9 - co.y) / 2.6)
            co.z = head_c.z + (co.z - head_c.z) * (1 - 0.3 * t) - 0.15 * t
            co.x *= 1.0 - 0.25 * t
            if co.z > head_c.z:
                co.z -= (co.z - head_c.z) * 0.25 * t
    md.shade_smooth(body)

    depsgraph = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(body, depsgraph)
    P = lambda k: Vector(J[N[k]][0])

    crest, horns_specs, beard, claws, teeth = [], [], [], [], []

    # chifres principais (grandes, curvados para trás) e secundários
    skull = P("skull")
    for sx in (1, -1):
        base = md.surface(tree, skull + Vector((0.45 * sx, 0.25, 0.1)), (0.6 * sx, 0.3, 0.8))
        horns_specs.append((base, Vector((0.35 * sx, 1.0, 0.45)), 2.6, 0.26, Vector((0.5 * sx, 0.4, -0.7)), 9, 14, 0.06))
        base2 = md.surface(tree, skull + Vector((0.6 * sx, -0.1, -0.15)), (1, 0.1, 0.1) if sx > 0 else (-1, 0.1, 0.1))
        horns_specs.append((base2, Vector((0.9 * sx, 0.7, 0.1)), 1.2, 0.13, Vector((0.1 * sx, 0.3, -0.25)), 8, 8, 0.05))
        # crista óssea pontuda acima do olho, apontando para trás
        bro = md.surface(tree, skull + Vector((0.42 * sx, -0.75, 0.25)), (0.6 * sx, -0.3, 0.8))
        horns_specs.append((bro, Vector((0.35 * sx, 0.9, 0.35)), 0.9, 0.12, Vector((0.05 * sx, 0.1, 0.1)), 7, 6, 0.0))
        # chifrinhos na testa
        for k in range(3):
            b = md.surface(tree, skull + Vector((0.28 * sx, -0.55 + k * 0.28, 0.2)), (0.4 * sx, -0.2, 1))
            horns_specs.append((b, Vector((0.2 * sx, 0.6, 0.9)), 0.35 + k * 0.08, 0.06, Vector((0, 0.08, 0)), 6, 4, 0.0))

    # chifre no nariz
    nb = md.surface(tree, P("snout") + Vector((0, -0.2, 0.1)), (0, -0.3, 1))
    horns_specs.append((nb, Vector((0, 0.35, 1)), 0.45, 0.1, Vector((0, 0.12, 0)), 7, 5, 0.0))

    # juba de espinhos carmesim na cabeça e no pescoço (várias camadas)
    neck_pts = [P("skull"), P("neck3"), P("neck2"), P("neck1"), P("chest")]
    for layer in range(3):
        for i in range(len(neck_pts) - 1):
            for k in range(4):
                t = (k + rng.random() * 0.5) / 4
                p = neck_pts[i].lerp(neck_pts[i + 1], t)
                for ang in (-1.1, -0.55, 0.0, 0.55, 1.1):
                    a = ang + rng.uniform(-0.12, 0.12) + (layer - 1) * 0.15
                    dirn = Vector((math.sin(a), 0.35, math.cos(a)))
                    base = md.surface(tree, p, dirn) - dirn.normalized() * 0.05
                    length = (1.5 - layer * 0.35) * (1.0 - i * 0.17) * rng.uniform(0.8, 1.15)
                    back = Vector((math.sin(a) * 0.5, 0.9 + layer * 0.2, 0.25))
                    crest.append((base, back, length, 0.14 * (1 - layer * 0.15), Vector((0, 0.25, -0.35)) * length, 7, 6, 0.0))
    # espinhos nas bochechas e na mandíbula
    for sx in (1, -1):
        for k in range(5):
            p = P("jaw1").lerp(P("jaw2"), k / 5)
            base = md.surface(tree, p, (sx, 0.3, -0.2))
            crest.append((base, Vector((0.7 * sx, 0.9, -0.15)), 0.6 + k * 0.05, 0.08, Vector((0.1 * sx, 0.2, -0.1)), 6, 5, 0.0))
        for k in range(4):
            p = P("skull").lerp(P("face"), k / 4)
            base = md.surface(tree, p + Vector((0, 0, -0.1)), (sx, 0.2, 0.1))
            crest.append((base, Vector((0.8 * sx, 0.8, 0.2)), 0.75 - k * 0.1, 0.09, Vector((0.1 * sx, 0.25, -0.2)), 6, 5, 0.0))
    # barba de espinhos claros embaixo do queixo
    for k in range(9):
        t = k / 8
        p = P("jaw1").lerp(P("jaw3"), t * 0.8)
        for sx in (-0.5, 0, 0.5):
            base = md.surface(tree, p + Vector((sx * 0.3, 0, 0)), (sx * 0.4, 0, -1))
            beard.append((base, Vector((sx * 0.3, 0.55, -1.0)), 0.55 * (1.2 - t * 0.5), 0.06, Vector((0, 0.2, 0.05)), 6, 5, 0.0))
    # espinhos nas costas e cauda (duas fileiras)
    spine = [P("chest"), P("belly"), P("pelvis")] + [P(f"tail{i}") for i in range(1, n_tail + 1)]
    for i in range(len(spine) - 1):
        for k in range(3):
            p = spine[i].lerp(spine[i + 1], (k + 0.5) / 3)
            size = max(0.25, 1.1 - i * 0.12)
            for sx in (-0.35, 0.35):
                dirn = Vector((sx, 0.2, 1))
                base = md.surface(tree, p, dirn) - Vector((0, 0, 0.06))
                crest.append((base, Vector((sx * 0.6, 0.7, 1.0)), size, 0.16 * size, Vector((0, 0.3, -0.15)) * size, 7, 5, 0.0))
    # ponta da cauda: leque de espinhos
    tip = P(f"tail{n_tail}")
    for a in range(-3, 4):
        crest.append((tip, Vector((a * 0.35, 1.0, 0.2 + abs(a) * 0.05)), 0.9 - abs(a) * 0.1, 0.09, Vector((a * 0.1, 0.2, 0)), 6, 5, 0.0))
    # espinhos nos cotovelos
    for sx, s in ((1, "L"), (-1, "R")):
        base = md.surface(tree, P(f"elbow{s}"), (0.3 * sx, 1, 0.2))
        crest.append((base, Vector((0.2 * sx, 1, 0.3)), 0.7, 0.1, Vector((0, 0.1, -0.1)), 6, 5, 0.0))
        # garras
        for key in (f"toe{s}", f"hand{s}"):
            p = P(key)
            for k in (-1, 0, 1):
                b = p + Vector((k * 0.18, -0.25, 0.02))
                claws.append((b, Vector((k * 0.1, -1, -0.35)), 0.35, 0.07, Vector((0, -0.05, -0.15)), 6, 5, 0.0))
    # dentes
    for sx in (1, -1):
        for k in range(10):
            t = k / 9
            up_p = P("face").lerp(P("nose"), t) + Vector((0.3 * sx * (1 - t * 0.45), 0, -0.3))
            teeth.append((up_p, Vector((0, -0.1, -1)), 0.14 + (0.1 if k in (6, 7) else 0), 0.04, Vector((0, -0.02, 0)), 5, 3, 0.0))
            lo_p = P("jaw1").lerp(P("jaw3"), 0.3 + t * 0.7) + Vector((0.28 * sx * (1 - t * 0.4), 0, 0.3))
            teeth.append((lo_p, Vector((0, -0.05, 1)), 0.16, 0.035, Vector((0, -0.02, 0)), 5, 3, 0.0))

    crest_obj = spikes_object("HornsCrest", crest, lambda t: lerp_color(CREST, t))
    horns_obj = spikes_object("HornsMain", horns_specs, lambda t: lerp_color(BONE, t))
    beard_obj = spikes_object("HornsBeard", beard, lambda t: lerp_color(BEARD, t))
    claws_obj = spikes_object("HornsClaws", claws + teeth, lambda t: lerp_color(BONE if t < 0.99 else CLAW, t * 0.6))

    # olhos vermelhos com pupila em fenda
    eyes, pupils = [], []
    for sx in (1, -1):
        c = md.surface(tree, P("skull") + Vector((0.45 * sx, -0.55, 0.12)), (0.8 * sx, -0.6, 0.25))
        eyes.append(md.sphere(f"Eye{sx}", c, 0.17, 16))
        pup = md.sphere(f"Pupil{sx}", c + Vector((0.09 * sx, -0.09, 0)), 0.11, 12)
        scale_about_center(pup, (0.35, 0.35, 1.0))
        pupils.append(pup)
        # sobrancelha (crista óssea acima do olho)
        brow = md.sphere(f"Brow{sx}", c + Vector((0.0, 0.08, 0.17)), 0.26, 12)
        scale_about_center(brow, (0.95, 1.8, 0.5))
        body = md.join([body, brow], "Body")

    # asas grandes
    wing_parts, wing_bones_mesh, wing_claws = [], [], []
    bones = {}
    for side, sx in (("L", 1), ("R", -1)):
        shoulder = Vector((0.85 * sx, -0.9, 3.85))
        elbow = shoulder + Vector((2.2 * sx, 0.5, 1.6))
        wrist = elbow + Vector((2.0 * sx, 0.9, 0.5))
        tips = [wrist + Vector((2.0 * sx, 1.2, -1.0)), wrist + Vector((1.2 * sx, 2.8, -2.0)), wrist + Vector((-0.4 * sx, 3.4, -2.6))]
        back = Vector((0.75 * sx, 2.0, 3.2))
        outline = [shoulder, elbow, wrist, tips[0]]
        seq = tips + [back]
        for a, b in zip(seq, seq[1:]):
            for k in (1, 2, 3, 4):
                t = k / 5
                outline.append(a.lerp(b, t).lerp(wrist, math.sin(t * math.pi) * 0.25))
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
        sol.thickness = 0.08
        md.apply_modifiers(w)
        md.shade_smooth(w)
        wing_parts.append(w)
        wj = [(tuple(shoulder), 0.24), (tuple(elbow), 0.17), (tuple(wrist), 0.14)]
        we = [(0, 1), (1, 2)]
        for t in tips:
            wj.append((tuple(t), 0.04))
            we.append((2, len(wj) - 1))
        wing_bones_mesh.append(md.skin_mesh(f"WingBone{side}", wj, we, root_index=0, subdiv=1))
        wing_claws.append((wrist, Vector((0.2 * sx, -0.6, 0.8)), 0.5, 0.09, Vector((0, -0.1, 0)), 6, 5, 0.0))
        bones[f"Wing{side}1"] = (shoulder, elbow, "Chest")
        bones[f"Wing{side}2"] = (elbow, wrist, f"Wing{side}1")
        bones[f"Wing{side}3"] = (wrist, tips[1], f"Wing{side}2")

    body = md.join([body] + wing_bones_mesh, "Body")
    md.decimate_to(body, 19500)
    wings = md.join(wing_parts, "Wings")
    wing_claw_obj = spikes_object("HornsWingClaws", wing_claws, lambda t: lerp_color(BONE, t * 0.6))
    horns = md.join([crest_obj, horns_obj, beard_obj, claws_obj, wing_claw_obj], "Horns")
    md.decimate_to(horns, 19500)
    eyes_obj = md.join(eyes, "Eyes")
    pupils_obj = md.join(pupils, "Pupils")

    # ossos
    bones["Root"] = (Vector((0, 0.2, 0.05)), Vector((0, 0.2, 0.7)), None)
    bones["Spine"] = (P("pelvis"), P("belly"), "Root")
    bones["Chest"] = (P("belly"), P("chest"), "Spine")
    bones["Neck1"] = (P("chest"), P("neck1"), "Chest")
    bones["Neck2"] = (P("neck1"), P("neck3"), "Neck1")
    bones["Head"] = (P("neck3"), P("snout"), "Neck2")
    prev, frm = "Root", P("pelvis")
    for i in range(1, n_tail + 1):
        bones[f"Tail{i}"] = (frm, P(f"tail{i}"), prev)
        prev, frm = f"Tail{i}", P(f"tail{i}")
    for s in ("L", "R"):
        bones[f"Thigh{s}"] = (P(f"hip{s}"), P(f"knee{s}"), "Spine")
        bones[f"Shin{s}"] = (P(f"knee{s}"), P(f"ankle{s}"), f"Thigh{s}")
        bones[f"Foot{s}"] = (P(f"ankle{s}"), P(f"toe{s}"), f"Shin{s}")
        bones[f"Arm{s}"] = (P(f"shoulder{s}"), P(f"elbow{s}"), "Chest")
        bones[f"Forearm{s}"] = (P(f"elbow{s}"), P(f"wrist{s}"), f"Arm{s}")
        bones[f"Hand{s}"] = (P(f"wrist{s}"), P(f"hand{s}"), f"Forearm{s}")

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
    edge.inputs["To Min"].default_value = 0.55
    edge.inputs["To Max"].default_value = 1.0
    nt.links.new(vor.outputs["Distance"], edge.inputs["Value"])
    # manchas de cor (laranja / marrom)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    noise.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.42, 0.17, 0.07, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.9, 0.48, 0.15, 1)
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
    mix_belly.inputs[7].default_value = (0.92, 0.78, 0.55, 1)
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
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 2.5
    wave.inputs["Distortion"].default_value = 4
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.25, 0.04, 0.06, 1)
    ramp.color_ramp.elements[1].color = (0.6, 0.18, 0.12, 1)
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
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
    parts["Eyes"].data.materials.append(flat_material("EyeGlow", (1.0, 0.12, 0.03, 1), 1.2))
    parts["Pupils"].data.materials.append(flat_material("Pupil", (0.02, 0.01, 0.01, 1)))

    if md.RENDER_PREVIEW:
        bpy.ops.mesh.primitive_plane_add(size=60)
        ground = bpy.context.active_object
        ground.data.materials.append(flat_material("Ground", (0.35, 0.33, 0.32, 1)))
        render(os.path.join(OUT, "preview_Ancient.png"), (-12, -13, 8), (0, 0.5, 3))
        render(os.path.join(OUT, "preview_Ancient_head.png"), (-2.6, -9.6, 5.6), (0, -5.0, 4.9), lens=45)
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
