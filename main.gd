extends Node2D

@onready var p1 = $players/Player1
@onready var p2 = $players/Player2
@onready var p1_name_label: Label = $GUICanvas/p1_name
@onready var p2_name_label: Label = $GUICanvas/p2_name
@onready var ui_layer = $GUICanvas
@onready var pauseMenu = $GUICanvas/PausePanel # 暂停界面
@onready var pauseMenu_resume_btn = $GUICanvas/PausePanel/CancelButton
@onready var endMenu = $GUICanvas/EndPanel
@onready var endMenu_resume_btn = $GUICanvas/EndPanel/RestartButton
@onready var messagePanel = $GUICanvas/MessagePanel
@onready var messageLabel = $GUICanvas/MessagePanel/Label
@onready var game_timer: Timer = $GameTimer
@onready var message_timer: Timer = $MessageTimer
@onready var wave_message: Label = $GUICanvas/WaveMessage
@onready var score_message: Label = $GUICanvas/ScoreMessage

var enemy_scene = preload("res://enemy.tscn")
var wave = 1
var game_time = 0.0
var spawn_timer = 0.0
var is_message_show = false

# 补给波次
var upgrade_menu_scene = preload("res://upgrade_menu.tscn")
var wave_duration = 30.0 # 每一波 30 秒
var event_possible=0.3
var current_wave_timer = 0.0

# 偶遇事件
var event_menu_scene = preload("res://event_menu.tscn")

var egg=preload("res://egg.tscn")
var has_egg = false

var diffculty=1.0

func show_message(content):
	messagePanel.show()
	message_timer.start()
	messageLabel.text=content

func _ready():
	diffculty=Global.diffc
	print("难度设置为："+str(diffculty))
	p1.setup_character(Global.p1_class,"p1")
	p2.setup_character(Global.p2_class,"p2")
	p1_name_label.text=p1.player_id
	p2_name_label.text=p2.player_id
	
	game_timer.start()
	
	SoundManager.play_random_music()
	
func _process(delta):
	if get_tree().paused: return
	
	# 暂停功能
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()
	
	if get_tree().paused: return

	game_time += delta
	
	# 角色信息更新
	update_ui()
	
	# 游戏结束检测
	if not (p1.is_alive or p2.is_alive):
		game_over()

	# 尸潮刷怪逻辑
	spawn_timer -= delta
	if spawn_timer <= 0:
		trigger_horde_spawn() # <--- 这里改成调用新的尸潮函数
		
	# 波次计时器
	current_wave_timer += delta
	if wave_duration - current_wave_timer <= 3 and is_message_show == false:
		messagePanel.show()
		messageLabel.text = "补给3s后到达"
		message_timer.start()
		is_message_show = true
	if current_wave_timer >= wave_duration:
		start_supply_drop()
		# 重置消息标记
		is_message_show = false	

	# --- 新增：互救逻辑 ---
	_check_revive(p1, p2, delta) # P1 救 P2
	_check_revive(p2, p1, delta) # P2 救 P1
	
	if not has_egg and p1.score>=10000:
		has_egg=true
		var egg_instance=egg.instantiate()
		add_child(egg_instance)
		

func _check_revive(rescuer, victim, delta):
	# 条件：救人者必须活着，被救者必须是 Downed 状态
	if rescuer.is_alive and victim.is_downed:
		var dist = rescuer.global_position.distance_to(victim.global_position)

		# 距离判断 (例如 60 像素内)
		if dist < 60:
			# 增加复活进度
			victim.revive_progress += victim.REVIVE_SPEED * delta

			# 复活成功
			if victim.revive_progress >= victim.MAX_REVIVE:
				victim.get_revived()
		else:
			# 离开范围，进度衰减
			victim.revive_progress = max(0, victim.revive_progress - (victim.REVIVE_SPEED * 2 * delta))

func spawn_enemy():
	var e = enemy_scene.instantiate()
	var angle = randf() * TAU
	var dist = 600 # 屏幕外
	e.global_position = Vector2(512, 384) + Vector2(cos(angle), sin(angle)) * dist
	
	if randf() > 0.8:
		e.is_ranged = true
		e.modulate = Color.PURPLE
	
	add_child(e)

func update_ui():
	var hud = $HUD
	if not hud: return
	
	# 准备 P1 数据
	var p1_cd = p1.skill_cooldown_timer
	var p1_max_cd = p1.max_skill_cd
	if p1.class_type == "盾兵":
		p1_cd = p1.shield_energy # 盾兵传能量
		p1_max_cd = p1.max_shield_energy
		
	# 准备 P2 数据 (同理)
	var p2_cd = p2.skill_cooldown_timer
	var p2_max_cd = p2.max_skill_cd
	if p2.class_type == "盾兵":
		p2_cd = p2.shield_energy
		p2_max_cd = p2.max_shield_energy
	
	var offset=Vector2(-12,-50)
	var aiOffset=Vector2(-27,0)
	p1_name_label.position=p1.global_position
	p1_name_label.position+=offset
	if p1.is_agent:p1_name_label.position+=aiOffset
	p2_name_label.position=p2.global_position
	p2_name_label.position+=offset
	if p2.is_agent:p2_name_label.position+=aiOffset

	# 调用 HUD 更新
	hud.update_p1(p1.hp, p1.max_hp, p1_cd, p1_max_cd, p1.score, p1.class_type == "盾兵")
	hud.update_p2(p2.hp, p2.max_hp, p2_cd, p2_max_cd, p1.score, p2.class_type == "盾兵")
	
	score_message.text="得分:"+str(int(p1.score))
	
	if p1.is_agent:
		p1_name_label.text="p1[ai agent]"
	else:
		p1_name_label.text="p1"
	if p2.is_agent:
		p2_name_label.text="p2[ai agent]"
	else:
		p2_name_label.text="p2"

func toggle_pause():
	messagePanel.hide()
	pauseMenu.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	pauseMenu_resume_btn.grab_focus()
	var tree = get_tree()
	tree.paused = not tree.paused

func game_over():
	messagePanel.hide()
	endMenu.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	endMenu_resume_btn.grab_focus()
	get_tree().paused = true

# 绑定给菜单按钮的函数
func _on_restart_pressed():
	get_tree().paused = false
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	get_tree().reload_current_scene()


func _on_cancel_button_pressed() -> void:
	get_tree().paused=false
	pauseMenu.visible=false	
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN


func _on_game_timer_timeout() -> void:
	p1.score += 30
	p2.score += 30

func _on_exit_button_pressed() -> void:
	get_tree().paused=false
	# 退回到开始菜单
	get_tree().change_scene_to_file("res://main_menu.tscn")
	SoundManager.stop_music()
	
func start_supply_drop():
	current_wave_timer = 0.0
	wave += 1
	# 更新waveUI
	wave_message.text="第%d波"%[wave]
	get_tree().paused = true
	
	# 这里可以提高下一波怪的数值
	
	# --- 偶遇事件逻辑 ---
	var trigger_chance = event_possible # 30% 概率
	
	if randf() < trigger_chance:
		# 触发事件
		var event = event_menu_scene.instantiate()
		event.connect("event_finished", _on_event_finished)
		add_child(event)
	else:
		# 没触发，直接开补给
		_open_upgrade_menu()


func _on_upgrades_complete():
	# 菜单发信号说选完了，恢复游戏
	get_tree().paused = false
	print("Wave ", wave, " Start!")

func _on_message_timer_timeout() -> void:
	messagePanel.hide()

# --- 新增：尸潮触发器 ---
func trigger_horde_spawn():
	var diff_mul=diffculty/2.0 #越大越难
	# 难度公式：
	# 数量：基础3只，每2波增加1只 (Wave 1=2只, Wave 10=7只)
	var burst_count = 3 + int(wave / 2) * diff_mul
	
	# 频率：基础2秒刷一波，随波次加快，最快1秒一波
	var next_interval = max(1.0, 2.0 - (wave * 0.15)) / diff_mul
	
	# 循环生成这一群怪
	for i in range(burst_count):
		spawn_single_enemy()
	
	# 重置计时器
	spawn_timer = next_interval

# --- 新增：单只怪物生成 (包含精英怪逻辑) ---
func spawn_single_enemy():
	var e = enemy_scene.instantiate()
	var diff_mul=diffculty/2.0 #越大越难
	# 1. 位置计算：在屏幕中心周围一圈生成，向内包围
	# 使用 Viewport 尺寸的一半作为中心点
	var center = get_viewport_rect().size / 2
	var angle = randf() * TAU
	# 生成距离：屏幕半径(约600) + 随机波动，保证在屏幕外生成
	var dist = 600 + randf_range(0, 100)
	e.global_position = center + Vector2(cos(angle), sin(angle)) * dist
	
	# 2. 精英怪判定 (5% 几率)
	var is_elite = randf() > 0.95
	
	var waveMul = 1.0
	if wave>=3:
		waveMul = wave/3  # min(wave/3,5)
	
	if is_elite:
		# --- 精英怪属性 ---
		e.scale = Vector2(1.5, 1.5) * min(waveMul,5) # 体型变大,限制最大大小
		e.modulate = Color(2.0, 0.4, 0.4) # 变红高亮
		e.max_hp = (30 + (wave * 10)) * 3 * waveMul* diff_mul# 血量 x3
		e.damage = 20 * waveMul* diff_mul
		e.speed *= 0.85 # 速度稍慢，压迫感
		e.is_ranged = false # 精英强制近战
	else:
		# --- 普通怪属性 ---
		e.hp = 30 + (wave * 10)* diff_mul
		
		# 20% 几率是远程怪
		if randf() > 0.8:
			e.is_ranged = true
			e.modulate = Color(0.6, 0.4, 1.0) # 紫色
			e.max_hp *= 0.7 * waveMul
		else:
			e.is_ranged = false
			e.modulate = Color(0.4, 0.8, 0.4) # 绿色

	add_child(e)

# 事件结束的回调
func _on_event_finished(success):
	if success:
		print("事件成功！获得技能提升奖励")
		
		if p1.skill_level>=3 or p2.skill_level>=3:
			_open_upgrade_menu()
			return
		if p1.is_alive:
			p1.upgrade_skill()
		if p2.is_alive:
			p2.upgrade_skill()
	else:
		print("事件失败，无奖励")
	get_tree().paused = false

# 抽离出来的补给菜单函数
func _open_upgrade_menu():
	var menu = upgrade_menu_scene.instantiate()
	if menu.has_signal("upgrades_complete"):
		menu.connect("upgrades_complete", _on_upgrades_complete)
	add_child(menu)
