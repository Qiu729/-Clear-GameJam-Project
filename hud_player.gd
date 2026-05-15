extends CanvasLayer

# 节点引用
@onready var p1_hp_bar = $HUD_P1/Content/HBox/InfoBox/HPBar
@onready var p1_skill_bar = $HUD_P1/Content/HBox/InfoBox/SkillBar
@onready var p1_hp_text = $HUD_P1/Content/HBox/InfoBox/Header/Value
@onready var p1_score_text = $HUD_P1/Content/HBox/InfoBox/Header/score


@onready var p2_hp_bar = $HUD_P2/Content/HBox/InfoBox/HPBar
@onready var p2_skill_bar = $HUD_P2/Content/HBox/InfoBox/SkillBar
@onready var p2_hp_text = $HUD_P2/Content/HBox/InfoBox/Header/Value
@onready var p2_score_text = $HUD_P2/Content/HBox/InfoBox/Header/score

func update_p1(current_hp, max_hp, current_cd, max_cd, score,is_shield_class):
	# 更新血条 (直接比例)
	p1_hp_bar.max_value = max_hp
	p1_hp_bar.value = current_hp
	p1_hp_text.text = "%d / %d" % [current_hp, max_hp]
	
	p1_score_text.text="  score:%d" % [score]
	
	# 更新技能条 (修复逻辑)
	if is_shield_class:
		# 盾兵：current_cd 其实是 energy (能量越高越好)
		p1_skill_bar.max_value = max_cd
		p1_skill_bar.value = current_cd
		p1_skill_bar.tint_progress = Color.CYAN # 盾兵蓝色能量
	else:
		# 其他职业：current_cd 是剩余时间 (0 是好的)
		# 我们希望：冷却中=空，就绪=满
		p1_skill_bar.max_value = max_cd
		# 反转逻辑： (1 - (剩余时间 / 总时间)) * 总时间
		p1_skill_bar.value = max_cd - current_cd
		
		# 视觉反馈：就绪时金色，冷却时灰色
		if current_cd <= 0:
			p1_skill_bar.tint_progress = Color.GOLD # 就绪！
		else:
			p1_skill_bar.tint_progress = Color.GRAY # 冷却中...

func update_p2(current_hp, max_hp, current_cd, max_cd, score, is_shield_class):
	# P2 逻辑同上
	p2_hp_bar.max_value = max_hp
	p2_hp_bar.value = current_hp
	p2_hp_text.text = "%d / %d" % [current_hp, max_hp]
	
	p2_score_text.text="  score:%d" % [score]
		
	if is_shield_class:
		p2_skill_bar.max_value = max_cd
		p2_skill_bar.value = current_cd
		p2_skill_bar.tint_progress = Color.CYAN
	else:
		p2_skill_bar.max_value = max_cd
		p2_skill_bar.value = max_cd - current_cd
		if current_cd <= 0:
			p2_skill_bar.tint_progress = Color.GOLD
		else:
			p2_skill_bar.tint_progress = Color.GRAY
