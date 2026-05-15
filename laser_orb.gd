extends Area2D

var speed = 160.0 # 缓慢移动
var damage = 60   # 单次伤害较高
var duration = 4.0 # 存在时间

var hit_list = [] # 记录已攻击过的敌人，实现穿透效果

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 视觉调整：稍微放大一点，并设置半透明增加激光感
	modulate.a = 0.9 

func _physics_process(delta):
	# 1. 向前移动
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
	# 2. 寿命管理
	duration -= delta
	if duration <= 0:
		queue_free()

# --- 伤害敌人的逻辑 ---
func _on_body_entered(body):
	# 如果是敌人，且还没被这颗球烫过
	if body.is_in_group("enemies") and body not in hit_list:
		if body.has_method("take_damage"):
			# 施加伤害和微弱的击退
			var kb_dir = Vector2.RIGHT.rotated(rotation)
			body.take_damage(damage, kb_dir * 100)
			
			# 加入名单，不再造成二次伤害
			# (如果你想要持续伤害，可以用 Timer 清空这个 list)
			hit_list.append(body)

# --- 摧毁敌方子弹的逻辑 ---
func _on_area_entered(area):
	# 假设你的子弹脚本里有 owner_id 变量
	if "owner_id" in area:
		if area.owner_id == "enemies":
			# 产生一个小的消弹特效 (可选)
			# spawn_effect(area.global_position)
			
			# 销毁敌人的子弹
			area.queue_free()
