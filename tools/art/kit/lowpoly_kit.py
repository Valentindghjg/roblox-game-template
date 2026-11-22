"""Low-poly modeling kit for Blender build scripts (skill blender-modeling).

Use it from a build script that runs from the repository root:

    import sys; sys.path.insert(0, "tools/art/kit")
    import lowpoly_kit as K

    def build():
        K.box("Floor", "WoodWarm", (8, 6, 0.4), (0, 0, 0.2), bevel=0.05)
        K.collider("Floor", (8, 6, 0.4), (0, 0, 0.2))

    K.run(build, tier="B")

    blender -b --factory-startup --python assets/art/source/<artPath>/build.py -- --out assets/art/source/<artPath>/model.blend

Contract (docs/MODEL_INTEGRATION.md, "Asset pipeline"): Blender axes, Z up, front = -Y,
1 unit = 1 stud, origin = ground pivot. Every shape belongs to a group `part` and a palette
key from src/shared/ArtPalette.lua; K.run joins all shapes of one palette key into one mesh
named "<FirstPart>__<Key>" (one MeshPart per colour). Colliders stay unrotated boxes.
"""

import math
import os
import random
import re
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

BUDGET = {"A": (4000, 10), "B": (1000, 4)}  # triangles, MeshParts (tools/art/lib/Config.luau)
NAME = re.compile(r"^[A-Z][A-Za-z0-9]*$")
_shapes = []  # (part, key, obj)
_rng = random.Random(7)


# ---------------------------------------------------------------- basics

def seed(value):
    """Fix the randomness (tier jitter, snow) so a rebuild gives the same model."""
    _rng.seed(value)


def _check(part, key):
    if not NAME.match(part) or not NAME.match(key):
        raise ValueError("KIT_BAD_NAME part=%r key=%r (use CamelCase letters and digits)" % (part, key))


def _finish_shape(obj, part, key, loc, rot, bevel, segments=1):
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = False
    _shapes.append((part, key, obj))
    return obj


def _mesh_object(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _primitive(op, **kwargs):
    op(**kwargs)
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def box(part, key, size, loc, rot=(0, 0, 0), bevel=0.0):
    """Box of size (x, y, z) centred on loc. bevel rounds the edges (studs)."""
    _check(part, key)
    obj = _primitive(bpy.ops.mesh.primitive_cube_add, size=1.0, scale=size)
    return _finish_shape(obj, part, key, loc, rot, bevel)


def cylinder(part, key, radius, depth, loc, rot=(0, 0, 0), verts=8, bevel=0.0):
    """Upright cylinder (along Z) centred on loc. 6-8 verts keeps the low-poly look."""
    _check(part, key)
    obj = _primitive(bpy.ops.mesh.primitive_cylinder_add, vertices=verts, radius=radius, depth=depth)
    return _finish_shape(obj, part, key, loc, rot, bevel)


def cone(part, key, radius_bottom, radius_top, depth, loc, rot=(0, 0, 0), verts=8):
    """Cone or frustum along Z centred on loc."""
    _check(part, key)
    obj = _primitive(bpy.ops.mesh.primitive_cone_add, vertices=verts, radius1=radius_bottom,
                     radius2=radius_top, depth=depth)
    return _finish_shape(obj, part, key, loc, rot, 0.0)


def ball(part, key, radius, loc, detail=1):
    """Low-poly ball (icosphere). detail 1 = 80 triangles, 0 = 20."""
    _check(part, key)
    obj = _primitive(bpy.ops.mesh.primitive_ico_sphere_add, subdivisions=max(1, detail), radius=radius)
    return _finish_shape(obj, part, key, loc, (0, 0, 0), 0.0)


def prism(part, key, width, depth, height, loc, rot=(0, 0, 0)):
    """Triangular prism: base width along X, depth along Y, ridge on top (a gable)."""
    _check(part, key)
    w, d = width / 2.0, depth / 2.0
    verts = [(-w, -d, 0), (w, -d, 0), (0, -d, height), (-w, d, 0), (w, d, 0), (0, d, height)]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    obj = _mesh_object(part + "_" + key, verts, faces)
    return _finish_shape(obj, part, key, loc, rot, 0.0)


# ---------------------------------------------------------------- building blocks

def planks(part, key, count, size, start, step, bevel=0.03, jitter=0.0):
    """count boards of size (x, y, z), the first centred on start, each moved by step.
    jitter (studs) varies the length slightly for a hand-built look."""
    for index in range(count):
        sx = size[0] + _rng.uniform(-jitter, jitter)
        loc = tuple(start[a] + step[a] * index for a in range(3))
        box(part, key, (sx, size[1], size[2]), loc, bevel=bevel)


def post(part, key, height, loc, width=0.5, bevel=0.04):
    """Square post standing on loc (loc is its foot)."""
    return box(part, key, (width, width, height), (loc[0], loc[1], loc[2] + height / 2.0), bevel=bevel)


def gable_roof(part, key, width, depth, height, base_z, overhang=0.6, thickness=0.3,
               snow=True, snow_key="SnowWhite", center=(0, 0)):
    """Two roof slabs over a span of width (X) and depth (Y), ridge along Y at base_z + height.
    With snow, a thin snow layer sits on each slab."""
    run = width / 2.0 + overhang  # horizontal reach of one slab from the ridge
    pitch = height / (width / 2.0)
    angle = math.degrees(math.atan(pitch))
    slope = math.hypot(run, run * pitch)
    cx, cy = center
    rad = math.radians(angle)
    for side in (-1, 1):
        # slab centre: halfway down from the ridge, lowered by half its thickness along the normal
        x = cx + side * run / 2.0 - side * math.sin(rad) * thickness / 2.0
        z = base_z + height - run / 2.0 * pitch - math.cos(rad) * thickness / 2.0
        box(part, key, (slope, depth + 2 * overhang, thickness), (x, cy, z), rot=(0, side * angle, 0), bevel=0.04)
        if snow:
            lift = thickness * 0.8
            box("Snow", snow_key, (slope * 0.94, depth + 2 * overhang - 0.25, thickness * 0.7),
                (x + side * math.sin(rad) * lift, cy, z + math.cos(rad) * lift), rot=(0, side * angle, 0), bevel=0.1)


def snow_cap(size, loc, key="SnowWhite"):
    """Soft snow slab lying on a surface; loc is the centre of its bottom face."""
    return box("Snow", key, size, (loc[0], loc[1], loc[2] + size[2] / 2.0), bevel=min(size[2] * 0.45, 0.25))


def fir(height, base_radius, loc=(0, 0, 0), tiers=4, trunk_key="BarkBrown", needle_key="NeedleGreen",
        snow=True, verts=7):
    """Stylised fir: short trunk plus stacked, slightly twisted cones; snow tips on each tier.
    loc is the ground point under the trunk. Triangles: about 60 per tier with snow, plus the trunk."""
    x, y, z = loc
    trunk_h = height * 0.14
    cylinder("Trunk", trunk_key, base_radius * 0.14, trunk_h, (x, y, z + trunk_h / 2.0), verts=6)
    crown = height - trunk_h
    tier_h = crown / tiers * 1.35
    for index in range(tiers):
        t = index / max(1, tiers - 1)
        radius = base_radius * (1.0 - 0.72 * t)
        cz = z + trunk_h + crown * (index / tiers) + tier_h / 2.0
        twist = _rng.uniform(0, 360.0 / verts)
        cone("Needles", needle_key, radius, radius * 0.18, tier_h, (x, y, cz), rot=(0, 0, twist), verts=verts)
        if snow:
            # a snow layer hugging the upper part of the tier (fractions 0.5 to 0.85 of its height)
            def radius_at(f):
                return radius * (1.0 - 0.82 * f) * 1.08
            cone("Snow", "SnowWhite", radius_at(0.5), radius_at(0.85), tier_h * 0.35,
                 (x, y, cz - tier_h / 2.0 + tier_h * 0.675), rot=(0, 0, twist), verts=verts)


def string_lights(start, end, count, sag=0.6, radius=0.14, wire=True):
    """Bulbs (LightWarm, Neon) hanging on a sagging wire between two points."""
    a, b = Vector(start), Vector(end)
    points = []
    for index in range(count):
        t = (index + 0.5) / count
        p = a.lerp(b, t)
        p.z -= sag * 4.0 * t * (1.0 - t)
        points.append(p)
        ball("Lights", "LightWarm", radius, tuple(p), detail=1)
    if wire:
        chain = [a] + points + [b]
        for p, q in zip(chain, chain[1:]):
            mid, d = (p + q) / 2.0, q - p
            if d.length < 1e-4:
                continue
            obj = cylinder("Wire", "MetalDark", 0.03, d.length, tuple(mid), verts=4)
            obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def wheel(radius, width, loc, key="MetalDark", hub_key="StoneGray", axis="X"):
    """Wheel lying on axis X (vehicle side) with a hub; loc is the wheel centre."""
    rot = (0, 90, 0) if axis == "X" else (90, 0, 0)
    cylinder("Wheels", key, radius, width, loc, rot=rot, verts=10, bevel=0.03)
    offset = width / 2.0 + 0.02
    for side in (-1, 1):
        hub = (loc[0] + side * offset, loc[1], loc[2]) if axis == "X" else (loc[0], loc[1] + side * offset, loc[2])
        cylinder("Wheels", hub_key, radius * 0.45, 0.05, hub, rot=rot, verts=8)


def awning(width, depth, loc, stripes=4, key_a="RoofRed", key_b="FabricCream", tilt=18, thickness=0.12):
    """Striped awning sloping down to the front (-Y); loc is the centre of its back edge."""
    stripe_w = width / stripes
    cy = loc[1] - depth / 2.0 * math.cos(math.radians(tilt))
    cz = loc[2] - depth / 2.0 * math.sin(math.radians(tilt))
    for index in range(stripes):
        x = loc[0] - width / 2.0 + stripe_w * (index + 0.5)
        box("Awning", key_a if index % 2 == 0 else key_b, (stripe_w, depth, thickness), (x, cy, cz),
            rot=(-tilt, 0, 0), bevel=0.02)


# ---------------------------------------------------------------- pipeline objects

def collider(name, size, loc):
    """Axis-aligned collision box COL_<name> (never rotated, it is not rendered)."""
    _check(name, "Collider")
    obj = _primitive(bpy.ops.mesh.primitive_cube_add, size=1.0, scale=size)
    obj.name = "COL_" + name
    obj.location = loc
    obj.display_type = "WIRE"
    return obj


def attachment(name, loc):
    """Attachment point ATT_<name> (Trees always need TreeBase at the ground point)."""
    _check(name, "Attachment")
    empty = bpy.data.objects.new("ATT_" + name, None)
    empty.location = loc
    bpy.context.scene.collection.objects.link(empty)
    return empty


# ---------------------------------------------------------------- run

def _out_path():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--out" in argv and argv.index("--out") + 1 < len(argv):
        return argv[argv.index("--out") + 1]
    print("KIT_USAGE blender -b --factory-startup --python <build.py> -- --out <model.blend>")
    sys.exit(2)


def _join_groups(merge):
    groups, names = {}, {}
    for part, key, obj in _shapes:
        group = key if merge == "key" else (part, key)
        groups.setdefault(group, []).append(obj)
        names.setdefault(group, (part, key))  # the first shape of a group names it
    joined = []
    for group, objs in groups.items():
        part, key = names[group]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            for mod in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = obj.data.name = "%s__%s" % (part, key)
        joined.append(obj)
    return joined


def _triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def run(build, tier=None, merge="key"):
    """Clears the scene, calls build(), joins shapes, checks the tier budget, saves the
    compressed .blend given by --out and prints one summary line.
    merge="key" (default) makes one MeshPart per palette colour, named after the first part
    in that colour; merge="part" keeps every (part, key) pair apart (costs more MeshParts)."""
    out = _out_path()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _shapes.clear()
    build()
    meshes = _join_groups(merge)
    triangles = sum(_triangles(obj) for obj in meshes)
    line = "KIT_OK triangles=%d meshparts=%d parts=%s" % (
        triangles, len(meshes), ",".join(obj.name for obj in meshes))
    if tier is not None:
        max_tri, max_parts = BUDGET[tier]
        if triangles > max_tri or len(meshes) > max_parts:
            print("KIT_OVER_BUDGET tier=%s triangles=%d/%d meshparts=%d/%d" % (
                tier, triangles, max_tri, len(meshes), max_parts))
            sys.exit(4)
        line += " tier=%s budget=%d/%d" % (tier, max_tri, max_parts)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print(line + " out=" + out)
