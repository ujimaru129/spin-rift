"""Concept mock of the cyberpunk arena, rendered with Blender (nothing here ships in the game).

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/mock/city.py -- OUT_DIR [samples] [game|wide]

Uses only boxes, cylinders, emissive strips, tiled window textures and signs, so the same city can
be built from Roblox parts. Coordinates are the game's: x along the table, y up, z across.
"""
import bpy, math, os, random, sys
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
OUT = os.path.abspath(args[0])
SAMPLES = int(args[1]) if len(args) > 1 else 64
VIEWS = args[2:] or ["game", "wide"]
rnd = random.Random(11)
CYAN, MAG, PINK, BLUE, VIOLET, ORANGE, RED, WHITE = (0, .78, 1), (1, .02, .62), (1, .12, .4), (.03, .16, 1), (.35, .06, 1), (1, .3, .04), (1, .02, .05), (.85, .92, 1)
HAZE = (.022, .016, .070)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def V(x, y, z):
    return Vector((x, -z, y))


mats = {}


def mat(key, build):
    if key not in mats:
        m = bpy.data.materials.new(str(key))
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        sh = build(nt)
        # distance haze
        cam = nt.nodes.new("ShaderNodeCameraData")
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = -1 / 430
        ex = nt.nodes.new("ShaderNodeMath"); ex.operation = "EXPONENT"
        hz = nt.nodes.new("ShaderNodeEmission"); hz.inputs[0].default_value = (*HAZE, 1)
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(cam.outputs["View Distance"], mul.inputs[0]); nt.links.new(mul.outputs[0], ex.inputs[0])
        nt.links.new(ex.outputs[0], mix.inputs[0]); nt.links.new(hz.outputs[0], mix.inputs[1]); nt.links.new(sh, mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs[0])
        mats[key] = m
    return mats[key]


def neon(c, power=6):
    def b(nt):
        e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*c, 1); e.inputs[1].default_value = power * .42
        return e.outputs[0]
    return mat(("neon", c, power), b)


def solid(c, rough=.5, metal=.0):
    def b(nt):
        p = nt.nodes.new("ShaderNodeBsdfPrincipled")
        p.inputs["Base Color"].default_value = (*c, 1); p.inputs["Roughness"].default_value = rough; p.inputs["Metallic"].default_value = metal
        return p.outputs[0]
    return mat(("solid", c, rough, metal), b)


def windows(c1, c2, lit, seed, cell=(1.0, 1.7), power=1.0):
    """Dark facade with a grid of lit windows (in the game: one tiled texture)."""
    def b(nt):
        N = nt.nodes.new; L = nt.links.new
        tc = N("ShaderNodeTexCoord"); sep = N("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs[0])
        geo = N("ShaderNodeNewGeometry")
        def m(op, a, b2=None):
            n = N("ShaderNodeMath"); n.operation = op
            for i, v in enumerate((a, b2)):
                if v is None: continue
                if isinstance(v, (int, float)): n.inputs[i].default_value = v
                else: L(v, n.inputs[i])
            return n.outputs[0]
        nrm = N("ShaderNodeSeparateXYZ"); L(tc.outputs["Normal"], nrm.inputs[0])
        side = m("GREATER_THAN", m("ABSOLUTE", nrm.outputs[0]), .5)
        u = m("ADD", m("MULTIPLY", sep.outputs[1], side), m("MULTIPLY", sep.outputs[0], m("SUBTRACT", 1, side)))
        u = m("DIVIDE", u, cell[0]); v = m("DIVIDE", sep.outputs[2], cell[1])
        fu, fv = m("FRACT", m("ADD", u, 500)), m("FRACT", m("ADD", v, 500))
        inside = m("MULTIPLY", m("MULTIPLY", m("GREATER_THAN", fu, .14), m("LESS_THAN", fu, .86)), m("MULTIPLY", m("GREATER_THAN", fv, .3), m("LESS_THAN", fv, .8)))
        oi = N("ShaderNodeObjectInfo")
        comb = N("ShaderNodeCombineXYZ"); L(m("FLOOR", u), comb.inputs[0]); L(m("FLOOR", v), comb.inputs[1]); L(m("ADD", m("MULTIPLY", oi.outputs["Random"], 97), m("MULTIPLY", side, 13)), comb.inputs[2])
        wn = N("ShaderNodeTexWhiteNoise"); L(comb.outputs[0], wn.inputs[0])
        # whole floors tend to be lit together
        comb2 = N("ShaderNodeCombineXYZ"); L(m("FLOOR", m("DIVIDE", u, 5)), comb2.inputs[0]); L(m("FLOOR", v), comb2.inputs[1]); L(m("MULTIPLY", oi.outputs["Random"], 31), comb2.inputs[2])
        wn2 = N("ShaderNodeTexWhiteNoise"); L(comb2.outputs[0], wn2.inputs[0])
        on = m("GREATER_THAN", m("ADD", m("MULTIPLY", wn.outputs["Value"], .55), m("MULTIPLY", wn2.outputs["Value"], .45)), 1 - lit)
        up = m("LESS_THAN", m("ABSOLUTE", nrm.outputs[2]), .5)
        s = m("MULTIPLY", m("MULTIPLY", inside, on), up)
        col = N("ShaderNodeMix"); col.data_type = "RGBA"; L(m("GREATER_THAN", wn2.outputs["Value"], .72), col.inputs[0])
        col.inputs[6].default_value = (*c1, 1); col.inputs[7].default_value = (*c2, 1)
        p = N("ShaderNodeBsdfPrincipled"); p.inputs["Base Color"].default_value = (.008, .010, .022, 1); p.inputs["Roughness"].default_value = .28; p.inputs["Metallic"].default_value = .6
        L(col.outputs[2], p.inputs["Emission Color"]); L(m("MULTIPLY", s, m("MULTIPLY", power, m("ADD", .25, wn.outputs["Value"]))), p.inputs["Emission Strength"])
        return p.outputs[0]
    return mat(("win", c1, c2, lit, seed, cell, power), b)


cube = bpy.data.meshes.new("cube")
cube.from_pydata([(x, y, z) for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)], [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])


def box(x, y, z, sx, sy, sz, m, yaw=0, realsize=False):
    """Box at game coordinates; yaw turns it about the vertical."""
    me = cube.copy()
    if realsize:  # keep object-space units for the window shader
        for v in me.vertices:
            v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
    ob = bpy.data.objects.new("b", me)
    ob.location = V(x, y, z)
    if not realsize:
        ob.scale = (sx, sz, sy)
    ob.rotation_euler = (0, 0, yaw)
    ob.data.materials.append(m)
    scene.collection.objects.link(ob)
    return ob


def beam(a, b, w, m, h=None):
    """Box from a to b (game coordinates)."""
    a, b = V(*a), V(*b)
    d = b - a
    ob = bpy.data.objects.new("beam", cube.copy())
    ob.location = (a + b) / 2
    ob.rotation_euler = d.to_track_quat("Y", "Z").to_euler()
    ob.scale = (w, d.length, h or w)
    ob.data.materials.append(m)
    scene.collection.objects.link(ob)
    return ob


def disc(x, y, z, r, h, m, seg=96):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r, depth=h, location=V(x, y, z))
    bpy.context.object.data.materials.append(m)
    return bpy.context.object


def ringmesh(x, y, z, R, r, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=128, minor_segments=8, location=V(x, y, z), rotation=rot)
    bpy.context.object.data.materials.append(m)


FONT = bpy.data.fonts.load("/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf")


def text(s, x, y, z, size, m, yaw):
    cu = bpy.data.curves.new("t", "FONT"); cu.body = s; cu.font = FONT; cu.size = size; cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.extrude = size * .01
    ob = bpy.data.objects.new("t", cu); ob.location = V(x, y, z); ob.rotation_euler = (math.pi / 2, 0, yaw); cu.materials.append(m)
    scene.collection.objects.link(ob)


def face(x, z):
    """Yaw so that an object's front (-Y in Blender) looks at the centre."""
    d = V(0, 0, 0) - V(x, 0, z)
    return math.atan2(d.y, d.x) + math.pi / 2


def off(x, z, yaw, side, fwd):
    """Move sideways / towards the viewer of something with this yaw (game x, z)."""
    c, s = math.cos(yaw), math.sin(yaw)
    bx, by = side * c + fwd * s, side * s - fwd * c
    return x + bx, z - by


WIN = [windows((1, .5, .2), (.2, .6, 1), .33, 1), windows((.08, .35, 1), (.8, .1, .9), .36, 2), windows((1, .15, .5), (.2, .25, 1), .30, 3), windows((.45, .65, 1), (1, .5, .2), .36, 4, (.8, 1.4)), windows((.04, .4, 1), (.1, .8, 1), .46, 5, (1.8, 1.3), 1.5)]
NEON = [CYAN, MAG, BLUE, VIOLET, PINK]
DARK = solid((.012, .014, .026), .35, .7)
SIGNS = ["RIFT", "NOVA-9", "AFTERBURN", "PULSE", "HYPER", "ZERO-G", "ORBITAL", "NEON BAY", "SMASH!", "ARC LIGHT", "VOLT", "QUANTUM"]


def sign(x, y, z, yaw, w, h, c, label):
    box(x, y, z, w + .8, h + .8, .5, DARK, yaw)
    px, pz = off(x, z, yaw, 0, .35)
    box(px, y, pz, w, h, .15, neon(tuple(v * .10 for v in c), 1.6), yaw)
    px, pz = off(x, z, yaw, 0, .55)
    for dy, sx, sy in ((h / 2, w, .25), (-h / 2, w, .25)):
        box(px, y + dy, pz, sx, sy, .2, neon(c, 9), yaw)
    for dx in (-w / 2, w / 2):
        ex, ez = off(px, pz, yaw, dx, 0)
        box(ex, y, ez, .25, h, .2, neon(c, 9), yaw)
    tx, tz = off(x, z, yaw, 0, .7)
    if w >= h:
        text(label, tx, y, tz, min(h * .85, w * 2.6 / max(len(label), 3)), neon(WHITE if sum(c) < 1.6 else c, 7), yaw)
    else:
        n = len(label)
        for i, ch in enumerate(label):
            text(ch, tx, y + h / 2 - (i + .5) * h / n, tz, min(h / n * 1.05, w * 1.1), neon(WHITE if i % 2 == 0 else c, 7), yaw)


def building(x, z, w, d, top, bottom, layer):
    yaw = face(x, z)
    h = top - bottom
    m = rnd.choice(WIN)
    box(x, (top + bottom) / 2, z, w, h, d, m, yaw, True)
    c = rnd.choice(NEON)
    # setback crown
    if rnd.random() < .6:
        h2 = h * rnd.uniform(.12, .3)
        box(x, top + h2 / 2, z, w * .66, h2, d * .66, rnd.choice(WIN), yaw, True)
        box(x, top + .3, z, w + .6, .7, d + .6, neon(c, 4), yaw)
        top += h2
    if rnd.random() < .55:  # antenna
        ah = rnd.uniform(8, 30)
        box(x, top + ah / 2, z, .6, ah, .6, DARK, yaw)
        box(x, top + ah, z, 1, 1, 1, neon(RED, 14), yaw)
    if rnd.random() < .6:  # corner strips
        for s in ((-1, 1) if rnd.random() < .5 else (rnd.choice((-1, 1)),)):
            ex, ez = off(x, z, yaw, s * w / 2, d / 2)
            lo = bottom + h * rnd.uniform(0, .4)
            box(ex, (lo + top) / 2, ez, .55, top - lo, .55, neon(c, 5), yaw)
    for _ in range(rnd.randint(0, 2)):  # bands
        box(x, rnd.uniform(bottom + h * .4, top - 4), z, w + .5, .5, d + .5, neon(rnd.choice(NEON), 4), yaw)
    if layer < 2:
        for _ in range(6):
            ux, uz = off(x, z, yaw, rnd.uniform(-.4, .4) * w, rnd.uniform(-.4, .4) * d)
            hh = rnd.uniform(1, 5)
            box(ux, top + hh / 2, uz, rnd.uniform(1.5, 5), hh, rnd.uniform(1.5, 5), DARK, yaw)
        for _ in range(5):
            lx, lz = off(x, z, yaw, rnd.uniform(-.4, .4) * w, d / 2 + .6)
            ly = rnd.uniform(bottom + h * .5, top - 3)
            box(lx, ly, lz, rnd.uniform(2, 7), rnd.uniform(.6, 2.4), 1, DARK, yaw)
            lx, lz = off(lx, lz, yaw, 0, .6)
            box(lx, ly, lz, rnd.uniform(1.5, 4), .25, .2, neon(rnd.choice(NEON + [ORANGE]), 6), yaw)
    if layer < 2 and rnd.random() < .3:
        sx, sz = off(x, z, yaw, rnd.uniform(-.15, .15) * w, d / 2 + .4)
        if rnd.random() < .5:
            sign(sx, rnd.uniform(max(bottom + 25, -8), max(top - 14, 2)), sz, yaw, w * .75, w * .36, rnd.choice(NEON), rnd.choice(SIGNS))
        else:
            sign(sx, rnd.uniform(max(bottom + 25, 0), max(top - 18, 6)), sz, yaw, 5, 22, rnd.choice(NEON), rnd.choice(SIGNS[:5]))


# ---- city
for layer, (n, r0, r1, t0, t1, w0, w1, bot) in enumerate(((13, 105, 150, -34, 2, 16, 26, -120), (30, 165, 250, -22, 34, 18, 32, -120), (64, 280, 470, -5, 78, 22, 42, -120), (80, 520, 900, 5, 140, 34, 70, -120))):
    for i in range(n):
        a = (i + rnd.uniform(-.35, .35)) / n * math.tau
        r = rnd.uniform(r0, r1)
        x, z = math.cos(a) * r, math.sin(a) * r
        top = t0 + (t1 - t0) * rnd.random() ** 1.5
        if rnd.random() < .12: top *= 1.5
        if x > 0 and abs(z) < 40 and layer < 2: continue  # the canyon the camera looks down stays open
        if x > 0 and abs(z) > r * .62 and layer < 2: top += 26  # taller at the sides, like a frame
        building(x, z, rnd.uniform(w0, w1), rnd.uniform(w0, w1), top, bot, layer)

# landmark: the cross-braced twin tower on the right and the spire straight ahead
for (x, z, w, top, c) in ((235, 92, 46, 130, PINK), (520, -95, 46, 190, CYAN)):
    yaw = face(x, z)
    box(x, (top - 110) / 2, z, w, top + 110, w, WIN[0] if c == PINK else WIN[4], yaw, True)
    for k in range(-60, top - 30, 48):
        for s in (-1, 1):
            p = off(x, z, yaw, -s * w / 2, w / 2 + .8); q = off(x, z, yaw, s * w / 2, w / 2 + .8)
            beam((p[0], k, p[1]), (q[0], k + 48, q[1]), 1.2, neon(c, 5))
    for s in (-1, 1):
        e = off(x, z, yaw, s * w / 2, w / 2)
        box(e[0], (top - 60) / 2, e[1], 1.2, top + 60, 1.2, neon(c, 6), yaw)
    box(x, top + 2, z, w + 2, 2, w + 2, neon(c, 8), yaw)
    for s in (-.25, .25):
        e = off(x, z, yaw, s * w, 0)
        box(e[0], top + 30, e[1], 1, 60, 1, DARK, yaw); box(e[0], top + 60, e[1], 1.8, 1.8, 1.8, neon(RED, 20), yaw)
# holographic rings round the spire
for k, R in ((80, 58), (112, 48), (144, 38)):
    ringmesh(520, k, -95, R, .9, neon(MAG if k == 120 else CYAN, 7), (.12, .08, 0))
# big signs framing the view
for (x, y, z, w, h, c, label) in ((112, 12, -70, 30, 14, MAG, "RIFT CITY"), (120, 4, 78, 28, 12, CYAN, "SPIN DRIVE"), (84, 16, -88, 8, 38, CYAN, "PULSE"), (80, 14, 92, 8, 36, PINK, "SMASH")):
    yw = face(x, z)
    bx, bz = off(x, z, yw, 0, -9)
    box(bx, (y + h / 2 + 6 - 120) / 2, bz, w + 8, y + h / 2 + 6 + 120, 16, WIN[1], yw, True)
    box(bx, y + h / 2 + 6, bz, w + 8.5, .4, 16.5, neon(c, 5), yw)
    sign(x, y, z, yw, w, h, c, label)

# ---- highways: curves of road with glowing rails and light trails
def road(pts, w, c, traffic=True):
    P = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = (Vector(pts[max(0, min(len(pts) - 1, i + k))]) for k in (-1, 0, 1, 2))
        for s in range(14):
            t = s / 14
            P.append(.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    P.append(Vector(pts[-1]))
    wet = solid((.010, .011, .018), .08, .5)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = (b - a).normalized(); n = Vector((-d.z, 0, d.x)).normalized(); e = d * .25
        beam(a - e, b + e, w, wet, 1.2)
        for s in (-1, 1):
            o = n * (s * w / 2)
            beam(a + o + Vector((0, 1.1, 0)) - e, b + o + Vector((0, 1.1, 0)) + e, .35, neon(c, 8))
            beam(a + o + Vector((0, .2, 0)) - e, b + o + Vector((0, .2, 0)) + e, .5, DARK, 2)
        beam(a - e + Vector((0, -1.5, 0)), b + e + Vector((0, -1.5, 0)), w * .5, DARK, 1.8)
        if traffic:
            for lane, col in ((-.28, RED), (-.12, ORANGE), (.12, WHITE), (.28, CYAN)):
                if rnd.random() < .5:
                    o = n * (lane * w) + Vector((0, .95, 0))
                    k = rnd.uniform(.1, .5)
                    beam(a.lerp(b, k) + o, a.lerp(b, k + rnd.uniform(.2, .5)) + o, .22, neon(col, 9), .16)
        if i % 6 == 0:
            q = (a + b) / 2
            box(q.x, (q.y - 110) / 2, q.z, 2.4, q.y + 108, 2.4, DARK)


road([(700, -6, -20), (420, -10, 0), (250, -12, 14), (150, -15, 6), (95, -18, -26), (60, -22, -62), (0, -26, -86), (-90, -30, -90)], 15, CYAN)
road([(420, -22, 150), (260, -22, 96), (150, -24, 40), (92, -30, 16), (62, -34, 34), (44, -38, 70), (0, -42, 104), (-100, -46, 120)], 13, ORANGE)
road([(220, 24, -260), (190, 16, -140), (176, 8, -60), (190, 2, 20), (230, 0, 110), (300, 6, 260)], 12, BLUE)
road([(120, -48, -220), (120, -48, -60), (125, -48, 60), (130, -48, 220)], 16, MAG)
road([(170, -62, -220), (172, -62, 0), (170, -62, 220)], 16, CYAN)

# street level far below: wet, with strips of light
box(300, -110, 0, 1600, 1, 1600, solid((.006, .006, .014), .12, .3))
for i in range(70):
    z = rnd.uniform(-500, 500)
    box(rnd.uniform(-100, 800), -109, z, rnd.uniform(30, 200), .4, .6, neon(rnd.choice(NEON + [ORANGE]), 5))
for i in range(50):
    box(rnd.uniform(40, 700), -109, rnd.uniform(-400, 400), .6, .4, rnd.uniform(30, 200), neon(rnd.choice(NEON + [ORANGE]), 5))

def mist(nt):
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (.10, .03, .22, 1); e.inputs[1].default_value = .55
    t = nt.nodes.new("ShaderNodeBsdfTransparent"); m = nt.nodes.new("ShaderNodeMixShader"); m.inputs[0].default_value = .10
    nt.links.new(t.outputs[0], m.inputs[1]); nt.links.new(e.outputs[0], m.inputs[2])
    return m.outputs[0]
for k in range(5):
    box(300, -95 + k * 13, 0, 1500, .05, 1500, mat("mist", mist))
# flying traffic
for _ in range(60):
    x, z, y = rnd.uniform(60, 420), rnd.uniform(-220, 220), rnd.uniform(-20, 80)
    box(x, y, z, .5, .5, rnd.uniform(1.5, 4), neon(rnd.choice([RED, WHITE, CYAN, ORANGE]), 14))
# embers
for _ in range(800):
    x, z, y = rnd.uniform(-10, 160), rnd.uniform(-80, 80), rnd.uniform(-20, 60)
    if abs(z) < 7 and y < 12 and x < 20: continue
    s = rnd.uniform(.04, .10)
    box(x, y, z, s, s, s * rnd.uniform(1, 3), neon(ORANGE, 16), rnd.uniform(0, 3))

# ---- the arena itself (same shapes as in the game)
disc(0, -.5, 0, 22, 1, solid((.008, .009, .016), .3, .5))
ringmesh(0, -.5, 0, 22.2, .25, neon(CYAN, 8))
ringmesh(0, .06, 0, 20.5, .06, neon(MAG, 4))
disc(0, -3, 0, 16, 4, DARK)
disc(0, -5.2, 0, 5, .6, neon(CYAN, 6))
for s, c in ((-1, CYAN), (1, MAG)):
    disc(s * 14, .03, 0, 4.2, .04, neon(tuple(v * .3 for v in c), 1.4))
    ringmesh(s * 14, .07, 0, 4.2, .08, neon(c, 6))
for k in range(16):
    a = k / 16 * math.tau
    beam((math.cos(a) * 17, .03, math.sin(a) * 17), (math.cos(a) * 20.2, .03, math.sin(a) * 20.2), .12, neon(CYAN if k % 2 else MAG, 3), .05)
box(0, 2.8, 0, 18, .4, 10, solid((.004, .012, .03), .2, .2))
for z in (-4.92, 4.92): box(0, 3.01, z, 18, .05, .15, neon(WHITE, 3))
for x in (-8.92, 8.92): box(x, 3.01, 0, .15, .05, 10, neon(WHITE, 3))
box(0, 3.01, 0, 18, .05, .08, neon(WHITE, 3)); box(0, 4.2, 0, .1, .1, 10.8, neon(WHITE, 3))
box(0, 3.6, 0, .05, 1.1, 10.6, solid((.12, .16, .24), .4))
box(0, 2.55, 0, 18.3, .12, 10.3, neon(CYAN, 8))
for x in (-5, 5): box(x, 1.3, 0, 2.2, 2.6, 3.2, DARK)
# opponent and ball
for (dy, sx, sy, sz, m) in ((1.2, .7, 2.4, 1.9, DARK), (3.3, 1.3, 2, 2.2, DARK), (3.5, 1.5, 1.4, 1.9, solid((.5, .55, .65), .3)), (4.95, 1.2, 1.2, 1.2, solid((.5, .55, .65), .3)), (2.35, 1.5, .18, 2.3, neon(MAG, 8)), (5, 1.3, .3, 1.1, neon(MAG, 8))):
    box(13, dy, 0, sx, sy, sz, m)
bpy.ops.mesh.primitive_uv_sphere_add(radius=.35, location=V(3, 5.6, -1.5)); bpy.context.object.data.materials.append(neon(WHITE, 12))
beam((9, 4.6, -.6), (3, 5.6, -1.5), .18, neon(VIOLET, 8))

# ---- lights, sky
def area(x, y, z, size, e, c):
    l = bpy.data.lights.new("a", "POINT"); l.energy = e; l.color = c; l.shadow_soft_size = size
    o = bpy.data.objects.new("a", l); o.location = V(x, y, z); o.visible_camera = False; o.visible_glossy = False; scene.collection.objects.link(o)
area(-12, 22, -20, 6, 2500, (.2, .6, 1)); area(14, 22, 20, 6, 2500, (1, .15, .7))
for k in range(16):
    area(rnd.uniform(60, 300), rnd.uniform(-70, 40), rnd.uniform(-140, 140), 10, rnd.uniform(4e4, 1.4e5), rnd.choice([(.1, .4, 1), (1, .1, .6), (.4, .1, 1)]))
w = bpy.data.worlds.new("w"); scene.world = w; w.use_nodes = True
nt = w.node_tree; nt.nodes.clear()
N = nt.nodes.new
tc = N("ShaderNodeTexCoord"); sp = N("ShaderNodeSeparateXYZ"); rp = N("ShaderNodeValToRGB"); bg = N("ShaderNodeBackground"); o = N("ShaderNodeOutputWorld")
nz = N("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 4; nz.inputs["Detail"].default_value = 8
mx = N("ShaderNodeMath"); mx.operation = "MULTIPLY_ADD"; mx.inputs[1].default_value = .5; mx.inputs[2].default_value = -.25
ad = N("ShaderNodeMath"); ad.operation = "ADD"
nt.links.new(tc.outputs["Generated"], sp.inputs[0]); nt.links.new(tc.outputs["Generated"], nz.inputs["Vector"])
nt.links.new(nz.outputs[0], mx.inputs[0]); nt.links.new(sp.outputs[2], ad.inputs[0]); nt.links.new(mx.outputs[0], ad.inputs[1]); nt.links.new(ad.outputs[0], rp.inputs[0])
cr = rp.color_ramp; cr.elements[0].position = 0; cr.elements[0].color = (.15, .045, .22, 1); cr.elements[1].position = .42; cr.elements[1].color = (.004, .005, .016, 1)
e = cr.elements.new(.12); e.color = (.045, .022, .12, 1)
e = cr.elements.new(.3); e.color = (.010, .012, .042, 1)
nt.links.new(rp.outputs[0], bg.inputs[0]); nt.links.new(bg.outputs[0], o.inputs[0])

# ---- render
scene.render.engine = "CYCLES"
cy = scene.cycles; cy.samples = SAMPLES; cy.use_denoising = True; cy.max_bounces = 5; cy.transparent_max_bounces = 16; cy.sample_clamp_indirect = 4
try:
    pr = bpy.context.preferences.addons["cycles"].preferences; pr.compute_device_type = "METAL"; pr.get_devices()
    for d in pr.devices: d.use = True
    cy.device = "GPU"
except Exception as ex:
    print("CPU", ex)
scene.view_settings.view_transform = "Raw"
scene.render.image_settings.file_format = "OPEN_EXR"
cam = bpy.data.cameras.new("c"); cam.clip_end = 3000
co = bpy.data.objects.new("c", cam); scene.collection.objects.link(co); scene.camera = co


def shoot(name, eye, focus, fov, rx, ry):
    co.location = V(*eye); co.rotation_euler = (V(*focus) - V(*eye)).to_track_quat("-Z", "Y").to_euler()
    cam.sensor_fit = "VERTICAL"; cam.angle = math.radians(fov)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    p = os.path.join(OUT, name + ".exr"); scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); im.colorspace_settings.name = "Non-Color"
    a = np.empty(rx * ry * 4, "f4"); im.pixels.foreach_get(a); a = a.reshape(ry, rx, 4)[..., :3].astype("f8")
    br = np.clip(a - .55, 0, 8)
    fy = np.fft.fftfreq(ry)[:, None]; fx = np.fft.rfftfreq(rx)[None]
    glow = np.zeros_like(a)
    for s, g in ((3, .25), (10, .16), (32, .10), (100, .10)):
        k = np.exp(-2 * (np.pi * s) ** 2 * (fx**2 + fy**2))
        for c in range(3):
            glow[..., c] += g * np.fft.irfft2(np.fft.rfft2(br[..., c]) * k, (ry, rx))
    a = (a + np.clip(glow, 0, None)) * 1.0
    a = a * (2.51 * a + .03) / (a * (2.43 * a + .59) + .14)  # filmic curve
    a = np.clip(a, 0, 1) ** (1 / 2.2)
    yy, xx = np.mgrid[-1 : 1 : ry * 1j, -1 : 1 : rx * 1j]
    a *= (1 - .22 * (xx**2 + yy**2) / 2)[..., None]
    out = bpy.data.images.new(name, rx, ry); out.colorspace_settings.name = "Non-Color"
    buf = np.ones((ry, rx, 4), "f4"); buf[..., :3] = a; out.pixels.foreach_set(buf.ravel())
    out.filepath_raw = os.path.join(OUT, name + ".png"); out.file_format = "PNG"; out.save(); os.remove(p)


if "game" in VIEWS: shoot("game", (-28, 11, 0), (2, 3, 0), 52, 1600, 740)
if "wide" in VIEWS: shoot("wide", (-46, 34, -10), (140, 4, 4), 48, 1800, 760)
