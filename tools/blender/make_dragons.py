"""Gera os dragões 3D (malha + ossos) no Blender e exporta em FBX para o Roblox.

Uso (com o Blender instalado):
    blender --background --python tools/blender/make_dragons.py
ou com o módulo bpy do Python:
    python tools/blender/make_dragons.py

Saída:
    assets/models/Dragon_<Estilo>.fbx   (para importar no Roblox Studio)
    assets/models/preview_<Estilo>.png  (imagem de conferência)

Cada FBX tem as partes separadas por nome (Body, Belly, Wings, Horns, Eyes, Pupils)
para o jogo pintar cada dragão com suas cores, e ossos com nomes fixos
(Spine, Chest, Neck1, Neck2, Head, Tail1..5, WingL1..3, WingR1..3, pernas)
que o jogo anima por código.
"""

import math
import os
import sys

import bpy  # precisa vir antes de bmesh/mathutils
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models")
RENDER_PREVIEW = "--no-preview" not in sys.argv


# ------------------------------------------------------------------ utilidades

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def apply_modifiers(obj):
    select_only([obj])
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def shade_smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate_to(obj, max_tris):
    tris = tri_count(obj)
    if tris > max_tris:
        m = obj.modifiers.new("Decimate", "DECIMATE")
        m.ratio = max_tris / tris
        apply_modifiers(obj)


def skin_mesh(name, joints, edges, root_index=0, subdiv=2):
    """Cria uma malha orgânica a partir de um esqueleto (pontos + raios)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([j[0] for j in joints], edges, [])
    obj = link(bpy.data.objects.new(name, me))
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    layer = me.skin_vertices[0].data
    for i, (_, r) in enumerate(joints):
        rx, ry = (r, r) if not isinstance(r, tuple) else r
        layer[i].radius = (rx, ry)
        layer[i].use_root = i == root_index
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    apply_modifiers(obj)
    shade_smooth(obj)
    return obj


def cone(name, base, tip, radius, segments=10):
    """Cone (chifre/espinho) da base até a ponta."""
    direction = Vector(tip) - Vector(base)
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(vertices=segments, radius1=radius, radius2=0.0, depth=length,
                                    location=Vector(base) + direction / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    shade_smooth(obj)
    return obj


def sphere(name, center, radius, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=radius, location=center)
    obj = bpy.context.active_object
    obj.name = name
    select_only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    shade_smooth(obj)
    return obj


def join(objs, name):
    objs = [o for o in objs if o]
    select_only(objs)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def surface(tree, target, direction):
    """Ponto na superfície do corpo vindo de 'direction' em direção a 'target'."""
    d = Vector(direction).normalized()
    origin = Vector(target) + d * 5
    hit, _, _, _ = tree.ray_cast(origin, -d, 10)
    return hit if hit is not None else Vector(target)


def mirror_x(p):
    return (-p[0], p[1], p[2])


# ------------------------------------------------------------------ modelo

def build_dragon(style):
    """Retorna (partes, ossos). Dragão olha para -Y, pés em Z=0."""
    P = {
        "Basic": dict(body=1.0, leg=1.0, wing=1.0, neck=1.0, tail=1.0, spikes=5, horns=1, heads=1),
        "Chunky": dict(body=1.3, leg=0.8, wing=0.75, neck=0.85, tail=0.85, spikes=4, horns=1, heads=1),
        "Serpent": dict(body=0.75, leg=0.6, wing=0.65, neck=1.5, tail=1.6, spikes=9, horns=1, heads=1),
        "Spiky": dict(body=1.0, leg=1.0, wing=1.05, neck=1.05, tail=1.0, spikes=9, horns=2, heads=1),
        "Hydra": dict(body=1.15, leg=0.95, wing=0.9, neck=1.25, tail=0.9, spikes=5, horns=1, heads=3),
    }[style]
    b, lg = P["body"], P["leg"]
    hip_z = 1.75 * lg + 0.25

    joints = []  # (posição, raio)
    edges = []
    names = {}

    def J(key, pos, r):
        names[key] = len(joints)
        joints.append((pos, r))
        return names[key]

    def E(a, c):
        edges.append((names[a], names[c]))

    # coluna
    J("pelvis", (0, 1.0, hip_z), 0.9 * b)
    J("belly", (0, 0.0, hip_z + 0.15), 1.12 * b)
    J("chest", (0, -1.0, hip_z + 0.3), 1.05 * b)
    E("pelvis", "belly")
    E("belly", "chest")

    # cauda
    n_tail = 5 if style != "Serpent" else 7
    prev = "pelvis"
    for i in range(1, n_tail + 1):
        t = i / n_tail
        y = 1.0 + t * 5.8 * P["tail"]
        z = hip_z - 0.2 - t * 0.9 + (math.sin(t * math.pi * 2) * 0.25 if style == "Serpent" else 0)
        r = max(0.08, 0.72 * b * (1 - t) ** 1.15)
        J(f"tail{i}", (0, y, max(0.35, z)), r)
        E(prev, f"tail{i}")
        prev = f"tail{i}"

    # pescoços e cabeças
    head_keys = []
    offsets = [0.0] if P["heads"] == 1 else [-1.35, 0.0, 1.35]
    for hi, ox in enumerate(offsets):
        tag = "" if P["heads"] == 1 else ["L", "", "R"][hi]
        nk = P["neck"]
        J(f"neck1{tag}", (ox * 0.5, -1.65, hip_z + 0.85 * nk), 0.64 * b * (0.85 if tag else 1))
        J(f"neck2{tag}", (ox * 0.9, -2.1, hip_z + 1.6 * nk), 0.54 * b * (0.85 if tag else 1))
        J(f"head{tag}", (ox, -2.6, hip_z + 2.25 * nk), (0.78, 0.7))
        J(f"snout{tag}", (ox, -3.4, hip_z + 2.05 * nk), 0.52)
        J(f"nose{tag}", (ox, -3.95, hip_z + 1.95 * nk), 0.38)
        E("chest", f"neck1{tag}")
        E(f"neck1{tag}", f"neck2{tag}")
        E(f"neck2{tag}", f"head{tag}")
        E(f"head{tag}", f"snout{tag}")
        E(f"snout{tag}", f"nose{tag}")
        head_keys.append((tag, ox))

    # pernas
    for side, sx in (("L", 1), ("R", -1)):
        J(f"hip{side}", (0.66 * sx * b, 1.0, hip_z - 0.3), 0.6 * b)
        J(f"knee{side}", (0.8 * sx * b, 1.35, 0.95 * lg + 0.2), 0.42 * b)
        J(f"ankle{side}", (0.8 * sx * b, 0.95, 0.32), 0.29 * b)
        J(f"toe{side}", (0.8 * sx * b, 0.5, 0.17), (0.34 * b, 0.2))
        E("pelvis", f"hip{side}")
        E(f"hip{side}", f"knee{side}")
        E(f"knee{side}", f"ankle{side}")
        E(f"ankle{side}", f"toe{side}")
        J(f"shoulder{side}", (0.64 * sx * b, -1.0, hip_z - 0.1), 0.5 * b)
        J(f"elbow{side}", (0.74 * sx * b, -1.2, 1.0 * lg + 0.1), 0.34 * b)
        J(f"wrist{side}", (0.74 * sx * b, -1.3, 0.3), 0.26 * b)
        J(f"hand{side}", (0.74 * sx * b, -1.7, 0.16), (0.3 * b, 0.18))
        E("chest", f"shoulder{side}")
        E(f"shoulder{side}", f"elbow{side}")
        E(f"elbow{side}", f"wrist{side}")
        E(f"wrist{side}", f"hand{side}")

    body = skin_mesh("Body", joints, edges, root_index=names["pelvis"], subdiv=2)

    # barriga: segundo "esqueleto" um pouco menor e deslocado para baixo/frente;
    # só a parte de baixo aparece para fora do corpo (borda lisa)
    bj, be = [], []
    belly_keys = ["tail2", "tail1", "pelvis", "belly", "chest"] + [k for k in names if k.startswith("neck") or k.startswith("snout")]
    index = {}
    for k in belly_keys:
        if k not in names:
            continue
        pos, r = joints[names[k]]
        r = r if not isinstance(r, tuple) else r[0]
        if k.startswith("snout"):
            pos = (pos[0], pos[1] - 0.05, pos[2] - 0.2)
            r *= 0.85
        else:
            pos = (pos[0], pos[1] - 0.12 * r, pos[2] - 0.2 * r)
            r *= 0.9
        index[k] = len(bj)
        bj.append((pos, r))
    chain = [k for k in ["tail2", "tail1", "pelvis", "belly", "chest"] if k in index]
    for a, c in zip(chain, chain[1:]):
        be.append((index[a], index[c]))
    for k in index:
        if k.startswith("neck1"):
            tag = k[5:]
            be.append((index["chest"], index[k]))
            be.append((index[k], index["neck2" + tag]))
        if k.startswith("snout"):
            tag = k[5:]
            be.append((index["neck2" + tag], index[k]))
    belly = skin_mesh("Belly", bj, be, root_index=index["pelvis"], subdiv=2)
    bm = bmesh.new()
    bm.from_mesh(belly.data)
    for v in bm.verts:
        # mais estreita dos lados para não vazar do corpo
        v.co.x *= 0.8
        # faixas (placas da barriga)
        band = 0.5 + 0.5 * math.cos(v.co.y * 6.0 + v.co.z * 3.0)
        v.co += v.normal * (0.03 * band)
    bm.to_mesh(belly.data)
    bm.free()
    shade_smooth(belly)

    extras_body = []  # ossos das asas (cor do corpo)
    horns = []
    eyes = []
    pupils = []
    wing_parts = []
    bones = {}

    depsgraph = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(body, depsgraph)
    hip = Vector(joints[names["pelvis"]][0])
    chest = Vector(joints[names["chest"]][0])

    # asas
    ws = P["wing"]
    for side, sx in (("L", 1), ("R", -1)):
        shoulder = Vector((0.65 * sx * b, -0.55, hip_z + 0.75 * b))
        elbow = shoulder + Vector((1.5 * sx, 0.3, 1.1)) * ws
        wrist = elbow + Vector((1.3 * sx, 0.55, 0.35)) * ws
        tips = [
            wrist + Vector((1.4 * sx, 0.9, -0.6)) * ws,
            wrist + Vector((0.9 * sx, 1.9, -1.4)) * ws,
            wrist + Vector((-0.2 * sx, 2.4, -1.8)) * ws,
        ]
        back = Vector((0.55 * sx * b, 1.3, hip_z + 0.45 * b))
        # membrana com recortes entre as pontas
        outline = [shoulder, elbow, wrist, tips[0]]
        seq = tips + [back]
        for a, c in zip(seq, seq[1:]):
            for k in (1, 2, 3):
                t = k / 4
                p = a.lerp(c, t)
                pull = math.sin(t * math.pi) * 0.3
                outline.append(p.lerp(wrist, pull))
            outline.append(c)
        outline = outline[:-1] + [back]
        me = bpy.data.meshes.new(f"Wing{side}")
        me.from_pydata([tuple(p) for p in outline], [], [list(range(len(outline)))])
        w = link(bpy.data.objects.new(f"Wing{side}", me))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
        bm.to_mesh(me)
        bm.free()
        sol = w.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = 0.07
        apply_modifiers(w)
        shade_smooth(w)
        wing_parts.append(w)
        # ossos da asa (tubos)
        wj = [(tuple(shoulder), 0.16), (tuple(elbow), 0.12), (tuple(wrist), 0.1)]
        we = [(0, 1), (1, 2)]
        for t in tips:
            wj.append((tuple(t), 0.03))
            we.append((2, len(wj) - 1))
        extras_body.append(skin_mesh(f"WingBone{side}", wj, we, root_index=0, subdiv=1))
        # garra na dobra da asa
        horns.append(cone(f"WingClaw{side}", tuple(wrist), tuple(wrist + Vector((0.25 * sx, -0.3, 0.35))), 0.07, 8))
        bones[f"Wing{side}1"] = (shoulder, elbow, "Chest")
        bones[f"Wing{side}2"] = (elbow, wrist, f"Wing{side}1")
        bones[f"Wing{side}3"] = (wrist, tips[1], f"Wing{side}2")

    # cabeças: olhos, chifres
    for tag, ox in head_keys:
        head = Vector(joints[names[f"head{tag}"]][0])
        for sx in (1, -1):
            eye_c = surface(tree, head + Vector((0.3 * sx, -0.3, 0.2)), (0.55 * sx, -0.7, 0.35)) - Vector((0.55 * sx, -0.7, 0.35)).normalized() * 0.08
            eyes.append(sphere(f"Eye{tag}{sx}", eye_c, 0.23))
            pupils.append(sphere(f"Pupil{tag}{sx}", eye_c + Vector((0.08 * sx, -0.14, 0.03)), 0.12, 12))
            base = surface(tree, head + Vector((0.3 * sx, 0.15, 0.0)), (0.25 * sx, 0.2, 1.0)) - Vector((0, 0, 0.06))
            horns.append(cone(f"Horn{tag}{sx}", tuple(base), tuple(base + Vector((0.3 * sx, 0.85, 0.65))), 0.17))
            if P["horns"] > 1:
                base2 = surface(tree, head + Vector((0.3 * sx, 0.2, 0.0)), (1.0 * sx, 0.3, 0.2)) - Vector((0.06 * sx, 0, 0))
                horns.append(cone(f"Horn2{tag}{sx}", tuple(base2), tuple(base2 + Vector((0.6 * sx, 0.5, 0.15))), 0.09))
            # dentinhos
            tooth = surface(tree, head + Vector((0.2 * sx, -0.9, -0.2)), (0.1 * sx, -0.6, -1.0)) + Vector((0, 0, 0.04))
            horns.append(cone(f"Tooth{tag}{sx}", tuple(tooth), tuple(tooth + Vector((0, -0.02, -0.16))), 0.04, 6))

    # garras nos pés
    for side in ("L", "R"):
        for key in (f"toe{side}", f"hand{side}"):
            p = Vector(joints[names[key]][0])
            for k in (-1, 0, 1):
                base = p + Vector((k * 0.14 * b, 0.04, 0.05))
                horns.append(cone(f"Claw{key}{k}", tuple(base), tuple(base + Vector((0, -0.16, -0.1))), 0.06, 6))

    # espinhos nas costas e na cauda
    spine_path = [names["chest"], names["belly"], names["pelvis"]] + [names[f"tail{i}"] for i in range(1, n_tail + 1)]
    pts = [Vector(joints[i][0]) for i in spine_path]
    rads = [joints[i][1] if not isinstance(joints[i][1], tuple) else joints[i][1][0] for i in spine_path]
    total = P["spikes"]
    for k in range(total):
        t = (k + 0.5) / total * (len(pts) - 1.5)
        i = int(t)
        f = t - i
        p = pts[i].lerp(pts[i + 1], f)
        r = rads[i] * (1 - f) + rads[i + 1] * f
        base = surface(tree, p, (0, 0, 1)) - Vector((0, 0, 0.05))
        h = 0.22 + r * 0.45
        horns.append(cone(f"Spike{k}", tuple(base), tuple(base + Vector((0, 0.18, h))), 0.08 + r * 0.12, 8))

    # pontinha da cauda (formato de lança)
    tip_p = Vector(joints[names[f"tail{n_tail}"]][0])
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.3, radius2=0, depth=0.6, location=tip_p + Vector((0, 0.25, 0)))
    spade = bpy.context.active_object
    spade.name = "TailSpade"
    spade.rotation_euler = (math.radians(-90), 0, 0)
    spade.scale = (1, 0.25, 1)
    select_only([spade])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    horns.append(spade)

    body = join([body] + extras_body, "Body")
    decimate_to(body, 9000)
    decimate_to(belly, 3000)
    wings = join(wing_parts, "Wings")
    horns_obj = join(horns, "Horns")
    decimate_to(horns_obj, 3000)
    eyes_obj = join(eyes, "Eyes")
    pupils_obj = join(pupils, "Pupils")

    # ossos do tronco
    J0 = lambda k: Vector(joints[names[k]][0])
    bones["Root"] = (Vector((0, 0.2, 0.05)), Vector((0, 0.2, 0.6)), None)
    bones["Spine"] = (J0("pelvis"), J0("belly"), "Root")
    bones["Chest"] = (J0("belly"), J0("chest"), "Spine")
    prev = "Spine"
    tail_from = J0("pelvis")
    for i in range(1, n_tail + 1):
        bname = f"Tail{i}"
        bones[bname] = (tail_from, J0(f"tail{i}"), prev if i > 1 else "Root")
        tail_from = J0(f"tail{i}")
        prev = bname
    for tag, _ in head_keys:
        bones[f"Neck1{tag}"] = (J0("chest"), J0(f"neck1{tag}"), "Chest")
        bones[f"Neck2{tag}"] = (J0(f"neck1{tag}"), J0(f"neck2{tag}"), f"Neck1{tag}")
        bones[f"Head{tag}"] = (J0(f"neck2{tag}"), J0(f"snout{tag}"), f"Neck2{tag}")
    for side in ("L", "R"):
        bones[f"Thigh{side}"] = (J0(f"hip{side}"), J0(f"knee{side}"), "Spine")
        bones[f"Shin{side}"] = (J0(f"knee{side}"), J0(f"ankle{side}"), f"Thigh{side}")
        bones[f"Foot{side}"] = (J0(f"ankle{side}"), J0(f"toe{side}"), f"Shin{side}")
        bones[f"Arm{side}"] = (J0(f"shoulder{side}"), J0(f"elbow{side}"), "Chest")
        bones[f"Forearm{side}"] = (J0(f"elbow{side}"), J0(f"wrist{side}"), f"Arm{side}")
        bones[f"Hand{side}"] = (J0(f"wrist{side}"), J0(f"hand{side}"), f"Forearm{side}")

    parts = {"Body": body, "Belly": belly, "Wings": wings, "Horns": horns_obj, "Eyes": eyes_obj, "Pupils": pupils_obj}
    head_bones = [f"Head{tag}" for tag, _ in head_keys]
    return parts, bones, head_bones


# ------------------------------------------------------------------ ossos e pesos

def make_armature(bones):
    arm_data = bpy.data.armatures.new("DragonRig")
    arm = link(bpy.data.objects.new("DragonRig", arm_data))
    select_only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    order = list(bones.keys())
    created = {}
    # pais antes dos filhos
    pending = order[:]
    while pending:
        for name in list(pending):
            head, tail, parent = bones[name]
            if parent and parent not in created:
                continue
            b = eb.new(name)
            b.head = head
            b.tail = tail if (Vector(tail) - Vector(head)).length > 0.01 else Vector(head) + Vector((0, 0, 0.2))
            if parent:
                b.parent = eb[parent]
            created[name] = b
            pending.remove(name)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def skin_to(obj, arm, bones, allowed=None, rigid=None):
    """Pesos pelos ossos mais próximos (até 3 por vértice)."""
    names = [n for n in bones if (allowed is None or n in allowed)]
    groups = {n: obj.vertex_groups.new(name=n) for n in names}
    segs = {n: (Vector(bones[n][0]), Vector(bones[n][1])) for n in names}
    for v in obj.data.vertices:
        p = v.co
        if rigid:
            best = min(rigid, key=lambda n: segment_distance(p, *segs[n]))
            groups[best].add([v.index], 1.0, "REPLACE")
            continue
        ds = sorted(((segment_distance(p, *segs[n]), n) for n in names))[:3]
        ws = [(1.0 / max(d, 0.02) ** 4, n) for d, n in ds]
        total = sum(w for w, _ in ws)
        for w, n in ws:
            if w / total > 0.02:
                groups[n].add([v.index], w / total, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm


# ------------------------------------------------------------------ preview

PREVIEW_COLORS = {
    "Body": (0.85, 0.15, 0.1, 1),
    "Belly": (1.0, 0.8, 0.35, 1),
    "Wings": (0.55, 0.05, 0.08, 1),
    "Horns": (1.0, 0.95, 0.8, 1),
    "Eyes": (1.0, 1.0, 0.6, 1),
    "Pupils": (0.02, 0.02, 0.02, 1),
}


def preview(parts, arm, path, pose=False):
    for name, obj in parts.items():
        mat = bpy.data.materials.new(name + "Mat")
        mat.diffuse_color = PREVIEW_COLORS[name]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = PREVIEW_COLORS[name]
            bsdf.inputs["Roughness"].default_value = 0.45
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    if pose:
        # pose de teste: asas levantadas, cabeça e cauda viradas
        select_only([arm])
        bpy.ops.object.mode_set(mode="POSE")
        pb = arm.pose.bones
        for name, ang in (("WingL1", (0, 0.5, 0)), ("WingR1", (0, -0.5, 0)), ("Tail3", (0, 0, 0.4)), ("Head", (0.3, 0, 0))):
            if name in pb:
                pb[name].rotation_mode = "XYZ"
                pb[name].rotation_euler = ang
        bpy.ops.object.mode_set(mode="OBJECT")
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 4
    sun = link(bpy.data.objects.new("Sun", sun_data))
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-40))
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3, 0.6, 0.25, 1)
    ground.data.materials.append(gm)
    cam_data = bpy.data.cameras.new("Cam")
    cam = link(bpy.data.objects.new("Cam", cam_data))
    cam.location = (-11, -10, 7)
    direction = Vector((0, 0.8, 2.2)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if pose:
        select_only([arm])
        bpy.ops.object.mode_set(mode="POSE")
        for p in arm.pose.bones:
            p.rotation_euler = (0, 0, 0)
            p.rotation_quaternion = (1, 0, 0, 0)
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in (ground, sun, cam):
        bpy.data.objects.remove(o, do_unlink=True)


# ------------------------------------------------------------------ principal

def make_style(style):
    reset_scene()
    parts, bones, head_bones = build_dragon(style)
    arm = make_armature(bones)
    wing_bones = [n for n in bones if n.startswith("Wing")] + ["Chest"]
    skin_to(parts["Body"], arm, bones)
    skin_to(parts["Belly"], arm, bones, allowed=[n for n in bones if not n.startswith("Wing")])
    skin_to(parts["Wings"], arm, bones, allowed=wing_bones)
    rigid_horns = head_bones + [n for n in bones if n.startswith("Wing") or n.startswith("Tail") or n in ("Spine", "Chest")]
    skin_to(parts["Horns"], arm, bones, allowed=rigid_horns, rigid=rigid_horns)
    skin_to(parts["Eyes"], arm, bones, allowed=head_bones, rigid=head_bones)
    skin_to(parts["Pupils"], arm, bones, allowed=head_bones, rigid=head_bones)

    os.makedirs(OUT, exist_ok=True)
    info = ", ".join(f"{n}={tri_count(o)}" for n, o in parts.items())
    print(f"[{style}] triângulos: {info} | ossos: {len(bones)}")

    if RENDER_PREVIEW:
        preview(parts, arm, os.path.join(OUT, f"preview_{style}.png"))
        preview(parts, arm, os.path.join(OUT, f"preview_{style}_pose.png"), pose=True)

    select_only([arm] + list(parts.values()))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, f"Dragon_{style}.fbx"),
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        mesh_smooth_type="FACE",
        use_armature_deform_only=True,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
    )


if __name__ == "__main__":
    styles = ["Basic", "Chunky", "Serpent", "Spiky", "Hydra"]
    only = [a for a in sys.argv if a in styles]
    for s in only or styles:
        make_style(s)
    print("ok")
