extends CanvasLayer

signal event_finished(success) # 信号：事件结束，参数代表是否获得了奖励

@onready var title_label = $VBoxContainer/Title
@onready var desc_label = $VBoxContainer/Desc

@onready var btn1 = $VBoxContainer/Option1
@onready var btn2 = $VBoxContainer/Option2
@onready var result_label = $VBoxContainer/ResultLabel
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var ready_timer: Timer = $ReadyTimer

var is_ready=false

var current_event = null
var focus_index = 0
var is_result_shown = false

var p1_ai
var p2_ai

func _ready():
	ready_timer.start()
	
	var main = get_parent()
	if "p1" in main: p1_ai = main.p1.is_agent
	if "p2" in main: p2_ai = main.p2.is_agent
	
	# 1. 随机抽取一个事件
	current_event = Global.RANDOM_EVENTS.pick_random()
	
	# 2. 填充 UI
	title_label.text = current_event.title
	desc_label.text = current_event.desc
	btn1.text = "A: " + current_event.options[0].text
	btn2.text = "B: " + current_event.options[1].text
	
	print(current_event.desc)
	
	result_label.text = ""
	_update_focus()
	
	if p1_ai and p2_ai:
		_make_choice(0)

func _process(delta):
	if not is_ready:
		return	
	
	if p1_ai and p2_ai:
		_close_menu()
		
	if is_result_shown:
		return
	# 选择阶段：P1 和 P2 都能控制上下
	if Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p2_up"):
		focus_index = 0
		_update_focus()
		SoundManager.play_sfx("ButtonGrab")
	elif Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("p2_down"):
		focus_index = 1
		_update_focus()
		SoundManager.play_sfx("ButtonGrab")
		
	# 确认选择
	if Input.is_action_just_pressed("p1_skill") or Input.is_action_just_pressed("p2_skill"):
		_make_choice(focus_index)
		SoundManager.play_sfx("ButtonPressed")

func _update_focus():
	# 简单的高亮逻辑
	btn1.modulate = Color.YELLOW if focus_index == 0 else Color.WHITE
	btn2.modulate = Color.YELLOW if focus_index == 1 else Color.WHITE
	
	# 也可以加箭头前缀
	btn1.text = ("> " if focus_index == 0 else "   ") + "A: " + current_event.options[0].text
	btn2.text = ("> " if focus_index == 1 else "   ") + "B: " + current_event.options[1].text

func _make_choice(idx):
	is_result_shown = true
	var choice = current_event.options[idx]
	var is_correct = choice.correct
	quit_button.show()
	quit_button.grab_focus()
	btn1.focus_mode=Control.FocusMode.FOCUS_NONE
	btn2.focus_mode=Control.FocusMode.FOCUS_NONE
	# 显示结果文本
	result_label.text = choice.msg
	result_label.modulate = Color.GREEN if is_correct else Color.RED
	
	# 禁用按钮视觉
	btn1.disabled = true
	btn2.disabled = true
	
	# 如果正确，发射信号带参数 true，否则 false
	# 但这里我们暂不直接关闭，而是等玩家看完文字再按一次键
	# 真正的数据处理在关闭时提交
	if is_correct:
		print("Choice Correct!")
	else:
		print("Choice Wrong!")

func _close_menu():
	# 再次检查当前选择是否正确，发送信号
	var is_correct = current_event.options[focus_index].correct
	emit_signal("event_finished", is_correct)
	queue_free()


func _on_quit_button_pressed() -> void:
	_close_menu()


func _on_ready_timer_timeout() -> void:
	is_ready=true
