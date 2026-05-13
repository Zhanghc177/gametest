extends Node2D

## 主游戏场景 - 管理撤离、物资、敌人

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const RESOURCE_SCENE = preload("res://scenes/resource_pickup.tscn")
const ANT_SCENE = preload("res://scenes/ant.tscn")

## 蚂蚁类型属性配置
const ANT_STATS = {
	"worker": {"hp": 20.0, "atk": 5.0, "speed": 180.0, "atk_range": 40.0, "atk_cool": 1.5},
	"shooter": {"hp": 25.0, "atk": 10.0, "speed": 120.0, "atk_range": 120.0, "atk_cool": 0.8},
	"bomber": {"hp": 22.0, "atk": 28.0, "speed": 100.0, "atk_range": 60.0, "atk_cool": 2.0},
	"soldier": {"hp": 45.0, "atk": 14.0, "speed": 150.0, "atk_range": 55.0, "atk_cool": 1.0},
	"flyer": {"hp": 20.0, "atk": 8.0, "speed": 220.0, "atk_range": 50.0, "atk_cool": 0.9}
}

## 性能优化配置
const MAX_ENEMIES: int = 20  # 敌人数量上限
const MAX_CELEBRATION_PARTICLES: int = 15  # 撤离庆祝粒子上限

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var extraction_point: Area2D = $ExtractionPoint
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var enemies: Array[CharacterBody2D] = []
var player_ants: Array[CharacterBody2D] = []
var obstacles: Array[Node2D] = []
var resources: Array[Area2D] = []

var game_running: bool = true
var _game_manager_cache: Node = null

## 虚拟触控变量
var joystick_input: Vector2 = Vector2.ZERO
var joystick_active: bool = false
var attack_button_down: bool = false
var dash_button_down: bool = false

## 触控手感优化参数
const JOYSTICK_DEADZONE: float = 0.15  # 虚拟摇杆死区（减少漂移）
const JOYSTICK_SENSITIVITY: float = 1.1  # 摇杆灵敏度（略高于手柄）
const ATTACK_BUTTON_RADIUS: float = 85.0  # 攻击按钮检测半径（扩大响应范围）
const DASH_BUTTON_RADIUS: float = 80.0  # 冲刺按钮检测半径
const ATTACK_RESPONSE_TIME: float = 0.02  # 攻击响应延迟（秒）
const DASH_RESPONSE_TIME: float = 0.015  # 冲刺响应延迟（秒）

## 手柄输入变量
var gamepad_leftstick: Vector2 = Vector2.ZERO  # 左摇杆
var gamepad_rightstick: Vector2 = Vector2.ZERO  # 右摇杆
var gamepad_lt: float = 0.0  # LT 扳机 (0.0-1.0)
var gamepad_rt: float = 0.0  # RT 扳机 (0.0-1.0)
var gamepad_lb: bool = false  # LB 按钮
var gamepad_rb: bool = false  # RB 按钮
var prev_gamepad_lb: bool = false  # LB 上一帧状态（用于检测按下）
var prev_gamepad_rb: bool = false  # RB 上一帧状态
var inventory: Dictionary = { "beetle_remains": 0, "locust_remains": 0, "spider_remains": 0, "mantis_remains": 0, "bee_remains": 0 }
var extraction_progress: float = 0.0
var has_extraction_started: bool = false

## 波次系统变量
var current_wave: int = 0
var max_waves: int = 1
var wave_enemies_remaining: int = 0
var wave_in_progress: bool = false

## BOSS血条系统变量
var current_boss: Node = null  # 当前BOSS引用
var boss_health_bar: ProgressBar = null  # BOSS血条
var boss_name_label: Label = null  # BOSS名称标签
var boss_phase_label: Label = null  # BOSS阶段标签

## 新手教学系统变量
var tutorial_step: int = 0  # 0=未开始, 1=WASD移动教学, 2=攻击教学, 3=资源收集教学, 4=撤离机制教学, 5=完成
var tutorial_highlight_target: Node2D = null
var tutorial_label: Label = null
var tutorial_arrow: Polygon2D = null
var tutorial_completed: bool = false  # 教程是否已完成过（用于判定是否显示奖励）
var tutorial_reward_panel: Panel = null  # 教程奖励面板
var _tutorial_resource_picked_up: bool = false  # 教程资源是否已被拾取
var tutorial_bubble: Panel = null  # 教程气泡框
var tutorial_hand: Polygon2D = null  # 手势指示动画
var tutorial_gesture_tween: Tween = null  # 手势动画Tween

## 结算界面变量
var kill_count: int = 0  # 击杀数
var survival_time: float = 0.0  # 存活时间（秒）
var battle_start_time: float = 0.0  # 战斗开始时间
var settlement_panel: Panel = null  # 结算界面面板

## 战斗回放系统变量
var input_recording: Array[Dictionary] = []  # 当前战斗的输入记录
var battle_recordings: Array[Dictionary] = []  # 保存最近3场战斗记录
const MAX_REPLAY_COUNT: int = 3  # 最大回放数量
const REPLAY_SAVE_PATH: String = "user://battle_replays/"  # 回放保存路径

## 公告系统变量
var announcement_panel: Panel = null  # 公告面板
var announcement_timer: Timer = null  # 公告计时器
var announcement_tween: Tween = null  # 公告动画

## 天气系统变量
var dust_particles: Array = []  # 尘埃粒子数组
var light_particles: Array = []  # 光效粒子数组
var weather_timer: Timer = null  # 天气更新计时器
var ambient_dust_container: Node2D = null  # 尘埃粒子容器
var light_beam_container: Node2D = null  # 光束容器
const MAX_DUST_PARTICLES: int = 30  # 尘埃粒子最大数量
const MAX_LIGHT_PARTICLES: int = 8   # 光效粒子最大数量

## 小地图系统变量
var minimap_panel: PanelContainer = null  # 小地图面板
var minimap_container: Control = null  # 小地图容器
var minimap_player_dot: Polygon2D = null  # 玩家小地图点
var minimap_extraction_dot: Polygon2D = null  # 撤离点小地图点
var minimap_enemy_container: Node2D = null  # 敌人小地图点容器
var enemy_dot_pool: Array[Polygon2D] = []  # 敌人点对象池
const MINIMAP_SIZE: float = 130.0  # 小地图显示尺寸
const MINIMAP_SCALE: float = 0.1  # 世界坐标到小地图的缩放比例 (130/1300 ≈ 0.1)

## 公告类型枚举
enum AnnouncementType {
	SYSTEM = 0,    # 系统公告（灰色）
	MAINTENANCE = 1,  # 维护公告（橙色）
	EVENT = 2,      # 活动公告（紫色）
	UPDATE = 3,     # 更新公告（蓝色）
	WARNING = 4     # 警告公告（红色）
}

signal resource_collected(amount: int)

## 触觉震动反馈
## mode: 0=轻微(攻击), 1=强烈(受伤), 2=庆祝(撤离成功)
func vibrate(mode: int = 0) -> void:
	var weak_mag: float = 0.0
	var strong_mag: float = 0.0
	var duration: float = 0.1

	match mode:
		0:  # 轻微震动 - 攻击
			weak_mag = 0.3
			strong_mag = 0.1
			duration = 0.1
		1:  # 强烈震动 - 受伤
			weak_mag = 0.2
			strong_mag = 0.8
			duration = 0.3
		2:  # 庆祝震动 - 撤离成功
			weak_mag = 0.6
			strong_mag = 0.6
			duration = 0.5

	# 触发手柄震动（第一个连接的手柄，设备索引0）
	var gamepad_id = 0
	Input.start_joy_vibration(gamepad_id, weak_mag, strong_mag, duration)

var _debug_frame_count: int = 0

func _ready() -> void:
	print("Main: _ready called")
	add_to_group("main")
	player.add_to_group("player")
	print("Main: player=", player, " camera=", camera)
	setup_camera()
	setup_extraction_point()
	print("Main: _ready 完成")

func _process(_delta: float) -> void:
	# 确保摄像机跟随玩家
	if camera and is_instance_valid(camera) and player and is_instance_valid(player):
		camera.global_position = player.global_position
		camera.make_current()
	else:
		print("Main: _process - camera=", camera, " player=", player)

## 初始化BOSS血条UI
func init_boss_health_bar() -> void:
	boss_health_bar = canvas_layer.get_node_or_null("BossHealthBar")
	boss_name_label = canvas_layer.get_node_or_null("BossNameLabel")
	boss_phase_label = canvas_layer.get_node_or_null("BossPhaseLabel")
	if boss_health_bar:
		boss_health_bar.visible = false
		print("Main: BOSS血条初始化完成")

## 显示战场UI元素（敌人数量、生命值、buff、小地图、触控按钮）
func show_battle_ui() -> void:
	var enemy_count_label = canvas_layer.get_node_or_null("EnemyCountLabel")
	if enemy_count_label:
		enemy_count_label.visible = true
	var health_bar = canvas_layer.get_node_or_null("HealthBar")
	if health_bar:
		health_bar.visible = true
	var buff_label = canvas_layer.get_node_or_null("BuffLabel")
	if buff_label:
		buff_label.visible = true
	var minimap = canvas_layer.get_node_or_null("Minimap")
	if minimap:
		minimap.visible = true
	var touch_controls = canvas_layer.get_node_or_null("TouchControls")
	if touch_controls:
		touch_controls.visible = true
	print("Main: 战场UI元素已显示")

## 显示BOSS血条
func show_boss_ui(boss_name: String = "蜂后") -> void:
	if boss_health_bar:
		boss_health_bar.visible = true
	if boss_name_label:
		boss_name_label.text = boss_name
		boss_name_label.visible = true
	if boss_phase_label:
		boss_phase_label.text = "阶段 1"
		boss_phase_label.visible = true
	show_boss_health(1.0, 1)  # 满血，阶段1

## 隐藏BOSS血条
func hide_boss_ui() -> void:
	if boss_health_bar:
		boss_health_bar.visible = false
	if boss_name_label:
		boss_name_label.visible = false
	if boss_phase_label:
		boss_phase_label.visible = false

## 更新BOSS血量显示
func show_boss_health(health_ratio: float, phase: int) -> void:
	if boss_health_bar:
		boss_health_bar.value = health_ratio * 100
		# 根据阶段改变颜色
		match phase:
			1:
				boss_health_bar.modulate = Color(0.2, 1.0, 0.2)  # 绿色
			2:
				boss_health_bar.modulate = Color(1.0, 0.8, 0.0)  # 黄色
			3:
				boss_health_bar.modulate = Color(1.0, 0.2, 0.2)  # 红色
	if boss_phase_label:
		boss_phase_label.text = "阶段 %d" % phase

func start_tutorial_if_needed() -> void:
	# 检测是否首次进入（tutorial_step为0表示首次进入）
	if tutorial_step == 0:
		# 检查是否已完成过教程
		if is_tutorial_completed():
			tutorial_step = 5  # 已完成，跳过教程
			tutorial_completed = true
			print("Main: 教程已完成过，跳过新手引导")
		else:
			tutorial_step = 1
			show_tutorial_step_1()

	battle_start_time = Time.get_ticks_msec() / 1000.0  # 记录战斗开始时间
	input_recording.clear()  # 开始新战斗记录

## 新手教学系统
func show_tutorial_step_1() -> void:
	# 步骤1: WASD移动教学
	clear_tutorial()
	# 使用气泡框显示教程
	tutorial_bubble = create_tutorial_bubble("使用 WASD 移动角色", player.global_position)
	# 高亮玩家角色
	tutorial_highlight_target = player
	player.modulate = Color(1.0, 0.8, 0.4, 1.0)
	# 添加手势动画指引
	create_gesture_animation("drag", player.global_position + Vector2(50, 0))
	await get_tree().create_timer(3.0).timeout
	if tutorial_step == 1:
		advance_tutorial()

func show_tutorial_step_2() -> void:
	# 步骤2: 攻击教学
	clear_tutorial()
	# 使用气泡框显示教程
	tutorial_bubble = create_tutorial_bubble("按 空格键 攻击敌人", player.global_position)
	# 高亮敌人
	if enemies.size() > 0:
		tutorial_highlight_target = enemies[0]
		enemies[0].modulate = Color(1.0, 0.8, 0.4, 1.0)
		# 添加点击手势动画指向敌人
		create_gesture_animation("tap", enemies[0].global_position)
	await get_tree().create_timer(3.0).timeout
	if tutorial_step == 2:
		advance_tutorial()

func show_tutorial_step_3() -> void:
	# 步骤3: 资源收集教学
	clear_tutorial()
	# 使用气泡框显示教程
	tutorial_bubble = create_tutorial_bubble("靠近发光资源点进行拾取", player.global_position)
	# 高亮一个资源点
	if resources.size() > 0:
		var target_resource = resources[0]
		tutorial_highlight_target = target_resource
		target_resource.modulate = Color(1.0, 0.9, 0.4, 1.0)
		create_tutorial_arrow(target_resource.global_position)
		# 添加手势动画
		create_gesture_animation("drag", target_resource.global_position)
	# 监听资源拾取事件
	if not resource_collected.is_connected(_on_tutorial_resource_collected):
		resource_collected.connect(_on_tutorial_resource_collected)
	# 5秒超时自动推进
	await get_tree().create_timer(5.0).timeout
	if tutorial_step == 3 and not _tutorial_resource_picked_up:
		advance_tutorial()

func _on_tutorial_resource_collected(_amount: int) -> void:
	if tutorial_step == 3 and not _tutorial_resource_picked_up:
		_tutorial_resource_picked_up = true
		advance_tutorial()

func show_tutorial_step_4() -> void:
	# 步骤4: 撤离机制教学
	clear_tutorial()
	_tutorial_resource_picked_up = false
	# 使用气泡框显示教程
	tutorial_bubble = create_tutorial_bubble("到达黄色撤离点，长按按钮等待撤离", player.global_position)
	# 高亮撤离点
	tutorial_highlight_target = extraction_point
	extraction_point.modulate = Color(1.0, 0.9, 0.4, 1.0)
	create_tutorial_arrow(extraction_point.global_position)
	# 添加手势动画指向撤离点
	create_gesture_animation("swipe", extraction_point.global_position)
	# 监听撤离开始事件
	if not extraction_point.extraction_started.is_connected(_on_tutorial_extraction_started):
		extraction_point.extraction_started.connect(_on_tutorial_extraction_started)
	# 6秒超时自动推进
	await get_tree().create_timer(6.0).timeout
	if tutorial_step == 4:
		advance_tutorial()

func _on_tutorial_extraction_started() -> void:
	if tutorial_step == 4:
		# 撤离已开始，等待完成
		if not extraction_point.extraction_progress.is_connected(_on_tutorial_extraction_progress):
			extraction_point.extraction_progress.connect(_on_tutorial_extraction_progress)

func _on_tutorial_extraction_progress(progress: float) -> void:
	if tutorial_step == 4 and progress >= 1.0:
		# 撤离完成，触发教程完成
		pass  # 撤离完成会触发 extraction_completed 信号

func advance_tutorial() -> void:
	match tutorial_step:
		1:
			tutorial_step = 2
			show_tutorial_step_2()
		2:
			tutorial_step = 3
			show_tutorial_step_3()
		3:
			tutorial_step = 4
			show_tutorial_step_4()
		4:
			tutorial_step = 5
			complete_tutorial()

func complete_tutorial() -> void:
	clear_tutorial()
	tutorial_completed = true
	print("Main: 新手教学完成")
	# 保存教程完成状态
	save_tutorial_completed()
	# 延迟显示奖励面板
	await get_tree().create_timer(1.0).timeout
	show_tutorial_reward()

## 保存教程完成状态到用户数据
func save_tutorial_completed() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		config.set_value("tutorial", "completed", true)
		config.save("user://settings.cfg")
		print("Main: 教程完成状态已保存")
	else:
		# 文件不存在，创建新配置
		config.set_value("tutorial", "completed", true)
		config.save("user://settings.cfg")
		print("Main: 教程完成状态已创建")

## 检查教程是否已完成过
func is_tutorial_completed() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		return config.get_value("tutorial", "completed", false)
	return false

## 显示教程完成奖励
func show_tutorial_reward() -> void:
	if tutorial_reward_panel and is_instance_valid(tutorial_reward_panel):
		return  # 奖励面板已显示

	# 创建奖励面板
	tutorial_reward_panel = Panel.new()
	tutorial_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_reward_panel.size = Vector2(350, 280)
	var reward_style = StyleBoxFlat.new()
	reward_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	tutorial_reward_panel.add_theme_stylebox_override("panel", reward_style)
	get_tree().root.add_child(tutorial_reward_panel)

	# 标题
	var title = Label.new()
	title.text = "新手教程完成！"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 20
	title.size = Vector2(350, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	tutorial_reward_panel.add_child(title)

	# 奖励图标
	var reward_icon = Label.new()
	reward_icon.text = "[礼包]"
	reward_icon.set_anchors_preset(Control.PRESET_CENTER)
	reward_icon.offset_top = 70
	reward_icon.size = Vector2(100, 60)
	reward_icon.add_theme_font_size_override("font_size", 48)
	reward_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_reward_panel.add_child(reward_icon)

	# 奖励说明
	var reward_desc = Label.new()
	reward_desc.text = "获得以下奖励：\n- 100 基础资源\n- 攻击buff持续时间+2秒\n- 解锁成就【初出茅庐】"
	reward_desc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	reward_desc.offset_top = 140
	reward_desc.size = Vector2(300, 80)
	reward_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	tutorial_reward_panel.add_child(reward_desc)

	# 确认按钮
	var confirm_btn = Button.new()
	confirm_btn.text = "确认"
	confirm_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	confirm_btn.offset_bottom = -20
	confirm_btn.size = Vector2(150, 40)
	confirm_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_btn.connect("pressed", _on_tutorial_reward_confirmed)
	tutorial_reward_panel.add_child(confirm_btn)

	# 面板入场动画
	tutorial_reward_panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.tween_property(tutorial_reward_panel, "scale", Vector2(1.0, 1.0), 0.3)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# 应用奖励效果
	apply_tutorial_reward()

func apply_tutorial_reward() -> void:
	# 给予资源奖励
	inventory["beetle_remains"] += 100
	# 给予攻击buff持续时间加成（如果有该机制）
	if "atk_boost_duration_bonus" in player:
		player.atk_boost_duration_bonus += 2.0
	print("Main: 教程奖励已应用 - 资源+100")

func _on_tutorial_reward_confirmed() -> void:
	if tutorial_reward_panel and is_instance_valid(tutorial_reward_panel):
		# 关闭动画
		var tween = create_tween()
		tween.tween_property(tutorial_reward_panel, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(Callable(self, "_on_tutorial_reward_closed"))

func _on_tutorial_reward_closed() -> void:
	if tutorial_reward_panel and is_instance_valid(tutorial_reward_panel):
		tutorial_reward_panel.queue_free()
		tutorial_reward_panel = null
	update_ui()
	show_system_announcement("欢迎来到战场，指挥官！")

func clear_tutorial() -> void:
	if tutorial_highlight_target and is_instance_valid(tutorial_highlight_target):
		tutorial_highlight_target.modulate = Color(1, 1, 1, 1)
	tutorial_highlight_target = null
	if tutorial_label and is_instance_valid(tutorial_label):
		tutorial_label.queue_free()
	tutorial_label = null
	if tutorial_arrow and is_instance_valid(tutorial_arrow):
		tutorial_arrow.queue_free()
	tutorial_arrow = null
	if tutorial_bubble and is_instance_valid(tutorial_bubble):
		tutorial_bubble.queue_free()
	tutorial_bubble = null
	if tutorial_hand and is_instance_valid(tutorial_hand):
		tutorial_hand.queue_free()
	tutorial_hand = null
	if tutorial_gesture_tween and is_instance_valid(tutorial_gesture_tween):
		tutorial_gesture_tween.kill()
	tutorial_gesture_tween = null

func create_tutorial_bubble(text: String, target_pos: Vector2) -> Panel:
	# 创建气泡框面板
	var bubble = Panel.new()
	bubble.name = "TutorialBubble"

	# 设置气泡框样式 - 半透明深色背景带圆角效果
	bubble.set_anchors_preset(Control.PRESET_CENTER)
	bubble.custom_minimum_size = Vector2(280, 80)

	# 添加装饰边框
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	style_box.border_color = Color(0.9, 0.75, 0.3, 0.8)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 15
	style_box.content_margin_top = 10
	style_box.content_margin_right = 15
	style_box.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", style_box)

	# 创建内部容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	bubble.add_child(vbox)

	# 创建标题标签（带图标）
	var title_label = Label.new()
	title_label.text = "[ 教程 ]"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	vbox.add_child(title_label)

	# 创建内容标签
	var content_label = Label.new()
	content_label.text = text
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_label.add_theme_font_size_override("font_size", 18)
	content_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(content_label)

	# 设置气泡框位置（在目标上方显示）
	var bubble_pos = target_pos + Vector2(0, -120)
	if bubble_pos.y < 100:
		bubble_pos = target_pos + Vector2(0, 80)
	bubble.position = bubble_pos - bubble.custom_minimum_size / 2

	get_tree().root.add_child(bubble)

	# 入场动画 - 缩放弹入
	bubble.scale = Vector2(0.3, 0.3)
	bubble.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.3)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	return bubble

func create_tutorial_label(text: String, pos: Vector2) -> Label:
	var label = Label.new()
	label.text = text
	label.global_position = pos - Vector2(100, 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bg = Panel.new()
	bg.position = label.global_position - Vector2(5, 2)
	bg.size = Vector2(210, 44)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.7)
	bg.add_theme_stylebox_override("panel", bg_style)
	get_tree().root.add_child(bg)
	label.add_child(bg)
	get_tree().root.add_child(label)
	return label

## 创建手势滑动动画指引
func create_gesture_animation(gesture_type: String, target_pos: Vector2) -> void:
	clear_gesture_animation()

	# 创建手势指示（手掌/手指图标）
	tutorial_hand = Polygon2D.new()

	# 根据手势类型选择不同的形状
	match gesture_type:
		"tap":
			# 点击手势 - 圆形手指
			var points = PackedVector2Array([
				Vector2(-8, -12), Vector2(0, -15),
				Vector2(8, -12), Vector2(8, 8),
				Vector2(3, 12), Vector2(-3, 12),
				Vector2(-8, 8)
			])
			tutorial_hand.polygon = points
			tutorial_hand.color = Color(1.0, 0.9, 0.5, 0.95)
		"drag", "swipe":
			# 拖拽/滑动手势 - 带方向箭头
			var points = PackedVector2Array([
				Vector2(-10, -8), Vector2(5, -8),
				Vector2(5, -15), Vector2(15, -5),
				Vector2(5, 5), Vector2(5, -2),
				Vector2(-10, -2)
			])
			tutorial_hand.polygon = points
			tutorial_hand.color = Color(1.0, 0.85, 0.4, 0.95)
		_:
			# 默认手势 - 圆形
			var circle_points = PackedVector2Array([])
			for i in range(16):
				var angle = 2.0 * PI * i / 16
				circle_points.append(Vector2(cos(angle) * 10, sin(angle) * 10 - 5))
			tutorial_hand.polygon = circle_points
			tutorial_hand.color = Color(1.0, 0.9, 0.5, 0.9)

	tutorial_hand.global_position = target_pos + Vector2(0, -60)
	get_tree().root.add_child(tutorial_hand)

	# 创建手势动画 - 上下浮动 + 缩放
	tutorial_gesture_tween = create_tween()
	tutorial_gesture_tween.set_loops()

	# 上下浮动动画
	tutorial_gesture_tween.set_parallel(true)
	tutorial_gesture_tween.tween_property(tutorial_hand, "position:y", -20, 0.5)
	tutorial_gesture_tween.tween_property(tutorial_hand, "scale", Vector2(1.15, 1.15), 0.25)
	tutorial_gesture_tween.set_trans(Tween.TRANS_SINE)
	tutorial_gesture_tween.set_ease(Tween.EASE_IN_OUT)

	tutorial_gesture_tween.chain()
	tutorial_gesture_tween.set_parallel(true)
	tutorial_gesture_tween.tween_property(tutorial_hand, "position:y", -60, 0.5)
	tutorial_gesture_tween.tween_property(tutorial_hand, "scale", Vector2(1.0, 1.0), 0.25)
	tutorial_gesture_tween.set_trans(Tween.TRANS_SINE)
	tutorial_gesture_tween.set_ease(Tween.EASE_IN_OUT)

	# 添加闪烁光环效果
	await get_tree().create_timer(0.3).timeout
	if tutorial_hand and is_instance_valid(tutorial_hand):
		var glow = Polygon2D.new()
		var glow_points = PackedVector2Array([])
		for i in range(24):
			var angle = 2.0 * PI * i / 24
			glow_points.append(Vector2(cos(angle) * 18, sin(angle) * 18))
		glow.polygon = glow_points
		glow.color = Color(1.0, 0.8, 0.3, 0.4)
		glow.global_position = tutorial_hand.global_position
		get_tree().root.add_child(glow)

		var glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.6)
		glow_tween.tween_property(glow, "modulate:a", 0.0, 0.6)
		glow_tween.set_trans(Tween.TRANS_QUAD)
		glow_tween.set_ease(Tween.EASE_OUT)
		glow_tween.chain()
		glow_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.0)
		glow_tween.tween_property(glow, "modulate:a", 0.4, 0.0)

		glow.tree_exited.connect(func(): glow.queue_free())

## 清理手势动画
func clear_gesture_animation() -> void:
	if tutorial_hand and is_instance_valid(tutorial_hand):
		tutorial_hand.queue_free()
		tutorial_hand = null
	if tutorial_gesture_tween and is_instance_valid(tutorial_gesture_tween):
		tutorial_gesture_tween.kill()
		tutorial_gesture_tween = null

func create_tutorial_arrow(target_pos: Vector2) -> void:
	clear_tutorial_arrow()
	tutorial_arrow = Polygon2D.new()
	# 优化箭头形状 - 更美观的三角形箭头
	var arrow_points = PackedVector2Array([
		Vector2(0, -20),    # 顶点
		Vector2(12, 8),     # 右上
		Vector2(5, 8),      # 右内凹
		Vector2(5, 20),     # 右下
		Vector2(-5, 20),    # 左下
		Vector2(-5, 8),     # 左内凹
		Vector2(-12, 8)     # 左上
	])
	tutorial_arrow.polygon = arrow_points
	# 使用明亮的金黄色
	tutorial_arrow.color = Color(1.0, 0.85, 0.3, 0.95)
	tutorial_arrow.global_position = target_pos + Vector2(0, -80)
	get_tree().root.add_child(tutorial_arrow)

	# 创建箭头动画 - 上下浮动 + 脉冲效果
	var arrow_tween = create_tween()
	arrow_tween.set_loops()
	# 向上移动
	arrow_tween.set_parallel(true)
	arrow_tween.tween_property(tutorial_arrow, "position:y", -40, 0.6)
	arrow_tween.tween_property(tutorial_arrow, "scale", Vector2(1.1, 1.1), 0.3)
	arrow_tween.set_trans(Tween.TRANS_SINE)
	arrow_tween.set_ease(Tween.EASE_IN_OUT)
	# 向下移动
	arrow_tween.chain()
	arrow_tween.set_parallel(true)
	arrow_tween.tween_property(tutorial_arrow, "position:y", -80, 0.6)
	arrow_tween.tween_property(tutorial_arrow, "scale", Vector2(1.0, 1.0), 0.3)
	arrow_tween.set_trans(Tween.TRANS_SINE)
	arrow_tween.set_ease(Tween.EASE_IN_OUT)

	# 添加箭头尾部装饰（两条短横线表示动态）
	var tail1 = Polygon2D.new()
	tail1.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 3), Vector2(-3, 3)])
	tail1.color = Color(1.0, 0.75, 0.2, 0.7)
	tail1.global_position = target_pos + Vector2(0, -50)
	get_tree().root.add_child(tail1)

	var tail2 = Polygon2D.new()
	tail2.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 3), Vector2(-3, 3)])
	tail2.color = Color(1.0, 0.75, 0.2, 0.5)
	tail2.global_position = target_pos + Vector2(0, -35)
	get_tree().root.add_child(tail2)

	var tail_tween = create_tween()
	tail_tween.set_loops()
	tail_tween.set_parallel(true)
	tail_tween.tween_property(tail1, "position:y", 10, 0.5)
	tail_tween.tween_property(tail2, "position:y", 25, 0.5)
	tail_tween.set_trans(Tween.TRANS_QUAD)
	tail_tween.set_ease(Tween.EASE_OUT)

	tail1.tree_exited.connect(func(): tail1.queue_free())
	tail2.tree_exited.connect(func(): tail2.queue_free())

func clear_tutorial_arrow() -> void:
	if tutorial_arrow and is_instance_valid(tutorial_arrow):
		tutorial_arrow.queue_free()
	tutorial_arrow = null

func setup_camera() -> void:
	# 摄像机现在在 player.tscn 中设置，limit 需要在这里配置
	print("Main: setup_camera called, camera=", camera)
	if camera and is_instance_valid(camera):
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = 1080
		camera.limit_bottom = 1920
		camera.make_current()
		print("Main: setup_camera done, camera.is_current=", camera.is_current())
	else:
		print("Main: setup_camera ERROR - camera is null!")

func setup_extraction_point() -> void:
	# 撤离点随机位置：从2-3个预设位置中选择
	var extraction_positions = [
		Vector2(950, 800),
		Vector2(850, 600),
		Vector2(750, 900)
	]
	extraction_point.position = extraction_positions[randi() % extraction_positions.size()]
	print("Main: 撤离点位置:", extraction_point.position)

## 生成玩家携带的蚂蚁（友方蚂蚁）
func spawn_player_ants(ant_count: Dictionary) -> void:
	if ant_count.is_empty():
		return
	if not ANT_SCENE:
		print("Main: ANT_SCENE 未加载")
		return

	print("Main: 生成玩家蚂蚁，ant_count=", ant_count)

	for ant_type in ant_count.keys():
		var count = ant_count[ant_type]
		if count <= 0:
			continue
		var stats = ANT_STATS.get(ant_type, ANT_STATS["worker"])
		for i in range(count):
			var ant = ANT_SCENE.instantiate()
			ant.ant_type = ant_type
			ant.max_hp = stats["hp"]
			ant.hp = stats["hp"]
			ant.atk = stats["atk"]
			ant.speed = stats["speed"]
			ant.atk_range = stats["atk_range"]
			ant.atk_cool = stats["atk_cool"]

			# 在玩家周围随机位置生成
			var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			ant.global_position = player.global_position + offset

			add_child(ant)
			player_ants.append(ant)
			ant.tree_exited.connect(_on_ant_died.bind(ant))

	print("Main: 生成了 %d 只蚂蚁" % player_ants.size())

func _on_ant_died(ant: CharacterBody2D) -> void:
	if ant in player_ants:
		player_ants.erase(ant)
	print("Main: 蚂蚁死亡，剩余 %d 只" % player_ants.size())

func spawn_resources() -> void:
	# 随机生成3-5个资源点
	var resource_count = randi() % 3 + 3  # 3-5个
	var resource_types = ["beetle_remains", "locust_remains", "spider_remains", "mantis_remains"]

	for i in range(resource_count):
		# 在地图范围内随机生成位置，避免太靠近边缘
		var pos = Vector2(randf_range(100, 980), randf_range(100, 1500))
		var res_type = resource_types[randi() % resource_types.size()]
		spawn_resource(pos, res_type)
	print("Main: 生成了 %d 个资源点" % resource_count)

func spawn_obstacles() -> void:
	# 障碍物优化：移除靠近玩家初始位置(1500Y)的障碍，保留战术区障碍
	var obstacle_base_positions = [
		Vector2(270, 422),
		Vector2(777, 537),
		Vector2(540, 680)
	]
	for base_pos in obstacle_base_positions:
		var obs = create_obstacle()
		# 障碍物位置随机偏移 ±50像素
		obs.position = base_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		obs.add_to_group("obstacles")
		add_child(obs)
		obstacles.append(obs)

func create_obstacle() -> Node2D:
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40
	collision.shape = circle

	var body = StaticBody2D.new()
	body.add_child(collision)

	var sprite = Sprite2D.new()
	sprite.modulate = Color(0.35, 0.35, 0.45)
	body.add_child(sprite)

	return body

func spawn_initial_enemies() -> void:
	# 根据玩家资源计算波次和每波敌人数量
	var player_resources = inventory.beetle_remains
	var enemies_per_wave = get_enemies_per_wave(player_resources)
	max_waves = 3  # 固定3波
	current_wave = 0
	wave_in_progress = false
	print("Main: 波次系统初始化 - 资源:%d, 每波敌人数:%d, 波次:%d" % [player_resources, enemies_per_wave, max_waves])
	spawn_next_wave(enemies_per_wave)

## 根据玩家资源计算每波敌人数量
func get_enemies_per_wave(res: int) -> int:
	if res < 50:
		return 3  # 低难度
	elif res <= 150:
		return 5  # 中难度
	else:
		return 7  # 高难度

## 生成下一波敌人
func spawn_next_wave(enemies_count: int) -> void:
	current_wave += 1
	wave_in_progress = true
	wave_enemies_remaining = enemies_count
	print("Main: 生成第%d波敌人, 数量:%d" % [current_wave, enemies_count])
	for i in range(enemies_count):
		spawn_enemy()

	# 第三波时有30%概率生成蜂后BOSS
	if current_wave == 3 and randf() < 0.3:
		spawn_boss_wasp()
		wave_enemies_remaining += 1

	update_ui()

## 生成蜂后BOSS
func spawn_boss_wasp() -> void:
	var boss_scene = preload("res://scenes/boss_wasp.tscn")
	var boss = boss_scene.instantiate()

	# 在地图边缘生成BOSS
	var spawn_pos: Vector2
	var edge = randi() % 4
	match edge:
		0: spawn_pos = Vector2(randf_range(100, 980), 100)  # 上边
		1: spawn_pos = Vector2(100, randf_range(100, 1800))  # 左边
		2: spawn_pos = Vector2(randf_range(100, 980), 1800)  # 下边
		3: spawn_pos = Vector2(980, randf_range(100, 1800))  # 右边

	boss.position = spawn_pos
	boss.boss_died.connect(_on_boss_died)
	add_child(boss)
	enemies.append(boss)
	current_boss = boss  # 记录当前BOSS引用
	print("Main: 蜂后BOSS已生成! 位置:", spawn_pos)

	# 显示BOSS血条UI
	show_boss_ui("蜂后")

## BOSS死亡回调
func _on_boss_died() -> void:
	print("Main: BOSS已被击败!")
	current_boss = null
	# 隐藏BOSS血条UI
	hide_boss_ui()
	show_warning_announcement("BOSS已被击败!")

## 敌人死亡时调用
func _on_enemy_died(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
			return
	enemies.erase(enemy)
	wave_enemies_remaining -= 1
	kill_count += 1  # 增加击杀数
	update_ui()
	if wave_enemies_remaining <= 0 and wave_in_progress:
		wave_in_progress = false
		if current_wave < max_waves:
			# 等待一小段时间后生成下一波
			if get_tree() != null:
				await get_tree().create_timer(1.0).timeout
				if not is_instance_valid(self) or not is_inside_tree():
					return
				var player_resources = inventory.beetle_remains
				var enemies_per_wave = get_enemies_per_wave(player_resources)
				spawn_next_wave(enemies_per_wave)
		else:
			# 所有波次完成
			victory()

func spawn_enemy() -> void:
	# 检查敌人数量上限
	if enemies.size() >= MAX_ENEMIES:
		print("Main: 敌人数量已达上限(%d)，暂停生成" % MAX_ENEMIES)
		return

	var enemy: Node = ENEMY_SCENE.instantiate()

	# 分区生成系统
	var _player_pos = player.global_position
	var pos := Vector2(500, 500)

	enemy.position = pos
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemies.append(enemy)

	enemy.tree_exited.connect(_on_enemy_died.bind(enemy))

func spawn_resource(pos: Vector2, type: String = "beetle_remains") -> void:
	var resource = RESOURCE_SCENE.instantiate()
	resource.position = pos
	resource.picked_up.connect(_on_resource_picked_up)
	resource.set_resource_type(type)
	add_child(resource)
	resources.append(resource)

func _on_resource_picked_up(resource: Area2D, res_type: String = "beetle_remains") -> void:
	if res_type in inventory:
		inventory[res_type] += 1
	else:
		inventory[res_type] = 1
	resource_collected.emit(1)
	player.apply_attack_boost()
	resources.erase(resource)
	update_ui()

func _on_extraction_started() -> void:
	print("Main: extraction started!")
	has_extraction_started = true
	extraction_progress = 0.0

func _on_extraction_progress(progress: float) -> void:
	extraction_progress = progress
	update_ui()

func _on_extraction_completed() -> void:
	print("Main: extraction completed!")
	# 教程撤离判定：如果教程步骤为4，标记撤离完成
	if tutorial_step == 4:
		_tutorial_resource_picked_up = true
		advance_tutorial()
	extraction_success()

func _on_player_dead() -> void:
	print("Main: player dead!")
	defeat()

func victory() -> void:
	game_running = false
	survival_time = Time.get_ticks_msec() / 1000.0 - battle_start_time
	save_battle_replay()  # 保存回放
	await get_tree().create_timer(1.5).timeout
	show_settlement(true)

func defeat() -> void:
	game_running = false
	survival_time = Time.get_ticks_msec() / 1000.0 - battle_start_time
	save_battle_replay()  # 保存回放
	await get_tree().create_timer(1.5).timeout
	show_settlement(false)

func extraction_success() -> void:
	print("Main: extraction_success called!")
	spawn_extraction_celebration()
	# 撤离成功时震动庆祝
	vibrate(2)
	game_running = false
	survival_time = Time.get_ticks_msec() / 1000.0 - battle_start_time
	save_battle_replay()  # 保存回放
	await get_tree().create_timer(1.0).timeout
	show_settlement(true, true)  # true=胜利, true=撤离成功

## 创建结算界面
func show_settlement(is_victory: bool, is_extraction: bool = false) -> void:
	# 计算存活时间格式
	var minutes = int(survival_time) / 60.0
	var seconds = int(survival_time) % 60
	var time_text = "%02d:%02d" % [minutes, seconds]

	# 创建结算面板
	settlement_panel = Panel.new()
	settlement_panel.set_anchors_preset(Control.PRESET_CENTER)
	settlement_panel.size = Vector2(400, 350)
	var settlement_style = StyleBoxFlat.new()
	settlement_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	settlement_panel.add_theme_stylebox_override("panel", settlement_style)
	settlement_panel.visible = true
	get_tree().root.add_child(settlement_panel)

	# 标题（胜利/失败）
	var title_label = Label.new()
	if is_extraction:
		title_label.text = "撤离成功！"
	else:
		title_label.text = "胜利！" if is_victory else "任务失败"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_top = 20
	title_label.size = Vector2(400, 40)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_extraction or is_victory:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # 金色
	else:
		title_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))  # 红色
	settlement_panel.add_child(title_label)

	# 分隔线
	var separator = Polygon2D.new()
	separator.position = Vector2(540 - 150, 65)
	separator.polygon = PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, 4), Vector2(0, 4)])
	separator.color = Color(0.3, 0.3, 0.4)
	settlement_panel.add_child(separator)

	# 统计信息容器
	var stats_vbox = VBoxContainer.new()
	stats_vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stats_vbox.offset_top = 80
	stats_vbox.offset_left = 50
	stats_vbox.size = Vector2(300, 160)
	settlement_panel.add_child(stats_vbox)

	# 资源统计
	var resource_label = Label.new()
	resource_label.text = "获得资源: %d" % inventory.beetle_remains
	resource_label.size = Vector2(300, 30)
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_vbox.add_child(resource_label)

	# 击杀统计
	var kill_label = Label.new()
	kill_label.text = "击杀敌人: %d" % kill_count
	kill_label.size = Vector2(300, 30)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_vbox.add_child(kill_label)

	# 存活时间
	var time_label = Label.new()
	time_label.text = "存活时间: %s" % time_text
	time_label.size = Vector2(300, 30)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_vbox.add_child(time_label)

	# 如果是撤离成功，显示额外提示
	if is_extraction:
		var tip_label = Label.new()
		tip_label.text = "[ 资源已安全运回基地 ]"
		tip_label.size = Vector2(300, 30)
		tip_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_vbox.add_child(tip_label)

	# 返回基地按钮
	var return_btn = Button.new()
	return_btn.text = "返回基地"
	return_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	return_btn.offset_top = 260
	return_btn.size = Vector2(200, 45)
	return_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_btn.connect("pressed", _on_return_button_pressed)
	settlement_panel.add_child(return_btn)

func _on_return_button_pressed() -> void:
	# 移除结算面板
	if settlement_panel and is_instance_valid(settlement_panel):
		settlement_panel.queue_free()
		settlement_panel = null
	return_to_base()

## 撤离成功金色粒子庆祝效果
func spawn_extraction_celebration() -> void:
	# 在玩家位置生成金色粒子庆祝效果
	if not player:
		return

	var player_pos = player.global_position
	var particle_count = mini(30, MAX_CELEBRATION_PARTICLES)  # 限制粒子数量

	# 金色粒子喷泉
	for i in range(particle_count):
		var particle = Polygon2D.new()
		var p_points = PackedVector2Array([
			Vector2(-5, -5), Vector2(5, -5),
			Vector2(5, 5), Vector2(-5, 5)
		])
		particle.polygon = p_points
		# 金色到黄色渐变
		var t = float(i) / 30.0
		particle.color = Color(1.0, 0.7 + t * 0.3, 0.1, 0.9)
		particle.global_position = player_pos
		get_tree().root.add_child(particle)

		# 向外散射的弧形轨迹
		var angle = -PI/2 + randf_range(-PI/3, PI/3)  # 向上散射
		var dist = randf_range(80, 200)
		var target_offset = Vector2(cos(angle), sin(angle)) * dist
		var target_pos = player_pos + target_offset

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, 0.6 + randf() * 0.3)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(particle.queue_free)

	# 中心金色光环爆发
	var burst = Polygon2D.new()
	var burst_points = PackedVector2Array()
	for j in range(24):
		var a = 2 * PI * j / 24
		burst_points.append(Vector2(cos(a), sin(a)) * 30)
	burst.polygon = burst_points
	burst.color = Color(1.0, 0.9, 0.3, 0.8)
	burst.global_position = player_pos
	get_tree().root.add_child(burst)

	var burst_tween = create_tween()
	burst_tween.tween_property(burst, "scale", Vector2(4.0, 4.0), 0.4)
	burst_tween.chain().tween_property(burst, "modulate:a", 0.0, 0.2)
	burst_tween.chain().tween_callback(burst.queue_free)

	# 星星闪烁（限制数量）
	for k in range(mini(8, particle_count / 3.0)):
		var star = Polygon2D.new()
		var star_points = PackedVector2Array([
			Vector2(0, -8), Vector2(2, -2), Vector2(8, 0),
			Vector2(2, 2), Vector2(0, 8), Vector2(-2, 2),
			Vector2(-8, 0), Vector2(-2, -2)
		])
		star.polygon = star_points
		star.color = Color(1.0, 0.95, 0.5, 1.0)
		star.global_position = player_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		star.scale = Vector2(0.5, 0.5)
		get_tree().root.add_child(star)

		var star_tween = create_tween()
		star_tween.set_parallel(true)
		star_tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.2)
		star_tween.chain().tween_property(star, "modulate:a", 0.0, 0.1)
		star_tween.chain().tween_callback(star.queue_free)

func return_to_base() -> void:
	print("Main: return_to_base called!")
	if not _game_manager_cache:
		_game_manager_cache = get_tree().get_first_node_in_group("game_manager")
		print("Main: got game_manager cache:", _game_manager_cache)
	if _game_manager_cache:
		_game_manager_cache.return_to_base()
	else:
		print("Main: ERROR - no game_manager found!")

func start_battle(initial_inventory: Dictionary = {}, ant_count: Dictionary = {}) -> void:
	print("Main: start_battle called, visible=", visible)
	game_running = true
	inventory = initial_inventory.duplicate()
	# 确保 inventory 有必要的键
	if not inventory.has("beetle_remains"):
		inventory["beetle_remains"] = 0
	if not inventory.has("locust_remains"):
		inventory["locust_remains"] = 0
	if not inventory.has("spider_remains"):
		inventory["spider_remains"] = 0
	if not inventory.has("mantis_remains"):
		inventory["mantis_remains"] = 0
	if not inventory.has("food") or inventory.get("food", 0) <= 0:
		inventory["food"] = 100
	print("Main: start_battle - inventory after check=", inventory, ", food=", inventory.get("food", 0))
	print("Main: start_battle - canvas_layer=", canvas_layer)
	extraction_progress = 0.0
	current_wave = 0
	max_waves = 1
	wave_enemies_remaining = 0
	wave_in_progress = false
	tutorial_step = 0  # 重置教学进度
	tutorial_completed = false  # 重置教程完成标志
	_tutorial_resource_picked_up = false  # 重置资源拾取标志
	kill_count = 0  # 重置击杀数
	survival_time = 0.0  # 重置存活时间
	input_recording.clear()  # 清空输入记录

	player.global_position = Vector2(540, 1500)
	player.hp = player.HP_MAX
	player.atk_boost = 0.0
	player.atk_boost_timer = 0.0
	player.health_bar.value = player.HP_MAX

	# 重置摄像机位置紧跟在玩家位置之后
	if camera and is_instance_valid(camera):
		camera.global_position = player.global_position
		camera.make_current()
		print("Main: camera reset to player position: ", camera.global_position)

	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	# 清理旧蚂蚁
	for a in player_ants:
		if is_instance_valid(a):
			a.queue_free()
	player_ants.clear()

	for r in resources:
		if is_instance_valid(r):
			r.queue_free()
	resources.clear()

	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()

	# 生成玩家携带的蚂蚁
	spawn_player_ants(ant_count)

	# 初始化战场内容
	spawn_obstacles()
	spawn_resources()
	spawn_initial_enemies()

	for enemy in enemies:
		enemy.add_to_group("enemies")

	if extraction_point and extraction_point.has_method("reset_extraction"):
		extraction_point.reset_extraction()

	# 连接信号
	if not extraction_point.extraction_started.is_connected(_on_extraction_started):
		extraction_point.extraction_started.connect(_on_extraction_started)
	if not extraction_point.extraction_progress.is_connected(_on_extraction_progress):
		extraction_point.extraction_progress.connect(_on_extraction_progress)
	if not extraction_point.extraction_completed.is_connected(_on_extraction_completed):
		extraction_point.extraction_completed.connect(_on_extraction_completed)
	if not player.player_dead.is_connected(_on_player_dead):
		player.player_dead.connect(_on_player_dead)
	print("Main: battle signals connected")

	# 初始化UI系统
	init_boss_health_bar()
	init_minimap()
	show_battle_ui()  # 显示战场UI元素
	update_ui()
	start_tutorial_if_needed()

	# 初始化天气系统
	init_weather_system()

	# 重置天气系统粒子
	if ambient_dust_container:
		for dust in dust_particles:
			if is_instance_valid(dust):
				dust.global_position = Vector2(randf_range(50, 1030), randf_range(-100, 1900))
				dust.set("_dust_age", 0.0)
				dust.set("_dust_velocity", Vector2(randf_range(-0.3, 0.3), randf_range(0.2, 0.8)))
	if light_beam_container:
		for light in light_particles:
			if is_instance_valid(light):
				light.global_position = Vector2(randf_range(100, 980), randf_range(200, 1600))
				light.set("_light_base_pos", light.global_position)
				light.set("_light_flicker", randf() * 10.0)
	update_ui()
	start_tutorial_if_needed()

	print("Main: start_battle completed")

func get_collected_resources() -> Dictionary:
	return inventory.duplicate()

func update_ui() -> void:
	print("Main: update_ui called, canvas_layer=", canvas_layer)
	var resource_display = canvas_layer.get_node_or_null("ResourceDisplay")
	print("Main: update_ui - resource_display=", resource_display)
	if resource_display:
		var vbox = resource_display.get_node_or_null("VBox")
		if vbox:
			var resource_label = vbox.get_node_or_null("ResourceLabel")
			if resource_label:
				resource_label.text = "x %d" % inventory.beetle_remains
				print("Main: update_ui - set resource_label to x %d" % inventory.beetle_remains)

	var buff_label = canvas_layer.get_node_or_null("BuffLabel")
	if buff_label:
		if player.atk_boost > 0:
			buff_label.text = "攻击+"
			buff_label.modulate = Color(0.29, 0.87, 0.31)
		else:
			buff_label.text = ""
			buff_label.modulate = Color(1, 1, 1, 0)

	var extract_label = canvas_layer.get_node_or_null("ExtractProgress")
	if extract_label:
		if has_extraction_started:
			extract_label.text = "撤离中: %.0f%%" % (extraction_progress * 100)
			extract_label.visible = true
		else:
			extract_label.visible = false

	var enemy_count_label = canvas_layer.get_node_or_null("EnemyCountLabel")
	if enemy_count_label:
		enemy_count_label.text = "敌人: %d" % enemies.size()

	var health_bar = canvas_layer.get_node_or_null("HealthBar")
	var health_label = canvas_layer.get_node_or_null("HealthBar/HealthLabel")
	if health_bar and health_label:
		health_bar.max_value = player.HP_MAX
		health_bar.value = player.hp
		health_label.text = "生命: %d/%d" % [player.hp, player.HP_MAX]

	# 更新BOSS血条
	update_boss_health_display()
	# 更新小地图
	update_minimap()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	# 记录玩家输入用于回放
	if game_running and event is InputEventKey and event.pressed:
		var input_data = {
			"time": Time.get_ticks_msec() / 1000.0 - battle_start_time,
			"action": event.action_name if "action_name" in event else "",
			"position": player.global_position if player else Vector2.ZERO
		}
		input_recording.append(input_data)

	# 虚拟触控输入处理
	handle_touch_input(event)

	# 手柄输入检测
	handle_gamepad_input(event)

## 手柄输入处理
func handle_gamepad_input(event: InputEvent) -> void:
	# 获取当前连接的手柄索引（第一个手柄）
	var _gamepad_id = 0

	# 左摇杆 (L3) - 移动
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			gamepad_leftstick.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y:
			gamepad_leftstick.y = event.axis_value
		# 右摇杆 (R3) - 攻击方向
		elif event.axis == JOY_AXIS_RIGHT_X:
			gamepad_rightstick.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			gamepad_rightstick.y = event.axis_value
		# LT 扳机 - 蓄力攻击
		elif event.axis == JOY_AXIS_TRIGGER_LEFT:
			gamepad_lt = (event.axis_value + 1) / 2  # 将 -1..1 转换为 0..1
		# RT 扳机 - 蓄力攻击
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			gamepad_rt = (event.axis_value + 1) / 2  # 将 -1..1 转换为 0..1

	# LB 按钮 - 切换武器（上）
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			gamepad_lb = event.pressed
		# RB 按钮 - 切换武器（下）
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			gamepad_rb = event.pressed

	# 检测 LB/RB 按下（而不是按住）
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER and not prev_gamepad_lb:
			_on_gamepad_lb_pressed()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER and not prev_gamepad_rb:
			_on_gamepad_rb_pressed()

	# 更新上一帧状态
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			prev_gamepad_lb = event.pressed
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			prev_gamepad_rb = event.pressed

## 手柄 LB 按下 - 切换到上一个武器
func _on_gamepad_lb_pressed() -> void:
	if player and player.has_method("switch_weapon_previous"):
		player.switch_weapon_previous()
		print("Main: 手柄 LB 切换到上一个武器")

## 手柄 RB 按下 - 切换到下一个武器
func _on_gamepad_rb_pressed() -> void:
	if player and player.has_method("switch_weapon_next"):
		player.switch_weapon_next()
		print("Main: 手柄 RB 切换到下一个武器")

## 获取手柄左摇杆输入（供 Player 调用）
func get_gamepad_leftstick() -> Vector2:
	return gamepad_leftstick

## 获取手柄右摇杆输入（供 Player 调用）
func get_gamepad_rightstick() -> Vector2:
	return gamepad_rightstick

## 获取手柄 LT/RT 扳机值（供 Player 调用，用于蓄力攻击）
func get_gamepad_trigger() -> float:
	return max(gamepad_lt, gamepad_rt)  # LT 和 RT 都可以触发蓄力

## 获取手柄是否连接
func is_gamepad_connected() -> bool:
	return Input.get_connected_joypads().size() > 0

## 公告系统

### 显示公告
## text: 公告文本
## type: AnnouncementType 枚举类型
## duration: 显示时长（秒），默认3秒
func show_announcement(text: String, type: AnnouncementType = AnnouncementType.SYSTEM, duration: float = 3.0) -> void:
	# 如果已有公告在显示，先移除
	if announcement_panel and is_instance_valid(announcement_panel):
		announcement_panel.queue_free()
	if announcement_timer and is_instance_valid(announcement_timer):
		announcement_timer.queue_free()
	if announcement_tween and is_instance_valid(announcement_tween):
		announcement_tween.kill()

	# 获取公告配置
	var config = _get_announcement_config(type)

	# 创建公告面板
	announcement_panel = Panel.new()
	announcement_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	announcement_panel.offset_top = -80  # 初始位置在屏幕外
	announcement_panel.offset_left = -200
	announcement_panel.offset_right = 200
	announcement_panel.offset_bottom = 0
	announcement_panel.size = Vector2(400, 60)
	var announce_style = StyleBoxFlat.new()
	announce_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	announce_style.border_color = config.color
	announce_style.border_width_left = 3
	announce_style.border_width_top = 3
	announce_style.border_width_right = 3
	announce_style.border_width_bottom = 3
	announcement_panel.add_theme_stylebox_override("panel", announce_style)
	get_tree().root.add_child(announcement_panel)

	# 创建图标标签
	var icon_label = Label.new()
	icon_label.text = config.icon
	icon_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	icon_label.offset_left = 15
	icon_label.offset_top = 8
	icon_label.offset_right = 50
	icon_label.offset_bottom = 52
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 28)
	announcement_panel.add_child(icon_label)

	# 创建文本标签
	var text_label = Label.new()
	text_label.text = text
	text_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	text_label.offset_left = 55
	text_label.offset_top = 10
	text_label.offset_right = 385
	text_label.offset_bottom = 50
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_color_override("font_color", config.text_color)
	text_label.add_theme_font_size_override("font_size", 18)
	announcement_panel.add_child(text_label)

	# 创建滑入动画
	announcement_tween = create_tween()
	announcement_tween.set_parallel(true)
	# 从顶部滑入
	announcement_tween.tween_property(announcement_panel, "offset_top", 20.0, 0.4)
	announcement_tween.set_ease(Tween.EASE_OUT)
	announcement_tween.set_trans(Tween.TRANS_BACK)

	# 创建计时器用于自动消失
	announcement_timer = Timer.new()
	announcement_timer.wait_time = duration
	announcement_timer.one_shot = true
	announcement_timer.timeout.connect(_on_announcement_timeout)
	get_tree().root.add_child(announcement_timer)
	announcement_timer.start()

### 公告自动消失
func _on_announcement_timeout() -> void:
	if announcement_tween and is_instance_valid(announcement_tween):
		announcement_tween.kill()

	# 滑出动画
	announcement_tween = create_tween()
	announcement_tween.set_parallel(true)
	announcement_tween.tween_property(announcement_panel, "offset_top", -80.0, 0.3)
	announcement_tween.set_ease(Tween.EASE_IN)
	announcement_tween.set_trans(Tween.TRANS_QUAD)
	announcement_tween.chain().tween_callback(Callable(self, "_on_announcement_hide_complete"))

### 公告完全隐藏后清理
func _on_announcement_hide_complete() -> void:
	if announcement_panel and is_instance_valid(announcement_panel):
		announcement_panel.queue_free()
		announcement_panel = null
	if announcement_timer and is_instance_valid(announcement_timer):
		announcement_timer.queue_free()
		announcement_timer = null

### 获取公告配置
func _get_announcement_config(type: AnnouncementType) -> Dictionary:
	match type:
		AnnouncementType.SYSTEM:
			return {"icon": "[S]", "color": Color(0.5, 0.5, 0.5), "text_color": Color(0.9, 0.9, 0.9)}
		AnnouncementType.MAINTENANCE:
			return {"icon": "[M]", "color": Color(1.0, 0.6, 0.2), "text_color": Color(1.0, 0.85, 0.7)}
		AnnouncementType.EVENT:
			return {"icon": "[E]", "color": Color(0.8, 0.4, 1.0), "text_color": Color(1.0, 0.9, 1.0)}
		AnnouncementType.UPDATE:
			return {"icon": "[U]", "color": Color(0.3, 0.6, 1.0), "text_color": Color(0.85, 0.95, 1.0)}
		AnnouncementType.WARNING:
			return {"icon": "[W]", "color": Color(1.0, 0.3, 0.3), "text_color": Color(1.0, 0.85, 0.85)}
		_:
			return {"icon": "[S]", "color": Color(0.5, 0.5, 0.5), "text_color": Color(0.9, 0.9, 0.9)}

### 快捷方法：显示系统公告
func show_system_announcement(text: String, duration: float = 3.0) -> void:
	show_announcement(text, AnnouncementType.SYSTEM, duration)

### 快捷方法：显示维护公告
func show_maintenance_announcement(text: String, duration: float = 3.0) -> void:
	show_announcement(text, AnnouncementType.MAINTENANCE, duration)

### 快捷方法：显示活动公告
func show_event_announcement(text: String, duration: float = 3.0) -> void:
	show_announcement(text, AnnouncementType.EVENT, duration)

### 快捷方法：显示更新公告
func show_update_announcement(text: String, duration: float = 3.0) -> void:
	show_announcement(text, AnnouncementType.UPDATE, duration)

### 快捷方法：显示警告公告
func show_warning_announcement(text: String, duration: float = 3.0) -> void:
	show_announcement(text, AnnouncementType.WARNING, duration)

## 战斗回放系统

### 保存当前战斗记录
func save_battle_replay() -> void:
	if input_recording.is_empty():
		return

	var replay_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"survival_time": survival_time,
		"kill_count": kill_count,
		"inventory": inventory.duplicate(),
		"input_recording": input_recording.duplicate()
	}

	# 添加到回放列表（保持最近3场）
	battle_recordings.append(replay_data)
	while battle_recordings.size() > MAX_REPLAY_COUNT:
		battle_recordings.pop_front()

	# 保存到文件
	_save_replays_to_file()

### 保存回放到文件
func _save_replays_to_file() -> void:
	var dir = DirAccess.open(REPLAY_SAVE_PATH)
	if dir == null:
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(REPLAY_SAVE_PATH)

	var file_path = REPLAY_SAVE_PATH + "replays.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(battle_recordings)
		file.store_string(json_string)
		file.close()
		print("Main: 回放已保存到 ", file_path)
	else:
		print("Main: 无法保存回放文件")

### 加载回放数据
func load_replays_from_file() -> void:
	var file_path = REPLAY_SAVE_PATH + "replays.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_string)
		if parsed:
			battle_recordings = parsed
			print("Main: 已加载 %d 场回放记录" % battle_recordings.size())
		else:
			print("Main: 回放文件解析失败")
	else:
		print("Main: 未找到回放文件")

### 回放指定场次战斗
## replay_index: 回放索引（0=最近一场，1=上一场，以此类推）
func replay_battle(replay_index: int = 0) -> void:
	if battle_recordings.is_empty():
		load_replays_from_file()

	if battle_recordings.is_empty():
		show_warning_announcement("没有可回放的战斗记录")
		return

	var index = battle_recordings.size() - 1 - replay_index
	if index < 0 or index >= battle_recordings.size():
		show_warning_announcement("无效的回放索引")
		return

	var replay_data = battle_recordings[index]
	print("Main: 开始回放第 %d 场战斗，存活时间: %.1f秒，击杀: %d" % [replay_index + 1, replay_data.survival_time, replay_data.kill_count])
	show_system_announcement("开始回放第 %d 场战斗" % (replay_index + 1))

### 获取回放列表信息
func get_replay_list() -> Array[Dictionary]:
	var list_info: Array[Dictionary] = []
	for i in range(battle_recordings.size()):
		var replay = battle_recordings[battle_recordings.size() - 1 - i]
		list_info.append({
			"index": i,
			"timestamp": replay.timestamp,
			"survival_time": replay.survival_time,
			"kill_count": replay.kill_count
		})
	return list_info

## 虚拟触控系统

### 处理触控输入
func handle_touch_input(event: InputEvent) -> void:
	var touch_controls = get_node_or_null("TouchControls")
	if not touch_controls:
		return

	var joystick_area = touch_controls.get_node_or_null("JoystickArea")
	var attack_button = touch_controls.get_node_or_null("AttackButton")
	var dash_button = touch_controls.get_node_or_null("DashButton")
	var extract_button = touch_controls.get_node_or_null("ExtractButton")

	# 攻击按钮处理 - 扩大检测半径提高灵敏度
	if attack_button:
		if event is InputEventScreenTouch:
			if event.position.distance_to(attack_button.global_position + attack_button.size / 2) < ATTACK_BUTTON_RADIUS:
				attack_button_down = event.pressed  # 即时响应

	# 冲刺按钮处理 - 扩大检测半径
	if dash_button:
		if event is InputEventScreenTouch:
			if event.position.distance_to(dash_button.global_position + dash_button.size / 2) < DASH_BUTTON_RADIUS:
				dash_button_down = event.pressed  # 即时响应

	# 撤离按钮处理 - 扩大检测半径
	if extract_button and event is InputEventScreenTouch:
		if event.position.distance_to(extract_button.global_position + extract_button.size / 2) < DASH_BUTTON_RADIUS:
			if event.pressed:
				start_extraction()

	# 虚拟摇杆处理
	if joystick_area and event is InputEventScreenDrag:
		var joystick_base_pos = joystick_area.global_position
		var drag_pos = event.position
		var offset = drag_pos - joystick_base_pos
		var max_dist = 50.0

		if offset.length() > max_dist:
			offset = offset.normalized() * max_dist

		# 应用死区处理 - 减少微小偏移产生的漂移
		var raw_input = offset / max_dist
		if raw_input.length() < JOYSTICK_DEADZONE:
			joystick_input = Vector2.ZERO
		else:
			# 应用灵敏度并归一化
			var adjusted_length = (raw_input.length() - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE)
			joystick_input = raw_input.normalized() * adjusted_length * JOYSTICK_SENSITIVITY
			joystick_input = joystick_input.limit_length(1.0)
		joystick_active = true

		# 更新摇杆视觉位置
		var thumb = joystick_area.get_node_or_null("JoystickThumb")
		if thumb:
			thumb.position = offset

		# 更新玩家攻击方向
		if joystick_input != Vector2.ZERO:
			player.attack_direction = joystick_input.angle()

	elif event is InputEventScreenTouch and not event.pressed and joystick_active:
		# 手指抬起，重置摇杆
		joystick_active = false
		joystick_input = Vector2.ZERO
		var thumb = joystick_area.get_node_or_null("JoystickThumb")
		if thumb:
			thumb.position = Vector2.ZERO

### 开始撤离（触控按钮触发）
func start_extraction() -> void:
	if extraction_point and not has_extraction_started:
		extraction_point.start_extraction()

### 获取虚拟摇杆输入（供Player调用）
func get_joystick_input() -> Vector2:
	return joystick_input

### 获取攻击按钮状态
func is_attack_button_down() -> bool:
	return attack_button_down

### 获取冲刺按钮状态
func is_dash_button_down() -> bool:
	return dash_button_down

## ==================== 天气系统 - 洞穴氛围效果 ====================

### 初始化天气系统
func init_weather_system() -> void:
	# 创建尘埃粒子容器
	ambient_dust_container = Node2D.new()
	ambient_dust_container.name = "AmbientDustContainer"
	add_child(ambient_dust_container)

	# 创建光效容器
	light_beam_container = Node2D.new()
	light_beam_container.name = "LightBeamContainer"
	add_child(light_beam_container)

	# 初始化尘埃粒子
	for i in range(MAX_DUST_PARTICLES):
		create_dust_particle()

	# 初始化光束
	for i in range(MAX_LIGHT_PARTICLES):
		create_light_beam()

	# 创建天气更新计时器
	weather_timer = Timer.new()
	weather_timer.wait_time = 0.05  # 每50ms更新一次
	weather_timer.timeout.connect(_on_weather_timer_timeout)
	add_child(weather_timer)
	weather_timer.start()

	print("Main: 天气系统初始化完成 - 尘埃粒子:%d, 光效:%d" % [MAX_DUST_PARTICLES, MAX_LIGHT_PARTICLES])

### 创建尘埃粒子
func create_dust_particle() -> void:
	var dust = Polygon2D.new()
	# 小型不规则多边形模拟尘埃
	var points = PackedVector2Array([
		Vector2(-2, -1), Vector2(1, -2),
		Vector2(2, 0), Vector2(1, 2),
		Vector2(-1, 1)
	])
	dust.polygon = points

	# 洞穴灰白色尘埃，带透明
	var brightness = randf_range(0.5, 0.8)
	dust.color = Color(brightness, brightness * 0.95, brightness * 0.9, randf_range(0.2, 0.5))
	dust.global_position = Vector2(randf_range(50, 1030), randf_range(-100, 1900))

	# 随机大小
	var scale_factor = randf_range(0.5, 1.5)
	dust.scale = Vector2(scale_factor, scale_factor)

	# 添加到容器
	ambient_dust_container.add_child(dust)
	dust_particles.append(dust)

	# 初始化粒子数据
	dust.set("_dust_velocity", Vector2(randf_range(-0.3, 0.3), randf_range(0.2, 0.8)))
	dust.set("_dust_lifetime", randf_range(8.0, 15.0))
	dust.set("_dust_age", 0.0)

### 创建光束效果
func create_light_beam() -> void:
	var light = Polygon2D.new()
	# 细长三角形光束
	var points = PackedVector2Array([
		Vector2(0, -80),  # 顶部
		Vector2(-15, 0),  # 左下
		Vector2(15, 0)     # 右下
	])
	light.polygon = points

	# 温暖的金色/琥珀色光效
	var color_variation = randf_range(0.8, 1.0)
	light.color = Color(1.0, color_variation * 0.85, color_variation * 0.5, randf_range(0.15, 0.35))
	light.global_position = Vector2(randf_range(100, 980), randf_range(200, 1600))

	# 添加到容器
	light_beam_container.add_child(light)
	light_particles.append(light)

	# 初始化光效数据
	light.set("_light_base_pos", light.global_position)
	light.set("_light_flicker", 0.0)
	light.set("_light_flicker_speed", randf_range(2.0, 5.0))

### 天气计时器回调 - 更新所有粒子
func _on_weather_timer_timeout() -> void:
	if not game_running:
		return

	# 更新尘埃粒子
	for dust in dust_particles:
		if not is_instance_valid(dust):
			continue

		# 累积年龄
		if "_dust_age" in dust:
			dust.set("_dust_age", dust.get("_dust_age") + 0.05)

		# 缓慢飘落 + 轻微横向漂移
		if "_dust_velocity" in dust:
			var vel = dust.get("_dust_velocity")
			dust.global_position += vel

			# 轻微横向摆动
			vel.x += randf_range(-0.02, 0.02)
			vel.x = clamp(vel.x, -0.5, 0.5)
			dust.set("_dust_velocity", vel)

		# 重置超出边界的粒子
		if dust.global_position.y > 2000 or dust.global_position.x < -50 or dust.global_position.x > 1150:
			dust.global_position = Vector2(randf_range(50, 1030), randf_range(-50, 100))
			dust.set("_dust_age", 0.0)
			dust.set("_dust_velocity", Vector2(randf_range(-0.3, 0.3), randf_range(0.2, 0.8)))

		# 根据年龄淡入淡出
		if "_dust_age" in dust:
			var life_ratio = dust.get("_dust_age") / dust.get("_dust_lifetime")
			if life_ratio < 0.1:
				# 淡入
				dust.modulate.a = lerp(0.0, dust.color.a * 3, life_ratio * 10)
			elif life_ratio > 0.8:
				# 淡出
				dust.modulate.a = lerp(dust.color.a * 3, 0.0, (life_ratio - 0.8) * 5)
			else:
				dust.modulate.a = dust.color.a * 3

	# 更新光束效果
	for light in light_particles:
		if not is_instance_valid(light):
			continue

		# 闪烁效果
		if "_light_flicker" in light:
			light.set("_light_flicker", light.get("_light_flicker") + 0.05 * light.get("_light_flicker_speed"))
			var flicker = (sin(light.get("_light_flicker")) + 1.0) * 0.5  # 0-1
			var base_alpha = light.color.a
			light.modulate.a = base_alpha * (0.7 + flicker * 0.3)

		# 轻微上下浮动
		if "_light_base_pos" in light:
			var offset_y = sin(light.get("_light_flicker") * 0.5) * 5
			light.global_position.y = light.get("_light_base_pos").y + offset_y

			# 缓慢横向漂移
			light.global_position.x += randf_range(-0.1, 0.1)
			light.set("_light_base_pos", Vector2(light.global_position.x, light.get("_light_base_pos").y))

### 清理天气系统
func cleanup_weather_system() -> void:
	if weather_timer and is_instance_valid(weather_timer):
		weather_timer.stop()
		weather_timer.queue_free()
		weather_timer = null

	for dust in dust_particles:
		if is_instance_valid(dust):
			dust.queue_free()
	dust_particles.clear()

	for light in light_particles:
		if is_instance_valid(light):
			light.queue_free()
	light_particles.clear()

	if ambient_dust_container and is_instance_valid(ambient_dust_container):
		ambient_dust_container.queue_free()
		ambient_dust_container = null

	if light_beam_container and is_instance_valid(light_beam_container):
		light_beam_container.queue_free()
		light_beam_container = null

	print("Main: 天气系统已清理")

## ==================== 战斗粒子效果系统 ====================

### 创建资源拾取橙色粒子爆发
func create_resource_burst(pos: Vector2) -> void:
	var particle_count = 8
	for i in range(particle_count):
		var particle = Polygon2D.new()
		var p_points = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4),
			Vector2(4, 4), Vector2(-4, 4)
		])
		particle.polygon = p_points
		# 橙色到金色渐变
		var t = float(i) / particle_count
		particle.color = Color(1.0, 0.5 + t * 0.3, 0.1, 0.9)
		particle.global_position = pos
		get_tree().root.add_child(particle)

		# 向外散射
		var angle = randf_range(-PI, PI)
		var dist = randf_range(30, 80)
		var target_offset = Vector2(cos(angle), sin(angle)) * dist
		var target_pos = pos + target_offset

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, 0.4 + randf() * 0.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(particle.queue_free)

	# 中心闪光
	var burst = Polygon2D.new()
	var burst_points = PackedVector2Array()
	for j in range(16):
		var a = 2 * PI * j / 16
		burst_points.append(Vector2(cos(a), sin(a)) * 15)
	burst.polygon = burst_points
	burst.color = Color(1.0, 0.7, 0.2, 0.8)
	burst.global_position = pos
	get_tree().root.add_child(burst)

	var burst_tween = create_tween()
	burst_tween.tween_property(burst, "scale", Vector2(2.5, 2.5), 0.3)
	burst_tween.chain().tween_property(burst, "modulate:a", 0.0, 0.15)
	burst_tween.chain().tween_callback(burst.queue_free)

### 创建攻击命中红色冲击波
func create_attack_shockwave(pos: Vector2) -> void:
	var shockwave = Polygon2D.new()
	var points = PackedVector2Array()
	# 多边形冲击波
	var segments = 24
	for i in range(segments):
		var a = 2 * PI * i / segments
		points.append(Vector2(cos(a), sin(a)) * 40)
	shockwave.polygon = points
	shockwave.color = Color(1.0, 0.2, 0.1, 0.7)
	shockwave.global_position = pos
	get_tree().root.add_child(shockwave)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(2.0, 2.0), 0.25)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.25)
	tween.set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(shockwave.queue_free)

	# 添加几个小的飞溅碎片
	for i in range(6):
		var debris = Polygon2D.new()
		debris.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(2, -3), Vector2(3, 2), Vector2(-2, 3)])
		debris.color = Color(1.0, 0.3, 0.1, 0.8)
		debris.global_position = pos
		get_tree().root.add_child(debris)

		var angle = randf_range(0, TAU)
		var dist = randf_range(50, 100)
		var debris_tween = create_tween()
		debris_tween.set_parallel(true)
		debris_tween.tween_property(debris, "global_position", pos + Vector2(cos(angle), sin(angle)) * dist, 0.35)
		debris_tween.set_ease(Tween.EASE_OUT)
		debris_tween.chain().tween_property(debris, "modulate:a", 0.0, 0.15)
		debris_tween.chain().tween_callback(debris.queue_free)

### 创建蚂蚁移动时的腿部尘埃
func create_ant_dust(pos: Vector2, count: int = 3) -> void:
	for i in range(count):
		var dust = Polygon2D.new()
		var dust_points = PackedVector2Array([
			Vector2(-2, -1), Vector2(1, -1),
			Vector2(2, 0), Vector2(1, 1),
			Vector2(-1, 1)
		])
		dust.polygon = dust_points
		# 棕色/土黄色尘埃
		var brightness = randf_range(0.4, 0.6)
		dust.color = Color(brightness, brightness * 0.85, brightness * 0.7, randf_range(0.3, 0.5))
		dust.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		dust.scale = Vector2(0.5, 0.5)
		get_tree().root.add_child(dust)

		# 下落+扩散
		var vel_x = randf_range(-0.5, 0.5)
		var vel_y = randf_range(0.3, 0.8)
		var dust_tween = create_tween()
		dust_tween.set_parallel(true)
		dust_tween.tween_property(dust, "global_position", dust.global_position + Vector2(vel_x * 40, vel_y * 40), 0.5)
		dust_tween.set_ease(Tween.EASE_OUT)
		dust_tween.chain().tween_property(dust, "modulate:a", 0.0, 0.2)
		dust_tween.chain().tween_callback(dust.queue_free)

## ==================== 天气系统结束 ====================

## 更新BOSS血量显示（每帧调用）
func update_boss_health_display() -> void:
	if current_boss == null or not is_instance_valid(current_boss):
		return

	# 如果BOSS有phase属性，更新阶段显示
	if "phase" in current_boss:
		var boss_phase = current_boss.phase
		var boss_hp = current_boss.hp if "hp" in current_boss else 0
		var boss_max_hp = current_boss.HP_MAX if "HP_MAX" in current_boss else 500

		var health_ratio = boss_hp / boss_max_hp if boss_max_hp > 0 else 0
		show_boss_health(health_ratio, boss_phase)

## ==================== 小地图系统 ====================

### 初始化小地图
func init_minimap() -> void:
	minimap_panel = canvas_layer.get_node_or_null("Minimap")
	if minimap_panel:
		minimap_container = minimap_panel.get_node_or_null("MinimapContainer")
		minimap_player_dot = minimap_container.get_node_or_null("PlayerDot") if minimap_container else null
		minimap_extraction_dot = minimap_container.get_node_or_null("ExtractionDot") if minimap_container else null
		minimap_enemy_container = minimap_container.get_node_or_null("EnemyDots") if minimap_container else null

		# 预创建敌人点对象池
		for i in range(MAX_ENEMIES):
			var dot = Polygon2D.new()
			dot.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
			dot.color = Color(1.0, 0.2, 0.2, 0.9)
			dot.visible = false
			minimap_enemy_container.add_child(dot)
			enemy_dot_pool.append(dot)

		print("Main: 小地图初始化完成")

### 更新小地图显示
func update_minimap() -> void:
	if not minimap_panel or not is_instance_valid(minimap_panel):
		return

	# 世界边界 (1080x1920)
	var world_width: float = 1080.0
	var world_height: float = 1920.0

	# 更新玩家点位置 (绿色)
	if minimap_player_dot and is_instance_valid(minimap_player_dot) and player:
		var player_map_x = (player.position.x / world_width) * MINIMAP_SIZE
		var player_map_y = (player.position.y / world_height) * MINIMAP_SIZE
		minimap_player_dot.position = Vector2(player_map_x, player_map_y)

	# 更新撤离点位置 (黄色)
	if minimap_extraction_dot and is_instance_valid(minimap_extraction_dot) and extraction_point:
		var extract_map_x = (extraction_point.position.x / world_width) * MINIMAP_SIZE
		var extract_map_y = (extraction_point.position.y / world_height) * MINIMAP_SIZE
		minimap_extraction_dot.position = Vector2(extract_map_x, extract_map_y)

	# 更新敌人点位置 (红色)
	var enemy_index = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy_index >= enemy_dot_pool.size():
			break

		var enemy_map_x = (enemy.position.x / world_width) * MINIMAP_SIZE
		var enemy_map_y = (enemy.position.y / world_height) * MINIMAP_SIZE
		var dot = enemy_dot_pool[enemy_index]
		dot.position = Vector2(enemy_map_x, enemy_map_y)
		dot.visible = true
		enemy_index += 1

	# 隐藏多余的点
	while enemy_index < enemy_dot_pool.size():
		enemy_dot_pool[enemy_index].visible = false
		enemy_index += 1
