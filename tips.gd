extends CanvasLayer

# 节点引用
@onready var tip_label: RichTextLabel = $HBox/Content
@onready var auto_timer: Timer = $AutoTimer

# 配置参数
@export var enable_auto_switch: bool = true    # 是否启用自动切换

# 内部变量
var current_index: int = 0
var tips_pool

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("last_tips"):
		_switch_tip(-1)
	if Input.is_action_just_pressed("next_tips"):
		_switch_tip(1)

func _ready():
	# 初始化Tips池
	tips_pool=Global.TIP_POOL.duplicate()
	
	# 打乱
	tips_pool.shuffle()
	
	# 设置定时器
	if enable_auto_switch:
		auto_timer.start()

	auto_timer.connect("timeout", _on_auto_timer_timeout)
	
	# 显示初始Tip
	_show_current_tip()

func _show_current_tip():

	current_index = wrapi(current_index, 0, tips_pool.size())
	var current_tip = tips_pool[current_index]
	
	# 使用居中对齐的富文本
	tip_label.text="[center]"+current_tip+"[/center]"
	
func _switch_tip(direction: int):
	if tips_pool.size() <= 1:
		return
	
	current_index = wrapi(current_index + direction, 0, tips_pool.size())
	_show_current_tip()
	
	# 手动切换时重置自动计时器
	if enable_auto_switch:
		auto_timer.start()

func _on_auto_timer_timeout():
	"""自动切换定时器超时"""
	if enable_auto_switch:
		_switch_tip(1)
