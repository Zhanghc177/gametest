extends CharacterBody2D

## Enemy Beetle - AI melee attack type

# Animation state machine
enum AnimState { IDLE, WALK, ATTACK, CHARGE, DEAD }
var current_animation: AnimState = AnimState.IDLE
var anim_frame: int = 0
var anim_timer: float = 0.0
const ANIM_FRAME_TIME: float = 0.12

const HP: float = 55.0
const ATK: float = 25.0
const SPEED: float = 140.0
const ATK_RANGE: float = 70.0
const ATK_COOL: float = 2.5
const CHARGE_TIME: float = 1.3
const WARN_RANGE: float = 90.0
const PATROL_RANGE: float = 120.0
const PREDICTION_FACTOR: float = 0.5

# AI 智能参数
const CAUTION_THRESHOLD: float = 0.35
const ENEMY_AWARENESS_RANGE: float = 280.0

var hp: float = HP
var attack_direction: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var move_timer: float = 0.0
var warn_timer: float = 0.0

var invincible: float = 0.0
var warn_fan: Polygon2D = null
var pulse_circle: Polygon2D = null
var attack_range_box: Polygon2D = null
var countdown_label: Label = null
var pulse_timer: float = 0.0

# Glow effect nodes
var glow_outline: Polygon2D = null
var glow_pulse_timer: float = 0.0
var base_glow_color: Color = Color(0.4, 0.6, 1.0, 0.3)

var spawn_position: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var is_patrolling: bool = false
var patrol_timer: float = 0.0

# 外观变体参数
var color_variant: Color = Color.WHITE
var size_scale: float = 1.0
var marker_nodes: Array = []

@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	hp = HP
	spawn_position = global_position
	patrol_target = global_position
	health_bar.max_value = HP
	health_bar.value = hp
	_apply_appearance_variants()
	# _init_glow_effect()  # TEMP DISABLED - causing hang

## 应用外观变体：随机颜色、尺寸、标记
func _apply_appearance_variants() -> void:
	# 随机颜色变体 - 在基础色上做偏移
	var base_color = Color(0.29, 0.345, 0.416, 1)
	var h_offset = randf_range(-0.05, 0.05)
	var s_offset = randf_range(-0.15, 0.15)
	var v_offset = randf_range(-0.1, 0.1)

	# HSV调整
	var hsv = Color()
	hsv.r = fmod(base_color.r + h_offset, 1.0) if base_color.r + h_offset > 0 else 1.0 + base_color.r + h_offset
	hsv.g = clamp(base_color.g + s_offset, 0.0, 1.0)
	hsv.b = clamp(base_color.b + v_offset, 0.0, 1.0)
	hsv.a = 1.0
	color_variant = hsv

	# 应用颜色到身体部件
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.color = _adjust_color(base_color, 0.0, 0.0, 0.0)
	if head:
		head.color = _adjust_color(base_color, 0.06, 0.07, 0.08)

	# 随机大小变化 ±10%
	size_scale = randf_range(0.9, 1.1)
	scale = Vector2(size_scale, size_scale)

	# 添加随机标记（斑点或条纹）
	_add_random_marker()

## 调整颜色
func _adjust_color(base: Color, r_off: float, g_off: float, b_off: float) -> Color:
	return Color(clamp(base.r + r_off, 0, 1), clamp(base.g + g_off, 0, 1), clamp(base.b + b_off, 0, 1), base.a)

## 初始化发光轮廓效果
func _init_glow_effect() -> void:
	glow_outline = Polygon2D.new()
	# 创建稍微放大的身体轮廓形状
	var body = get_node_or_null("Body")
	if body:
		# 复制身体的形状作为发光轮廓
		var offset_scale = 1.15
		glow_outline.global_position = global_position
		glow_outline.rotation = rotation
		glow_outline.scale = Vector2(offset_scale, offset_scale)
		glow_outline.color = base_glow_color
		glow_outline.z_index = -1  # 放在身体后面
		get_tree().root.call_deferred("add_child", glow_outline)

## 更新发光脉冲效果
func _update_glow_effect(delta: float) -> void:
	glow_pulse_timer += delta
	var pulse = (sin(glow_pulse_timer * 3.0) + 1.0) * 0.5  # 0-1 脉冲

	# 根据冷色调敌人主题设置蓝紫色发光
	var glow_color = Color(0.3 + pulse * 0.2, 0.5 + pulse * 0.2, 1.0, 0.2 + pulse * 0.15)

	if glow_outline:
		glow_outline.global_position = global_position
		glow_outline.rotation = rotation
		glow_outline.color = glow_color

## 清理发光效果
func _cleanup_glow_effect() -> void:
	if glow_outline:
		glow_outline.queue_free()
		glow_outline = null

## 添加随机标记
func _add_random_marker() -> void:
	var marker_type = randi() % 3  # 0=斑点, 1=条纹, 2=无标记

	if marker_type == 0:
		# 斑点
		_add_spots()
	elif marker_type == 1:
		# 条纹
		_add_stripes()

## 添加斑点标记
func _add_spots() -> void:
	var spot_count = randi() % 3 + 2  # 2-4个斑点
	var body = get_node_or_null("Body")
	if not body:
		return

	for i in range(spot_count):
		var spot = ColorRect.new()
		var spot_size = randf_range(3.0, 6.0)
		spot.size = Vector2(spot_size, spot_size)
		spot.color = Color(0.15, 0.15, 0.18, 0.7)

		# 随机位置
		var offset_x = randf_range(-12.0, 12.0)
		var offset_y = randf_range(-10.0, 15.0)
		spot.position = Vector2(offset_x, offset_y)
		spot.anchor_left = 0.5
		spot.anchor_top = 0.5
		spot.anchor_right = 0.5
		spot.anchor_bottom = 0.5

		body.add_child(spot)
		marker_nodes.append(spot)

## 添加条纹标记
func _add_stripes() -> void:
	var stripe_count = randi() % 2 + 1  # 1-2条
	var body = get_node_or_null("Body")
	if not body:
		return

	for i in range(stripe_count):
		var stripe = ColorRect.new()
		stripe.size = Vector2(3.0, randf_range(15.0, 25.0))
		stripe.color = Color(0.15, 0.15, 0.18, 0.5)

		var offset_x = randf_range(-10.0, 10.0)
		var offset_y = randf_range(-5.0, 10.0)
		stripe.position = Vector2(offset_x, offset_y)
		stripe.rotation = randf_range(-0.3, 0.3)

		body.add_child(stripe)
		marker_nodes.append(stripe)

func _physics_process(delta: float) -> void:
	# 更新动画状态机
	_update_animation(delta)
	# _update_glow_effect(delta)  # TEMP DISABLED
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("game_running") == false:
		hide_warn_fan()
		_hide_warning_effects()
		_hide_attack_range_box()
		_hide_countdown()
		return

	if invincible > 0:
		invincible -= delta
		modulate.a = 0.5 if fmod(invincible, 0.1) < 0.05 else 1.0
	else:
		modulate.a = 1.0

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# 检查玩家是否隐形
	if player.has_method("is_stealthed") and player.is_stealthed():
		# 隐形时停止追踪，不进行任何攻击行为
		return

	# 预测玩家位置（用于追踪逃跑方向）
	var predicted_pos = _predict_player_position()
	var d = global_position.distance_to(predicted_pos)
	var atk_dist = ATK_RANGE + 24

	# 谨慎模式降低移动积极性
	var speed_mult = 1.0
	if _is_in_caution_mode():
		speed_mult = 0.7

	if d < WARN_RANGE and not is_attacking and attack_cooldown <= 0:
		warn_timer += delta
		_update_warning_pulse(delta)
	else:
		warn_timer = max(0, warn_timer - delta * 0.5)
		_hide_warning_effects()

	if d < atk_dist:
		if attack_cooldown <= 0 and not is_attacking:
			start_attack()
		if is_attacking and attack_timer <= 0:
			perform_attack()
		is_patrolling = false
	else:
		if is_attacking and attack_timer > CHARGE_TIME * 0.5:
			is_attacking = false
			attack_cooldown = 0.6
			hide_warn_fan()

		# Patrol when player not in warn range, chase when in warn range
		if d < WARN_RANGE:
			# Player detected - chase with predictive tracking
			is_patrolling = false
			move_timer -= delta
			if move_timer <= 0:
				move_timer = randf_range(0.6, 1.5)

				# 协作包围：检查是否需要绕到玩家身后
				var surround_pos = _calculate_surround_position()
				var target_pos = predicted_pos
				if surround_pos != Vector2.ZERO and not _is_in_caution_mode():
					target_pos = surround_pos

				var dir = (target_pos - global_position).normalized()
				dir = dir.rotated(randf_range(-0.3, 0.3))
				global_position += dir * SPEED * delta * speed_mult
		else:
			# Player not detected - patrol around spawn position
			is_patrolling = true
			patrol_timer -= delta
			if patrol_timer <= 0 or global_position.distance_to(patrol_target) < 10:
				patrol_timer = randf_range(1.5, 3.0)
				# Pick random point within patrol range of spawn position
				var angle = randf_range(0, TAU)
				var dist = randf_range(20, PATROL_RANGE)
				patrol_target = spawn_position + Vector2(cos(angle), sin(angle)) * dist

			# Move toward patrol target
			var dir = (patrol_target - global_position).normalized()
			global_position += dir * SPEED * delta * 0.4 * speed_mult

	if attack_cooldown > 0:
		attack_cooldown -= delta
	if attack_timer > 0:
		attack_timer -= delta
		_update_countdown()
		_update_screen_red_effect()

	attack_direction = global_position.angle_to(predicted_pos) - PI / 2
	rotation = attack_direction + PI / 2

func start_attack() -> void:
	is_attacking = true
	attack_timer = CHARGE_TIME
	show_warn_fan()
	_show_attack_range_box()
	_show_countdown()

func perform_attack() -> void:
	is_attacking = false
	attack_cooldown = ATK_COOL
	warn_timer = 0
	hide_warn_fan()
	_hide_attack_range_box()
	_hide_countdown()

	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < ATK_RANGE + 24:
		player.take_damage(ATK)

	spawn_attack_effect()

func spawn_attack_effect() -> void:
	pass

func show_warn_fan() -> void:
	hide_warn_fan()
	warn_fan = Polygon2D.new()
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)

	var segments = 12
	var fan_angle = PI / 2
	for i in range(segments + 1):
		var a = -fan_angle / 2 + fan_angle * i / segments
		points.append(Vector2(cos(a), sin(a)) * WARN_RANGE)

	warn_fan.polygon = points
	warn_fan.color = Color(1.0, 0.35, 0.1, 0.14)
	warn_fan.global_position = global_position
	warn_fan.rotation = attack_direction
	warn_fan.add_to_group("battle_effects")
	get_tree().root.add_child(warn_fan)

func hide_warn_fan() -> void:
	if warn_fan:
		warn_fan.queue_free()
		warn_fan = null

## 警戒范围脉冲红圈效果
func _update_warning_pulse(_delta: float) -> void:
	_hide_warning_effects()

func _hide_warning_effects() -> void:
	if pulse_circle:
		pulse_circle.queue_free()
		pulse_circle = null

## 显示攻击范围红框
func _show_attack_range_box() -> void:
	_hide_attack_range_box()
	attack_range_box = Polygon2D.new()
	var box_points = PackedVector2Array([
		Vector2(-ATK_RANGE - 24, -ATK_RANGE - 24),
		Vector2(ATK_RANGE + 24, -ATK_RANGE - 24),
		Vector2(ATK_RANGE + 24, ATK_RANGE + 24),
		Vector2(-ATK_RANGE - 24, ATK_RANGE + 24)
	])
	attack_range_box.polygon = box_points
	attack_range_box.color = Color(1.0, 0.45, 0.15, 0.08)
	attack_range_box.global_position = global_position
	attack_range_box.add_to_group("battle_effects")
	get_tree().root.add_child(attack_range_box)

func _hide_attack_range_box() -> void:
	if attack_range_box:
		attack_range_box.queue_free()
		attack_range_box = null

## 显示攻击倒计时
func _show_countdown() -> void:
	_hide_countdown()

func _hide_countdown() -> void:
	if countdown_label:
		countdown_label.queue_free()
		countdown_label = null

func take_damage(dmg: float) -> void:
	if invincible > 0:
		return
	hp -= dmg
	invincible = 0.3
	health_bar.value = hp

	# 增强受击闪烁效果 - 白光闪烁 + 缩放效果
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:r", 3.0, 0.05)
	tween.tween_property(self, "modulate:g", 3.0, 0.05)
	tween.tween_property(self, "modulate:b", 3.0, 0.05)
	tween.chain().tween_property(self, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	tween.chain().tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)

	# 受击缩放抖动
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.05)
	scale_tween.chain().tween_property(self, "scale", Vector2(0.9, 1.1), 0.05)
	scale_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

	# 伤害弹出
	spawn_damage_popup(dmg)

	var knock_dir = Vector2.ZERO
	var player = get_tree().get_first_node_in_group("player")
	if player:
		knock_dir = (global_position - player.global_position).normalized()
	global_position += knock_dir * 22

	if hp <= 0:
		die()

func spawn_damage_popup(dmg: float) -> void:
	var popup = Label.new()
	popup.text = str(int(dmg))
	popup.global_position = global_position + Vector2(-10, -30)
	popup.add_theme_font_size_override("font_size", 16)
	popup.modulate = Color(1.0, 0.3, 0.1, 1.0)
	popup.add_to_group("battle_effects")
	get_tree().root.add_child(popup)

	var tween = create_tween()
	tween.tween_property(popup, "position:y", popup.global_position.y - 40, 0.5)
	tween.chain().tween_property(popup, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(popup.queue_free)

## 动画状态机
func _update_animation(delta: float) -> void:
	anim_timer += delta
	if anim_timer >= ANIM_FRAME_TIME:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4

	var new_state = AnimState.IDLE
	var is_moving = is_patrolling or move_timer > 0
	var is_attacking_or_charging = is_attacking or attack_timer > 0

	if is_attacking_or_charging:
		new_state = AnimState.ATTACK if attack_timer <= CHARGE_TIME * 0.5 else AnimState.CHARGE
	elif is_moving:
		new_state = AnimState.WALK
	elif hp <= 0:
		new_state = AnimState.DEAD

	if new_state != current_animation:
		current_animation = new_state
		anim_frame = 0
		anim_timer = 0.0
		_apply_animation_state()

func _apply_animation_state() -> void:
	match current_animation:
		AnimState.IDLE:
			_apply_idle_animation()
		AnimState.WALK:
			_apply_walk_animation()
		AnimState.ATTACK:
			_apply_attack_animation()
		AnimState.CHARGE:
			_apply_charge_animation()
		AnimState.DEAD:
			_apply_dead_animation()

func _apply_idle_animation() -> void:
	# 站立：轻微上下起伏
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.scale = Vector2(1.0, 1.0 + sin(anim_frame * PI / 2) * 0.02)
	if head:
		head.scale = Vector2(1.0, 1.0 + sin(anim_frame * PI / 2) * 0.02)

func _apply_walk_animation() -> void:
	# 行走：左右摆动
	var wobble = sin(anim_frame * PI / 2) * 0.15
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.rotation = wobble
		body.scale = Vector2(1.0 + abs(wobble) * 0.1, 1.0 - abs(wobble) * 0.05)
	if head:
		head.rotation = wobble * 0.5

func _apply_attack_animation() -> void:
	# 攻击：快速前伸
	var progress = 1.0 - float(anim_frame) / 4
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.scale = Vector2(1.0 + progress * 0.3, 1.0 - progress * 0.2)
	if head:
		head.scale = Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.1)

func _apply_charge_animation() -> void:
	# 蓄力：身体膨胀，准备攻击
	var progress = float(anim_frame) / 4
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.scale = Vector2(1.0 + progress * 0.15, 1.0 + progress * 0.1)
	if head:
		head.scale = Vector2(1.0 + progress * 0.1, 1.0 + progress * 0.05)

func _apply_dead_animation() -> void:
	# 死亡：身体萎缩、变淡、消失
	var fade = 1.0 - float(anim_frame) / 4
	modulate.a = fade
	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.scale = Vector2(1.0 - float(anim_frame) / 4 * 0.5, 1.0 - float(anim_frame) / 4 * 0.5)
	if head:
		head.scale = Vector2(1.0 - float(anim_frame) / 4 * 0.5, 1.0 - float(anim_frame) / 4 * 0.5)

## 获取附近盟友进行协作
func _get_allies_in_range() -> Array:
	var allies: Array = []
	var group = get_tree().get_nodes_in_group("enemies")
	for ally in group:
		if ally != self and is_instance_valid(ally):
			var dist = global_position.distance_to(ally.global_position)
			if dist < ENEMY_AWARENESS_RANGE:
				allies.append({
					"node": ally,
					"distance": dist,
					"position": ally.global_position
				})
	# 按距离排序
	allies.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return allies

## 计算包围位置 - 敌人协作包围玩家
func _calculate_surround_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return global_position

	var allies = _get_allies_in_range()
	if allies.is_empty():
		return Vector2.ZERO

	# 计算所有盟友的中心位置
	var center = global_position
	for ally in allies:
		center += ally["position"]
	center /= (allies.size() + 1)

	# 计算玩家相对于中心的位置
	var _to_player = (player.global_position - center).normalized()
	var my_angle = global_position.angle_to_point(player.global_position)

	# 分配包围角度 - 敌人沿弧线分布包围玩家
	var surround_angle_offset = TAU / max(1, allies.size() + 1)
	var surround_angle = my_angle + surround_angle_offset * 0.5

	return player.global_position + Vector2(cos(surround_angle), sin(surround_angle)) * 60.0

## 判断是否进入谨慎模式（低血量时更保守）
func _is_in_caution_mode() -> bool:
	return hp / HP < CAUTION_THRESHOLD

## 获取预测的玩家位置
func _predict_player_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return global_position

	var player_velocity = Vector2.ZERO
	if player.has_method("get_velocity"):
		player_velocity = player.get_velocity()

	var prediction_time = PREDICTION_FACTOR
	if _is_in_caution_mode():
		prediction_time *= 1.5

	return player.global_position + player_velocity * prediction_time

func die() -> void:
	_cleanup_glow_effect()  # 清理发光效果
	hide_warn_fan()  # 清理 warn_fan 防止内存泄漏
	_hide_warning_effects()
	_hide_attack_range_box()
	_hide_countdown()
	_hide_screen_red_effect()

	# 播放敌人死亡音效
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.sfx_enemy_death()

	# 清理标记节点
	for marker in marker_nodes:
		if is_instance_valid(marker):
			marker.queue_free()
	marker_nodes.clear()

	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.spawn_resource(global_position, "beetle_remains")
	queue_free()

## 更新倒计时显示
func _update_countdown() -> void:
	if countdown_label and is_instance_valid(countdown_label):
		countdown_label.text = "%.1f" % max(0, attack_timer)
		countdown_label.global_position = global_position + Vector2(-20, -60)

## 接近时屏幕边缘泛红
var screen_red_vignette: Polygon2D = null

func _update_screen_red_effect() -> void:
	_hide_screen_red_effect()

func _hide_screen_red_effect() -> void:
	if screen_red_vignette:
		screen_red_vignette.queue_free()
		screen_red_vignette = null
