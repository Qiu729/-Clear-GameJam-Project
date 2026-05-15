extends Area2D

# 节点引用
@onready var point_light: PointLight2D = $PointLight2D
@onready var interaction_timer: Timer = $InteractionTimer

# 可配置参数
@export var detection_radius: float = 60.0  # 检测半径
@export var required_stay_time: float = 3.0  # 需要停留的时间（秒）
@export var color_change_speed: float = 2.0  # 颜色变化速度

# 内部变量
var player_in_range: bool = false
var current_hue: float = 0.0
var player_node: Node = null

func _ready():
	# 设置碰撞检测区域
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_radius
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	# 设置交互计时器
	interaction_timer.wait_time = required_stay_time
	interaction_timer.one_shot = true
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interaction_timer.timeout.connect(_on_interaction_timeout)

func _process(delta):
	# 更新灯光颜色，实现彩虹效果
	current_hue += delta * color_change_speed
	if current_hue >= 1.0:
		current_hue = 0.0
	
	point_light.color = Color.from_hsv(current_hue, 0.8, 1.0, 1.0)
	
	# 如果玩家在范围内，可以添加一些额外的视觉效果
	if player_in_range:
		# 例如：灯光闪烁或强度变化
		point_light.energy = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.3

func _on_body_entered(body: Node):
	# 检查进入的物体是否是玩家
	if body.is_in_group("players"):
		player_in_range = true
		player_node = body
		print("玩家接近彩蛋!")
		
		# 开始计时
		interaction_timer.start()

func _on_body_exited(body: Node):
	# 检查离开的物体是否是玩家
	if body.is_in_group("players"):
		player_in_range = false
		player_node = null
		print("玩家离开彩蛋范围")
		
		# 停止计时
		interaction_timer.stop()
		
		# 恢复灯光强度
		point_light.energy = 1.0

func _on_interaction_timeout():
	# 玩家在范围内停留足够时间，触发彩蛋
	if player_node != null:
		print("彩蛋触发!")
		
		# 调用玩家的函数
		if player_node.has_method("on_secret_found"):
			player_node.on_secret_found()
		else:
			print("玩家节点没有找到 on_secret_found 方法")
		
		# 可以添加一些特效
		_play_activation_effects()
		
		# 禁用彩蛋，防止重复触发
		set_process(false)
		interaction_timer.stop()
		player_in_range = false
		
	hide()

func _play_activation_effects():
	# 彩蛋激活时的特效
	# 例如：灯光闪烁、粒子效果等
	
	# 创建闪烁效果
	var tween = create_tween()
	tween.tween_property(point_light, "energy", 2.0, 0.2)
	tween.tween_property(point_light, "energy", 0.5, 0.2)
	tween.tween_property(point_light, "energy", 2.0, 0.2)
	tween.tween_property(point_light, "energy", 1.0, 0.2)
	
	# 可以在这里添加粒子效果或声音
	# 例如: $Particles2D.emitting = true
