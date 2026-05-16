extends Control

## 基地界面 - 蚁巢管理、蚂蚁生产、物资存储

signal enter_battle(selected_ant_type: String)
signal open_settings
signal return_to_main_menu
signal open_mail

const MAIL_TYPE_NAMES = {
	"system": "系统",
	"event": "活动",
	"gift": "礼物"
}

## 资源图标定义：icon（Unicode符号或emoji），color（Color类型）
const RESOURCE_ICONS = {
	"beetle_remains": { "icon": "🪲", "color": Color(0.6, 0.4, 0.2, 1) },   # 甲虫 - 棕色
	"locust_remains": { "icon": "🦗", "color": Color(0.4, 0.7, 0.2, 1) },   # 蝗虫 - 绿色
	"spider_remains": { "icon": "🕷️", "color": Color(0.3, 0.3, 0.3, 1) },   # 蜘蛛 - 灰色
	"mantis_remains": { "icon": "🐛", "color": Color(0.5, 0.8, 0.3, 1) },    # 螳螂 - 青绿色
	"food": { "icon": "🍖", "color": Color(1, 0.6, 0.4, 1) }                # 食物 - 橙红色
}

const ANT_TYPES = {
	"worker": { "name": "工蚁", "cost": 20, "time": 10, "remains": 0, "require_type": "", "require_count": 0, "icon": "W" },
	"soldier": { "name": "兵蚁", "cost": 40, "time": 30, "remains": 10, "require_type": "beetle_remains", "require_count": 3, "icon": "S" },
	"shooter": { "name": "射手蚁", "cost": 60, "time": 45, "remains": 15, "require_type": "locust_remains", "require_count": 3, "icon": "Sh" },
	"bomber": { "name": "爆炸蚁", "cost": 80, "time": 60, "remains": 20, "require_type": "spider_remains", "require_count": 3, "icon": "B" },
	"flyer": { "name": "飞蚁", "cost": 100, "time": 90, "remains": 25, "require_type": "mantis_remains", "require_count": 3, "icon": "F" }
}

var inventory: Dictionary = {
	"beetle_remains": 0,
	"locust_remains": 0,
	"spider_remains": 0,
	"mantis_remains": 0,
	"food": 100
}

var ant_count: Dictionary = {
	"worker": 5,
	"soldier": 2,
	"shooter": 0,
	"bomber": 0,
	"flyer": 0
}

var production_queue: Array = []
var production_max: int = 3
var queen_health: float = 100.0
var queen_max_health: float = 100.0
var current_nest_level: int = 1
var shop_opened: bool = false

const NEST_LEVEL_NAMES = {
	1: "Lv.1 初始蚁巢",
	2: "Lv.2 兵蚁巢穴",
	3: "Lv.3 射手巢穴",
	4: "Lv.4 完整蚁巢"
}

func _ready() -> void:
	print("BaseCamp: _ready 开始")
	# 连接按钮信号 - 使用直接路径
	prepare_for_show()
	_apply_base_visual_style()
	$CenterContainer/VBox/EnterBattleBtn.pressed.connect(_on_enter_battle_pressed)
	print("BaseCamp: EnterBattleBtn 信号已连接")
	$CenterContainer/VBox/ShopBtn.pressed.connect(_on_shop_pressed)
	$CenterContainer/VBox/ButtonsHBox/WorkerBtn.pressed.connect(_on_add_worker)
	if $CenterContainer/VBox/ButtonsHBox.has_node("SoldierBtn"):
		$CenterContainer/VBox/ButtonsHBox/SoldierBtn.pressed.connect(_on_add_soldier)
	$CenterContainer/VBox/ButtonsHBox/ShooterBtn.pressed.connect(_on_add_shooter)
	$CenterContainer/VBox/ButtonsHBox/BomberBtn.pressed.connect(_on_add_bomber)
	$CenterContainer/VBox/ButtonsHBox/FlyerBtn.pressed.connect(_on_add_flyer)
	$CenterContainer/VBox/UpgradeNestBtn.pressed.connect(_on_upgrade_nest_pressed)
	$CenterContainer/VBox/SettingsBtn.pressed.connect(_on_settings_pressed)
	$CenterContainer/VBox/ReturnMenuBtn.pressed.connect(_on_return_menu_pressed)
	$CenterContainer/VBox/MailBtn.pressed.connect(_on_mail_pressed)

	# 初始化蚁巢等级显示 - 延迟到所有节点的 _ready() 都执行完毕后执行
	# 这样可以确保 game_manager 已经调用过 _ready() 并添加到 "game_manager" 组
	call_deferred("_init_from_game_manager")
	print("BaseCamp: _ready 完成 (init deferred enabled)")

func prepare_for_show() -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child_name in ["Background", "CenterContainer"]:
		var child = get_node_or_null(child_name)
		if child is Control:
			child.position = Vector2.ZERO
			child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _apply_base_visual_style() -> void:
	var bg = get_node_or_null("Background")
	if bg is ColorRect:
		bg.color = Color(0.055, 0.050, 0.060, 1.0)
	_ensure_cave_backdrop()
	var vbox = get_node_or_null("CenterContainer/VBox")
	if vbox:
		vbox.add_theme_constant_override("separation", 8)
		for child in vbox.get_children():
			if child is Label:
				_style_base_label(child)
			elif child is Button:
				_style_base_button(child)
			elif child is HBoxContainer:
				for nested in child.get_children():
					if nested is Button:
						_style_base_button(nested)

func _ensure_cave_backdrop() -> void:
	if has_node("CaveBackdrop"):
		return
	var layer = Node2D.new()
	layer.name = "CaveBackdrop"
	layer.z_index = -1
	add_child(layer)
	move_child(layer, 1)
	for i in range(32):
		var stone = Polygon2D.new()
		var radius = randf_range(12.0, 34.0)
		var points = PackedVector2Array()
		for p in range(7):
			var angle = TAU * p / 7.0
			points.append(Vector2(cos(angle), sin(angle)) * radius * randf_range(0.65, 1.15))
		stone.polygon = points
		stone.color = Color(0.11, 0.095, 0.085, randf_range(0.20, 0.38))
		stone.position = Vector2(randf_range(20, 1060), randf_range(40, 1880))
		layer.add_child(stone)
	var glow = Polygon2D.new()
	glow.name = "NestGlow"
	glow.polygon = _ui_ring_points(260.0, 215.0, 48)
	glow.color = Color(0.72, 0.43, 0.16, 0.13)
	glow.position = Vector2(540, 940)
	layer.add_child(glow)

func _style_base_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.70))
	if label.name == "Title":
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	elif label.name.ends_with("Label"):
		label.add_theme_font_size_override("font_size", 17)

func _style_base_button(button: Button) -> void:
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 42.0)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.19, 0.13, 0.09, 0.94), Color(0.54, 0.36, 0.18, 1.0), 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.27, 0.18, 0.10, 0.98), Color(0.86, 0.58, 0.23, 1.0), 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.08, 0.06, 1.0), Color(1.0, 0.70, 0.28, 1.0), 2))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.09, 0.08, 0.08, 0.72), Color(0.25, 0.23, 0.20, 1.0), 1))
	button.add_theme_color_override("font_color", Color(0.96, 0.86, 0.68))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.36))

func _make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _ui_ring_points(outer_radius: float, inner_radius: float, segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * i / segments
		var radius = outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _init_from_game_manager() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		update_nest_level_display(game_manager.get_nest_level(), game_manager.get_available_ant_types())
		inventory = game_manager.inventory
		if not inventory.has("food") or inventory.get("food", 0) <= 0:
			inventory["food"] = 100
		ant_count = game_manager.ant_count.duplicate()
	else:
		print("BaseCamp: _init_from_game_manager - game_manager is null!")

	update_display()

	var timer = Timer.new()
	timer.name = "ProductionTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(_on_production_timer_timeout)
	add_child(timer)
	timer.start()
	print("BaseCamp: _ready 完成")

func update_display() -> void:
	update_ant_count()
	update_resources()
	update_production_queue()
	update_queen_status()
	# 同步 ant_count 到 game_manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.ant_count = ant_count.duplicate()

func update_ant_count() -> void:
	var text = ""
	for type_key in ant_count:
		text += "%s: %d  " % [ANT_TYPES[type_key].name, ant_count[type_key]]
	$CenterContainer/VBox/AntCountLabel.text = text

## 根据蚁巢等级更新显示和按钮状态
func update_nest_level_display(level: int, unlocked_types: Array) -> void:
	current_nest_level = level

	# 更新蚁巢等级显示
	if $CenterContainer/VBox.has_node("NestLevelLabel"):
		$CenterContainer/VBox/NestLevelLabel.text = NEST_LEVEL_NAMES.get(level, "Lv.%d" % level)

	# 更新升级按钮状态
	var upgrade_btn = $CenterContainer/VBox/UpgradeNestBtn
	if level >= 4:
		upgrade_btn.text = "已满级"
		upgrade_btn.disabled = true
	else:
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			var info = game_manager.get_upgrade_info()
			upgrade_btn.text = "升级蚁巢 (食物: %d)" % info.cost
			upgrade_btn.disabled = not info.can_upgrade

	# 更新各类型蚂蚁按钮的可用状态
	var all_types = ["worker", "soldier", "shooter", "bomber", "flyer"]
	var buttons = {
		"worker": $CenterContainer/VBox/ButtonsHBox/WorkerBtn,
		"soldier": $CenterContainer/VBox/ButtonsHBox/SoldierBtn,
		"shooter": $CenterContainer/VBox/ButtonsHBox/ShooterBtn,
		"bomber": $CenterContainer/VBox/ButtonsHBox/BomberBtn,
		"flyer": $CenterContainer/VBox/ButtonsHBox/FlyerBtn
	}
	for ant_type in all_types:
		if buttons.has(ant_type):
			buttons[ant_type].disabled = not ant_type in unlocked_types

func update_resources() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var gm_inv = game_manager.inventory if game_manager else inventory

	# 食物显示
	var food_data = RESOURCE_ICONS.get("food", {})
	$CenterContainer/VBox/FoodLabel.text = "%s 食物: %d" % [food_data.icon, gm_inv.get("food", 0)]

	# 残骸资源显示（带图标和颜色）
	$CenterContainer/VBox/BeetleLabel.text = "%s 甲虫残骸: %d" % [RESOURCE_ICONS.beetle_remains.icon, gm_inv.get("beetle_remains", 0)]
	$CenterContainer/VBox/LocustLabel.text = "%s 蝗虫残骸: %d" % [RESOURCE_ICONS.locust_remains.icon, gm_inv.get("locust_remains", 0)]
	$CenterContainer/VBox/SpiderLabel.text = "%s 蜘蛛残骸: %d" % [RESOURCE_ICONS.spider_remains.icon, gm_inv.get("spider_remains", 0)]
	$CenterContainer/VBox/MantisLabel.text = "%s 螳螂残骸: %d  蜜蜂残骸: %d" % [RESOURCE_ICONS.mantis_remains.icon, gm_inv.get("mantis_remains", 0), gm_inv.get("bee_remains", 0)]

	# 为残骸标签设置自定义颜色
	$CenterContainer/VBox/BeetleLabel.modulate = RESOURCE_ICONS.beetle_remains.color
	$CenterContainer/VBox/LocustLabel.modulate = RESOURCE_ICONS.locust_remains.color
	$CenterContainer/VBox/SpiderLabel.modulate = RESOURCE_ICONS.spider_remains.color
	$CenterContainer/VBox/MantisLabel.modulate = RESOURCE_ICONS.mantis_remains.color

func update_production_queue() -> void:
	var queue_text = "生产队列:\n"
	for i in range(production_max):
		if i < production_queue.size():
			var item = production_queue[i]
			var ant_type = ANT_TYPES[item.type]
			var elapsed = Time.get_ticks_msec() / 1000.0 - item.start_time
			var remaining = max(0, ant_type.time - elapsed)
			queue_text += "%s %s (%.0f秒)\n" % [ant_type.icon, ant_type.name, remaining]
		else:
			queue_text += "[ 空 ]\n"
	$CenterContainer/VBox/ProductionLabel.text = queue_text
	update_production_progress_bars()

func add_production(type: String) -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		print("BaseCamp: add_production - game_manager is null!")
		return false

	# 检查该类型是否已解锁
	var available = game_manager.get_available_ant_types()
	if not type in available:
		show_tip("尚未解锁此蚂蚁类型！")
		return false

	if production_queue.size() >= production_max:
		show_tip("生产队列已满！")
		return false

	var ant_type = ANT_TYPES[type]

	# 直接从 game_manager 获取 inventory 的副本，避免引用问题
	var game_inv = game_manager.inventory.duplicate()
	print("BaseCamp: add_production - game_manager.inventory=", game_manager.inventory)
	print("BaseCamp: add_production - game_inv (duplicate)=", game_inv)

	# 检查食物
	var current_food = game_inv.get("food", 0)
	print("BaseCamp: add_production - current_food=", current_food, ", ant_type.cost=", ant_type.cost)
	if current_food < ant_type.cost:
		show_tip("食物不足！需要 " + str(ant_type.cost) + " 食物")
		return false

	# 检查需要的残骸
	if ant_type.require_type != "":
		var require_count = ant_type.require_count
		var have_count = game_inv.get(ant_type.require_type, 0)
		if have_count < require_count:
			var type_name = ant_type.require_type.replace("_remains", "")
			show_tip("残骸不足！需要 " + str(require_count) + " 个" + type_name + "残骸")
			return false
		# 消耗残骸
		game_inv[ant_type.require_type] = have_count - require_count

	# 消耗食物
	game_inv["food"] = current_food - ant_type.cost
	print("BaseCamp: add_production - after consumption, game_inv['food']=", game_inv["food"])

	# 同步回 game_manager.inventory（通过字典键的逐一赋值）
	for key in game_inv:
		game_manager.inventory[key] = game_inv[key]

	# 同步到本地inventory
	inventory = game_manager.inventory.duplicate()

	production_queue.append({ "type": type, "start_time": Time.get_ticks_msec() / 1000.0 })
	update_display()
	show_tip("开始生产 " + ant_type.name)
	game_manager.save_game()
	return true

func show_tip(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.position = Vector2(540, 400)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1, 0.5, 0.5, 1)
	add_child(label)
	await get_tree().create_timer(2.0).timeout
	label.queue_free()

func _on_add_worker() -> void:
	add_production("worker")

func _on_add_soldier() -> void:
	add_production("soldier")

func _on_add_shooter() -> void:
	add_production("shooter")

func _on_add_bomber() -> void:
	add_production("bomber")

func _on_add_flyer() -> void:
	add_production("flyer")

func _on_production_timer_timeout() -> void:
	if production_queue.size() == 0:
		return

	var changed = false
	var to_remove = []

	for i in range(production_queue.size()):
		var item = production_queue[i]
		var ant_type = ANT_TYPES[item.type]
		var elapsed = Time.get_ticks_msec() / 1000.0 - item.start_time

		if elapsed >= ant_type.time:
			ant_count[item.type] += 1
			# 添加残骸奖励
			if ant_type.remains > 0:
				inventory["beetle_remains"] = inventory.get("beetle_remains", 0) + ant_type.remains
			# 播放生产完成动画
			play_production_complete_animation(item.type)
			to_remove.append(i)
			changed = true

	for i in to_remove:
		production_queue.remove_at(i)

	if changed:
		update_display()
	else:
		update_production_queue()

func play_production_complete_animation(ant_type: String) -> void:
	var ant_data = ANT_TYPES[ant_type]
	var label = Label.new()
	label.text = "+1 %s" % ant_data.name
	label.global_position = Vector2(500, 300)
	label.modulate = Color(0, 1, 0, 1)
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position", Vector2(500, 200), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

func update_production_progress_bars() -> void:
	var progress_bars = [
		$ProductionProgressPanel/ProductionVBox/ProductionProgress1,
		$ProductionProgressPanel/ProductionVBox/ProductionProgress2,
		$ProductionProgressPanel/ProductionVBox/ProductionProgress3
	]
	for i in range(production_max):
		if i < production_queue.size():
			var item = production_queue[i]
			var ant_type = ANT_TYPES[item.type]
			var elapsed = Time.get_ticks_msec() / 1000.0 - item.start_time
			var progress = min(1.0, elapsed / ant_type.time) * 100.0
			progress_bars[i].value = progress
		else:
			progress_bars[i].value = 0.0

func update_queen_status() -> void:
	var queen_health_bar = $QueenStatusPanel/QueenVBox/QueenHealthBar
	var queen_label = $QueenStatusPanel/QueenVBox/QueenLabel
	if queen_health_bar:
		queen_health_bar.max_value = queen_max_health
		queen_health_bar.value = queen_health
	if queen_label:
		queen_label.text = "健康: %.0f%%" % (queen_health / queen_max_health * 100)

func _on_enter_battle_pressed() -> void:
	print("BaseCamp: _on_enter_battle_pressed called!")
	print("BaseCamp: button pressed, game_manager=", get_tree().get_first_node_in_group("game_manager"))
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		print("BaseCamp: 未找到 game_manager，直接发射信号")
		enter_battle.emit("worker")
		return

	# 检查是否有可用蚂蚁
	var has_ants = false
	for type_key in ant_count.keys():
		if ant_count[type_key] > 0:
			has_ants = true
			break

	if not has_ants:
		print("BaseCamp: 没有蚂蚁可以进入战场")
		show_tip("没有蚂蚁！请先生产蚂蚁")
		return

	_show_ant_selection_panel()

func _show_ant_selection_panel() -> void:
	if has_node("BattleAntSelectPanel"):
		$BattleAntSelectPanel.queue_free()
	var available_types = _get_available_battle_ant_types()
	if available_types.is_empty():
		show_tip("没有已解锁且可出战的蚂蚁")
		return

	var panel = PanelContainer.new()
	panel.name = "BattleAntSelectPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.modulate = Color(1, 1, 1, 0.98)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.045, 0.038, 0.96), Color(0.72, 0.46, 0.18, 1.0), 3))
	add_child(panel)

	var outer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(outer)

	var title = Label.new()
	title.text = "选择出战蚂蚁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	outer.add_child(title)

	for ant_type in available_types:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(360, 54)
		btn.text = "%s  x%d" % [_get_ant_type_name(ant_type), ant_count.get(ant_type, 0)]
		btn.pressed.connect(_on_battle_ant_selected.bind(ant_type))
		_style_base_button(btn)
		outer.add_child(btn)

	var cancel_btn = Button.new()
	cancel_btn.custom_minimum_size = Vector2(360, 46)
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_close_ant_selection_panel)
	_style_base_button(cancel_btn)
	outer.add_child(cancel_btn)

func _get_available_battle_ant_types() -> Array:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var unlocked = game_manager.get_available_ant_types() if game_manager else ant_count.keys()
	var result = []
	for ant_type in ["worker", "soldier", "shooter", "bomber", "flyer"]:
		if ant_type in unlocked and ant_count.get(ant_type, 0) > 0:
			result.append(ant_type)
	return result

func _on_battle_ant_selected(ant_type: String) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.save_game()
	_close_ant_selection_panel()
	enter_battle.emit(ant_type)

func _close_ant_selection_panel() -> void:
	if has_node("BattleAntSelectPanel"):
		$BattleAntSelectPanel.queue_free()

func _get_ant_type_name(ant_type: String) -> String:
	if ANT_TYPES.has(ant_type):
		return ANT_TYPES[ant_type].name
	return ant_type

func _on_shop_pressed() -> void:
	_show_shop_panel()

func _on_upgrade_nest_pressed() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		if game_manager.upgrade_nest():
			# 更新成功，刷新显示
			update_display()
		else:
			print("BaseCamp: 升级失败")

func _on_settings_pressed() -> void:
	open_settings.emit()
	_show_settings_panel()

func _on_mail_pressed() -> void:
	open_mail.emit()
	_show_mail_panel()

func _on_return_menu_pressed() -> void:
	return_to_main_menu.emit()

## 显示商店面板
func _show_shop_panel() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var shop_items = game_manager.get_shop_items()

	# 清除旧的商店面板
	if has_node("ShopPanel"):
		$ShopPanel.queue_free()

	# 创建商店面板
	var shop_panel = PanelContainer.new()
	shop_panel.name = "ShopPanel"
	shop_panel.anchors_preset = 15
	shop_panel.anchor_right = 1.0
	shop_panel.anchor_bottom = 1.0
	shop_panel.grow_horizontal = 2
	shop_panel.grow_vertical = 2
	shop_panel.modulate = Color(0, 0, 0, 0.8)
	shop_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.045, 0.038, 0.96), Color(0.72, 0.46, 0.18, 1.0), 3))
	add_child(shop_panel)

	var shop_vbox = VBoxContainer.new()
	shop_vbox.name = "ShopVBox"
	shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_panel.add_child(shop_vbox)

	# 标题
	var title = Label.new()
	title.name = "ShopTitle"
	title.text = "商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_base_label(title)
	shop_vbox.add_child(title)

	# 商店物品列表
	for item_id in shop_items.keys():
		var item = shop_items[item_id]
		var item_btn = Button.new()
		item_btn.name = item_id
		item_btn.text = "%s - %d %s (%s)" % [item.name, item.cost, item.cost_type, item.description]
		item_btn.pressed.connect(_on_shop_item_pressed.bind(item_id))
		_style_base_button(item_btn)
		shop_vbox.add_child(item_btn)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseShopBtn"
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_shop_pressed)
	_style_base_button(close_btn)
	shop_vbox.add_child(close_btn)

	shop_opened = true

## 处理商店物品购买
func _on_shop_item_pressed(item_id: String) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		if game_manager.purchase_item(item_id):
			update_display()
			# 刷新商店面板
			_show_shop_panel()

## 关闭商店
func _on_close_shop_pressed() -> void:
	if has_node("ShopPanel"):
		$ShopPanel.queue_free()
	shop_opened = false

## 显示设置面板
func _show_settings_panel() -> void:
	# 清除旧的设置面板
	if has_node("SettingsPanel"):
		$SettingsPanel.queue_free()

	var settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.anchors_preset = 15
	settings_panel.anchor_right = 1.0
	settings_panel.anchor_bottom = 1.0
	settings_panel.grow_horizontal = 2
	settings_panel.grow_vertical = 2
	settings_panel.modulate = Color(0, 0, 0, 0.8)
	add_child(settings_panel)

	var settings_vbox = VBoxContainer.new()
	settings_vbox.name = "SettingsVBox"
	settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_panel.add_child(settings_vbox)

	# 标题
	var title = Label.new()
	title.name = "SettingsTitle"
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(title)

	# 获取 AudioManager
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")

	# 音乐音量
	var bgm_hbox = HBoxContainer.new()
	bgm_hbox.name = "BgmVolumeHBox"
	settings_vbox.add_child(bgm_hbox)

	var bgm_label = Label.new()
	bgm_label.text = "音乐音量:"
	bgm_hbox.add_child(bgm_label)

	var bgm_slider = HSlider.new()
	bgm_slider.name = "BgmVolumeSlider"
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.01
	if audio_manager:
		bgm_slider.value = audio_manager.bgm_volume
	else:
		bgm_slider.value = 0.8
	bgm_slider.custom_minimum_size = Vector2(200, 0)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	bgm_hbox.add_child(bgm_slider)

	var bgm_value_label = Label.new()
	bgm_value_label.name = "BgmValueLabel"
	bgm_value_label.text = "%d%%" % int(bgm_slider.value * 100)
	bgm_hbox.add_child(bgm_value_label)

	var bgm_mute_check = CheckBox.new()
	bgm_mute_check.name = "BgmMuteCheck"
	bgm_mute_check.text = "静音"
	if audio_manager:
		bgm_mute_check.set_pressed(audio_manager.is_bgm_muted())
	bgm_mute_check.toggled.connect(_on_bgm_mute_toggled)
	bgm_hbox.add_child(bgm_mute_check)

	# 音效音量
	var sfx_hbox = HBoxContainer.new()
	sfx_hbox.name = "SfxVolumeHBox"
	settings_vbox.add_child(sfx_hbox)

	var sfx_label = Label.new()
	sfx_label.text = "音效音量:"
	sfx_hbox.add_child(sfx_label)

	var sfx_slider = HSlider.new()
	sfx_slider.name = "SfxVolumeSlider"
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	if audio_manager:
		sfx_slider.value = audio_manager.sfx_volume
	else:
		sfx_slider.value = 1.0
	sfx_slider.custom_minimum_size = Vector2(200, 0)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_hbox.add_child(sfx_slider)

	var sfx_value_label = Label.new()
	sfx_value_label.name = "SfxValueLabel"
	sfx_value_label.text = "%d%%" % int(sfx_slider.value * 100)
	sfx_hbox.add_child(sfx_value_label)

	var sfx_mute_check = CheckBox.new()
	sfx_mute_check.name = "SfxMuteCheck"
	sfx_mute_check.text = "静音"
	if audio_manager:
		sfx_mute_check.set_pressed(audio_manager.is_sfx_muted())
	sfx_mute_check.toggled.connect(_on_sfx_mute_toggled)
	sfx_hbox.add_child(sfx_mute_check)

	# 语音音量
	var voice_hbox = HBoxContainer.new()
	voice_hbox.name = "VoiceVolumeHBox"
	settings_vbox.add_child(voice_hbox)

	var voice_label = Label.new()
	voice_label.text = "语音音量:"
	voice_hbox.add_child(voice_label)

	var voice_slider = HSlider.new()
	voice_slider.name = "VoiceVolumeSlider"
	voice_slider.min_value = 0.0
	voice_slider.max_value = 1.0
	voice_slider.step = 0.01
	if audio_manager:
		voice_slider.value = audio_manager.voice_volume
	else:
		voice_slider.value = 1.0
	voice_slider.custom_minimum_size = Vector2(200, 0)
	voice_slider.value_changed.connect(_on_voice_volume_changed)
	voice_hbox.add_child(voice_slider)

	var voice_value_label = Label.new()
	voice_value_label.name = "VoiceValueLabel"
	voice_value_label.text = "%d%%" % int(voice_slider.value * 100)
	voice_hbox.add_child(voice_value_label)

	var voice_mute_check = CheckBox.new()
	voice_mute_check.name = "VoiceMuteCheck"
	voice_mute_check.text = "静音"
	if audio_manager:
		voice_mute_check.set_pressed(audio_manager.is_voice_muted())
	voice_mute_check.toggled.connect(_on_voice_mute_toggled)
	voice_hbox.add_child(voice_mute_check)

	# 画质设置
	var quality_hbox = HBoxContainer.new()
	quality_hbox.name = "QualityHBox"
	settings_vbox.add_child(quality_hbox)

	var quality_label = Label.new()
	quality_label.text = "画质:"
	quality_hbox.add_child(quality_label)

	var quality_option = OptionButton.new()
	quality_option.name = "QualityOption"
	quality_option.add_item("低画质", 0)
	quality_option.add_item("高画质", 1)
	quality_option.selected = 1  # 默认高画质
	quality_option.item_selected.connect(_on_quality_selected)
	quality_hbox.add_child(quality_option)

	# 跳过教程选项
	var skip_tutorial_hbox = HBoxContainer.new()
	skip_tutorial_hbox.name = "SkipTutorialHBox"
	settings_vbox.add_child(skip_tutorial_hbox)

	var skip_tutorial_label = Label.new()
	skip_tutorial_label.text = "跳过教程:"
	skip_tutorial_hbox.add_child(skip_tutorial_label)

	var skip_tutorial_check = CheckBox.new()
	skip_tutorial_check.name = "SkipTutorialCheck"
	skip_tutorial_check.text = "老玩家跳过新手引导"
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		skip_tutorial_check.set_pressed(game_manager.is_tutorial_skipped())
	skip_tutorial_check.toggled.connect(_on_skip_tutorial_toggled)
	skip_tutorial_hbox.add_child(skip_tutorial_check)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseSettingsBtn"
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_settings_pressed)
	settings_vbox.add_child(close_btn)

func _on_bgm_volume_changed(value: float) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_bgm_volume(value, audio_manager.is_bgm_muted())
	# 更新显示值
	if has_node("SettingsPanel/SettingsVBox/BgmVolumeHBox/BgmValueLabel"):
		$SettingsPanel/SettingsVBox/BgmVolumeHBox/BgmValueLabel.text = "%d%%" % int(value * 100)

func _on_bgm_mute_toggled(toggled: bool) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_bgm_muted(toggled)

func _on_sfx_volume_changed(value: float) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_sfx_volume(value, audio_manager.is_sfx_muted())
	# 更新显示值
	if has_node("SettingsPanel/SettingsVBox/SfxVolumeHBox/SfxValueLabel"):
		$SettingsPanel/SettingsVBox/SfxVolumeHBox/SfxValueLabel.text = "%d%%" % int(value * 100)

func _on_sfx_mute_toggled(toggled: bool) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_sfx_muted(toggled)

func _on_voice_volume_changed(value: float) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_voice_volume(value, audio_manager.is_voice_muted())
	# 更新显示值
	if has_node("SettingsPanel/SettingsVBox/VoiceVolumeHBox/VoiceValueLabel"):
		$SettingsPanel/SettingsVBox/VoiceVolumeHBox/VoiceValueLabel.text = "%d%%" % int(value * 100)

func _on_voice_mute_toggled(toggled: bool) -> void:
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.set_voice_muted(toggled)

func _on_quality_selected(index: int) -> void:
	# 画质设置 - 可以在这里添加实际的质量切换逻辑
	var quality_names = ["低画质", "高画质"]
	print("BaseCamp: 画质设置为 ", quality_names[index])

func _on_skip_tutorial_toggled(toggled: bool) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.set_tutorial_skipped(toggled)
		print("BaseCamp: 跳过教程设置为 ", toggled)

## 关闭设置面板
func _on_close_settings_pressed() -> void:
	if has_node("SettingsPanel"):
		$SettingsPanel.queue_free()

func add_to_inventory(type: String, amount: int) -> void:
	if type in inventory:
		inventory[type] += amount
	else:
		inventory[type] = amount
	update_display()

## 从游戏管理器同步库存数据
func sync_inventory_from_game_manager() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		inventory = game_manager.inventory.duplicate()
		update_display()

func get_ant_count() -> Dictionary:
	return ant_count.duplicate()

## 显示新邮件通知
func show_mail_notification(title: String) -> void:
	# 如果有邮件按钮，更新其显示
	var mail_btn = $CenterContainer/VBox/MailBtn
	if mail_btn and mail_btn.has_method("set_notification"):
		mail_btn.set_notification(true)
	print("BaseCamp: 新邮件通知 - ", title)

## 显示邮件面板
func _show_mail_panel() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var all_emails = game_manager.get_all_emails()

	# 清除旧的邮件面板
	if has_node("MailPanel"):
		$MailPanel.queue_free()

	# 创建邮件面板
	var mail_panel = PanelContainer.new()
	mail_panel.name = "MailPanel"
	mail_panel.anchors_preset = 15
	mail_panel.anchor_right = 1.0
	mail_panel.anchor_bottom = 1.0
	mail_panel.grow_horizontal = 2
	mail_panel.grow_vertical = 2
	mail_panel.modulate = Color(0, 0, 0, 0.8)
	add_child(mail_panel)

	var mail_vbox = VBoxContainer.new()
	mail_vbox.name = "MailVBox"
	mail_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mail_panel.add_child(mail_vbox)

	# 标题
	var title = Label.new()
	title.name = "MailTitle"
	title.text = "邮件列表"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mail_vbox.add_child(title)

	# 邮件列表
	var scroll_container = ScrollContainer.new()
	scroll_container.name = "MailScroll"
	scroll_container.custom_minimum_size = Vector2(600, 400)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mail_vbox.add_child(scroll_container)

	var mail_list_vbox = VBoxContainer.new()
	mail_list_vbox.name = "MailListVBox"
	mail_list_vbox.custom_minimum_size = Vector2(580, 380)
	scroll_container.add_child(mail_list_vbox)

	if all_emails.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "没有邮件"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mail_list_vbox.add_child(empty_label)
	else:
		for i in range(all_emails.size()):
			var mail = all_emails[i]
			var mail_type_name = MAIL_TYPE_NAMES.get(mail.type, mail.type)
			var read_indicator = "[未读]" if not mail.read else ""
			var items_info = ""
			if mail.items.size() > 0:
				items_info = " [附件:%s:%d]" % [mail.items.get("type", ""), mail.items.get("count", 0)]

			var mail_btn = Button.new()
			mail_btn.name = "MailItem_%d" % i
			mail_btn.text = "[%s] %s %s%s" % [mail_type_name, mail.title, read_indicator, items_info]

			# 未读邮件按钮高亮显示
			if not mail.read:
				mail_btn.add_theme_color_override("font_color", Color(1, 1, 0.2, 1))

			mail_btn.pressed.connect(_on_mail_item_clicked.bind(i))
			mail_list_vbox.add_child(mail_btn)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseMailBtn"
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_mail_pressed)
	mail_vbox.add_child(close_btn)

## 处理邮件项点击
func _on_mail_item_clicked(index: int) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# 标记为已读
	game_manager.mark_as_read(index)

	# 刷新邮件面板显示
	_show_mail_panel()

	# 显示邮件详情（可以通过弹出窗口显示，这里简化处理）
	var emails = game_manager.get_all_emails()
	if index >= 0 and index < emails.size():
		var mail = emails[index]
		print("BaseCamp: 邮件详情 - [%s] %s\n%s" % [mail.type, mail.title, mail.content])

## 关闭邮件面板
func _on_close_mail_pressed() -> void:
	if has_node("MailPanel"):
		$MailPanel.queue_free()
