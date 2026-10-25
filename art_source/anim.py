import bpy, math
from mathutils import Vector, Matrix, Euler, Quaternion

V = Vector
rig = bpy.data.objects['AdventurerRig']
FPS = 30
bpy.context.scene.render.fps = FPS

PB = rig.pose.bones
BN = rig.data.bones
REST = {b.name: b.matrix_local.to_3x3().normalized() for b in BN}
HEAD = {b.name: V(b.head_local) for b in BN}
PARENT = {b.name: (b.parent.name if b.parent else None) for b in BN}
ORDER = [b.name for b in BN]  # pais antes dos filhos (ordem de criação)
for n in ORDER:
    PB[n].rotation_mode = 'QUATERNION'

L1 = (HEAD['shin_L'] - HEAD['thigh_L']).length   # coxa
L2 = (HEAD['foot_L'] - HEAD['shin_L']).length    # canela
ANKLE_Z = HEAD['foot_L'].z


def rx(deg): return Matrix.Rotation(math.radians(deg), 3, 'X')
def ry(deg): return Matrix.Rotation(math.radians(deg), 3, 'Y')
def rz(deg): return Matrix.Rotation(math.radians(deg), 3, 'Z')
def rot(x=0, y=0, z=0):
    """rotação em eixos do armature (X = lateral, Y = frente, Z = cima), ordem Z·Y·X."""
    return rz(z) @ ry(y) @ rx(x)


class Pose:
    """Descreve uma pose: rotações relativas ao pai (eixos do armature) ou absolutas, e deslocamento do quadril."""
    def __init__(self):
        self.rel = {}
        self.abs = {}
        self.hips_loc = V((0, 0, 0))
        self.root_rot = Matrix.Identity(3)

    def r(self, bone, x=0, y=0, z=0):
        self.rel[bone] = rot(x, y, z)

    def a(self, bone, x=0, y=0, z=0):
        self.abs[bone] = rot(x, y, z)


def apply_pose(p, frame):
    D = {}
    for n in ORDER:
        par = PARENT[n]
        Dp = D[par] if par else Matrix.Identity(3)
        if n == 'root':
            Dl = p.root_rot
        elif n in p.abs:
            Dl = Dp.inverted() @ p.abs[n]
        else:
            Dl = p.rel.get(n, Matrix.Identity(3))
        D[n] = Dp @ Dl
        R = REST[n]
        B = R.inverted() @ Dl @ R
        PB[n].rotation_quaternion = B.to_quaternion()
        PB[n].keyframe_insert('rotation_quaternion', frame=frame, group=n)
    # quadril: deslocamento em coordenadas do osso
    R = REST['hips']
    PB['hips'].location = R.inverted() @ p.hips_loc
    PB['hips'].keyframe_insert('location', frame=frame, group='hips')
    return D


def leg_ik(p, side, foot_pos, foot_pitch=0.0, knee_out=0.0):
    """Resolve coxa/canela/pé no plano sagital para que o tornozelo fique em foot_pos (mundo).
    Depende de p.rel['hips'] e p.hips_loc já definidos (rotações do tronco acima não importam)."""
    Dh = p.rel.get('hips', Matrix.Identity(3))
    root = p.root_rot
    Dh = root @ Dh
    hh = HEAD['hips']
    thigh_h = HEAD[f'thigh_{side}']
    hip_w = hh + p.hips_loc + Dh @ (thigh_h - hh)
    v = foot_pos - hip_w
    vy, vz = v.y, v.z
    r = math.hypot(vy, vz)
    rmax = (L1 + L2) * 0.9995
    rmin = abs(L1 - L2) + 0.02
    r = max(rmin, min(rmax, r))
    phi_t = math.atan2(vy, -vz)
    cg = (L1 * L1 + r * r - L2 * L2) / (2 * L1 * r)
    gam = math.acos(max(-1, min(1, cg)))
    ck = (L1 * L1 + L2 * L2 - r * r) / (2 * L1 * L2)
    beta = math.pi - math.acos(max(-1, min(1, ck)))
    phi1 = phi_t + gam
    phi2 = phi1 - beta
    # em termos de pitch absoluto em torno de X (positivo = pé para frente)
    p.a(f'thigh_{side}', x=math.degrees(phi1), z=0, y=knee_out)
    p.a(f'shin_{side}', x=math.degrees(phi2))
    p.a(f'foot_{side}', x=foot_pitch)
    return (hip_w, r)


# --------------------------------------------------------------------------- utilidades de ciclo
def ease(t):
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def new_action(name):
    for a in list(bpy.data.actions):
        if a.name == name:
            bpy.data.actions.remove(a)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    return act


def set_range(act, a, b, loop=True):
    act.use_frame_range = True
    act.frame_start = a
    act.frame_end = b
    act.use_cyclic = loop


def foot_cycle(p_phase, S_front, S_back, stance, lift, toe_off_deg=28, heel_deg=18):
    """Retorna (y, lift_z, pitch) do tornozelo para a fase p_phase em [0,1)."""
    u = p_phase % 1.0
    if u < stance:
        t = u / stance
        y = lerp(S_front, -S_back, t)
        z = 0.0
        # rolamento: calcanhar -> planta -> ponta
        if t < 0.15:
            pitch = lerp(heel_deg, 0, t / 0.15)
        elif t < 0.65:
            pitch = 0.0
        else:
            pitch = -toe_off_deg * ease((t - 0.65) / 0.35)
        z = ANKLE_Z * 0 + 0.11 * math.sin(math.radians(-min(pitch, 0)))
    else:
        t = (u - stance) / (1 - stance)
        y = lerp(-S_back, S_front, ease(t))
        z = lift * math.sin(math.pi * t) ** 1.2
        pitch = lerp(-toe_off_deg, heel_deg, ease(t)) + 12 * math.sin(math.pi * t)
        z += 0.11 * math.sin(math.radians(-min(pitch, 0))) * (1 - t)
    return y, z, pitch


def gait(act_name, N, S_front, S_back, stance, lift, leg_len, dip, lean, arm_sw, elbow, twist, bounce_phase=0.0,
         head_up=0.0, hip_sway=0.012, crouch_drop=0.0, hips_back=0.0, arm_out=6.0, yaw_twist=1.0):
    act = new_action(act_name)
    for f in range(N):
        ph = (f % N) / N
        p = Pose()
        stride = S_front + S_back
        base = ANKLE_Z + math.sqrt(max(leg_len ** 2 - (stride / 2) ** 2, 0.2)) - crouch_drop
        z = base + dip * (0.5 - 0.5 * math.cos(4 * math.pi * (ph - bounce_phase)))
        sway = hip_sway * math.sin(2 * math.pi * ph)
        p.hips_loc = V((sway, hips_back, z - HEAD['hips'].z + ANKLE_Z * 0 + (0.93 - 0.93)))
        p.hips_loc = V((sway, hips_back, z - 0.93))
        p.r('hips', x=-lean * 0.35, z=twist * 0.4 * math.sin(2 * math.pi * ph) * yaw_twist, y=-1.5 * math.sin(2 * math.pi * ph))
        p.r('spine', x=-lean * 0.35, z=-twist * 0.55 * math.sin(2 * math.pi * ph) * yaw_twist)
        p.r('chest', x=-lean * 0.3, z=-twist * 0.6 * math.sin(2 * math.pi * ph) * yaw_twist)
        p.r('neck', x=lean * 0.5 + head_up * 0.5, z=twist * 0.3 * math.sin(2 * math.pi * ph) * yaw_twist)
        p.r('head', x=lean * 0.5 + head_up * 0.5)
        for side, off in (('L', 0.0), ('R', 0.5)):
            y, zz, pitch = foot_cycle(ph + off, S_front, S_back, stance, lift)
            ank = V((HEAD[f'foot_{side}'].x, y + hips_back * 0.0, ANKLE_Z + zz))
            leg_ik(p, side, ank, pitch)
            # braço oposto à perna
            sgn = 1 if side == 'L' else -1
            sw = math.sin(2 * math.pi * (ph + off + 0.5 + (0.0))) * arm_sw
            sw = -math.sin(2 * math.pi * (ph + off)) * arm_sw
            sx = -1 if side == 'L' else 1
            p.r(f'upperarm_{side}', x=sw - 4, z=0, y=-arm_out * sx * -1 * 0 + arm_out * sx)
            fl = elbow + max(0.0, -sw) * 0.0 + (arm_sw * 0.35 if arm_sw > 10 else arm_sw * 0.2) * (0.5 + 0.5 * math.sin(2 * math.pi * (ph + off) + math.pi))
            p.r(f'forearm_{side}', x=fl)
            p.r(f'hand_{side}', x=-6, z=0)
            p.r(f'clavicle_{side}', x=0, z=0, y=0)
        apply_pose(p, f + 1)
    set_range(act, 1, N)
    return act


# =========================================================================== poses paramétricas
DEF = dict(hz=0.915, hy=0.0, hx=0.0, hp=0.0, hr=0.0, hyaw=0.0, sp=0.0, cp=0.0, np_=0.0, hdp=0.0, tw=0.0, roll=0.0,
           uaL=-4.0, uaR=-4.0, abL=6.0, abR=6.0, faL=12.0, faR=12.0, uizL=0.0, uizR=0.0,
           fLy=0.0, fLz=0.0, fLp=0.0, fRy=0.0, fRz=0.0, fRp=0.0, fLx=0.0, fRx=0.0)


def P(**kw):
    d = dict(DEF)
    d.update(kw)
    return d


def hip_world(p, side):
    Dh = p.root_rot @ p.rel.get('hips', Matrix.Identity(3))
    hh = HEAD['hips']
    return hh + p.hips_loc + Dh @ (HEAD[f'thigh_{side}'] - hh)


def render(d):
    p = Pose()
    p.hips_loc = V((d['hx'], d['hy'], d['hz'] - 0.93))
    p.r('hips', x=d['hp'], y=d['hr'], z=d['hyaw'])
    p.r('spine', x=d['sp'], z=d['tw'] * 0.5, y=d['roll'] * 0.5)
    p.r('chest', x=d['cp'], z=d['tw'] * 0.5, y=d['roll'] * 0.5)
    p.r('neck', x=d['np_'])
    p.r('head', x=d['hdp'])
    for side, sx in (('L', -1), ('R', 1)):
        p.r(f'upperarm_{side}', x=d[f'ua{side}'], y=d[f'ab{side}'] * -sx, z=d[f'uiz{side}'])
        p.r(f'forearm_{side}', x=d[f'fa{side}'])
        p.r(f'hand_{side}', x=-6)
        leg_ik(p, side, V((HEAD[f'foot_{side}'].x + d[f'f{side}x'], d[f'f{side}y'], ANKLE_Z + d[f'f{side}z'])), d[f'f{side}p'])
    return p


def blend(a, b, t):
    t = ease(max(0.0, min(1.0, t)))
    return {k: lerp(a[k], b[k], t) for k in a}


def keyed(act_name, keys, loop=False):
    """keys: [(frame, params)] com frame começando em 1. Interpolação suave entre as chaves."""
    act = new_action(act_name)
    f0, f1 = keys[0][0], keys[-1][0]
    for f in range(f0, f1 + (0 if loop else 1)):
        for i in range(len(keys) - 1):
            if keys[i][0] <= f <= keys[i + 1][0]:
                a, b = keys[i], keys[i + 1]
                t = (f - a[0]) / max(1, (b[0] - a[0]))
                d = blend(a[1], b[1], t)
                break
        apply_pose(render(d), f)
    set_range(act, f0, f1 - (1 if loop else 0), loop)
    return act


def procedural(act_name, N, fn, loop=True):
    act = new_action(act_name)
    for f in range(N):
        apply_pose(render(fn(f / N)), f + 1)
    set_range(act, 1, N, loop)
    return act
