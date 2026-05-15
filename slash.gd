extends Area2D

var damage = 40
var knockback_force = 300.0
var duration = 0.4 # 剑气存在的时间，很短
var speed = 450.0  # 剑气也会稍微往前飞一点点，增加打击感

var is_ghost_slash=false

# 记录已经攻击过的敌人，实现穿透效果（一刀砍一片）
var hit_list = [] 

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 初始透明度设为 1
	modulate.a = 1.0

func _physics_process(delta):
	# 1. 剑气向前推进一点点
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	
	# 2. 视觉效果：逐渐变透明
	duration -= delta
	modulate.a = duration / 0.3 # 随着时间减少透明度
	
	if duration <= 0:
		queue_free()
		
func _on_area_entered(area):
	if area.is_in_group("shields") and is_ghost_slash:
		queue_free()

func _on_body_entered(body):
	# 如果是敌人或者幽灵剑气，并且还没被这道剑气打过
	if (body.is_in_group("enemies") or is_ghost_slash) and body not in hit_list:
		if body.has_method("take_damage"):
			# 计算击退方向：从剑气中心推向敌人
			var kb_dir = (body.global_position - global_position).normalized()
			body.take_damage(damage, kb_dir * knockback_force)
			
			# 加入黑名单，防止下一帧重复造成伤害
			hit_list.append(body)
			
			# 狂暴模式回血
			var players=get_tree().get_nodes_in_group("players")

			for p in players:
				var mx_times=10
				if p.skill_level==2:
					mx_times=15
				elif p.skill_level>=3:
					mx_times=20
				if p.curr_addhp_count > mx_times:
					continue
				p.curr_addhp_count+=1
				
				if p.is_berserk:
					var addhp=3 * p.skill_level
					p.hp=min(p.max_hp,p.hp+addhp)
