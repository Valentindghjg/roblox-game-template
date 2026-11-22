"""Exports an art .blend to FBX plus a report.json.

Run: blender -b --factory-startup <blend> --python tools/art/blender_export.py -- --fbx <path> --report <path>

Exit codes: 3 ART_BAD_NAME, 4 ART_BAD_COLLIDER, 5 ART_NO_MESH, 2 usage.
Report coordinates are Roblox axes in studs: Xr = -Xb, Yr = Zb, Zr = Yb.
"""

import json
import re
import sys

import bpy

MESH_NAME = re.compile(r"^[A-Z][A-Za-z0-9]*__[A-Z][A-Za-z0-9]*$")
COLLIDER_NAME = re.compile(r"^COL_[A-Z][A-Za-z0-9]*$")
ATTACHMENT_NAME = re.compile(r"^ATT_[A-Z][A-Za-z0-9]*$")
ROTATION_EPSILON = 1e-4


def fail(code, detail, exit_code):
    print("%s %s" % (code, detail))
    sys.exit(exit_code)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    values = {}
    index = 0
    while index < len(argv):
        if argv[index] in ("--fbx", "--report") and index + 1 < len(argv):
            values[argv[index]] = argv[index + 1]
            index += 2
        else:
            index += 1
    if "--fbx" not in values or "--report" not in values:
        print("ART_USAGE blender_export.py -- --fbx <path> --report <path>")
        sys.exit(2)
    return values["--fbx"], values["--report"]


def to_roblox(vector):
    return (-vector.x, vector.z, vector.y)


def rounded(values):
    # "+ 0.0" turns a negative zero into 0.0 so the JSON stays tidy.
    return [round(float(value), 5) + 0.0 for value in values]


def world_bounds(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        triangles = sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)
        points = [to_roblox(evaluated.matrix_world @ vertex.co) for vertex in mesh.vertices]
    finally:
        evaluated.to_mesh_clear()
    if not points:
        return None
    low = [min(point[axis] for point in points) for axis in range(3)]
    high = [max(point[axis] for point in points) for axis in range(3)]
    return low, high, triangles


def is_unrotated(obj):
    rotation = obj.matrix_world.to_quaternion()
    return (
        abs(rotation.w - 1.0) < ROTATION_EPSILON
        and abs(rotation.x) < ROTATION_EPSILON
        and abs(rotation.y) < ROTATION_EPSILON
        and abs(rotation.z) < ROTATION_EPSILON
    )


def main():
    fbx_path, report_path = parse_args()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    export_meshes = []
    colliders = []
    attachments = []
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            if MESH_NAME.match(obj.name):
                export_meshes.append(obj)
            elif COLLIDER_NAME.match(obj.name):
                colliders.append(obj)
            else:
                fail("ART_BAD_NAME", obj.name, 3)
        elif obj.type == "EMPTY" and obj.name.startswith("ATT_"):
            if not ATTACHMENT_NAME.match(obj.name):
                fail("ART_BAD_NAME", obj.name, 3)
            attachments.append(obj)
    for obj in colliders:
        if not is_unrotated(obj):
            fail("ART_BAD_COLLIDER", obj.name, 4)
    if not export_meshes:
        fail("ART_NO_MESH", "no mesh object named <Part>__<PaletteKey>", 5)

    objects = []
    total_triangles = 0
    low_all = [float("inf")] * 3
    high_all = [float("-inf")] * 3
    for obj in export_meshes:
        bounds = world_bounds(obj, depsgraph)
        if bounds is None:
            fail("ART_NO_MESH", obj.name + " has no vertices", 5)
        low, high, triangles = bounds
        total_triangles += triangles
        for axis in range(3):
            low_all[axis] = min(low_all[axis], low[axis])
            high_all[axis] = max(high_all[axis], high[axis])
        objects.append(
            {
                "name": obj.name,
                "center": rounded([(low[axis] + high[axis]) / 2 for axis in range(3)]),
                "size": rounded([high[axis] - low[axis] for axis in range(3)]),
                "triangles": triangles,
            }
        )

    collider_entries = []
    for obj in colliders:
        bounds = world_bounds(obj, depsgraph)
        if bounds is None:
            continue
        low, high, _ = bounds
        collider_entries.append(
            {
                "name": obj.name[len("COL_") :],
                "center": rounded([(low[axis] + high[axis]) / 2 for axis in range(3)]),
                "size": rounded([high[axis] - low[axis] for axis in range(3)]),
            }
        )

    attachment_entries = {}
    for obj in attachments:
        attachment_entries[obj.name[len("ATT_") :]] = rounded(to_roblox(obj.matrix_world.translation))

    report = {
        "schemaVersion": 1,
        "blenderVersion": bpy.app.version_string,
        "size": rounded([high_all[axis] - low_all[axis] for axis in range(3)]),
        "bboxMin": rounded(low_all),
        "bboxMax": rounded(high_all),
        "triangles": total_triangles,
        "objects": objects,
        "attachments": attachment_entries,
        "colliders": collider_entries,
    }

    for obj in export_meshes:
        obj.data.name = obj.name
        obj.data.shade_flat()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_meshes[0]
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        apply_unit_scale=True,
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        path_mode="STRIP",
        embed_textures=False,
        add_leaf_bones=False,
        bake_anim=False,
    )
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print("ART_EXPORT_OK %d triangles %d objects" % (total_triangles, len(objects)))


main()
