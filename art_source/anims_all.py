exec(open('/tmp/claude-1000/-var-mnt-HD-Godot-jogo-claude/0407a7df-0e8c-485d-8054-3d20f9d37c5b/scratchpad/anim.py').read())
S = lambda ph, k=1, o=0: math.sin(2 * math.pi * (ph * k + o))

# ---------------- idle (respiração, balanço de peso, olhar)
def idle_fn(ph):
    return P(hz=0.912 + 0.004 * S(ph), hx=0.006 * S(ph), hp=-0.5, cp=-1.0 + 1.4 * S(ph, 1, -0.1), sp=0.4 * S(ph),
             hdp=1.5 * S(ph, 1, -0.25), tw=1.2 * S(ph, 1, 0.2), roll=0.8 * S(ph),
             uaL=-5 + 2.5 * S(ph, 1, -0.15), uaR=-4 + 2.5 * S(ph, 1, -0.2),
             faL=12 + 3 * S(ph, 1, -0.3), faR=12 + 3 * S(ph, 1, -0.3),
             abL=7 + 1.0 * S(ph), abR=7 - 1.0 * S(ph), fLy=0.0, fRy=0.0, fLp=0, fRp=0)
procedural('idle', 90, idle_fn)

# ---------------- agachado parado
def crouch_fn(ph):
    return P(hz=0.60 + 0.004 * S(ph), hy=-0.09, hp=-6, sp=-14 + 1.2 * S(ph), cp=-10 + 1.5 * S(ph, 1, -0.1), np_=14, hdp=20 + 1.5 * S(ph, 1, -0.3),
             uaL=16 + 2 * S(ph, 1, -0.2), uaR=16 + 2 * S(ph, 1, -0.2), faL=42, faR=42, abL=10, abR=10, tw=1.0 * S(ph),
             fLy=0.06, fRy=-0.04, fLp=0, fRp=0)
procedural('crouch', 90, crouch_fn)

# ---------------- andar / correr / andar agachado
gait('walk', 27, 0.50, 0.50, 0.62, 0.11, 0.83, 0.03, 4, 24, 16, 6, bounce_phase=0.06)
gait('run', 18, 0.42, 0.55, 0.36, 0.32, 0.80, 0.08, 16, 58, 88, 10, bounce_phase=0.18, head_up=8, hip_sway=0.01, arm_out=10)
gait('crouch_walk', 30, 0.32, 0.32, 0.66, 0.07, 0.80, 0.02, 16, 14, 40, 5, bounce_phase=0.06, crouch_drop=0.27, hips_back=-0.07, head_up=14, hip_sway=0.008)

# ---------------- pulo (uma vez): agacha -> impulso -> sobe
base = P()
k0 = P(hz=0.915)
k1 = P(hz=0.70, hy=-0.06, hp=-8, sp=-8, cp=-5, np_=10, hdp=8, uaL=-38, uaR=-38, faL=20, faR=20, abL=8, abR=8, fLy=0.0, fRy=0.0)
k2 = P(hz=0.95, hy=0.02, hp=2, sp=3, cp=2, np_=-3, uaL=95, uaR=95, faL=15, faR=15, abL=22, abR=22,
       fLy=-0.02, fLz=0.07, fLp=-40, fRy=-0.02, fRz=0.07, fRp=-40)
k3 = P(hz=0.95, hy=0.0, hp=0, sp=4, cp=2, uaL=122, uaR=115, faL=22, faR=20, abL=34, abR=30,
       fLy=0.14, fLz=0.30, fLp=-10, fRy=-0.10, fRz=0.14, fRp=-35)
k4 = P(hz=0.95, hy=0.0, hp=0, sp=3, cp=2, uaL=128, uaR=118, faL=24, faR=22, abL=38, abR=34,
       fLy=0.16, fLz=0.32, fLp=-8, fRy=-0.12, fRz=0.15, fRp=-38)
keyed('jump', [(1, k0), (5, k1), (9, k2), (13, k3), (18, k4)], loop=False)

# ---------------- queda (loop): braços abertos, pernas soltas
def fall_fn(ph):
    return P(hz=0.95, hy=0.0, hp=-2, sp=2, cp=1, np_=-2, hdp=2 * S(ph), roll=2.0 * S(ph),
             uaL=70 + 8 * S(ph), uaR=70 + 8 * S(ph, 1, 0.5), abL=48 + 6 * S(ph, 1, 0.25), abR=48 + 6 * S(ph, 1, 0.75),
             faL=22 + 6 * S(ph), faR=22 + 6 * S(ph, 1, 0.5),
             fLy=0.12 + 0.02 * S(ph), fLz=0.18 + 0.02 * S(ph, 1, 0.25), fLp=-18,
             fRy=-0.09 - 0.02 * S(ph), fRz=0.08 + 0.02 * S(ph, 1, 0.75), fRp=-30)
procedural('fall', 24, fall_fn)

# ---------------- nadar (crawl na superfície, corpo inclinado)
def swim_action():
    N = 32
    act = new_action('swim')
    for f in range(N):
        ph = f / N
        p = Pose()
        pitch = -52.0
        p.hips_loc = V((0.0, 0.0, 0.22 + 0.012 * S(ph, 2)))
        p.r('hips', x=pitch * 0.55, y=14 * S(ph), z=3 * S(ph))
        p.r('spine', x=pitch * 0.25, y=6 * S(ph), z=-3 * S(ph))
        p.r('chest', x=pitch * 0.2, y=6 * S(ph), z=-3 * S(ph))
        p.r('neck', x=22, z=-4 * S(ph))
        p.r('head', x=24)
        for side, sx, off in (('L', -1, 0.0), ('R', 1, 0.5)):
            t = (ph + off) % 1.0
            # recuperação sobre a água em 42% do ciclo, puxada em 58%
            if t < 0.42:
                th = lerp(-60, -210, ease(t / 0.42)); el = lerp(30, 95, math.sin(math.pi * t / 0.42))
            else:
                th = lerp(-210, -420, (t - 0.42) / 0.58); el = lerp(25, 45, math.sin(math.pi * (t - 0.42) / 0.58))
            p.r(f'upperarm_{side}', x=th, y=-sx * 8)
            p.r(f'forearm_{side}', x=el)
            p.r(f'hand_{side}', x=-4)
            p.r(f'clavicle_{side}', x=0)
            # pernas: adejar
            kick = 16 * math.sin(2 * math.pi * (ph * 2 + off * 2 + 0.0)) if False else 18 * math.sin(2 * math.pi * (ph * 2 + (0.0 if side == 'L' else 0.5)))
            hw = hip_world(p, side)
            ang = math.radians(52 + kick * 0.8)
            r = 0.79 + 0.03 * math.sin(2 * math.pi * (ph * 2 + (0.0 if side == 'L' else 0.5) + 0.25))
            tgt = V((HEAD[f'foot_{side}'].x, hw.y - math.sin(ang) * r, hw.z - math.cos(ang) * r))
            leg_ik(p, side, tgt, foot_pitch=-35 + kick)
        apply_pose(p, f + 1)
    set_range(act, 1, N, True)
swim_action()

# deixa o rig em pose de repouso para visualização
print([a.name for a in bpy.data.actions])
