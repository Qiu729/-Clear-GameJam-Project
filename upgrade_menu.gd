extends CanvasLayer

signal upgrades_complete

@onready var p1_container = $ColorRect/HBoxContainer/VBoxP1
@onready var p2_container = $ColorRect/HBoxContainer/VBoxP2

var p1_options = []
var p2_options = []

var p1_focus_idx = 0
var p2_focus_idx = 0
var p1_confirmed = false
var p2_confirmed = false
var p1_dead = false
var p2_dead = false
var p1_alive
var p2_alive
var p1_ai
var p2_ai

@onready var ready_timer: Timer = $ReadyTimer
var is_ready=false

func _ready():
	ready_timer.start()
	
	# 1. 确保暂停时能运行
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var main = get_parent()
	# 安全获取引用
	if "p1" in main: p1_dead = not main.p1.is_alive
	if "p2" in main: p2_dead = not main.p2.is_alive
	if "p1" in main: p1_alive = main.p1.is_alive
	if "p2" in main: p2_alive = main.p2.is_alive
	if "p1" in main: p1_ai = main.p1.is_agent
	if "p2" in main: p2_ai = main.p2.is_agent
	
	# P1 初始化
	if not p1_alive:
		p1_confirmed = true
		_show_offline_status(p1_container)
	else:
		if p1_ai:p1_confirmed=true
		p1_options = _get_random_upgrades(3)
		_create_buttons(p1_container, p1_options)
		
	# P2 初始化
	if not p2_alive:
		p2_confirmed = true
		_show_offline_status(p2_container)
	else:
		if p2_ai:p2_confirmed=true
		p2_options = _get_random_upgrades(3)
		_create_buttons(p2_container, p2_options)
	
	# 初始化高亮
	_update_visuals()

func _process(_delta):
	if not is_ready:
		return
	
	_check_finish()
	
	# P1 Controls
	if p1_alive:
		if not p1_confirmed:
			if Input.is_action_just_pressed("p1_up"):
				p1_focus_idx = (p1_focus_idx - 1 + p1_options.size()) % p1_options.size()
				_update_visuals()
				SoundManager.play_button_grab()
			elif Input.is_action_just_pressed("p1_down"):
				p1_focus_idx = (p1_focus_idx + 1) % p1_options.size()
				_update_visuals()
				SoundManager.play_button_grab()
			elif Input.is_action_just_pressed("p1_skill"): # E Confirm
				p1_confirmed = true
				_update_visuals()
				_check_finish()
				SoundManager.play_button_click()
		else:
			if Input.is_action_just_pressed("p1_cancel"): # Q Cancel
				p1_confirmed = false
				_update_visuals()

	# P2 Controls
	if p2_alive:
		if not p2_confirmed:
			if Input.is_action_just_pressed("p2_up"):
				p2_focus_idx = (p2_focus_idx - 1 + p2_options.size()) % p2_options.size()
				_update_visuals()
				SoundManager.play_button_grab()
			elif Input.is_action_just_pressed("p2_down"):
				p2_focus_idx = (p2_focus_idx + 1) % p2_options.size()
				_update_visuals()
				SoundManager.play_button_grab()
			elif Input.is_action_just_pressed("p2_skill"): # Shift Confirm
				p2_confirmed = true
				_update_visuals()
				_check_finish()
				SoundManager.play_button_click()
		else:
			if Input.is_action_just_pressed("p2_cancel"): # / Cancel
				p2_confirmed = false
				_update_visuals()

# --- 生成按钮 (带颜色初始化) ---
func _create_buttons(container, options):
	_clear_container(container)
	for data in options:
		var btn = Button.new()
		btn.text = data.name + "\n" + data.desc
		btn.custom_minimum_size = Vector2(240, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# 禁用默认焦点，防止抢占输入
		btn.focus_mode = Control.FOCUS_NONE 
		
		# 初始颜色 (虽然会被 update_visuals 覆盖，但初始化一下也没坏处)
		btn.modulate = _get_rarity_color(data.rarity).darkened(0.5)
		
		container.add_child(btn)

# --- 更新视觉 (核心: 结合了颜色和高亮) ---
func _update_visuals():
	_update_player_visuals(p1_container, p1_options, p1_focus_idx, p1_confirmed, p1_dead)
	_update_player_visuals(p2_container, p2_options, p2_focus_idx, p2_confirmed, p2_dead)

func _update_player_visuals(container, options, focus_idx, confirmed, is_dead):
	if is_dead: return
	
	var buttons = container.get_children()
	
	for i in range(options.size()):
		if i >= buttons.size(): break
		var btn = buttons[i]
		var data = options[i]
		
		if not (btn is Button): continue
		
		# 1. 获取稀有度颜色
		var base_color = _get_rarity_color(data.rarity)
		
		btn.text = data.name + "\n" + data.desc
		
		if confirmed:
			if i == focus_idx:
				btn.modulate = Color.GREEN # 锁定显示绿色
				btn.text = "[ LOCKED ]\n" + data.name
			else:
				btn.modulate = base_color.darkened(0.8) # 其他变暗
		else:
			if i == focus_idx:
				# 选中：全亮
				btn.modulate = base_color 
				btn.text = "> " + data.name + "\n" + data.desc
			else:
				# 未选中：变暗
				btn.modulate = base_color.darkened(0.5)

# --- 辅助函数 ---
func _get_rarity_color(rarity):
	match rarity:
		"RARE": return Color(0.4, 0.6, 1.0)
		"LEGENDARY": return Color(1.0, 0.8, 0.2)
		_: return Color(0.9, 0.9, 0.9)

func _get_random_upgrades(count):
	var pool = Global.UPGRADE_POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, count)

func _clear_container(container):
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _show_offline_status(container):
	_clear_container(container)
	var label = Label.new()
	label.text = "\n[ UNIT OFFLINE ]\n"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color.RED
	container.add_child(label)

func _check_finish():
	if p1_confirmed and p2_confirmed:
		await get_tree().create_timer(0.5).timeout
		_apply_and_close()

func _apply_and_close():
	var main = get_parent()
	if p1_alive: main.p1.apply_upgrade(p1_options[p1_focus_idx])
	if p2_alive: main.p2.apply_upgrade(p2_options[p2_focus_idx])
	emit_signal("upgrades_complete")
	queue_free()


func _on_ready_timer_timeout() -> void:
	is_ready=true
