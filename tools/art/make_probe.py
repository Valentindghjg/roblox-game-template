"""Builds the asset-pipeline probe scene and saves it as a compressed .blend.

Run: blender -b --factory-startup --python tools/art/make_probe.py -- --out <model.blend>

Blender axes, 1 unit = 1 stud, front faces -Y. The Top block is off-centre so a
mirrored import is detectable.
"""

import os
import sys

import bpy


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = None
    index = 0
    while index < len(argv):
        if argv[index] == "--out" and index + 1 < len(argv):
            out = argv[index + 1]
            index += 2
        else:
            index += 1
    if not out:
        print("ART_USAGE make_probe.py -- --out <model.blend>")
        sys.exit(2)
    return out


def add_box(name, size, location):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, scale=size)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def main():
    out = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    add_box("Body__WoodWarm", (4.0, 4.0, 3.0), (0.0, 0.0, 1.5))
    add_box("Nose__RoofRed", (1.0, 1.0, 1.0), (0.0, -2.5, 1.5))
    add_box("Top__SnowWhite", (2.0, 2.0, 0.5), (1.0, 0.0, 3.25))
    add_box("COL_Body", (4.0, 4.0, 3.0), (0.0, 0.0, 1.5))
    attachment = bpy.data.objects.new("ATT_Front", None)
    attachment.location = (0.0, -3.0, 0.0)
    bpy.context.scene.collection.objects.link(attachment)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print("ART_PROBE_OK " + out)


main()
