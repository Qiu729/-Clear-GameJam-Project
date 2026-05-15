extends CharacterBody2D

var class_type: String = "剑士"
@export_enum("p1", "p2") var player_id: String = "p1"

var screen_size

# --- 新增：属性加成系数 ---
var damage_mult = 1
var cooldown_mult = 1
var speed_mult = 1
var size_mult = 1
var max_hp_mult = 1
var range_mult = 1

# 配置参数 (对应 React 常量)
var hp = 100
var max_hp = 100
var speed = 200.0
var skill_cooldown_timer = 0.0
var max_skill_cd = 5.0 # 秒
var attack_cooldown = 0.0
var score = 0
var is_dead = false

# 护盾专用变量
var max_shield_energy = 150
var shield_energy = 150
var is_shield_active = false
var shield_regen_rate = 8.0 # 每秒恢复多少
var shield_drain_rate = 15 # 每秒消耗多少 15
var shield_push_force = 250.0 # 推力大小
var defind_enemies # 护盾附近的敌人，每shield_update_timer周期更新一次
@onready var 盾兵 = $shieldArea2d
@onready var shield_collsion = $shieldArea2d/CollisionShape2D
@onready var shield_visual  = $shieldArea2d/shieldVisual
@onready var pointLight = $PointLight2D
@onready var shield_update_timer: Timer = $ShieldUpdateTimer


# --- 新增：狂暴相关变量 ---
var is_berserk = false
var berserk_duration = 5.0 # 狂暴持续 5 秒
var berserk_timer = 0.0
var original_color = Color.WHITE # 用于结束时恢复颜色
var curr_addhp_count=0
@onready var berserk_time_acount: Timer = $BerserkTimer


# 预加载子弹
var bullet_scene = preload("res://bullet.tscn")
var slash_scene = preload("res://slash.tscn")
var laser_orb_scene = preload("res://laser_orb.tscn")

# --- 死亡状态变量 ---
var is_alive = true
var is_downed = false # 是否濒死
var is_ghost = false  # 是否是幽灵
var revive_progress = 0.0
var max_downed_timer = 15.0 # 濒死倒计时 15秒
var downed_timer = 15.0
var knockback_velocity = Vector2.ZERO

# 配置常量
const REVIVE_SPEED = 30.0 # 每秒恢复30点 (约3.3秒拉起来)
const MAX_REVIVE = 100.0

@onready var revive_bar = $ReviveBar
@onready var die_bar = $DieBar

# 技能等级
var skill_level = 1
# 用于步枪手 Lv3 的卫星球引用
var satellite_orb = null

# audio
var is_skillOk_played=false

# ai托管
var is_agent=false

# 彩虹效果变量
var is_rainbow_mode: bool = false
var rainbow_hue: float = 0.0
var rainbow_speed: float = 2.0
var rainbow_duration: float = 0.0
var rainbow_timer: float = 0.0

func setup_character(type, id):
	class_type = type
	player_id = id

	# 从 Global 读取配置
	var data = Global.CLASS_DATA[class_type]
	hp = data.hp	
	max_hp = hp
	$ColorRect.color = data.color
	original_color = data.color # <--- 记录原始颜色
	
	# 根据职业设置技能冷却
	if class_type == "剑士": max_skill_cd = 9.0
	elif class_type == "步兵": max_skill_cd = 3.0
	elif class_type == "盾兵": max_skill_cd = 6.5
	
	if class_type == "盾兵":
		hp=250
		max_hp=250
		max_skill_cd=max_shield_energy
		_generate_shield_circle(70)
		shield_update_timer.start()

	# 重置状态
	is_dead = false
	$CollisionShape2D.disabled = false
	$PointLight2D.enabled = true
	print("Player ", id, " initialized as ", class_type)
	
	
func _ready() -> void:
	screen_size = get_viewport_rect().size
	
func get_id():
	return player_id

func _physics_process(delta):
	# ai托管
	if Input.is_action_just_pressed(player_id + "_ai"):
		is_agent=!is_agent
	
	# 1. 状态流转逻辑
	if is_downed:
		_handle_downed_state(delta)
		# 濒死时禁止移动和攻击，直接 return
		return 
		
	# 1. 击退力物理模拟
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
	
	# --- 处理狂暴倒计时 ---
	if is_berserk:
		berserk_timer -= delta
		if berserk_timer <= 0:
			_end_berserk() # 时间到，关闭狂暴
	# --- 战士 Lv 2 & 3 ---
	if class_type == "剑士" and is_berserk:
		# Lv 3: 狂暴无限时间 (重置计时器)
		if skill_level >= 3:
			berserk_timer = berserk_duration 

	# 1. 移动控制
	var input_dir = Vector2.ZERO
	if player_id == "p1":
		input_dir = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	else:
		input_dir = Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
		
	# 计算最终速度
	var current_speed = speed * speed_mult
	if is_berserk:
		if skill_level >= 2:
			current_speed *= 1.4
		else:
			current_speed *= 1.25
		
	velocity = input_dir * current_speed + knockback_velocity
	
	# 限制玩家活动范围
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)
	
	move_and_slide()
	
	# --- 步枪手 Lv 3 (卫星跟随) ---
	if class_type == "步兵" and skill_level >= 3:
		if is_instance_valid(satellite_orb):
			satellite_orb.global_position = global_position
		else:
			_spawn_satellite_orb() # 如果不小心没了，重新生成
	
	# --- 盾兵 ---
	if class_type == "盾兵":
		_handle_shield_logic(delta)
	# --- 步枪&战士 ---
	else:
		# 2. 冷却处理
		if skill_cooldown_timer > 0: skill_cooldown_timer -= delta
		if attack_cooldown > 0: attack_cooldown -= delta
		if skill_cooldown_timer<0 and is_skillOk_played==false:
			SoundManager.play_sfx("SkillOK")
			is_skillOk_played=true
		# 3. 技能释放
		var skill_pressed = Input.is_action_just_pressed(player_id + "_skill")
		if skill_pressed and skill_cooldown_timer <= 0:
			cast_skill()
		# 4. 自动普攻
		if attack_cooldown <= 0:
			auto_attack()
	
	if is_rainbow_mode:
		_update_player_rainbow_light(delta)
			
# 修改：apply_upgrade 函数，供 UI 调用
func apply_upgrade(upgrade_data):
	var type = upgrade_data.type
	var val = upgrade_data.value
	
	match type:
		Global.UpgradeType.DAMAGE:
			damage_mult += val
		Global.UpgradeType.SPEED:
			speed_mult += val
		Global.UpgradeType.COOLDOWN:
			cooldown_mult *= val # 冷却时间是乘法 (0.85倍)
		Global.UpgradeType.SIZE:
			size_mult += val
		Global.UpgradeType.HP:
			max_hp_mult += val
			max_hp = Global.CLASS_DATA[class_type].hp * max_hp_mult
			hp = max_hp # 补给通常会回血
		Global.UpgradeType.RANGE:
			range_mult += val # 应用升级
			
	# 显示一个浮动文字提示 (可选)
	print(player_id, " 获得了 ", upgrade_data.name)

# --- 盾兵核心逻辑 ---
func _handle_shield_logic(delta):
	# 1. 输入检测：切换护盾开关
	if Input.is_action_just_pressed(player_id + "_skill"):
		if is_shield_active:
			_deactivate_shield()
		elif shield_energy > 10.0: # 至少有一点能量才能开
			_activate_shield()
	# 2. 状态处理
	if is_shield_active:
		# 消耗能量
		shield_energy -= shield_drain_rate * delta * cooldown_mult
		# 斥力场逻辑：推开范围内的敌人
		var mx_defind=1 * skill_level
		var curr_defind = 0
		if is_ghost:
			defind_enemies.append_array(get_tree().get_nodes_in_group("players"))
		if defind_enemies==null:_on_shield_update_timer_timeout()
		for e in defind_enemies:
			if e==null:
				continue
			if curr_defind>mx_defind:
				break
			curr_defind+=1
			if e.get_id() == player_id: continue #避免打自己
			var dist = global_position.distance_to(e.global_position)
			# 80 是护盾半径，加 e.radius 是为了边缘接触判定
			if dist < 70 * range_mult * size_mult: 
				# 计算推开的方向
				var push_dir = (e.global_position - global_position).normalized()
				var dis_mul = (70 * range_mult * size_mult) / dist # 距离越近，推力越大
				e.knockback_velocity = push_dir * shield_push_force * dis_mul
			if dist < (70+15) * range_mult * size_mult:
				# 造成少量挤压伤害
				if attack_cooldown > 0: attack_cooldown -= delta
				if attack_cooldown <= 0:
					e.take_damage(20 * damage_mult, Vector2.ZERO)
					attack_cooldown = 0.5 * cooldown_mult
				
		# 能量耗尽自动关闭
		if shield_energy <= 0:
			shield_energy = 0
			_deactivate_shield()
	else:
		# 恢复能量
		if shield_energy < max_shield_energy:
			shield_energy += shield_regen_rate * delta / cooldown_mult
			
	# 3. 同步 UI 数据
	skill_cooldown_timer = shield_energy
	
func _activate_shield():
	盾兵.scale = Vector2(1,1) * range_mult * size_mult # 应用攻击范围倍率
	pointLight.scale = Vector2(1.5,1.5) * range_mult * size_mult
	is_shield_active = true
	shield_visual.visible = true
	shield_collsion.set_deferred("disabled",false)
	# 可以加个音效
	SoundManager.play_sfx("ShieldOpen")
	
func _deactivate_shield():
	is_shield_active = false
	shield_visual.visible = false
	shield_collsion.set_deferred("disabled",true)

func cast_skill():
	skill_cooldown_timer = max_skill_cd
	is_skillOk_played=false
	
	if class_type == "剑士":
		SoundManager.play_sfx("SkillWarrior")
		_start_berserk()
			
	elif class_type == "步兵":
		SoundManager.play_sfx("SkillRifleman")
		# Lv 1 & 2: 发射巨大电浆球
		var orb = laser_orb_scene.instantiate()
		orb.damage=70*skill_level*damage_mult
		orb.global_position = global_position + Vector2.RIGHT.rotated(rotation) * 30
		orb.rotation = rotation
		
		# 基础数值
		var scale_mult = 1.0 * size_mult
		var duration_mult = 1.0 * range_mult
		var dmg_mult = 1.0 * damage_mult
		
		# --- Lv 2 强化 ---
		if skill_level >= 2:
			scale_mult *= 1.5 # 更大
			duration_mult *= 2.0 # 飞得更久(更远)
			dmg_mult *= 1.5 # 伤害更高
		
		orb.scale = Vector2(scale_mult, scale_mult)
		orb.duration = 4.0 * duration_mult
		orb.damage = 60 * dmg_mult
		
		get_parent().add_child(orb)

	elif class_type == "盾兵":
		# 盾兵的逻辑主要在 _handle_shield_logic 里
		pass

func auto_attack():
	if class_type == "步兵":
		var target = get_nearest_target(250 * range_mult)
		if target:
			var dir = (target.global_position - global_position).normalized()
			spawn_bullet(global_position, dir, 1000, 25, 2.0, 1.0)
			attack_cooldown = 0.15 * cooldown_mult
			look_at(target.global_position)
			SoundManager.play_sfx("GunShoot")
	elif class_type == "剑士":
		# 计算当前索敌范围 (狂暴时范围 x 1.5)
		var search_range = 120 * range_mult
		if is_berserk: search_range *= 1.5
		
		var target = get_nearest_target(search_range)
		
		if target:
			look_at(target.global_position)
			spawn_slash()
			
			# 计算攻击间隔 (狂暴时攻速翻倍，即间隔减半)
			var cd = 0.6 # 基础间隔
			if is_berserk: cd *= 0.5 
			
			# 应用通用的冷却缩减
			attack_cooldown = cd * cooldown_mult
		
func spawn_slash():
	var s = slash_scene.instantiate()
	
	# 计算剑气生成位置 (范围加成)
	var offset_dist = 20 * range_mult
	if is_berserk: offset_dist *= 1.3 # 狂暴时剑气生成得更远一点
	
	s.global_position = global_position + Vector2.RIGHT.rotated(rotation) * offset_dist
	s.rotation = rotation
	
	if is_ghost:
		s.is_ghost_slash = true
	
	# 计算伤害 (狂暴时伤害 x 1.5)
	var final_dmg = 40 * damage_mult
	if is_berserk: final_dmg *= 1.5
	s.damage = final_dmg
	
	# 计算大小 (狂暴时剑气变大 x 1.5)
	var final_scale = size_mult
	if is_berserk: final_scale *= 1.5
	s.scale = Vector2(final_scale, final_scale)
	SoundManager.play_sfx("SwordAttack")
	get_parent().add_child(s)

func spawn_bullet(pos, dir, speed, dmg, knockback, life):
	var b = bullet_scene.instantiate()
	b.global_position = pos
	b.velocity = dir * speed
	b.damage = dmg * damage_mult # <--- 应用伤害加成
	b.scale = Vector2(0.25, 0.25) * size_mult # 应用大小加成
	b.knockback_force = knockback
	b.duration = life
	b.owner_id = player_id

	# 标记这是否是幽灵子弹
	if is_ghost:
		b.is_ghost_bullet = true
		b.modulate = Color.CYAN # 幽灵子弹变色
	
	get_parent().add_child(b)

func get_nearest_target(range_limit):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = range_limit
	if is_ghost:
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p.get_id() != player_id:
				enemies.append(p)
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

func take_damage(amount, _knockback=Vector2.ZERO):
	if is_ghost or is_downed: return # 幽灵无敌
	
	hp -= amount
	if hp <= 0:
		if not is_downed:
			_become_downed()
	
	if amount>=1:
		SoundManager.play_sfx("PlayerHurt")

func die():
	is_dead = true
	$ColorRect.color = Color.DARK_GRAY
	$CollisionShape2D.set_deferred("disabled", true) # 禁用碰撞
	$PointLight2D.enabled = false # 熄灯

# 辅助函数：用代码画圆
func _generate_shield_circle(radius):
	if not shield_visual: return
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * (TAU / 32.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	shield_visual.polygon = points
	shield_visual.color = Color(0.2, 0.6, 1.0, 0.7) # 半透明蓝
	
func add_score(amount):
	score+=amount
	
# 新增：开启狂暴
func _start_berserk():
	is_berserk = true
	berserk_timer = berserk_duration
	# 视觉反馈：变成亮红色/发光
	$ColorRect.color = Color(1.5, 0.5, 0.5) # HDR 高亮红
	# 可选：播放音效或特效
	print("剑士 BERSERK MODE ON!")
	
	berserk_time_acount.start()

# 新增：结束狂暴
func _end_berserk():
	is_berserk = false
	# 恢复颜色
	$ColorRect.color = original_color
	print("Berserk ended.")
	
func _handle_downed_state(delta):
	# 倒计时
	downed_timer -= delta

	# 更新复活条 UI
	die_bar.value = 100 * (downed_timer/max_downed_timer)
	revive_bar.value = revive_progress
	revive_bar.visible = revive_progress > 0

	# 变成幽灵
	if downed_timer <= 0:
		_become_ghost()

func _become_downed():
	die_bar.show()
	is_alive = false
	modulate = Color(1, 0.5, 0.5) # 濒死视觉 (变红)
	is_downed = true
	hp = 0
	downed_timer = 15.0
	revive_progress = 0.0
	print(player_id, " is DOWNED!")
	SoundManager.play_sfx("PlayerDead")

func _become_ghost():
	die_bar.hide()
	is_alive = false
	is_downed = false
	is_ghost = true
	revive_bar.hide()
	var p=get_parent().get_parent()
	p.show_message(player_id+"成为幽灵")

	# 恢复移动能力
	# 视觉变成半透明幽灵色
	modulate = Color(0.5, 1.0, 1.0, 0.6) # 青色半透明
	
	# 降低数值，避免秒杀队友
	damage_mult = 0.005
	cooldown_mult = 1.4
	speed_mult = 0.6
	size_mult = 0.6
	max_hp_mult = 0.6
	range_mult = 0.6

	print(player_id, " became a GHOST!")

# 被别人救活
func get_revived():
	die_bar.hide()
	is_alive = true
	is_downed = false
	is_ghost = false
	hp = max_hp * 0.5 # 复活回一半血
	rotation = 0
	modulate = Color.WHITE # 恢复颜色
	revive_bar.visible = false
	print(player_id, " REVIVED!")
	SoundManager.play_sfx("PlayerRevived")
	
func upgrade_skill():
	if skill_level < 3:
		skill_level += 1
		
		# 玩家体型变大
		scale= scale * 1.3
		
		print(player_id, " Skill Level Up! Now: ", skill_level)
		
		# --- 盾兵 Lv 2 & 3 (能量消耗) ---
		if class_type == "盾兵":
			if skill_level == 2:
				shield_drain_rate *= 0.4 # Lv 2: 消耗大幅降低
			elif skill_level >= 3:
				shield_drain_rate = 0.0 # Lv 3: 无限盾
		
		# 步枪手 Lv3 特殊处理：立即生成一个永久卫星
		cooldown_mult*=0.6
		if class_type == "步兵" and skill_level == 3:
			_spawn_satellite_orb()

func _spawn_satellite_orb():
	satellite_orb = laser_orb_scene.instantiate()
	satellite_orb.global_position = global_position
	# 设置特殊属性，让它不移动、不销毁
	satellite_orb.speed = 0 
	satellite_orb.duration = 99999
	satellite_orb.damage = 5 # 持续伤害低一点
	satellite_orb.scale = Vector2(1.2, 1.2) * size_mult
	get_parent().add_child(satellite_orb)

func _on_berserk_timer_timeout() -> void:
	curr_addhp_count=0

func _on_shield_update_timer_timeout() -> void:
	# 更新盾兵附近敌人
	defind_enemies = get_tree().get_nodes_in_group("enemies")
	defind_enemies.sort_custom(func(a, b): 
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	
# 彩蛋触发时调用的函数
func on_secret_found():
	print("玩家: 哇! 我找到了彩虹蛋!")
	
	# 启用彩虹模式
	is_rainbow_mode = true
	rainbow_speed = 2.0
	rainbow_timer = 0.0

	# 播放特效
	play_rainbow_effect()

func play_rainbow_effect():
	# 示例：灯光闪烁一下
	var tween = create_tween()
	var original_energy = pointLight.energy
	tween.tween_property(pointLight, "energy", original_energy * 2.0, 0.3)
	tween.tween_property(pointLight, "energy", original_energy, 0.3)

func _update_player_rainbow_light(delta):
	rainbow_hue += delta * rainbow_speed
	if rainbow_hue >= 1.0:
		rainbow_hue = 0.0
	
	pointLight.color = Color.from_hsv(rainbow_hue, 0.8, 1.0, 1.0)
