extends Area2D

var velocity = Vector2.ZERO
var damage = 10
var duration = 2.0 # 秒
var owner_id = "" # "p1", "p2", 或 "enemy"
var knockback_force = 0.0
var is_ghost_bullet = false # 新增变量

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	position += velocity * delta
	duration -= delta
	if duration <= 0:
		queue_free()
		
func _on_area_entered(area):
	if area.is_in_group("shields") and (owner_id == "enemies" or is_ghost_bullet):
		queue_free()
		# 播放击中护盾的音效
		SoundManager.play_sfx("ShieldHit")

func _on_body_entered(body):
	# 防止打到自己
	if body.has_method("get_id") and body.get_id() == owner_id:
		return
		
	# 击中逻辑
	if body.has_method("take_damage"):
		# A. 打敌人 (正常逻辑)
		if body.is_in_group("enemies"):
			body.take_damage(damage)
			queue_free()
			
		# B. 打player
		elif body.is_in_group("players") and (is_ghost_bullet or owner_id == "enemies"):
			# 只有当对方不是幽灵且不是濒死时才造成伤害
			if not body.is_ghost and not body.is_downed:
				body.take_damage(damage)
				queue_free()
