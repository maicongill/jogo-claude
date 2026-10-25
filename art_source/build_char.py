import bpy, bmesh, math
from mathutils import Vector, Matrix

# ---------------------------------------------------------------- limpeza
for o in list(bpy.data.objects):
    if o.type in {'MESH', 'ARMATURE'}:
        bpy.data.objects.remove(o, do_unlink=True)
for blk in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
    for b in list(blk):
        if b.users == 0:
            blk.remove(b)

V = Vector

# ---------------------------------------------------------------- esqueleto (personagem olha para +Y, esquerda = -X)
BONES = {
    # nome: (pai, cabeça, cauda)
    'root':       (None,        V((0, 0, 0)),          V((0, 0, 0.12))),
    'hips':       ('root',      V((0, 0, 0.93)),       V((0, 0, 1.02))),
    'spine':      ('hips',      V((0, 0, 1.02)),       V((0, 0, 1.20))),
    'chest':      ('spine',     V((0, 0, 1.20)),       V((0, 0, 1.43))),
    'neck':       ('chest',     V((0, 0, 1.43)),       V((0, 0, 1.53))),
    'head':       ('neck',      V((0, 0, 1.53)),       V((0, 0, 1.78))),
}
ARM_DIR = {}
for side, sx in (('L', -1), ('R', 1)):
    sh = V((0.04 * sx, 0, 1.40)); sh2 = V((0.19 * sx, 0, 1.41))
    elbow = sh2 + V((0.075 * sx, 0, -0.28))
    wrist = elbow + V((0.045 * sx, 0.0, -0.256))
    tip = wrist + V((0.03 * sx, 0, -0.16))
    BONES[f'clavicle_{side}'] = ('chest', sh, sh2)
    BONES[f'upperarm_{side}'] = (f'clavicle_{side}', sh2, elbow)
    BONES[f'forearm_{side}'] = (f'upperarm_{side}', elbow, wrist)
    BONES[f'hand_{side}'] = (f'forearm_{side}', wrist, tip)
    hip = V((0.085 * sx, 0, 0.93)); knee = V((0.085 * sx, 0.012, 0.50)); ankle = V((0.085 * sx, 0, 0.10))
    BONES[f'thigh_{side}'] = ('hips', hip, knee)
    BONES[f'shin_{side}'] = (f'thigh_{side}', knee, ankle)
    BONES[f'foot_{side}'] = (f'shin_{side}', ankle, ankle + V((0, 0.2, 0)))
ORDER = list(BONES.keys())

bpy.ops.object.select_all(action='DESELECT')
arm_data = bpy.data.armatures.new('AdventurerArmature')
rig = bpy.data.objects.new('AdventurerRig', arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for n in ORDER:
    par, h, t = BONES[n]
    eb = arm_data.edit_bones.new(n)
    eb.head, eb.tail = h, t
    eb.roll = 0
    eb.use_connect = False
    if par:
        eb.parent = arm_data.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
arm_data.display_type = 'OCTAHEDRAL'

# ---------------------------------------------------------------- materiais (cor chapada; o toon/outline é aplicado no Godot)
def mat(name, rgb, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*rgb, 1)
    return m

bpy.context.scene.view_settings.view_transform = 'Standard'
MATS = {
    'skin':    (0.96, 0.78, 0.66),
    'hair':    (0.07, 0.09, 0.20),
    'eye':     (0.40, 0.62, 0.85),
    'eye_dark': (0.05, 0.06, 0.12),
    'eye_white': (0.97, 0.97, 0.97),
    'coat':    (0.30, 0.36, 0.50),
    'tunic':   (0.93, 0.88, 0.76),
    'scarf':   (0.62, 0.70, 0.80),
    'pants':   (0.17, 0.17, 0.18),
    'leather': (0.36, 0.23, 0.15),
    'boots':   (0.40, 0.28, 0.20),
    'armor':   (0.30, 0.25, 0.22),
    'bracer':  (0.10, 0.10, 0.13),
    'metal':   (0.55, 0.56, 0.60),
}
MAT_LIST = list(MATS.keys())
mat_objs = [mat(f'M_{k}', MATS[k], metal=0.0) for k in MAT_LIST]

# ---------------------------------------------------------------- construtor de malha
bm = bmesh.new()
PARTS = []  # (verts, weighter)


def circle_basis(t):
    t = t.normalized()
    ref = V((0, 1, 0)) if abs(t.y) < 0.9 else V((1, 0, 0))
    u = t.cross(ref).normalized()
    v = t.cross(u).normalized()
    return u, v


def tube(rings, seg=10, cap=True, close_ring=False, angle0=0.0, angle1=2 * math.pi):
    """rings: lista de (centro, direção, rx, ry). Cria um tubo; angle0..angle1 limita o arco (casaco aberto)."""
    partial = abs((angle1 - angle0) - 2 * math.pi) > 1e-6
    n = seg if partial else seg
    steps = seg + 1 if partial else seg
    grid = []
    for c, t, rx, ry in rings:
        u, v = circle_basis(t)
        row = []
        for i in range(steps):
            a = angle0 + (angle1 - angle0) * i / (seg if partial else seg)
            p = c + u * (math.cos(a) * rx) + v * (math.sin(a) * ry)
            row.append(bm.verts.new(p))
        grid.append(row)
    for r in range(len(grid) - 1):
        for i in range(steps if not partial else steps - 1):
            j = (i + 1) % steps
            try:
                bm.faces.new((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]))
            except ValueError:
                pass
    if cap and not partial:
        for row, flip in ((grid[0], True), (grid[-1], False)):
            c = sum((v.co for v in row), V()) / len(row)
            cv = bm.verts.new(c)
            for i in range(len(row)):
                j = (i + 1) % len(row)
                tri = (cv, row[j], row[i]) if flip else (cv, row[i], row[j])
                try:
                    bm.faces.new(tri)
                except ValueError:
                    pass
    return grid


def ellipsoid(c, r, seg=10, rings=7, rot=None):
    c = V(c)
    verts = []
    top = bm.verts.new(c + V((0, 0, r[2])))
    rowsv = []
    for k in range(1, rings):
        phi = math.pi * k / rings
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            row.append(bm.verts.new(c + V((math.sin(phi) * math.cos(a) * r[0], math.sin(phi) * math.sin(a) * r[1], math.cos(phi) * r[2]))))
        rowsv.append(row)
    bot = bm.verts.new(c + V((0, 0, -r[2])))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((top, rowsv[0][j], rowsv[0][i]))
        bm.faces.new((bot, rowsv[-1][i], rowsv[-1][j]))
    for k in range(len(rowsv) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((rowsv[k][i], rowsv[k][j], rowsv[k + 1][j], rowsv[k + 1][i]))
    return [top, bot] + [v for r_ in rowsv for v in r_]


def cone(p0, p1, r0, seg=5):
    """Mecha/ponta: de p0 (base, raio r0) afinando até p1."""
    t = (V(p1) - V(p0))
    return tube([(V(p0), t, r0, r0 * 0.8), (V(p0) + t * 0.55, t, r0 * 0.6, r0 * 0.5), (V(p1), t, 0.001, 0.001)], seg=seg, cap=True)


def box(c, s):
    c = V(c)
    vs = [bm.verts.new(c + V((sx * s[0] / 2, sy * s[1] / 2, sz * s[2] / 2))) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    idx = lambda x, y, z: (x * 4 + y * 2 + z)
    for quad in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in quad])
    return vs


def add_part(name, material, build, weighter):
    old = set(bm.verts)
    build()
    new = [v for v in bm.verts if v not in old]
    newset = set(new)
    for f in bm.faces:
        if f.verts[0] in newset:
            f.material_index = MAT_LIST.index(material)
    PARTS.append((name, new, weighter))


# ---------------------------------------------------------------- pesos
def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def chain(joints):
    """joints: lista [(osso, ponto_da_junta_com_o_próximo, normal, largura)]; o último osso termina a cadeia.
    Retorna weighter(co) que mistura ossos consecutivos perto de cada junta."""
    def w(co):
        # s_k = peso de 'já passou da junta k'
        n = len(joints)
        s = []
        for (b, p, nrm, width) in joints[:-1]:
            d = (co - p).dot(nrm.normalized())
            s.append(smooth((d + width) / (2 * width)))
        out = {}
        for k, (b, p, nrm, width) in enumerate(joints):
            prev = s[k - 1] if k > 0 else 1.0
            nxt = s[k] if k < n - 1 else 0.0
            out[b] = prev * (1 - nxt)
        return out
    return w


def rigid(bone):
    return lambda co: {bone: 1.0}


def mix(*pairs):
    return lambda co: {b: w for b, w in pairs}


def downward(p, width):  # normal apontando para baixo (z-)
    return (p, V((0, 0, -1)), width)


def leg_weights(side, with_hips=False):
    sx = -1 if side == 'L' else 1
    knee = BONES[f'shin_{side}'][1]
    ankle = BONES[f'foot_{side}'][1]
    hip = BONES[f'thigh_{side}'][1]
    j = []
    if with_hips:
        j.append(('hips', hip + V((0, 0, 0.0)), V((0, 0, -1)), 0.06))
    j.append((f'thigh_{side}', knee, V((0, 0, -1)), 0.05))
    j.append((f'shin_{side}', ankle, V((0, 0, -1)), 0.03))
    j.append((f'foot_{side}', ankle, V((0, 0, -1)), 0.03))
    return chain(j)


def arm_weights(side, start_bone='clavicle'):
    sh = BONES[f'upperarm_{side}'][1]
    el = BONES[f'forearm_{side}'][1]
    wr = BONES[f'hand_{side}'][1]
    ua = (el - sh).normalized(); fa = (wr - el).normalized(); ha = (BONES[f'hand_{side}'][2] - wr).normalized()
    return chain([
        (f'chest', sh, V((0, 0, -1)), 0.001),
        (f'upperarm_{side}', el, ua, 0.035),
        (f'forearm_{side}', wr, fa, 0.02),
        (f'hand_{side}', wr, ha, 0.02),
    ])


# ---------------------------------------------------------------- partes do corpo
SIDES = (('L', -1), ('R', 1))

# cabeça (pele)
def build_head():
    prof = [(1.535, 0.025, 0.035), (1.56, 0.060, 0.072), (1.60, 0.087, 0.093), (1.645, 0.096, 0.104),
            (1.695, 0.093, 0.100), (1.74, 0.070, 0.078), (1.765, 0.035, 0.040)]
    tube([(V((0, 0.005, z)), V((0, 0, 1)), rx, ry) for z, rx, ry in prof], seg=12)
    # nariz
    ellipsoid((0, 0.104, 1.625), (0.010, 0.014, 0.014), seg=6, rings=4)
    for sx in (-1, 1):  # orelhas
        ellipsoid((0.094 * sx, 0.0, 1.635), (0.012, 0.016, 0.028), seg=6, rings=5)
add_part('head', 'skin', build_head, rigid('head'))

# pescoço
def build_neck():
    tube([(V((0, 0, 1.43)), V((0, 0, 1)), 0.05, 0.05), (V((0, 0, 1.56)), V((0, 0, 1)), 0.042, 0.042)], seg=8)
add_part('neck', 'skin', build_neck, mix(('neck', 1.0)))

# olhos e sobrancelhas
def build_eyes():
    for sx in (-1, 1):
        ellipsoid((0.037 * sx, 0.093, 1.645), (0.020, 0.010, 0.026), seg=8, rings=6)
add_part('eye_white', 'eye_white', build_eyes, rigid('head'))

def build_iris():
    for sx in (-1, 1):
        ellipsoid((0.037 * sx, 0.1015, 1.642), (0.0155, 0.006, 0.022), seg=8, rings=6)
add_part('iris', 'eye', build_iris, rigid('head'))

def build_pupil():
    for sx in (-1, 1):
        ellipsoid((0.037 * sx, 0.1055, 1.640), (0.008, 0.004, 0.0125), seg=6, rings=4)
        # linha dos cílios
        ellipsoid((0.037 * sx, 0.1005, 1.672), (0.024, 0.006, 0.0045), seg=8, rings=4)
        # sobrancelha
        ellipsoid((0.040 * sx, 0.094, 1.700), (0.026, 0.008, 0.0045), seg=8, rings=4)
    ellipsoid((0, 0.1055, 1.585), (0.012, 0.004, 0.0030), seg=6, rings=4)  # boca
add_part('eye_dark', 'eye_dark', build_pupil, rigid('head'))

# cabelo
def build_hair():
    # calota (remove a frente/rosto)
    cap = ellipsoid((0, -0.004, 1.700), (0.108, 0.114, 0.092), seg=14, rings=8)
    bm.verts.ensure_lookup_table()
    rm = [v for v in cap if (v.co.y > 0.04 and v.co.z < 1.738) or v.co.z < 1.66]
    bmesh.ops.delete(bm, geom=rm, context='VERTS')
    # franja
    for x, z in ((-0.080, 1.725), (-0.045, 1.742), (-0.012, 1.748), (0.022, 1.744), (0.055, 1.738), (0.085, 1.722)):
        cone((x, 0.085, z), (x * 1.15 + (0.01 if x > 0 else -0.01), 0.112, z - 0.085 - 0.015 * abs(x) * 6), 0.030, seg=5)
    # mechas das laterais
    for sx in (-1, 1):
        cone((0.100 * sx, 0.035, 1.700), (0.112 * sx, 0.045, 1.600), 0.028, seg=5)
        cone((0.098 * sx, -0.015, 1.690), (0.108 * sx, -0.02, 1.595), 0.030, seg=5)
    # nuca e volume de trás
    for x in (-0.07, -0.025, 0.025, 0.07):
        cone((x, -0.085, 1.700), (x * 1.1, -0.115, 1.560), 0.032, seg=5)
    # topo bagunçado
    cone((-0.03, 0.01, 1.78), (-0.07, 0.03, 1.835), 0.032, seg=5)
    cone((0.03, 0.0, 1.785), (0.075, -0.01, 1.84), 0.030, seg=5)
    cone((0.0, -0.04, 1.78), (0.01, -0.09, 1.835), 0.030, seg=5)
add_part('hair', 'hair', build_hair, rigid('head'))

# túnica (tronco por baixo do casaco)
def build_tunic():
    prof = [(0.90, 0.150, 0.104), (0.98, 0.150, 0.104), (1.12, 0.150, 0.104), (1.25, 0.168, 0.112), (1.38, 0.178, 0.108), (1.46, 0.100, 0.085)]
    tube([(V((0, 0, z)), V((0, 0, 1)), rx, ry) for z, rx, ry in prof], seg=12, cap=False)
add_part('tunic', 'tunic', build_tunic, chain([
    ('hips', V((0, 0, 1.02)), V((0, 0, 1)), 0.05),
    ('spine', V((0, 0, 1.20)), V((0, 0, 1)), 0.06),
    ('chest', V((0, 0, 1.43)), V((0, 0, 1)), 0.03),
    ('neck', V((0, 0, 1.43)), V((0, 0, 1)), 0.03)]))

# calça: pelve + pernas
def build_pants():
    tube([(V((0, 0, 0.88)), V((0, 0, 1)), 0.155, 0.108), (V((0, 0, 0.99)), V((0, 0, 1)), 0.153, 0.106)], seg=12, cap=True)
    for side, sx in SIDES:
        hip = BONES[f'thigh_{side}'][1]; knee = BONES[f'shin_{side}'][1]; ankle = BONES[f'foot_{side}'][1]
        tube([(V((0.085 * sx, 0, 0.93)), V((0, 0, -1)), 0.083, 0.083),
              (V((0.085 * sx, 0.004, 0.72)), V((0, 0, -1)), 0.075, 0.078),
              (V((0.085 * sx, 0.012, 0.50)), V((0, 0, -1)), 0.062, 0.064),
              (V((0.085 * sx, 0.01, 0.40)), V((0, 0, -1)), 0.066, 0.068),
              (V((0.085 * sx, 0.0, 0.31)), V((0, 0, -1)), 0.070, 0.070)], seg=10, cap=True)
def pants_w(co):
    side = 'L' if co.x < 0 else 'R'
    if co.z > 0.93:
        return {'hips': 1.0}
    return leg_weights(side, with_hips=True)(co)
add_part('pants', 'pants', build_pants, pants_w)

# botas
def build_boots():
    for side, sx in SIDES:
        x = 0.085 * sx
        tube([(V((x, 0.0, 0.07)), V((0, 0, 1)), 0.064, 0.070), (V((x, 0.0, 0.22)), V((0, 0, 1)), 0.068, 0.072),
              (V((x, 0.005, 0.33)), V((0, 0, 1)), 0.078, 0.080), (V((x, 0.005, 0.36)), V((0, 0, 1)), 0.078, 0.080)], seg=10, cap=True)
        # pé da bota: tubo ao longo de +Y
        tube([(V((x, -0.075, 0.045)), V((0, 1, 0)), 0.050, 0.045), (V((x, 0.0, 0.050)), V((0, 1, 0)), 0.062, 0.058),
              (V((x, 0.09, 0.040)), V((0, 1, 0)), 0.064, 0.048), (V((x, 0.17, 0.032)), V((0, 1, 0)), 0.050, 0.032),
              (V((x, 0.215, 0.028)), V((0, 1, 0)), 0.022, 0.020)], seg=8, cap=True)
def boots_w(co):
    side = 'L' if co.x < 0 else 'R'
    ankle = BONES[f'foot_{side}'][1]
    if co.z > 0.12 and co.y < 0.10 or co.z > 0.16:
        # cano: segue a canela, com mistura perto do tornozelo
        f = smooth((0.16 - co.z) / 0.10)
        return {f'shin_{side}': 1 - f, f'foot_{side}': f}
    return {f'foot_{side}': 1.0}
add_part('boots', 'boots', build_boots, boots_w)

# casaco: concha aberta na frente
def coat_prof():
    return [(0.50, 0.262, 0.190), (0.60, 0.240, 0.168), (0.72, 0.210, 0.148), (0.90, 0.178, 0.122), (1.00, 0.166, 0.118),
            (1.12, 0.170, 0.120), (1.25, 0.190, 0.128), (1.38, 0.205, 0.122), (1.455, 0.140, 0.100)]

def solid(faces, t=0.014):
    bmesh.ops.solidify(bm, geom=faces, thickness=t)


def build_coat():
    gap = math.radians(34)
    a0 = 3 * math.pi / 2 + gap / 2
    a1 = 3 * math.pi / 2 - gap / 2 + 2 * math.pi
    fb = set(f for f in bm.faces)
    tube([(V((0, 0, z)), V((0, 0, 1)), rx, ry) for z, rx, ry in coat_prof()], seg=22, cap=False, angle0=a0, angle1=a1)
    solid([f for f in bm.faces if f not in fb])


def coat_w(co):
    s = 'L' if co.x < 0 else 'R'
    if co.z > 1.43:
        return {'chest': 0.5, 'neck': 0.5}
    if co.z > 1.2:
        return {'chest': 1.0}
    if co.z > 1.0:
        f = smooth((co.z - 1.0) / 0.2)
        return {'spine': f, 'hips': 1 - f}
    front = 0.5 + 0.5 * max(-1, min(1, co.y / 0.18))
    k = smooth((1.0 - co.z) / 0.55) * (0.35 + 0.45 * front)
    return {'hips': 1 - k, f'thigh_{s}': k}
add_part('coat', 'coat', build_coat, coat_w)


def build_collar():
    fb = set(bm.faces)
    tube([(V((0, -0.01, 1.43)), V((0, 0, 1)), 0.108, 0.098), (V((0, -0.015, 1.52)), V((0, 0, 1)), 0.098, 0.092)],
         seg=14, cap=False, angle0=math.radians(300), angle1=math.radians(240 + 360))
    solid([f for f in bm.faces if f not in fb], 0.012)
add_part('collar', 'coat', build_collar, mix(('chest', 0.5), ('neck', 0.5)))


def build_sleeves():
    for side, sx in SIDES:
        sh = BONES[f'upperarm_{side}'][1] + V((0, 0, 0.02)); el = BONES[f'forearm_{side}'][1]; wr = BONES[f'hand_{side}'][1]
        d1 = (el - sh); d2 = (wr - el)
        p_end = el + d2 * 0.5
        tube([(sh - d1.normalized() * 0.01, d1, 0.060, 0.060), (sh + d1 * 0.5, d1, 0.056, 0.056), (el, d1 + d2, 0.052, 0.052),
              (el + d2 * 0.3, d2, 0.056, 0.056), (p_end, d2, 0.062, 0.062)], seg=10, cap=False)
add_part('sleeves', 'coat', build_sleeves, lambda co: arm_weights('L' if co.x < 0 else 'R')(co))

# cachecol
def build_scarf():
    ring = [(V((0, 0.0, 1.47 + 0.01 * math.cos(a))), V((-math.sin(a), math.cos(a), 0)), 0.034, 0.030) for a in []]
    # anel em torno do pescoço
    N = 12
    pts = []
    for i in range(N + 1):
        a = 2 * math.pi * i / N
        pts.append(V((math.cos(a) * 0.092, math.sin(a) * 0.088 - 0.005, 1.50 - 0.01 * math.sin(a))))
    rings = []
    for i in range(N):
        t = pts[(i + 1) % N] - pts[i - 1]
        rings.append((pts[i], t, 0.040, 0.034))
    g = tube(rings, seg=8, cap=False)
    # fecha o anel
    for i in range(8):
        j = (i + 1) % 8
        try:
            bm.faces.new((g[-1][i], g[-1][j], g[0][j], g[0][i]))
        except ValueError:
            pass
    # ponta caindo no peito (lado esquerdo do personagem)
    tube([(V((-0.065, 0.100, 1.45)), V((0, 0.2, -1)), 0.040, 0.012), (V((-0.07, 0.130, 1.30)), V((0, 0.15, -1)), 0.043, 0.013),
          (V((-0.075, 0.135, 1.16)), V((0, 0.0, -1)), 0.040, 0.012)], seg=8, cap=True)
    # pontas atrás
    tube([(V((0.04, -0.095, 1.46)), V((0, -0.2, -1)), 0.040, 0.012), (V((0.045, -0.12, 1.32)), V((0, -0.1, -1)), 0.040, 0.012),
          (V((0.045, -0.12, 1.22)), V((0, 0.0, -1)), 0.036, 0.011)], seg=8, cap=True)
add_part('scarf', 'scarf', build_scarf, mix(('neck', 0.5), ('chest', 0.5)))

# cinto
def build_belt():
    tube([(V((0, 0, 0.945)), V((0, 0, 1)), 0.158, 0.112), (V((0, 0, 0.995)), V((0, 0, 1)), 0.158, 0.112)], seg=16, cap=False)
    # fivela e ponta
    box((0, 0.114, 0.97), (0.05, 0.016, 0.06))
    box((-0.07, 0.112, 0.955), (0.12, 0.010, 0.035))
add_part('belt', 'leather', build_belt, rigid('hips'))

def build_buckle():
    box((0, 0.1225, 0.97), (0.032, 0.006, 0.040))
add_part('buckle', 'metal', build_buckle, rigid('hips'))

# braçadeiras (pretas) e tiras
def build_bracers():
    for side, sx in SIDES:
        el = BONES[f'forearm_{side}'][1]; wr = BONES[f'hand_{side}'][1]
        d = wr - el
        p0 = el + d * 0.48; p1 = wr + d * 0.04
        tube([(p0, d, 0.066, 0.066), (p0 + (p1 - p0) * 0.5, d, 0.058, 0.058), (p1, d, 0.052, 0.052)], seg=10, cap=True)
add_part('bracers', 'bracer', build_bracers, lambda co: arm_weights('L' if co.x < 0 else 'R')(co))

def build_straps():
    for side, sx in SIDES:
        el = BONES[f'forearm_{side}'][1]; wr = BONES[f'hand_{side}'][1]
        d = wr - el
        for f in (0.62, 0.88):
            c = el + d * f
            tube([(c - d * 0.03, d, 0.066, 0.066), (c + d * 0.03, d, 0.066, 0.066)], seg=10, cap=True)
add_part('bracer_straps', 'leather', build_straps, lambda co: arm_weights('L' if co.x < 0 else 'R')(co))

# ombreira de couro/armadura (ombro esquerdo do personagem = -X) + tiras nas costas
def build_pauldron():
    cap = ellipsoid((-0.215, 0.0, 1.445), (0.092, 0.100, 0.070), seg=12, rings=7)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in cap if v.co.z < 1.43], context='VERTS')
    plate = ellipsoid((-0.228, 0.0, 1.405), (0.085, 0.094, 0.055), seg=12, rings=6)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in plate if v.co.z > 1.40 or v.co.z < 1.375], context='VERTS')
    plate2 = ellipsoid((-0.233, 0.0, 1.372), (0.078, 0.088, 0.050), seg=12, rings=6)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in plate2 if v.co.z > 1.37 or v.co.z < 1.35], context='VERTS')
add_part('pauldron', 'armor', build_pauldron, mix(('clavicle_L', 0.6), ('upperarm_L', 0.4)))

def build_harness():
    # alças em V nas costas, da ombreira até o centro baixo
    for sx in (-1, 1):
        tube([(V((0.10 * sx, -0.100, 1.42)), V((-0.9 * sx, 0, -1)), 0.020, 0.006), (V((0.05 * sx, -0.117, 1.30)), V((-0.5 * sx, 0, -1)), 0.020, 0.006),
              (V((0.0, -0.121, 1.17)), V((-0.3 * sx, 0, -1)), 0.020, 0.006)], seg=6, cap=True)
    # alça frontal que prende a ombreira
    tube([(V((-0.20, 0.108, 1.40)), V((0.3, 0, -1)), 0.016, 0.006), (V((-0.15, 0.117, 1.24)), V((0.3, 0, -1)), 0.016, 0.006)], seg=6, cap=True)
add_part('harness', 'leather', build_harness, mix(('chest', 1.0)))

# mãos
def build_hands():
    for side, sx in SIDES:
        wr = BONES[f'hand_{side}'][1]; tip = BONES[f'hand_{side}'][2]
        d = (tip - wr)
        tube([(wr - d * 0.05, d, 0.032, 0.020), (wr + d * 0.35, d, 0.040, 0.022), (wr + d * 0.8, d, 0.034, 0.018), (tip + d * 0.1, d, 0.012, 0.010)], seg=8, cap=True)
        # polegar
        ellipsoid(wr + d * 0.35 + V((0.0, 0.026, 0.0)), (0.011, 0.014, 0.032), seg=6, rings=5)
add_part('hands', 'skin', build_hands, lambda co: {f'hand_{"L" if co.x < 0 else "R"}': 1.0})

# ---------------------------------------------------------------- finaliza: cria o objeto, grupos e pesos
mesh = bpy.data.meshes.new('AdventurerMesh')
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
for f in bm.faces:
    f.smooth = True
bm.verts.index_update()
WEIGHTS = []
for name, verts, weighter in PARTS:
    for v in verts:
        if not v.is_valid:
            continue
        ws = weighter(v.co.copy())
        tot = sum(ws.values())
        if tot <= 0:
            ws = {'hips': 1.0}; tot = 1.0
        WEIGHTS.append((v.index, {b: w / tot for b, w in ws.items() if w > 1e-4}))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
body = bpy.data.objects.new('Adventurer', mesh)
bpy.context.scene.collection.objects.link(body)
for n in ORDER:
    body.vertex_groups.new(name=n)
for vi, ws in WEIGHTS:
    for b, w in ws.items():
        body.vertex_groups[b].add([vi], w, 'REPLACE')
for m in mat_objs:
    mesh.materials.append(m)
body.parent = rig
mod = body.modifiers.new('Armature', 'ARMATURE')
mod.object = rig
print('verts', len(mesh.vertices), 'faces', len(mesh.polygons), 'bones', len(ORDER))
