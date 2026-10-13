"""Baddies Dragão: 3 personagens estilizadas (corpo feminino quase realista, roupa completa),
com rosto anime pintado, cabelo em camadas, chifres, asas e cauda de dragão.

Uso:  python tools/blender/make_baddies.py
Saída: assets/baddies/ (rostos .png, renders e cartões de prévia)
"""

import importlib.util
import math
import os
import random

import bpy  # noqa: E402  (precisa vir antes de bmesh/mathutils)
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("make_ancient_dragon", os.path.join(HERE, "make_ancient_dragon.py"))
ad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ad)
md = ad.md

OUT = os.path.join(HERE, "..", "..", "assets", "baddies")
FONT = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"


def lin(c):
    """sRGB 0-255 -> linear 0-1 (para o Blender)."""
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


# ------------------------------------------------------------------ personagens

BADDIES = [
    {
        "id": "Brasa", "name": "Baddie Brasa", "rarity": "Lendário", "rarity_color": (255, 190, 40),
        "skin": (226, 172, 136), "shadow": (230, 110, 40), "brow": (40, 24, 20), "lips": (196, 90, 80), "iris": ((255, 196, 60), (214, 70, 0)), "scales": (235, 110, 40),
        "hair": [(0.0, (22, 16, 16)), (0.65, (34, 20, 18)), (1.0, (230, 70, 20))],
        "horn": [(0.0, (120, 30, 10)), (0.7, (230, 90, 30)), (1.0, (255, 210, 120))],
        "wing": (205, 60, 25), "wing_bone": (110, 25, 10), "tail": (215, 75, 30), "tail_tip": (60, 20, 15),
        "outfit": "hoodie",
    },
    {
        "id": "Glacial", "name": "Baddie Glacial", "rarity": "Mítico", "rarity_color": (255, 70, 90),
        "skin": (250, 222, 206), "shadow": (120, 190, 255), "brow": (200, 205, 220), "lips": (230, 140, 160), "iris": ((170, 240, 255), (30, 110, 220)), "scales": (120, 200, 250),
        "hair": [(0.0, (238, 240, 250)), (0.6, (215, 230, 250)), (1.0, (110, 190, 255))],
        "horn": [(0.0, (150, 210, 255)), (0.6, (200, 240, 255)), (1.0, (255, 255, 255))],
        "wing": (150, 205, 245), "wing_bone": (235, 245, 255), "tail": (140, 200, 240), "tail_tip": (220, 245, 255),
        "outfit": "puffer",
    },
    {
        "id": "Sombria", "name": "Baddie Sombria", "rarity": "Secreto", "rarity_color": (20, 20, 20),
        "skin": (246, 216, 204), "shadow": (120, 20, 60), "brow": (20, 14, 18), "lips": (150, 20, 45), "iris": ((255, 70, 80), (130, 0, 20)), "scales": (150, 20, 40),
        "hair": [(0.0, (14, 12, 16)), (0.7, (24, 18, 28)), (1.0, (120, 20, 50))],
        "horn": [(0.0, (20, 16, 20)), (0.75, (45, 35, 40)), (1.0, (150, 30, 40))],
        "wing": (25, 18, 24), "wing_bone": (10, 8, 10), "tail": (28, 22, 28), "tail_tip": (170, 20, 40),
        "outfit": "goth",
    },
]


# ------------------------------------------------------------------ rosto (pintura 2D projetada de frente na cabeça)
# Mapa: u = x / 0.9 + 0.5 ; v = (z - 5.35) / 0.95  (cabeça centrada em x=0, olhos em z≈5.86)

FACE_S = 1024


def fpx(x, z):
    return ((x / 0.9 + 0.5) * FACE_S, (1 - (z - 5.35) / 0.95) * FACE_S)


def draw_face(b, path):
    S = FACE_S
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    top, bot = b["iris"]
    lash = (28, 16, 20, 255)
    soft = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(soft)
    # blush e sombra nos olhos (suaves)
    for sx in (-1, 1):
        cx, cy = fpx(0.22 * sx, 5.69)
        sd.ellipse((cx - 85, cy - 38, cx + 85, cy + 38), fill=(255, 120, 135, 105))
        ex, ey = fpx(0.17 * sx, 5.9)
        sd.ellipse((ex - 120, ey - 70, ex + 120, ey + 40), fill=b["shadow"] + (110,))
    img.alpha_composite(soft.filter(ImageFilter.GaussianBlur(22)))
    d = ImageDraw.Draw(img)
    # escamas de dragão nas têmporas
    sc = b["scales"] + (255,)
    for sx in (-1, 1):
        for k in range(5):
            x, y = fpx(sx * (0.33 + 0.02 * (k % 2)), 5.98 - k * 0.06)
            d.chord((x - 15, y - 13, x + 15, y + 15), 0, 180, fill=sc, outline=(0, 0, 0, 80), width=2)
    for sx in (-1, 1):
        cx, cy = fpx(0.168 * sx, 5.86)
        w, h = 122, 80
        # branco do olho em formato amendoado
        eye_mask = Image.new("L", (S, S), 0)
        em = ImageDraw.Draw(eye_mask)
        em.ellipse((cx - w, cy - h, cx + w, cy + h), fill=255)
        em.rectangle((cx - w, cy + 30, cx + w, cy + h), fill=0)
        em.ellipse((cx - w + 6, cy - h + 20, cx + w - 6, cy + h - 6), fill=255)
        white = Image.new("RGBA", (S, S), (250, 246, 246, 255))
        img.paste(white, (0, 0), eye_mask)
        # íris com degradê + pupila em fenda
        iris = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        idr = ImageDraw.Draw(iris)
        r = 68
        for k in range(2 * r):
            t = k / (2 * r)
            col = tuple(int(top[i] + (bot[i] - top[i]) * (1 - t)) for i in range(3)) + (255,)
            idr.line((cx - r, cy - r + k + 4, cx + r, cy - r + k + 4), fill=col)
        im = Image.new("L", (S, S), 0)
        ImageDraw.Draw(im).ellipse((cx - r, cy - r + 4, cx + r, cy + r + 4), fill=255)
        im = Image.fromarray(__import__("numpy").minimum(__import__("numpy").array(im), __import__("numpy").array(eye_mask)))
        img.paste(iris, (0, 0), im)
        d = ImageDraw.Draw(img)
        d.ellipse((cx - 12, cy - 54, cx + 12, cy + 58), fill=(15, 5, 10, 255))
        d.ellipse((cx - 30 * sx - 16, cy - 34, cx - 30 * sx + 10, cy - 8), fill=(255, 255, 255, 245))
        d.ellipse((cx + 26 * sx - 7, cy + 22, cx + 26 * sx + 7, cy + 36), fill=(255, 255, 255, 200))
        # delineado grosso com gatinho + cílios
        d.arc((cx - w - 4, cy - h - 2, cx + w + 4, cy + h + 10), 192, 348, fill=lash, width=17)
        ox = cx + sx * (w + 2)
        d.polygon([(ox, cy - 22), (ox + sx * 58, cy - 58), (ox + sx * 8, cy + 4)], fill=lash)
        for k in range(4):
            a = math.radians(225 + k * 18) if sx < 0 else math.radians(315 - k * 18)
            x0, y0 = cx + math.cos(a) * w * 0.98, cy + math.sin(a) * (h + 4)
            d.line((x0, y0, x0 + math.cos(a) * 26, y0 + math.sin(a) * 30), fill=lash, width=6)
        d.arc((cx - w + 14, cy - h + 26, cx + w - 10, cy + h + 2), 28, 152, fill=(90, 50, 55, 230), width=5)
        # sobrancelha
        bx, by = fpx(0.17 * sx, 6.03)
        d.arc((bx - 105, by - 20, bx + 105, by + 80), 200, 340, fill=b["brow"] + (255,), width=13)
    # lábios
    lx, ly = fpx(0, 5.535)
    lip = b["lips"] + (255,)
    d.chord((lx - 62, ly - 18, lx + 62, ly + 34), 0, 180, fill=lip)
    d.chord((lx - 58, ly - 22, lx - 2, ly + 14), 180, 360, fill=lip)
    d.chord((lx + 2, ly - 22, lx + 58, ly + 14), 180, 360, fill=lip)
    d.line((lx - 58, ly + 2, lx + 58, ly + 2), fill=tuple(int(c * 0.55) for c in b["lips"]) + (255,), width=5)
    d.ellipse((lx - 20, ly + 8, lx + 8, ly + 18), fill=(255, 255, 255, 110))
    # presinha de dragão
    d.polygon([(lx + 22, ly + 3), (lx + 36, ly + 3), (lx + 30, ly + 22)], fill=(255, 255, 255, 255))
    img.save(path)


# ------------------------------------------------------------------ peças

def mat(name, color, rough=0.6, emission=0.0, metallic=0.0, sheen=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
    if emission:
        b.inputs["Emission Color"].default_value = lin(color)
        b.inputs["Emission Strength"].default_value = emission
    return m


def give(obj, m):
    obj.data.materials.clear()
    obj.data.materials.append(m)
    return obj


def rbox(name, center, size, m, bevel=0.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = bevel
    bv.segments = 4
    md.apply_modifiers(o)
    md.shade_smooth(o)
    return give(o, m)


def torus(name, center, major, minor, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=center, rotation=rot,
                                     major_segments=32, minor_segments=10)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    md.shade_smooth(o)
    return give(o, m)


def spikes(name, specs, stops):
    stops = [(t, tuple(c / 255 for c in col)) for t, col in stops]
    o = ad.spikes_object(name, specs, lambda t: ad.lerp_color(stops, t))
    return give(o, ad.vcol_material())


def tube(name, pts, m, sides=14):
    o = ad.loft(name, [(s[0], s[1], s[2], s[3], s[4]) for s in ad.catmull(pts, 24)], sides=sides)
    md.shade_smooth(o)
    return give(o, m)


def flame_material():
    """Moletom preto com chamas laranja subindo da barra."""
    m = bpy.data.materials.new("Flames")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.2
    noise.inputs["Detail"].default_value = 3
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    rng_ = nt.nodes.new("ShaderNodeMapRange")
    rng_.inputs["From Min"].default_value = 3.5
    rng_.inputs["From Max"].default_value = 4.55
    rng_.inputs["To Min"].default_value = 0.75
    rng_.inputs["To Max"].default_value = -0.25
    nt.links.new(sep.outputs["Z"], rng_.inputs["Value"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(rng_.outputs["Result"], add.inputs[0])
    nt.links.new(noise.outputs["Fac"], add.inputs[1])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position = 0.0
    el[0].color = lin((18, 16, 18))
    el[1].position = 1.17
    el[1].color = lin((255, 210, 80))
    e = el.new(0.97)
    e.color = lin((235, 90, 20))
    nt.links.new(add.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# ------------------------------------------------------------------ corpo estilizado (silhueta feminina, roupa completa)

def smooth_stations(stations, per=5):
    """Interpola estações (listas de números) com Catmull-Rom em cada valor."""
    out = []
    n = len(stations)
    for i in range(n - 1):
        for k in range(per):
            f = k / per
            p0, p1, p2, p3 = stations[max(i - 1, 0)], stations[i], stations[i + 1], stations[min(i + 2, n - 1)]
            out.append([0.5 * ((2 * b1) + (-a0 + c2) * f + (2 * a0 - 5 * b1 + 4 * c2 - d3) * f * f + (-a0 + 3 * b1 - 3 * c2 + d3) * f ** 3)
                        for a0, b1, c2, d3 in zip(p0, p1, p2, p3)])
    out.append(list(stations[-1]))
    return out


def vloft(name, stations, sides=40, per=5, caps=True, n=2.2, wave=None):
    """Superfície por anéis horizontais. estação = (cx, cy, z, rx, ry_frente, ry_costas).
    wave = (amplitude, frequência) para babados (saia)."""
    st = smooth_stations(stations, per)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for cx, cy, z, rx, ryf, ryb in st:
        ring = []
        for k in range(sides):
            th = k / sides * math.pi * 2
            x, y = ad.superellipse(th, n)
            r = 1.0
            if wave:
                r += wave[0] * math.sin(th * wave[1])
            ry = ryf if y < 0 else ryb
            ring.append(bm.verts.new((cx + x * rx * r, cy + y * ry * r, z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    if caps:
        for ring in (rings[0], rings[-1]):
            c = bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
            for k in range(sides):
                bm.faces.new((ring[k], ring[(k + 1) % sides], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return md.link(bpy.data.objects.new(name, me))


TORSO = [  # (cx, cy, z, rx, ry_frente, ry_costas)
    (0, 0.02, 2.95, 0.5, 0.3, 0.3),
    (0, 0.02, 3.12, 0.66, 0.36, 0.42),
    (0, 0.02, 3.32, 0.78, 0.41, 0.52),     # quadril
    (0, 0.0, 3.55, 0.68, 0.37, 0.4),
    (0, 0.0, 3.82, 0.5, 0.31, 0.3),    # cintura
    (0, 0.0, 4.1, 0.6, 0.35, 0.33),
    (0, -0.02, 4.33, 0.66, 0.44, 0.34),  # busto (moderado)
    (0, 0.0, 4.55, 0.7, 0.38, 0.34),
    (0, 0.02, 4.8, 0.76, 0.3, 0.3),      # ombros
    (0, 0.02, 4.95, 0.5, 0.22, 0.24),
    (0, 0.03, 5.02, 0.2, 0.17, 0.18),
]
NECK = [(0, 0.03, 4.9, 0.19, 0.17, 0.17), (0, 0.04, 5.2, 0.165, 0.15, 0.16), (0, 0.05, 5.5, 0.16, 0.15, 0.16)]
ARM = [  # x positivo; espelhado depois
    (0.62, 0.02, 4.85, 0.2, 0.2, 0.2),
    (0.78, 0.02, 4.68, 0.17, 0.16, 0.16),
    (0.84, 0.03, 4.3, 0.14, 0.13, 0.13),
    (0.89, 0.04, 3.95, 0.11, 0.11, 0.11),   # cotovelo
    (0.94, 0.03, 3.62, 0.115, 0.11, 0.11),
    (0.98, 0.02, 3.32, 0.08, 0.07, 0.07),   # pulso
    (1.0, 0.0, 3.2, 0.09, 0.05, 0.05),      # mão
    (1.01, -0.01, 3.0, 0.085, 0.045, 0.045),
    (1.01, -0.02, 2.86, 0.04, 0.03, 0.03),
]
LEG = [
    (0.34, 0.02, 3.12, 0.3, 0.3, 0.34),
    (0.36, 0.0, 2.8, 0.28, 0.28, 0.3),
    (0.35, 0.0, 2.3, 0.23, 0.23, 0.24),
    (0.32, 0.0, 1.75, 0.16, 0.16, 0.16),    # joelho
    (0.31, 0.01, 1.4, 0.16, 0.15, 0.19),    # panturrilha
    (0.3, 0.01, 0.9, 0.13, 0.12, 0.14),
    (0.29, 0.0, 0.4, 0.09, 0.09, 0.09),     # tornozelo
    (0.29, 0.0, 0.2, 0.09, 0.09, 0.09),
]
HEAD = [
    (0, -0.13, 5.41, 0.08, 0.06, 0.06),    # queixo
    (0, -0.09, 5.48, 0.22, 0.19, 0.2),
    (0, -0.05, 5.6, 0.33, 0.3, 0.32),
    (0, -0.01, 5.72, 0.375, 0.345, 0.39),
    (0, 0.0, 5.88, 0.41, 0.365, 0.44),     # linha dos olhos
    (0, 0.0, 6.06, 0.42, 0.37, 0.46),
    (0, 0.01, 6.24, 0.37, 0.31, 0.41),
    (0, 0.02, 6.37, 0.24, 0.2, 0.27),
    (0, 0.02, 6.44, 0.06, 0.05, 0.07),
]


def mirror(st):
    return [(-s[0],) + tuple(s[1:]) for s in st]


def make_body():
    parts = [vloft("Torso", TORSO), vloft("Neck", NECK, sides=24)]
    for sx in (1, -1):
        parts.append(vloft("Arm", ARM if sx > 0 else mirror(ARM), sides=24))
        parts.append(vloft("Leg", LEG if sx > 0 else mirror(LEG), sides=28))
    body = md.join(parts, "Body")
    rem = body.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = 0.022
    md.apply_modifiers(body)
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 12
    sm.use_only_smooth = True
    md.apply_modifiers(body)
    md.shade_smooth(body)
    return body


def assign(obj, mats, region):
    """Pinta cada face com o material da região (roupa colada no corpo)."""
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.material_index = region(p.center)


def shell(src, name, keep, offset, m, thickness=0.02, ribs=None):
    """Cópia inflada de uma parte do corpo (jaqueta, bota...)."""
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    md.link(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median())], context="FACES")
    bm.normal_update()
    for v in bm.verts:
        extra = 0.0
        if ribs:
            extra = ribs[0] * abs(math.sin(v.co.z * math.pi / ribs[1]))
        v.co += v.normal * (offset + extra)
    bm.to_mesh(o.data)
    bm.free()
    o.modifiers.clear()
    sol = o.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = -1
    md.apply_modifiers(o)
    md.shade_smooth(o)
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


def is_hand(p):
    return abs(p.x) > 0.86 and p.z < 3.3


def on_surface(tree, p, direction, lift=0.03):
    d = Vector(direction).normalized()
    hit = md.surface(tree, p, d)
    return hit + d * lift


def make_head(b, face_path):
    head = vloft("Head", HEAD, sides=64, per=8, n=2.0)
    sub = head.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    md.apply_modifiers(head)
    md.shade_smooth(head)
    # UV projetada de frente; nas costas vai para um canto transparente
    me = head.data
    uv = me.uv_layers.new(name="UV")
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if poly.normal.y > 0.25:
                uv.data[li].uv = (0.002, 0.002)
            else:
                uv.data[li].uv = (co.x / 0.9 + 0.5, (co.z - 5.35) / 0.95)
    m = bpy.data.materials.new("HeadSkin")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Subsurface Weight"].default_value = 0.12
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(face_path)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = lin(b["skin"])
    nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tex.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    give(head, m)
    nose = vloft("Nose", [(0, -0.345, 5.64, 0.032, 0.022, 0.02), (0, -0.352, 5.69, 0.026, 0.024, 0.02), (0, -0.34, 5.78, 0.016, 0.014, 0.02)],
                 sides=16, per=4)
    md.shade_smooth(nose)
    return head, nose


def skin_mat(b):
    m = mat("Skin", b["skin"], 0.5)
    m.node_tree.nodes["Principled BSDF"].inputs["Subsurface Weight"].default_value = 0.12
    return m


# ------------------------------------------------------------------ montagem de uma baddie

def build(b, face_path):
    md.reset_scene()
    rng = random.Random(7)
    skin = skin_mat(b)
    objs = []
    style = b["outfit"]

    body = make_body()
    head, nose = make_head(b, face_path)
    objs += [body, head, give(nose, skin)]
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())

    # ---------------- roupa
    if style == "hoodie":
        top = mat("Turtleneck", (24, 22, 26), 0.75)
        pants = mat("Cargo", (52, 52, 58), 0.85)
        assign(body, [skin, top, pants], lambda p: 0 if is_hand(p) else (1 if p.z > 3.6 else 2))
        # jaqueta bomber aberta com chamas
        jacket = shell(body, "Jacket", lambda p: 3.5 < p.z < 4.97 and not (abs(p.x) > 0.86 and p.z < 3.42)
                       and not (abs(p.x) < 0.13 and p.y < -0.05 and p.z < 4.85), 0.055, flame_material(), 0.025)
        objs.append(jacket)
        objs.append(torus("Waistband", (0, 0.0, 3.52), 0.6, 0.05, mat("Rib", (230, 90, 25), 0.7), scale=(1.12, 0.66, 1)))
        for sx in (1, -1):
            objs.append(torus("Cuff", (0.975 * sx, 0.02, 3.4), 0.11, 0.035, mat("Rib2", (230, 90, 25), 0.7)))
            pk = on_surface(tree, Vector((0.36 * sx, 0, 2.45)), (sx, 0.05, 0), 0.0)
            objs.append(rbox("Pocket", tuple(pk), (0.08, 0.32, 0.38), pants, 0.03))
            objs.append(rbox("Sneaker", (0.29 * sx, -0.13, 0.16), (0.3, 0.62, 0.3), mat("Sneaker", (240, 95, 30), 0.45), 0.12))
            objs.append(rbox("Sole", (0.29 * sx, -0.13, 0.04), (0.32, 0.66, 0.09), mat("Sole", (245, 245, 245), 0.5), 0.04))
        gold = mat("Gold", (255, 200, 80), 0.25, metallic=1.0)
        for k in range(17):  # corrente de ouro sobre o peito
            t = k / 16
            guide = Vector((-0.2 + 0.4 * t, 0, 4.95 - 0.4 * math.sin(t * math.pi)))
            p = on_surface(tree, guide, (0, -1, 0.15), 0.035)
            objs.append(torus("Link", tuple(p), 0.028, 0.01, gold, rot=(math.pi / 2, (k % 2) * math.pi / 2, 0)))
        objs.append(spikes("Pendant", [(on_surface(tree, Vector((0, 0, 4.55)), (0, -1, 0.1), 0.03), Vector((0, -0.1, -1)), 0.18, 0.05,
                                        Vector((0, 0, 0)), 6, 3, 0.0, 1.0)], [(0, (255, 200, 80)), (1, (255, 235, 160))]))
        for sx in (1, -1):
            objs.append(torus("Hoop", (0.43 * sx, -0.02, 5.6), 0.09, 0.012, gold, rot=(0, math.pi / 2, 0)))
    elif style == "puffer":
        top = mat("Knit", (244, 244, 250), 0.85)
        jeans = mat("Jeans", (105, 140, 200), 0.8)
        assign(body, [skin, top, jeans], lambda p: 0 if is_hand(p) else (1 if p.z > 3.58 else 2))
        puff = mat("Puffer", (170, 215, 250), 0.3, sheen=0.4)
        objs.append(shell(body, "Puffer", lambda p: 3.72 < p.z < 4.96 and not (abs(p.x) > 0.86 and p.z < 3.45), 0.05, puff, 0.03,
                          ribs=(0.035, 0.28)))
        fur = mat("Fur", (252, 252, 255), 0.95, sheen=1.0)
        objs.append(torus("Collar", (0, 0.03, 4.98), 0.3, 0.1, fur, scale=(1.45, 1.15, 0.8)))
        for sx in (1, -1):
            objs.append(torus("CuffFur", (0.975 * sx, 0.02, 3.45), 0.13, 0.05, fur))
            boot = shell(body, "Boot", lambda p, sx=sx: p.z < 1.25 and p.x * sx > 0, 0.03, mat("Boot", (255, 255, 255), 0.9, sheen=0.8), 0.02)
            objs.append(boot)
            objs.append(rbox("BootFoot", (0.29 * sx, -0.12, 0.15), (0.34, 0.6, 0.3), mat("BootF", (250, 250, 255), 0.9, sheen=0.8), 0.13))
            objs.append(torus("BootFur", (0.3 * sx, 0.01, 1.24), 0.17, 0.07, fur, scale=(1.05, 1.1, 1)))
        flake = [(Vector((-0.3, -0.36, 6.18)), Vector((math.cos(a), -0.2, math.sin(a))), 0.09, 0.018, Vector((0, 0, 0)), 5, 2, 0.0, 1.0)
                 for a in [i * math.pi / 3 for i in range(6)]]
        objs.append(spikes("Snowflake", flake, [(0, (200, 240, 255)), (1, (255, 255, 255))]))
        for sx in (1, -1):
            objs.append(spikes("Earring", [(Vector((0.43 * sx, -0.02, 5.6)), Vector((0, 0, -1)), 0.2, 0.035, Vector((0, 0, 0)), 5, 2, 0.0, 1.0)],
                               [(0, (190, 235, 255)), (1, (255, 255, 255))]))
    else:  # goth
        dress = mat("Dress", (24, 20, 26), 0.5, sheen=0.3)
        tights = mat("Tights", (40, 34, 46), 0.65)
        red = mat("Red", (190, 20, 40), 0.4)
        silver = mat("Silver", (215, 215, 225), 0.2, metallic=1.0)
        gold = mat("Gold", (255, 200, 80), 0.25, metallic=1.0)
        assign(body, [skin, dress, tights], lambda p: 0 if (is_hand(p) or p.z > 4.97) else (1 if p.z > 3.6 else 2))
        skirt = vloft("Skirt", [(0, 0.0, 3.82, 0.56, 0.35, 0.34), (0, 0.0, 3.5, 0.78, 0.48, 0.56), (0, 0.0, 3.0, 0.98, 0.66, 0.74),
                                (0, 0.0, 2.45, 1.1, 0.8, 0.86)], sides=64, caps=False, wave=(0.045, 14))
        sol = skirt.modifiers.new("Solid", "SOLIDIFY")
        sol.thickness = 0.03
        md.apply_modifiers(skirt)
        md.shade_smooth(skirt)
        objs.append(give(skirt, dress))
        objs.append(torus("Hem", (0, 0.0, 2.47), 1.08, 0.035, red, scale=(1, 0.77, 1)))
        objs.append(torus("Belt", (0, 0.0, 3.8), 0.56, 0.04, red, scale=(1, 0.62, 1)))
        for k in range(13):  # corrente prateada caindo pelo quadril
            t = k / 12
            p = Vector((-0.62 + 1.1 * t, -0.55 - 0.1 * math.sin(t * math.pi), 3.72 - 0.28 * math.sin(t * math.pi)))
            objs.append(torus("Link", tuple(p), 0.04, 0.013, silver, rot=(math.pi / 2, (k % 2) * math.pi / 2, 0)))
        objs.append(torus("Choker", (0, 0.04, 5.15), 0.165, 0.03, red, scale=(1.05, 1.0, 1)))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0, -0.13, 5.08))
        gem = bpy.context.active_object
        gem.scale = (1, 0.6, 1.3)
        md.shade_smooth(gem)
        objs.append(give(gem, mat("Gem", (255, 30, 60), 0.1, emission=0.6)))
        objs.append(torus("Neckline", (0, 0.02, 4.95), 0.36, 0.035, red, scale=(1.35, 0.75, 1)))
        for sx in (1, -1):
            objs.append(torus("Ruffle", (0.975 * sx, 0.02, 3.36), 0.12, 0.04, red))
            boot = shell(body, "Boot", lambda p, sx=sx: p.z < 1.95 and p.x * sx > 0, 0.03, mat("Boot", (16, 14, 16), 0.25), 0.02)
            objs.append(boot)
            objs.append(rbox("BootFoot", (0.29 * sx, -0.1, 0.2), (0.3, 0.58, 0.28), mat("BootF", (16, 14, 16), 0.25), 0.12))
            objs.append(rbox("Platform", (0.29 * sx, -0.1, 0.05), (0.33, 0.62, 0.12), red, 0.04))
            for zz in (0.75, 1.15, 1.55):
                objs.append(rbox("Strap", (0.3 * sx, -0.17, zz), (0.2, 0.04, 0.05), silver, 0.015))
        for sx in (1, -1):
            objs.append(torus("HornRing", (0.29 * sx, 0.0, 6.62), 0.08, 0.025, gold, rot=(0.1, 0.5 * sx, 0)))
        crown = [(Vector((-0.14 + 0.07 * k, -0.18, 6.36)), Vector((0, -0.1, 1)), 0.11 + (0.05 if k == 2 else 0), 0.028, Vector((0, 0, 0)), 5, 2, 0.0, 1.0)
                 for k in range(5)]
        objs.append(spikes("Crown", crown, [(0, (255, 200, 80)), (1, (255, 240, 170))]))
        objs.append(torus("CrownBand", (0, -0.18, 6.36), 0.16, 0.02, gold, rot=(math.pi / 2, 0, 0), scale=(1, 1, 0.3)))

    # ---------------- cabelo
    hair_root = mat("HairRoot", b["hair"][0][1], 0.4, sheen=0.3)
    cap = head.copy()
    cap.data = head.data.copy()
    cap.name = "HairCap"
    md.link(cap)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    for v in bm.verts:
        v.co = Vector((v.co.x * 1.07, (v.co.y - 0.01) * 1.07 + 0.01, (v.co.z - 5.9) * 1.06 + 5.92))
    kill = [v for v in bm.verts if (v.co.z < 5.5) or (v.co.y < 0.06 and v.co.z < 6.12 and not (abs(v.co.x) > 0.4 and v.co.z > 5.7))]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(cap.data)
    bm.free()
    objs.append(give(cap, hair_root))

    strands = []
    for layer, (count, z0, length, rad, flick_k) in enumerate(((27, 6.12, 2.45, 0.16, 0.05), (19, 6.2, 1.0, 0.18, 0.1))):
        for k in range(count):
            a = math.radians(-115 + 230 * k / (count - 1)) + rng.uniform(-0.03, 0.03)
            outward = Vector((math.sin(a), math.cos(a), 0))
            base = Vector((0.4 * math.sin(a), 0.03 + 0.44 * math.cos(a), z0))
            ln = length * (0.8 if abs(a) > math.radians(95) else 1.0) * rng.uniform(0.92, 1.06)
            dirn = Vector((outward.x * 0.16, outward.y * 0.2, -1))
            flick = outward * flick_k + Vector((0, 0, 0.03))
            strands.append((base, dirn, ln, rad, flick, 8, 14, 0.0, 0.25, outward))
    for sx in (1, -1):  # mechas da frente sobre o peito
        for k, x in enumerate((0.38, 0.3)):
            base = Vector((x * sx, -0.26, 6.08))
            strands.append((base, Vector((0.06 * sx, -0.22, -1)), 1.55 - k * 0.3, 0.12, Vector((0.05 * sx, -0.12, 0.05)), 8, 14, 0.0, 0.3,
                            Vector((sx, -0.4, 0))))
    # risca no meio: mechas saem da risca e descem pelos lados da cabeça (franja cortina na frente)
    for k in range(10):
        t = k / 9
        y = -0.3 + 0.62 * t
        z = 6.4 + 0.05 * math.sin(t * math.pi)
        for sx in (1, -1):
            base = Vector((0.02 * sx, y, z))
            if t < 0.2:
                dirn, ln, bend = Vector((0.7 * sx, -0.45, -0.75)), 0.62, Vector((0.08 * sx, -0.06, -0.12))
            else:
                dirn, ln, bend = Vector((1.0 * sx, 0.1 * t, -0.25)), 0.62, Vector((0.05 * sx, 0, -0.38))
            strands.append((base, dirn, ln * rng.uniform(0.95, 1.08), 0.13, bend, 8, 10, 0.0, 0.3, Vector((0.5 * sx, -0.2 if t < 0.2 else 0, 1))))
    objs.append(spikes("Hair", strands, b["hair"]))

    # ---------------- chifres e barbatanas
    horns, fins = [], []
    for sx in (1, -1):
        base = Vector((0.2 * sx, 0.0, 6.33))
        if style == "goth":
            horns.append((base, Vector((0.45 * sx, 0.1, 1)), 0.95, 0.1, Vector((0.6 * sx, 0.25, -0.45)), 10, 16, 0.06, 1.0))
        elif style == "puffer":
            horns.append((base, Vector((0.25 * sx, 0.15, 1)), 0.62, 0.09, Vector((0.05 * sx, 0.06, 0)), 5, 3, 0.0, 1.0))
            horns.append((base + Vector((0.08 * sx, 0.07, -0.03)), Vector((0.7 * sx, 0.3, 1)), 0.32, 0.055, Vector((0, 0, 0)), 5, 2, 0.0, 1.0))
        else:
            horns.append((base, Vector((0.3 * sx, 0.3, 1)), 0.58, 0.085, Vector((0.15 * sx, 0.22, -0.06)), 9, 12, 0.07, 1.0))
        fins.append((Vector((0.43 * sx, 0.08, 5.86)), Vector((1.0 * sx, 0.7, 0.4)), 0.36, 0.12, Vector((0.03 * sx, 0.1, 0.08)), 8, 6, 0.0, 0.2,
                     Vector((0, 0, 1))))
    objs.append(spikes("Horns", horns, b["horn"]))
    objs.append(spikes("Fins", fins, b["horn"]))

    # ---------------- asas
    wm = mat("Wing", b["wing"], 0.55)
    for sx in (1, -1):
        root = Vector((0.18 * sx, 0.38, 4.55))
        arm = Vector((1.05 * sx, 0.85, 5.35))
        tips = [Vector((2.05 * sx, 1.05, 5.1)), Vector((1.9 * sx, 1.1, 4.25)), Vector((1.2 * sx, 0.95, 3.7))]
        seq = [arm] + tips + [Vector((0.3 * sx, 0.45, 3.95))]
        outline = [root, arm]
        for a_, b_ in zip(seq[1:], seq[2:]):
            outline.append(a_)
            outline.append(((a_ + b_) / 2).lerp(arm, 0.18))
        outline.append(seq[-1])
        me = bpy.data.meshes.new("Wing")
        me.from_pydata([tuple(p) for p in outline], [], [list(range(len(outline)))])
        w = md.link(bpy.data.objects.new("Wing", me))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()
        sol = w.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = 0.03
        md.apply_modifiers(w)
        objs.append(give(w, wm))
        bones = [(root, arm - root, (arm - root).length, 0.05, Vector((0, 0, 0)), 7, 3, 0.0, 1.0)]
        for t in tips:
            bones.append((arm, t - arm, (t - arm).length, 0.032, Vector((0, 0, 0)), 6, 3, 0.0, 1.0))
        bones.append((arm, Vector((0.2 * sx, -0.2, 1)), 0.22, 0.045, Vector((0, -0.04, 0)), 6, 3, 0.0, 1.0))
        objs.append(spikes("WingBones", bones, [(0, b["wing_bone"]), (1, b["wing_bone"])]))

    # ---------------- cauda
    tm = mat("Tail", b["tail"], 0.5)
    pts = [((0, 0.38, 3.4), 0.13, 0.12, 2, None), ((0.05, 0.95, 2.85), 0.11, 0.1, 2, None),
           ((0.35, 1.45, 2.15), 0.085, 0.08, 2, None), ((0.8, 1.7, 1.65), 0.06, 0.06, 2, None),
           ((1.2, 1.65, 1.75), 0.03, 0.03, 2, None)]
    objs.append(tube("Tail", pts, tm))
    tip = Vector(pts[-1][0])
    tail_sp = [(tip - Vector((0.03, 0, 0)), Vector((1, -0.2, 0.5)), 0.32, 0.16, Vector((0, 0, 0)), 4 if style == "puffer" else 8, 4, 0.0,
                1.0 if style == "puffer" else 0.3, Vector((0, 1, 0)))]
    path = ad.catmull(pts, 24)
    for k in range(5):
        c = path[int((0.15 + k * 0.17) * 23)][0]
        tail_sp.append((c + Vector((0, 0, 0.06)), Vector((0, 0.6, 1)), 0.15 - k * 0.018, 0.045, Vector((0, 0.05, 0)), 6, 3, 0.0, 0.4,
                        Vector((1, 0, 0))))
    objs.append(spikes("TailSpikes", tail_sp, [(0, b["tail_tip"]), (1, b["tail_tip"])]))
    return objs


# ------------------------------------------------------------------ render e cartões

def render(path, cam_loc, target, lens=50, size=(720, 960)):
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = size
    if not scene.world:
        world = bpy.data.worlds.new("W")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.55, 1)
        scene.world = world
    if "Key" not in bpy.data.objects:
        for name, energy, rot in (("Key", 3.2, (50, 0, -30)), ("Rim", 2.5, (60, 0, 160)), ("Fill", 0.8, (75, 0, 60))):
            light = md.link(bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN")))
            light.data.energy = energy
            light.rotation_euler = tuple(math.radians(v) for v in rot)
    cam = bpy.data.objects.get("Cam") or md.link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    cam.data.lens = lens
    cam.location = cam_loc
    cam.rotation_euler = (Vector(target) - Vector(cam_loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def text(d, xy, txt, size, fill, stroke=(0, 0, 0), anchor="mm"):
    font = ImageFont.truetype(FONT, size)
    d.text(xy, txt, font=font, fill=fill, stroke_width=max(3, size // 9), stroke_fill=stroke, anchor=anchor)


def make_card(b, render_path, out_path):
    W, H = 720, 1140
    rc = b["rarity_color"]
    card = Image.new("RGBA", (W, H), (40, 40, 44, 255))
    d = ImageDraw.Draw(card)
    # fundo quadriculado escuro (como os cartões dos jogos de roubar)
    for y in range(0, H, 48):
        for x in range(0, W, 48):
            if (x // 48 + y // 48) % 2:
                d.rectangle((x, y, x + 47, y + 47), fill=(48, 48, 53, 255))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gc = rc if b["rarity"] != "Secreto" else (200, 20, 40)
    ImageDraw.Draw(glow).ellipse((60, 120, W - 60, H - 200), fill=gc + (110,))
    card.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
    char = Image.open(render_path).convert("RGBA")
    card.alpha_composite(char, (0, -10))
    d = ImageDraw.Draw(card)
    # faixa do nome
    band_top = H - 150
    for y in range(band_top, H):
        t = (y - band_top) / 150
        if b["rarity"] == "Secreto":
            col = (int(150 * (1 - t) + 20 * t), 0, int(20 * (1 - t)))
        else:
            col = tuple(int(c * (1 - 0.35 * t)) for c in rc)
        d.line((0, y, W, y), fill=col + (255,))
    d.line((0, band_top, W, band_top), fill=(255, 255, 255, 255), width=4)
    text(d, (W // 2, band_top + 78), b["name"], 64, (255, 255, 255))
    label_col = (255, 60, 70) if b["rarity"] == "Secreto" else (255, 255, 255)
    text(d, (W // 2, band_top - 50), b["rarity"], 58, label_col)
    card.convert("RGB").save(out_path)


def main():
    os.makedirs(OUT, exist_ok=True)
    cards = []
    backs = []
    for b in BADDIES:
        face = os.path.abspath(os.path.join(OUT, f"face_{b['id']}.png"))
        draw_face(b, face)
        build(b, face)
        front = os.path.abspath(os.path.join(OUT, f"render_{b['id']}.png"))
        back = os.path.abspath(os.path.join(OUT, f"render_{b['id']}_costas.png"))
        render(front, (-2.6, -10.5, 4.3), (0, 0, 3.3), lens=46)
        render(back, (6.5, 9.5, 5.2), (0.3, 0.5, 3.5), lens=44)
        render(os.path.abspath(os.path.join(OUT, f"render_{b['id']}_rosto.png")), (-0.6, -4.2, 5.95), (0, 0, 5.75), lens=60, size=(720, 720))
        card = os.path.join(OUT, f"card_{b['id']}.png")
        make_card(b, front, card)
        cards.append(card)
        backs.append(back)
    # junta os 3 cartões numa imagem só
    imgs = [Image.open(c) for c in cards]
    sheet = Image.new("RGB", (sum(i.width for i in imgs) + 40 * 4, imgs[0].height + 80), (20, 20, 24))
    x = 40
    for im in imgs:
        sheet.paste(im, (x, 40))
        x += im.width + 40
    sheet.save(os.path.join(OUT, "baddies_cartoes.png"))
    bimgs = [Image.open(p).convert("RGBA") for p in backs]
    bsheet = Image.new("RGBA", (sum(i.width for i in bimgs), bimgs[0].height), (45, 45, 50, 255))
    x = 0
    for im in bimgs:
        bsheet.alpha_composite(im, (x, 0))
        x += im.width
    bsheet.convert("RGB").save(os.path.join(OUT, "baddies_costas.png"))
    print("ok")


if __name__ == "__main__":
    main()
