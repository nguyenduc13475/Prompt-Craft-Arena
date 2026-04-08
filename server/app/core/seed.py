import uuid

from app.models.user_hero import HeroSkillSet, User
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

HUAN_ROSE_CODE = """
def execute(event):
    if not hasattr(event.self, 'initialized'):
        event.self.initialized = True
        event.self.attack_damage = 60
        event.self.attack_speed = 1.2
        event.self.speed = 60
        event.self.base_hp_regen = 1.0
        event.self.last_attack = 0
        event.self.orbs_logic = [] # Mảng logic ngầm
        event.self.current_spell = None
        event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_normal.glb'
        event.self.current_anim = 'Idle'
        event.self.anim_speed = 1.0 # Base speed
        
        event.self.q_stacks = 0
        event.self.w_stacks = 0
        event.self.e_stacks = 0
        
        event.self.cd = {'Q': 0, 'W': 0, 'E': 0, 'R': 0}
        event.self.suy_timer = event.current_time
        event.self.is_suy = False

    if event.current_time > event.self.suy_timer + 60.0 and not getattr(event.self, 'is_suy', False):
        event.self.is_suy = True
        event.self.suy_timer = event.current_time
        
        towers = get_objects(event.self.coord, 2000.0)
        nearest_tower = None
        min_dist = 9999.0
        for t in towers:
            if getattr(t, 'type', '') == 'tower' and t.team == event.self.team:
                dist = math.hypot(t.coord[0] - event.self.coord[0], t.coord[1] - event.self.coord[1])
                if dist < min_dist:
                    min_dist = dist
                    nearest_tower = t
        
        spawn_pos = list(nearest_tower.coord) if nearest_tower else [event.self.coord[0] + 50, event.self.coord[1] + 50]

        def drug_cb(e):
            if e.current_time > e.self.spawn_time + 30.0:
                delete_object(e.self.id)
                return
            if contain(e.self.coord, getattr(e.self, 'bounding_box', ((0,0),(0,0),(0,0),(0,0))), getattr(e.self.caster, 'coord', [0,0])):
                e.self.caster.is_suy = False
                e.self.caster.suy_timer = e.current_time
                e.self.caster.hp = min(e.self.caster.hp + 280, getattr(e.self.caster, 'max_hp', 1000))
                e.self.caster.fury_until = e.current_time + 30.0
                e.self.caster.current_anim = 'Smell'
                delete_object(e.self.id)
        
        create_object({
            'team': event.self.team, 'coord': spawn_pos, 'size': [30, 30], 
            'color': 'WHITE', 'spawn_time': event.current_time, 'caster': event.self,
            'model_url': 'res://assets/default_heroes/huan_rose/heroin.glb'
        }, drug_cb)

    speed_mult = 1.0
    if getattr(event.self, 'is_suy', False):
        event.self.hp = event.self.hp - (getattr(event.self, 'max_hp', 1000) * 0.025 * 0.033)
        event.self.current_anim = 'Tired Walk'
        speed_mult = 0.4
        event.self.anim_speed = 0.5 # Lê lết nên chậm lại
    else:
        if getattr(event.self, 'fury_until', 0) > event.current_time:
            speed_mult = 1.6
            event.self.anim_speed = 2.0 # Hút đồ xong chạy x2 tốc độ

    def add_orb(orb_type):
        orbs = event.self.orbs_logic + [orb_type]
        if len(orbs) > 3:
            orbs = [orbs[1], orbs[2], orbs[3]]
        event.self.orbs_logic = orbs
        
        # Build Attachments Visual cho Client
        vis_orbs = []
        for o in orbs:
            model = 'res://assets/default_heroes/huan_rose/dollar.glb'
            if o == 'W': model = 'res://assets/default_heroes/huan_rose/shield.glb'
            elif o == 'E': model = 'res://assets/default_heroes/huan_rose/axe.glb'
            vis_orbs.append({'model_url': model})
        event.self.attachments = vis_orbs

    if event.type == 'Q' and event.current_time > getattr(event.self.cd, 'Q', 0):
        event.self.cd['Q'] = event.current_time + 1.0
        event.self.q_stacks = min(3, event.self.q_stacks + 1)
        add_orb('Q')
    
    if event.type == 'W' and event.current_time > getattr(event.self.cd, 'W', 0):
        event.self.cd['W'] = event.current_time + 1.0
        event.self.w_stacks = min(3, event.self.w_stacks + 1)
        add_orb('W')

    if event.type == 'E' and event.current_time > getattr(event.self.cd, 'E', 0):
        event.self.cd['E'] = event.current_time + 1.0
        event.self.e_stacks = min(3, event.self.e_stacks + 1)
        add_orb('E')

    if event.type == 'R' and event.current_time > getattr(event.self.cd, 'R', 0):
        r_cooldown = 100.0 - (getattr(event.self, 'level', 1) * 2.0)
        if event.self.q_stacks == 3: 
            r_cooldown = r_cooldown - 1.0
        event.self.cd['R'] = event.current_time + r_cooldown
        
        q_count = event.self.orbs_logic.count('Q')
        w_count = event.self.orbs_logic.count('W')
        e_count = event.self.orbs_logic.count('E')
        
        event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_normal.glb'

        if q_count == 3: event.self.current_spell = 'QQQ'
        elif q_count == 2 and w_count == 1: event.self.current_spell = 'QQW'
        elif q_count == 1 and w_count == 2: event.self.current_spell = 'QWW'
        elif w_count == 3: 
            event.self.current_spell = 'WWW'
            event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_dick.glb'
        elif w_count == 2 and e_count == 1: 
            event.self.current_spell = 'WWE'
            event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_dick.glb'
        elif w_count == 1 and e_count == 2: event.self.current_spell = 'WEE'
        elif e_count == 3: event.self.current_spell = 'EEE'
        elif e_count == 2 and q_count == 1: event.self.current_spell = 'EEQ'
        elif e_count == 1 and q_count == 2: event.self.current_spell = 'EQQ'
        elif q_count == 1 and w_count == 1 and e_count == 1: 
            event.self.current_spell = 'QWE'
            event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_book.glb'
        
        # Tiêu hao ngọc sau khi ulti
        event.self.orbs_logic = []
        event.self.attachments = []

    if event.self.current_spell == 'QQQ':
        event.self.current_spell = None
        enemies = get_objects(event.coord, 300.0)
        for en in enemies:
            if en.team != event.self.team and getattr(en, 'hp', None) is not None:
                if random.random() > 0.5:
                    event.self.gold = getattr(event.self, 'gold', 0) + 1000
                    en.gold = max(0, getattr(en, 'gold', 0) - 1000)
                else:
                    en.gold = getattr(en, 'gold', 0) + 1000
                    event.self.gold = max(0, getattr(event.self, 'gold', 0) - 1000)
                break
    
    if event.self.current_spell == 'QQW':
        event.self.current_spell = None
        event.self.current_anim = 'Throw Around'
        event.self.gold = max(0, getattr(event.self, 'gold', 0) - 500)
        def money_cb(e):
            if e.current_time > e.self.spawn_time + 1.0:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 200.0)
            for en in enemies:
                if en.team != e.self.team and getattr(en, 'hp', None) is not None:
                    en.team = e.self.team 
                    en.gold = getattr(en, 'gold', 0) + 100
        create_object({'team': event.self.team, 'coord': list(event.self.coord), 'size': [200,200], 'color': 'YELLOW', 'vfx_type': 'electric', 'spawn_time': event.current_time, 'model_url': 'res://assets/default_heroes/huan_rose/money.glb'}, money_cb)

    if event.self.current_spell == 'QWW':
        event.self.current_spell = None
        event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_book.glb'
        def preach_cb(e):
            if e.current_time > e.self.spawn_time + 5.0:
                awake_enemies = get_objects(e.self.coord, 300.0)
                for ae in awake_enemies:
                    if ae.team != e.self.team and getattr(ae, 'hp', None) is not None:
                        ae.hp = ae.hp - 250
                delete_object(e.self.id)
                return
            e.self.coord = list(e.self.caster.coord)
            enemies = get_objects(e.self.coord, 300.0)
            for en in enemies:
                if en.team != e.self.team and getattr(en, 'hp', None) is not None:
                    en.coord[0] = en.coord[0] - (en.velocity[0] * 0.033 * 0.3) 
        create_object({'team': event.self.team, 'coord': list(event.self.coord), 'size': [300,300], 'color': 'CYAN', 'vfx_type': 'dark', 'spawn_time': event.current_time, 'caster': event.self}, preach_cb)

    if event.self.current_spell == 'WWW':
        event.self.current_spell = None
        event.self.current_anim = 'Power Up'
        event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_dick.glb'
        event.self.fury_until = event.current_time + 7.0

    if event.self.current_spell == 'WWE':
        event.self.current_spell = None
        event.self.current_anim = 'Dick Sweep'
        def sweep_cb(e):
            if e.current_time > e.self.spawn_time + 0.5:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 300.0)
            for en in enemies:
                if en.team != e.self.team and getattr(en, 'hp', None) is not None:
                    en.hp = en.hp - 300
                    kb_angle = e.self.caster.orientation + (math.pi / 2)
                    en.coord[0] = en.coord[0] + math.cos(kb_angle) * 100
                    en.coord[1] = en.coord[1] + math.sin(kb_angle) * 100
        create_object({'team': event.self.team, 'coord': list(event.self.coord), 'size': [300,300], 'color': 'RED', 'vfx_type': 'slash', 'spawn_time': event.current_time, 'caster': event.self}, sweep_cb)

    if event.self.current_spell == 'WEE':
        event.self.current_spell = None
        event.self.current_anim = 'Mouth Job'
        enemies = get_objects(event.coord, 150.0)
        for en in enemies:
            if en.team != event.self.team and getattr(en, 'hp', None) is not None:
                en.hp = en.hp - 500
                en.velocity = [0.0, 0.0] 
                break

    if event.self.current_spell == 'EEE':
        event.self.current_spell = None
        event.self.current_anim = 'Shrink'
        def poop_cb(e):
            if e.current_time > e.self.spawn_time + 1.0:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 40.0)
            for en in enemies:
                if en.team != e.self.team and getattr(en, 'hp', None) is not None:
                    en.hp = en.hp - 75
                    delete_object(e.self.id)
                    break
        for i in range(5): 
            angle = event.self.orientation + (i - 2) * 0.2
            proj_vel = [math.cos(angle)*400, math.sin(angle)*400]
            create_object({'team': event.self.team, 'velocity': proj_vel, 'coord': list(event.self.coord), 'size': [20,20], 'color': 'BROWN', 'spawn_time': event.current_time, 'model_url': 'res://assets/default_heroes/huan_rose/poop.glb'}, poop_cb)

    if event.self.current_spell == 'EEQ':
        event.self.current_spell = None
        enemies = get_objects(event.coord, 150.0)
        for en in enemies:
            if en.team != event.self.team and getattr(en, 'hp', None) is not None:
                en.hp = en.hp - 400
                event.self.hp = min(event.self.hp + (getattr(event.self, 'max_hp', 1000) * 0.2), getattr(event.self, 'max_hp', 1000))
                break
                
    if event.self.current_spell == 'EQQ':
        event.self.current_spell = None
        enemies = get_objects(event.coord, 9999.0)
        for en in enemies:
            if en.team != event.self.team and getattr(en, 'hp', None) is not None:
                if getattr(en, 'hp', 0) < getattr(event.self, 'hp', 0):
                    event.self.anim_speed = 3.0 # Cuồng nộ x3 tốc chạy
                break

    if event.self.current_spell == 'QWE':
        event.self.current_spell = None
        event.self.model_url = 'res://assets/default_heroes/huan_rose/huan_rose_book.glb'
        dx = event.coord[0] - event.self.coord[0]
        dy = event.coord[1] - event.self.coord[1]
        angle = math.atan2(dy, dx)
        proj_vel = [math.cos(angle)*500, math.sin(angle)*500]
        def med_cb(e):
            if e.current_time > e.self.spawn_time + 2.0:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 40.0)
            for en in enemies:
                if en.team != e.self.team and getattr(en, 'hp', None) is not None:
                    e.self.caster.gold = getattr(e.self.caster, 'gold', 0) + 200
                    en.gold = max(0, getattr(en, 'gold', 0) - 200)
                    en.hp = en.hp - 200 
                    delete_object(e.self.id)
                    break
        create_object({'team': event.self.team, 'velocity': proj_vel, 'coord': list(event.self.coord), 'size': [20,20], 'color': 'GREEN', 'spawn_time': event.current_time, 'caster': event.self, 'model_url': 'res://assets/default_heroes/huan_rose/medicine.glb'}, med_cb)

    if event.type == 'right':
        event.self.target_coord = event.coord
    
    if hasattr(event.self, 'target_coord'):
        dx = event.self.target_coord[0] - event.self.coord[0]
        dy = event.self.target_coord[1] - event.self.coord[1]
        dist = math.hypot(dx, dy)
        if dist > 10:
            angle = math.atan2(dy, dx)
            if not getattr(event, 'space_pressed', False):
                event.self.orientation = angle
            event.self.velocity = [math.cos(angle) * event.self.speed * speed_mult, math.sin(angle) * event.self.speed * speed_mult]
            if not getattr(event.self, 'is_suy', False): 
                event.self.current_anim = 'Running' if speed_mult >= 1.0 else 'Walking'
        else:
            event.self.velocity = [0.0, 0.0]
            if not getattr(event.self, 'is_suy', False): 
                event.self.current_anim = 'Idle'
                event.self.anim_speed = 1.0 # Về tốc độ chuẩn
            delattr(event.self, 'target_coord')
"""

TIEN_BIP_CODE = """
def execute(event):
    if not hasattr(event.self, 'initialized'):
        event.self.initialized = True
        event.self.attack_damage = 70
        event.self.attack_speed = 1.5
        event.self.speed = 300
        event.self.q_cd = 0
        event.self.w_cd = 0
        event.self.last_attack = 0

    if event.type == 'right':
        event.self.target_coord = event.coord
    
    if hasattr(event.self, 'target_coord'):
        dx = event.self.target_coord[0] - event.self.coord[0]
        dy = event.self.target_coord[1] - event.self.coord[1]
        dist = math.hypot(dx, dy)
        if dist > 5:
            angle = math.atan2(dy, dx)
            if not getattr(event, 'space_pressed', False):
                event.self.orientation = angle
            event.self.velocity = [math.cos(angle) * event.self.speed, math.sin(angle) * event.self.speed]
        else:
            event.self.velocity = [0.0, 0.0]
            delattr(event.self, 'target_coord')

    if event.type == 'Q' and event.current_time > getattr(event.self, 'q_cd', 0):
        event.self.q_cd = event.current_time + 6.0
        event.self.velocity = [0.0, 0.0]
        dx = event.coord[0] - event.self.coord[0]
        dy = event.coord[1] - event.self.coord[1]
        angle = math.atan2(dy, dx)
        proj_vel = [math.cos(angle) * 700, math.sin(angle) * 700]
        
        def nit_cb(e):
            if e.current_time > e.self.spawn_time + 1.2:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 25.0)
            for enemy in enemies:
                if enemy.team != e.self.team and getattr(enemy, 'hp', None) is not None:
                    enemy.hp = enemy.hp - 150
                    enemy.stun_until = e.current_time + 1.5
                    delete_object(e.self.id)
                    break
        create_object({'team': event.self.team, 'velocity': proj_vel, 'coord': list(event.self.coord), 'size': [20, 20], 'color': 'ORANGE', 'spawn_time': event.current_time}, nit_cb)

    if event.type == 'W' and event.current_time > getattr(event.self, 'w_cd', 0):
        event.self.w_cd = event.current_time + 12.0
        def bat_cb(e):
            if e.current_time > e.self.spawn_time + 3.0:
                delete_object(e.self.id)
                return
            enemies = get_objects(e.self.coord, 150.0)
            for enemy in enemies:
                if enemy.team != e.self.team and getattr(enemy, 'hp', None) is not None:
                    if getattr(enemy, 'gold', 0) >= 10:
                        enemy.gold = enemy.gold - 10
                        if getattr(e.self.caster, 'gold', None) is not None:
                            e.self.caster.gold = e.self.caster.gold + 10
        create_object({'team': event.self.team, 'coord': list(event.self.coord), 'size': [300, 300], 'color': 'PURPLE', 'spawn_time': event.current_time, 'caster': event.self}, bat_cb)
"""

KHA_BANH_CODE = """
def execute(event):
    if not hasattr(event.self, 'initialized'):
        event.self.initialized = True
        event.self.attack_damage = 90
        event.self.speed = 320
        event.self.q_cd = 0
        event.self.w_cd = 0

    if event.type == 'right':
        event.self.target_coord = event.coord
    
    if hasattr(event.self, 'target_coord'):
        dx = event.self.target_coord[0] - event.self.coord[0]
        dy = event.self.target_coord[1] - event.self.coord[1]
        dist = math.hypot(dx, dy)
        if dist > 5:
            angle = math.atan2(dy, dx)
            if not getattr(event, 'space_pressed', False):
                event.self.orientation = angle
            event.self.velocity = [math.cos(angle) * event.self.speed, math.sin(angle) * event.self.speed]
        else:
            event.self.velocity = [0.0, 0.0]
            delattr(event.self, 'target_coord')

    if event.type == 'Q' and event.current_time > getattr(event.self, 'q_cd', 0):
        event.self.q_cd = event.current_time + 8.0
        def quat_cb(e):
            if e.current_time > e.self.spawn_time + 2.0:
                delete_object(e.self.id)
                return
            e.self.coord = list(e.self.caster.coord) 
            enemies = get_objects(e.self.coord, 100.0)
            for enemy in enemies:
                if enemy.team != e.self.team and getattr(enemy, 'hp', None) is not None:
                    enemy.hp = enemy.hp - 10 
        create_object({'team': event.self.team, 'coord': list(event.self.coord), 'size': [200, 200], 'color': 'CYAN', 'spawn_time': event.current_time, 'caster': event.self}, quat_cb)
"""


async def seed_data(session: AsyncSession):
    sys_user_result = await session.execute(
        select(User).where(User.username == "system")
    )
    sys_user = sys_user_result.scalars().first()

    if not sys_user:
        sys_user = User(id=1, username="system", hashed_password="sys")
        session.add(sys_user)
        await session.flush()

    async def add_hero(name, prompt, hp, color, size, scale, code, url):
        res = await session.execute(
            select(HeroSkillSet).where(HeroSkillSet.name == name)
        )
        if not res.scalars().first():
            hero = HeroSkillSet(
                id=str(uuid.uuid4()),
                name=name,
                prompt=prompt,
                owner_id=1,
                attributes={
                    "hp": hp,
                    "max_hp": hp,
                    "color": color,
                    "size": size,
                    "scale": scale,
                },
                callback_code=code,
                model_url=url,
                skins=[],
            )
            session.add(hero)
            print(f"[Seed] Đã nạp thành công tướng mặc định: {name}")

    await add_hero(
        "Huan Rose",
        "Thầy giáo dục công dân",
        2000,
        "GOLD",
        [50, 50],
        10,
        HUAN_ROSE_CODE,
        "res://assets/default_heroes/huan_rose/huan_rose_normal.glb",
    )
    await add_hero(
        "Tien Bip",
        "Thầy hóa học",
        1500,
        "PURPLE",
        [45, 45],
        1.2,
        TIEN_BIP_CODE,
        "res://assets/default_heroes/tien_bip/tien_bip_normal.glb",
    )
    await add_hero(
        "Kha'Banh",
        "Thầy dạy múa quạt",
        1200,
        "CYAN",
        [40, 40],
        1.3,
        KHA_BANH_CODE,
        "res://assets/default_heroes/kha_banh/kha_banh_normal.glb",
    )

    await session.commit()
