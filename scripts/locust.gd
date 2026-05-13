extends CharacterBody2D

## Enemy Locust - Fast melee attacker

const HP: float = 30.0
const ATK: float = 22.0
const SPEED: float = 250.0
const ATK_RANGE: float = 55.0
const ATK_COOL: float = 1.8
const CHARGE_TIME: float = 0.8
const WARN_RANGE: float = 75.0
const PATROL_RANGE: float = 100.0

# AI 智能参数
const PREDICTION_FACTOR: float = 0.45
const CAUTION_THRESHOLD: float = 0.35
const ENEMY_AWARENESS_RANGE: float = 250.0

var hp: float = HP
var attack_direction: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var move_timer: float = 0.0
var warn_timer: float = 0.0

var invincible: float = 0.0
var warn_fan: Polygon2D = null

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

## 应用外观变体：随机颜色、尺寸、标记
func _apply_appearance_variants() -> void:
	# 随机颜色变体 - 蝗虫偏绿/黄色系
	var base_color = Color(0.35, 0.45, 0.2, 1)
	var h_offset = randf_range(-0.1, 0.1)
	var s_offset = randf_range(-0.2, 0.2)
	var v_offset = randf_range(-0.1, 0.15)

	var hsv = Color()
	hsv.r = fmod(base_color.r + h_offset, 1.0) if base_color.r + h_offset > 0 else 1.0 + base_color.r + h_offset
	hsv.g = clamp(base_color.g + s_offset, 0.0, 1.0)
	hsv.b = clamp(base_color.b + v_offset, 0.0, 1.0)
	hsv.a = 1.0
	color_variant = hsv

	var body = get_node_or_null("Body")
	var head = get_node_or_null("Head")
	if body:
		body.color = _adjust_color(base_color, 0.0, 0.0, 0.0)
	if head:
		head.color = _adjust_color(base_color, 0.05, 0.08, -0.05)

	# 随机大小变化 ±10%
	size_scale = randf_range(0.9, 1.1)
	scale = Vector2(size_scale, size_scale)

	# 添加随机标记
	_add_random_marker()

func _adjust_color(base: Color, r_off: float, g_off: float, b_off: float) -> Color:
	return Color(clamp(base.r + r_off, 0, 1), clamp(base.g + g_off, 0, 1), clamp(base.b + b_off, 0, 1), base.a)

func _add_random_marker() -> void:
	var marker_type = randi() % 3
	if marker_type == 0:
		_add_spots()
	elif marker_type == 1:
		_add_stripes()

func _add_spots() -> void:
	var spot_count = randi() % 3 + 2
	var body = get_node_or_null("Body")
	if not body:
		return
	for i in range(spot_count):
		var spot = ColorRect.new()
		var spot_size = randf_range(2.0, 5.0)
		spot.size = Vector2(spot_size, spot_size)
		spot.color = Color(0.2, 0.25, 0.1, 0.6)
		spot.position = Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 12.0))
		body.add_child(spot)
		marker_nodes.append(spot)

func _add_stripes() -> void:
	var stripe_count = randi() % 2 + 1
	var body = get_node_or_null("Body")
	if not body:
		return
	for i in range(stripe_count):
		var stripe = ColorRect.new()
		stripe.size = Vector2(2.0, randf_range(10.0, 20.0))
		stripe.color = Color(0.2, 0.25, 0.1, 0.5)
		stripe.position = Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 8.0))
		stripe.rotation = randf_range(-0.2, 0.2)
		body.add_child(stripe)
		marker_nodes.append(stripe)

func _physics_process(delta: float) -> void:
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
		return

	# 预测玩家位置（用于追踪逃跑方向）
	var predicted_pos = _predict_player_position()
	var d = global_position.distance_to(predicted_pos)
	var atk_dist = ATK_RANGE + 24

	# 谨慎模式降低移动积极性
	var speed_mult = 1.0
	if _is_in_caution_mode():
		speed_mult = 0.65

	if d < WARN_RANGE and not is_attacking and attack_cooldown <= 0:
		warn_timer += delta
	else:
		warn_timer = max(0, warn_timer - delta * 0.5)

	if d < atk_dist:
		if attack_cooldown <= 0 and not is_attacking:
			start_attack()
		if is_attacking and attack_timer <= 0:
			perform_attack()
		is_patrolling = false
	else:
		if is_attacking and attack_timer > CHARGE_TIME * 0.5:
			is_attacking = false
			attack_cooldown = 0.5
			hide_warn_fan()

		# Patrol when player not in warn range, chase when in warn range
		if d < WARN_RANGE:
			# Player detected - chase with predictive tracking
			is_patrolling = false

			# 协作包围：快速敌人绕后夹击
			var surround_pos = _calculate_surround_position()
			var target_pos = predicted_pos
			if surround_pos != Vector2.ZERO and not _is_in_caution_mode():
				target_pos = surround_pos

			var dir = (target_pos - global_position).normalized()
			dir = dir.rotated(randf_range(-0.2, 0.2))
			global_position += dir * SPEED * delta * speed_mult
		else:
			# Player not detected - patrol around spawn position
			is_patrolling = true
			patrol_timer -= delta
			if patrol_timer <= 0 or global_position.distance_to(patrol_target) < 10:
				patrol_timer = randf_range(1.5, 3.0)
				var angle = randf_range(0, TAU)
				var dist = randf_range(20, PATROL_RANGE)
				patrol_target = spawn_position + Vector2(cos(angle), sin(angle)) * dist

			var dir = (patrol_target - global_position).normalized()
			global_position += dir * SPEED * delta * 0.4 * speed_mult

	if attack_cooldown > 0:
		attack_cooldown -= delta
	if attack_timer > 0:
		attack_timer -= delta

	attack_direction = global_position.angle_to(predicted_pos) - PI / 2
	rotation = attack_direction + PI / 2

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

	var center = global_position
	for ally in allies:
		center += ally["position"]
	center /= (allies.size() + 1)

	var my_angle = global_position.angle_to_point(player.global_position)
	var surround_angle_offset = TAU / max(1, allies.size() + 1)
	var surround_angle = my_angle + surround_angle_offset * 0.5

	return player.global_position + Vector2(cos(surround_angle), sin(surround_angle)) * 55.0

## 判断是否进入谨慎模式
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

func start_attack() -> void:
	is_attacking = true
	attack_timer = CHARGE_TIME
	show_warn_fan()

func perform_attack() -> void:
	is_attacking = false
	attack_cooldown = ATK_COOL
	warn_timer = 0
	hide_warn_fan()

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
	warn_fan.color = Color(0.6, 1.0, 0.2, 0.25)
	warn_fan.global_position = global_position
	warn_fan.rotation = attack_direction
	get_tree().root.add_child(warn_fan)

func hide_warn_fan() -> void:
	if warn_fan:
		warn_fan.queue_free()
		warn_fan = null

func take_damage(dmg: float) -> void:
	if invincible > 0:
		return
	hp -= dmg
	invincible = 0.3
	health_bar.value = hp

	var tween = create_tween()
	tween.tween_property(self, "modulate:r", 2.0, 0.05)
	tween.chain().tween_property(self, "modulate:r", 1.0, 0.05)

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
	get_tree().root.add_child(popup)

	var tween = create_tween()
	tween.tween_property(popup, "position:y", popup.global_position.y - 40, 0.5)
	tween.chain().tween_property(popup, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(popup.queue_free)

func die() -> void:
	hide_warn_fan()  # 清理 warn_fan 防止内存泄漏
	# 清理标记节点
	for marker in marker_nodes:
		if is_instance_valid(marker):
			marker.queue_free()
	marker_nodes.clear()
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.spawn_resource(global_position, "locust_remains")
	queue_free()
