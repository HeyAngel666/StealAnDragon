"""Renderiza a prévia do mapa (JSON exportado por export_map.py) no Blender.

Uso: python tools/preview/render_map.py <map.json> <pasta_saida>
"""
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector

src, outdir = sys.argv[-2], sys.argv[-1]
parts = json.load(open(src))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# malhas base
bpy.ops.mesh.primitive_cube_add(size=1)
cube = bpy.context.active_object.data
bpy.data.objects.remove(bpy.context.active_object)
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1, rotation=(0, math.pi / 2, 0))
cyl_obj = bpy.context.active_object
bpy.ops.object.transform_apply(rotation=True)
cyl = cyl_obj.data
bpy.data.objects.remove(cyl_obj)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.5)
sph = bpy.context.active_object.data
bpy.data.objects.remove(bpy.context.active_object)
for m in (cyl, sph):
    for p in m.polygons:
        p.use_smooth = True


def make_mat(name, kind):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    info = nt.nodes.new("ShaderNodeObjectInfo")
    nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    if kind == "neon":
        nt.links.new(info.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 2.5
    if kind == "glass":
        bsdf.inputs["Alpha"].default_value = 0.35
        bsdf.inputs["Roughness"].default_value = 0.05
    return mat


MATS = {"solid": make_mat("Solid", "solid"), "neon": make_mat("Neon", "neon"), "glass": make_mat("Glass", "glass")}

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox (Y em cima) -> Blender (Z em cima)
coll = scene.collection
for p in parts:
    if p["transparency"] >= 0.95:
        continue
    shape = p["shape"]
    sx, sy, sz = p["size"]
    if shape == "Cylinder":
        data, scale = cyl, (sx, min(sy, sz), min(sy, sz))
    elif shape == "Ball":
        d = min(sx, sy, sz)
        data, scale = sph, (d, d, d)
    else:
        data, scale = cube, (sx, sy, sz)
    obj = bpy.data.objects.new(p["name"], data)
    R = Matrix((p["rot"][0:3], p["rot"][3:6], p["rot"][6:9]))
    Rb = C @ R @ C.transposed()
    pos = C @ Vector(p["pos"])
    # escala no espaço local do Roblox (X, Y, Z) -> eixos locais convertidos
    S = Matrix.Diagonal((scale[0], scale[1], scale[2]))
    local = C @ S @ C.transposed()
    M = Rb @ local
    obj.matrix_world = Matrix.Translation(pos) @ M.to_4x4()
    r, g, b = p["color"]
    obj.color = (r, g, b, 1)
    kind = "neon" if p["material"] == "Neon" else ("glass" if p["transparency"] > 0.2 else "solid")
    obj.data = data
    obj.active_material = None
    coll.objects.link(obj)
    obj.material_slots  # noqa
    if not obj.data.materials:
        pass
    obj.material_slots
    mod_mat = MATS[kind]
    # material por objeto (link no objeto, não na malha)
    if len(obj.material_slots) == 0:
        obj.data.materials.append(None)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = mod_mat

# céu e sol
world = bpy.data.worlds.new("Sky")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.45, 0.7, 1.0, 1)
bg.inputs[1].default_value = 1.0
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4
sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
coll.objects.link(sun)

scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.device = "CPU"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720


def shot(name, loc, target, lens=28):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_end = 3000
    coll.objects.link(cam)
    cam.location = C @ Vector(loc)
    direction = (C @ Vector(target)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = f"{outdir}/{name}.png"
    bpy.ops.render.render(write_still=True)


# vistas (coordenadas do Roblox)
shot("map_overview", (-260, 140, 200), (20, 0, 0), 24)
shot("map_lane", (-120, 14, 0), (60, 4, 0), 30)
shot("map_base_front", (-40, 22, 10), (-40, 10, 72), 26)
shot("map_base_inside", (-40, 30, 98), (-40, 6, 60), 22)
print("ok")
