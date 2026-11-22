"""Renders two Workbench previews of an art .blend; no upload needed.

Run: blender -b --factory-startup <blend> --python tools/art/blender_render.py -- --out-dir <dir> --colors Key=r,g,b ...

Writes preview_front.png (camera on -Y looking +Y) and preview_34.png (azimuth 45
degrees, elevation 25 degrees). Object colours come from the palette key after "__"
in the object name; colliders and empties are hidden.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

SIZE = 1024
FALLBACK_COLOR = (0.8, 0.8, 0.8, 1.0)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = None
    colors = {}
    index = 0
    while index < len(argv):
        if argv[index] == "--out-dir" and index + 1 < len(argv):
            out_dir = argv[index + 1]
            index += 2
        elif argv[index] == "--colors":
            index += 1
            while index < len(argv) and not argv[index].startswith("--"):
                key, _, triple = argv[index].partition("=")
                parts = triple.split(",")
                if key and len(parts) == 3:
                    colors[key] = tuple(int(part) / 255.0 for part in parts) + (1.0,)
                index += 1
        else:
            index += 1
    if not out_dir:
        print("ART_USAGE blender_render.py -- --out-dir <dir> --colors Key=r,g,b ...")
        sys.exit(2)
    return out_dir, colors


def srgb_to_linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def prepare_objects(colors):
    meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and "__" in obj.name and not obj.name.startswith("COL_"):
            key = obj.name.split("__", 1)[1]
            rgba = colors.get(key, FALLBACK_COLOR)
            obj.color = tuple(srgb_to_linear(channel) for channel in rgba[:3]) + (1.0,)
            meshes.append(obj)
        else:
            obj.hide_render = True
    return meshes


def scene_bounds(meshes):
    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return low, high


def render(camera_object, location, center, extent, path):
    camera_object.location = location
    direction = center - location
    camera_object.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera_object.data.ortho_scale = extent
    scene = bpy.context.scene
    scene.camera = camera_object
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("ART_RENDER_OK " + path)


def main():
    out_dir, colors = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    meshes = prepare_objects(colors)
    if not meshes:
        print("ART_NO_MESH no mesh object named <Part>__<PaletteKey>")
        sys.exit(5)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_object_outline = True
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.62, 0.7, 0.78)

    low, high = scene_bounds(meshes)
    center = (low + high) / 2
    # The bounding-box diagonal keeps the 3/4 view inside the frame.
    extent = (high - low).length * 1.15
    distance = extent * 4
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.type = "ORTHO"
    camera_data.clip_end = distance * 4
    camera_object = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera_object)

    render(
        camera_object,
        center + Vector((0.0, -distance, 0.0)),
        center,
        extent,
        os.path.join(out_dir, "preview_front.png"),
    )
    azimuth = math.radians(45.0)
    elevation = math.radians(25.0)
    offset = Vector(
        (
            math.sin(azimuth) * math.cos(elevation),
            -math.cos(azimuth) * math.cos(elevation),
            math.sin(elevation),
        )
    )
    render(camera_object, center + offset * distance, center, extent, os.path.join(out_dir, "preview_34.png"))


main()
