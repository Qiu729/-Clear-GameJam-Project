extends TextureProgressBar

func update_health(current, max_val):
	max_value = max_val
	
	# 创建动画补间
	var tween = get_tree().create_tween()
	# 在 0.1 秒内把 value 属性变成 current
	tween.tween_property(self, "value", current, 0.1).set_trans(Tween.TRANS_SINE)
