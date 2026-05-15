extends Control

@onready var p1_selector = $P1Panel/OptionButton
@onready var p2_selector = $P2Panel/OptionButton
@onready var start_btn = $StartButton
@onready var p2_type_des: Label = $P2Panel/typeDes
@onready var p1_type_des: Label = $P1Panel/typeDes
@onready var diffc_button: OptionButton = $OptionButton


var worrorDes="剑士：普通攻击是释放剑气,\n开启技能进入狂暴状态，提高输出能力，同时获得回血效果。\n技能等级2：获得更高输出能力；技能等级3：狂暴状态无限持续时间！"
var riflerDes="步兵：发射子弹进行攻击,\n开启技能会释放一个量子球，能够对路径对人造成伤害，还能摧毁子弹。\n技能等级2：获得更高输出能力；\n技能等级3：获得一个特殊的量子球跟随，能够挡住子弹。"
var shieldDes="盾兵：点击技能开启量子护盾，再次点击关闭护盾。\n护盾开启期间持续消耗能量，护盾能够击退敌人并造成伤害和抵挡子弹\n但是阻挡的敌人有上限\n技能等级2：降低能耗；技能等级3：不消耗能量。"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 初始化下拉菜单
	add_items(p1_selector)
	add_items(p2_selector)
	
	# 设置默认选中项
	p1_selector.selected = 0 # 剑士
	p2_selector.selected = 1 # 步兵
	
	start_btn.pressed.connect(_on_start_pressed)
	
func _process(delta: float) -> void:
	if p1_selector.selected == 0:
		p1_type_des.text=worrorDes
	elif p1_selector.selected == 1:
		p1_type_des.text=riflerDes
	else:
		p1_type_des.text=shieldDes
		
	if p2_selector.selected == 0:
		p2_type_des.text=worrorDes
	elif p2_selector.selected == 1:
		p2_type_des.text=riflerDes
	else:
		p2_type_des.text=shieldDes

func add_items(btn: OptionButton):
	# 对应 Global.CLASS_DATA 的键
	btn.add_item("剑士")
	btn.add_item("步兵")
	btn.add_item("盾兵")

func _on_start_pressed():
	# 1. 保存选择到全局变量
	Global.p1_class = p1_selector.get_item_text(p1_selector.selected)
	Global.p2_class = p2_selector.get_item_text(p2_selector.selected)
	Global.diffc=diffc_button.selected+1
	
	# 2. 切换到游戏场景
	get_tree().change_scene_to_file("res://main.tscn")
	
	SoundManager.play_sfx("GameStarted")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
