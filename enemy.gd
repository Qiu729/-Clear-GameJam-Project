extends CharacterBody2D

var hp = 30
var max_hp = 30 # 新增：用于计算血条比例
var speed = 100.0
var damage = 10
var is_ranged = false
var attack_timer = 0.0
var knockback_velocity = Vector2.ZERO

# 新增：死亡状态标记
var is_dead = false 

var bullet_scene = preload("res://bullet.tscn")
var hp_bar_scene = preload("res://health_bar.tscn")
var hp_bar_instance = null

func _ready():
	# 初始化血条
	hp=max_hp
	hp_bar_instance = hp_bar_scene.instantiate()
	var layer = get_tree().get_first_node_in_group("mob_hp_layer")
	if layer:
		layer.add_child(hp_bar_instance)
	
	hp_bar_instance.update_health(hp, max_hp)
	hp_bar_instance.visible = false

func _physics_process(delta):
	if is_dead: return # 核心：如果死了，就不再执行任何移动和攻击逻辑

	# 1. 击退力物理模拟
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
		
	var target = get_nearest_living_player()
	
	if target:
		var dir = (target.global_position - global_position).normalized()
		var dist = global_position.distance_to(target.global_position)
		
		# 2. 移动逻辑
		var move_vel = Vector2.ZERO
		if is_ranged and dist < 250:
			move_vel = Vector2.ZERO 
		else:
			move_vel = dir * speed
			
		velocity = move_vel + knockback_velocity
		
		move_and_slide()
		look_at(target.global_position)
		
		# 3. 攻击逻辑
		if attack_timer > 0: 
			attack_timer -= delta
		else:
			if is_ranged and dist < 350:
				_shoot_at(target)
			elif not is_ranged and dist < 45:
				target.take_damage(damage, Vector2.ZERO)
				attack_timer = 1.0
	
	# 更新血条位置
	if hp_bar_instance:
		hp_bar_instance.position = get_global_transform_with_canvas().origin + Vector2(-32, -50)

func _shoot_at(target):
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	var aim_dir = (target.global_position - global_position).normalized()
	b.velocity = aim_dir * 250
	b.damage = 10
	b.owner_id = "enemies"
	get_parent().add_child(b)
	attack_timer = 2.0

func get_nearest_living_player():
	var players = get_tree().get_nodes_in_group("players")
	var nearest = null
	var min_dist = INF
	for p in players:
		if p.is_ghost or p.is_dead: continue
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest

func take_damage(amount, knockback = Vector2.ZERO):
	if is_dead: return # 鞭尸无效

	hp -= amount
	knockback_velocity = knockback 
	
	# 简单的受击闪烁 (可选)
	modulate = Color(1.5, 1.5, 1.5) # 变亮
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	# 更新血条
	if hp_bar_instance:
		hp_bar_instance.visible = true
		hp_bar_instance.update_health(hp, max_hp)

	if hp <= 0:
		_die()

func _die():
	is_dead = true
	hp = 0
	
	# 1. 加分 (移到这里确保只加一次)
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_alive:
			p.add_score(max_hp/2) # 根据难度加分
	
	# 2. 禁用物理碰撞 (关键！让子弹穿过去)
	$CollisionShape2D.set_deferred("disabled", true)
	
	# 3. 停止物理处理 (停止移动代码)
	set_physics_process(false)
	
	# 4. 血条处理：强制显示为空血，并跟随淡出
	if hp_bar_instance:
		hp_bar_instance.update_health(0, max_hp) # 显式设为0
		# 让血条也半透明消失
		var bar_tween = create_tween()
		bar_tween.tween_property(hp_bar_instance, "modulate:a", 0.0, 0.5)

	# 5. 播放死亡动画 (Tween)
	var tween = create_tween()
	# 并行执行：
	tween.set_parallel(true)
	# 变红 (死亡色)
	tween.tween_property(self, "modulate", Color.RED, 0.2)
	# 变透明 (0.5秒内)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	# 缩小 (0.5秒内缩到 0.5倍)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.5)
	
	# 6. 动画结束后销毁
	tween.chain().tween_callback(queue_free)

func _exit_tree():
	# 清理血条
	if hp_bar_instance and is_instance_valid(hp_bar_instance):
		hp_bar_instance.queue_free()

func get_id():
	return "enemies"
