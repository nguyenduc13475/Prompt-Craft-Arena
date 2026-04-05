# Thư viện Callback tiêu chuẩn cho Terrain/Cấu trúc (Dùng chung cho mọi Map)
TERRAIN_CALLBACKS = {
    "bush": """
def execute(event):
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None:
            obj.in_bush_id = event.self.id
""",
    "river": """
def execute(event):
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and getattr(obj, 'in_river_id', '') != event.self.id:
            obj.in_river_id = event.self.id
""",
    "wall": """
def execute(event):
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2 + 20)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and obj.id != event.self.id:
            dx = obj.coord[0] - event.self.coord[0]
            dy = obj.coord[1] - event.self.coord[1]
            if abs(dx) > abs(dy):
                obj.coord[0] = obj.coord[0] + (5 if dx > 0 else -5)
            else:
                obj.coord[1] = obj.coord[1] + (5 if dy > 0 else -5)
""",
    "mud": """
def execute(event):
    objs = get_objects(event.self.coord, max(event.self.size[0], event.self.size[1])/2)
    for obj in objs:
        if getattr(obj, 'hp', None) is not None and obj.id != event.self.id:
            obj.coord[0] = obj.coord[0] - (obj.velocity[0] * 0.033 * 0.5)
            obj.coord[1] = obj.coord[1] - (obj.velocity[1] * 0.033 * 0.5)
""",
    "spawner": """
def execute(event):
    if not hasattr(event.self, 'last_spawn'):
        event.self.last_spawn = event.current_time
    if event.current_time > event.self.last_spawn + getattr(event.self, 'spawn_rate', 15.0):
        event.self.last_spawn = event.current_time
        
        def minion_ai(e):
            wps = getattr(e.self, 'waypoints', [])
            idx = getattr(e.self, 'wp_index', 0)
            if idx < len(wps):
                target_coord = wps[idx]
                dx = target_coord[0] - e.self.coord[0]
                dy = target_coord[1] - e.self.coord[1]
                dist = math.hypot(dx, dy)
                if dist > 30:
                    angle = math.atan2(dy, dx)
                    e.self.velocity = [math.cos(angle)*80, math.sin(angle)*80]
                    e.self.orientation = angle
                else:
                    e.self.wp_index = idx + 1
            else:
                e.self.velocity = [0.0, 0.0]
            
            if not hasattr(e.self, 'last_atk'): e.self.last_atk = 0
            if e.current_time > e.self.last_atk + 1.5:
                enemies = get_objects(e.self.coord, 120.0)
                for en in enemies:
                    if en.team != e.self.team and getattr(en, 'hp', None) is not None and en.hp > 0:
                        en.hp = en.hp - getattr(e.self, 'attack_damage', 15)
                        e.self.last_atk = e.current_time
                        e.self.velocity = [0.0, 0.0]
                        e.self.current_anim = 'Attack'
                        break
            else:
                if math.hypot(e.self.velocity[0], e.self.velocity[1]) > 0:
                    e.self.current_anim = 'Walk'
                else:
                    e.self.current_anim = 'Idle'

        create_object({
            'team': event.self.team, 'hp': 300, 'max_hp': 300, 
            'coord': list(event.self.coord), 'size': [20, 20], 
            'color': 'DODGER_BLUE' if event.self.team==1 else 'CRIMSON', 
            'bounty': 20, 'exp_reward': 20, 
            'waypoints': getattr(event.self, 'waypoints', []), 'wp_index': 0,
            'model_url': 'res://assets/environments/minion/melee/minion_melee_1.glb'
        }, minion_ai)
""",
    "tower": """
def execute(event):
    if not hasattr(event.self, 'last_attack'):
        event.self.last_attack = event.current_time
        
    if getattr(event.self, 'hp', 0) <= 0:
        event.self.is_deleted = True
        return

    if event.current_time > event.self.last_attack + getattr(event.self, 'attack_speed', 1.2):
        enemies = get_objects(event.self.coord, getattr(event.self, 'attack_range', 300.0))
        target = None
        for e in enemies:
            if e.team != event.self.team and getattr(e, 'hp', None) is not None and e.hp > 0:
                target = e
                break
                
        if target:
            event.self.last_attack = event.current_time
            target_pos = list(target.coord)
            
            def bullet_cb(ev):
                if not hasattr(ev.self, 'target_pos'):
                    ev.self.target_pos = target_pos
                dx = ev.self.target_pos[0] - ev.self.coord[0]
                dy = ev.self.target_pos[1] - ev.self.coord[1]
                dist = math.hypot(dx, dy)
                if dist < 20:
                    hit_objs = get_objects(ev.self.coord, 40.0)
                    for ho in hit_objs:
                        if ho.team != ev.self.team and getattr(ho, 'hp', None) is not None:
                            ho.hp = ho.hp - getattr(ev.self, 'damage', 120)
                    delete_object(ev.self.id)
                else:
                    angle = math.atan2(dy, dx)
                    ev.self.velocity = [math.cos(angle)*500, math.sin(angle)*500]
                    
            create_object({
                'team': event.self.team, 'coord': list(event.self.coord),
                'size': [15, 15], 'color': 'YELLOW', 
                'damage': getattr(event.self, 'attack_damage', 120)
            }, bullet_cb)
""",
}
