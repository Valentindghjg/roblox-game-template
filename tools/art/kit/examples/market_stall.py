"""Example build script for the low-poly modeling kit: a small snowy market stall with a fir.

blender -b --factory-startup --python tools/art/kit/examples/market_stall.py -- --out <dir>/model.blend
"""

import sys

sys.path.insert(0, "tools/art/kit")
import lowpoly_kit as K  # noqa: E402


def build():
    K.seed(3)
    # floor and counter
    K.box("Floor", "WoodWarmShade", (8, 5, 0.4), (0, 0, 0.2), bevel=0.06)
    K.planks("Counter", "WoodWarm", 3, (7.6, 0.9, 0.35), (0, -1.9, 1.0), (0, 0, 0.36), jitter=0.15)
    K.box("Counter", "WoodWarmShade", (7.8, 1.1, 0.2), (0, -1.9, 1.75), bevel=0.05)
    # posts, back wall, roof
    for x in (-3.7, 3.7):
        for y in (-2.2, 2.2):
            K.post("Frame", "WoodWarmShade", 4.2, (x, y, 0.4))
    K.planks("Wall", "WoodWarm", 7, (7.4, 0.25, 0.55), (0, 2.2, 0.75), (0, 0, 0.56), jitter=0.12)
    K.gable_roof("Roof", "RoofRed", 7.8, 4.8, 1.8, 4.6)
    K.string_lights((-4.2, -2.9, 4.5), (4.2, -2.9, 4.5), 9, sag=0.5)
    # goods: a small fir beside the stall
    K.fir(5.0, 1.5, loc=(5.6, -0.5, 0.0), tiers=4)
    # pipeline objects
    K.collider("Stall", (8, 5, 4.6), (0, 0, 2.3))
    K.attachment("Checkout1", (0, -3.2, 0))


K.run(build, tier="A")
