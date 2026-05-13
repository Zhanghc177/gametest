extends CharacterBody2D

## 蚂蚁单位 - 玩家携带的自动战斗单位

## 蚂蚁类型属性
var ant_type: String = "worker"
var hp: float = 20.0
var max_hp: float = 20.0
var atk: float = 5.0
var speed: float = 180.0
var atk_range: float = 40.0
var atk_cool: float = 1.5
var attack_cooldown: float = 0.0

var player: Node = null
var health_bar: ProgressBar = null
var is_dead: bool = false

# Glow effect variables
var glow_outline: Polygon2D = null
var glow_pulse_timer: float = 0.0
var base_glow_color: Color = Color(0.3, 0.8, 0.5, 0.25)

const ANT_COLORS = {
	"worker": Color(0.545, 0.271, 0.075, 1),    # 棕色
	"soldier": Color(0.7, 0.2, 0.1, 1),          # 深红
	"shooter": Color(0.2, 0.5, 0.3, 1),          # 绿色
	"bomber": Color(0.4, 0.1, 0.4, 1),          # 紫色
	"flyer": Color(0.3, 0.4, 0.7, 1)            # 蓝色
}

func _init():
	add_to_group("player_ants")

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	health_bar = $HealthBar
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp
	_set_ant_color()

func _set_ant_color() -> void:
	var color = ANT_COLORS.get(ant_type, ANT_COLORS["worker"])
	if $AntBody/Head:
		$AntBody/Head.color = color
	if $AntBody/Body:
		$AntBody/Body.color = color
		$AntBody/Body.color.r += 0.1
	if $AntBody/Abdomen:
		$AntBody/Abdomen.color = color
		$AntBody/Abdomen.color.r += 0.05
	# _init_glow_effect()  # TEMP DISABLED

## 初始化发光轮廓效果
func _init_glow_effect() -> void:
	glow_outline = Polygon2D.new()
	var offset_scale = 1.12
	glow_outline.global_position = global_position
	glow_outline.rotation = rotation
	glow_outline.scale = Vector2(offset_scale, offset_scale)
	glow_outline.color = base_glow_color
	glow_outline.z_index = -1
	get_tree().root.call_deferred("add_child", glow_outline)

## 更新发光脉冲效果
func _update_glow_effect(delta: float) -> void:
	glow_pulse_timer += delta
	var pulse = (sin(glow_pulse_timer * 2.5) + 1.0) * 0.5

	var glow_color = Color(0.2 + pulse * 0.15, 0.7 + pulse * 0.1, 0.4 + pulse * 0.1, 0.15 + pulse * 0.1)
	if glow_outline:
		glow_outline.global_position = global_position
		glow_outline.rotation = rotation
		glow_outline.color = glow_color

func _physics_process(delta: float) -> void:
	if is_dead or not player:
		return

	# 更新攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# 更新发光效果  # DISABLED
	# _update_glow_effect(delta)

	# 跟随玩家
	_follow_player(delta)

	# 自动攻击范围内的敌人
	_auto_attack()

func _follow_player(_delta: float) -> void:
	var target_pos = player.global_position
	var dist = global_position.distance_to(target_pos)
	var follow_dist = 50.0

	if dist > follow_dist:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

		# 面向移动方向
		if velocity.length() > 0:
			rotation = velocity.angle() + PI / 2
	else:
		velocity = Vector2.ZERO

func _auto_attack() -> void:
	if attack_cooldown > 0:
		return

	var enemy = _find_nearest_enemy_in_range()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(atk)
		attack_cooldown = atk_cool

		# 播放攻击特效
		_play_attack_effect()

func _find_nearest_enemy_in_range() -> Node:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var d = global_position.distance_to(enemy.global_position)
		if d <= atk_range and d < min_dist:
			nearest = enemy
			min_dist = d

	return nearest

func _play_attack_effect() -> void:
	# 简单的闪烁效果
	var original_color = ANT_COLORS.get(ant_type, ANT_COLORS["worker"])
	modulate = original_color + Color(0.5, 0.5, 0.5, 0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

func take_damage(dmg: float) -> void:
	if is_dead:
		return

	hp -= dmg
	if health_bar:
		health_bar.value = hp

	# 受伤闪烁
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true

	# 清理发光效果
	if glow_outline:
		glow_outline.queue_free()
		glow_outline = null

	# 从场景移除
	if get_parent():
		get_parent().remove_child(self)
	queue_free()
