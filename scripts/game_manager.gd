extends Node

## 游戏管理器 - 处理基地/战场切换

## 存档版本管理
const SAVE_VERSION: int = 2
var save_version: int = SAVE_VERSION

@onready var base_camp: Control = $BaseCamp
@onready var battle_scene: Node2D = $BattleScene

## 过渡效果系统
var transition_layer: CanvasLayer
var transition_overlay: ColorRect
var transition_label: Label
var transition_tip: Label  # 加载提示文字
var loading_progress: ProgressBar  # 加载进度条
var ant_container: Node2D  # 蚂蚁动画容器
var ant_animation: AnimationPlayer  # 蚂蚁动画播放器
var is_transitioning: bool = false
var game_was_interrupted: bool = false  ## 追踪撤离是否被中断

var inventory: Dictionary = { "beetle_remains": 0, "locust_remains": 0, "spider_remains": 0, "mantis_remains": 0, "food": 100 }

## 蚂蚁数量 (基地中现有的蚂蚁)
var ant_count: Dictionary = {
	"worker": 5,
	"soldier": 2,
	"shooter": 0,
	"bomber": 0,
	"flyer": 0
}

## 巢穴等级 (1-4)
## Lv.1: 0% 返还, Lv.2: 20% 返还, Lv.3: 40% 返还, Lv.4: 60% 返还
var nest_level: int = 1

## 巢穴升级配置 - 每个等级解锁的蚂蚁类型和升级费用
var nest_upgrade_config: Dictionary = {
	2: { "unlock": ["soldier"], "cost": 50, "desc": "解锁兵蚁" },
	3: { "unlock": ["shooter"], "cost": 100, "desc": "解锁射手蚁" },
	4: { "unlock": ["soldier", "shooter"], "cost": 200, "desc": "全部解锁" }
}

## 当前可生产的蚂蚁类型列表
var available_ant_types: Array = ["worker"]

## 进化材料定义 - 昆虫类型及其消耗材料
## 格式: insect_type: {material: 材料名, count: 消耗数量, color: 进化后颜色}
var evolution_materials: Dictionary = {
	"mantis": {"material": "mantis_remains", "count": 3, "color": Color(0.2, 0.8, 0.3, 1.0)},      # 螳螂 - 绿色
	"spider": {"material": "spider_remains", "count": 3, "color": Color(0.4, 0.2, 0.5, 1.0)},       # 蜘蛛 - 紫色
	"bee": {"material": "bee_remains", "count": 3, "color": Color(1.0, 0.9, 0.2, 1.0)},             # 蜜蜂 - 金黄色
	"beetle": {"material": "beetle_remains", "count": 3, "color": Color(0.6, 0.3, 0.1, 1.0)}       # 甲虫 - 棕色
}

## 当前进化状态
var current_evolution: String = ""

## 成就系统
## 成就定义：id: {name: 名称, desc: 描述, reward_type: 奖励类型, reward_value: 奖励值, condition_type: 条件类型, condition_value: 条件值}
var achievements: Dictionary = {
	"first_kill": { "name": "初次击杀", "desc": "击杀第一只敌人", "reward_type": "food", "reward_value": 10, "condition_type": "kill_count", "condition_value": 1, "unlocked": false },
	"kill_10": { "name": "小试牛刀", "desc": "累计击杀10只敌人", "reward_type": "food", "reward_value": 20, "condition_type": "kill_count", "condition_value": 10, "unlocked": false },
	"kill_50": { "name": "杀戮机器", "desc": "累计击杀50只敌人", "reward_type": "food", "reward_value": 50, "condition_type": "kill_count", "condition_value": 50, "unlocked": false },
	"kill_100": { "name": "昆虫杀手", "desc": "累计击杀100只敌人", "reward_type": "title", "reward_value": "昆虫杀手", "condition_type": "kill_count", "condition_value": 100, "unlocked": false },
	"first_extraction": { "name": "首次撤离", "desc": "成功完成第一次撤离", "reward_type": "food", "reward_value": 15, "condition_type": "extraction_count", "condition_value": 1, "unlocked": false },
	"extraction_5": { "name": "老练撤离", "desc": "成功撤离5次", "reward_type": "food", "reward_value": 30, "condition_type": "extraction_count", "condition_value": 5, "unlocked": false },
	"extraction_10": { "name": "撤离专家", "desc": "成功撤离10次", "reward_type": "title", "reward_value": "撤离专家", "condition_type": "extraction_count", "condition_value": 10, "unlocked": false },
	"first_evolution": { "name": "首次进化", "desc": "完成第一次进化", "reward_type": "food", "reward_value": 25, "condition_type": "evolution_count", "condition_value": 1, "unlocked": false },
	"evolve_3": { "name": "进化大师", "desc": "完成3次进化", "reward_type": "appearance", "reward_value": "golden_ant", "condition_type": "evolution_count", "condition_value": 3, "unlocked": false },
	"nest_2": { "name": "蚁巢升级", "desc": "将蚁巢升级到2级", "reward_type": "food", "reward_value": 20, "condition_type": "nest_level", "condition_value": 2, "unlocked": false },
	"nest_4": { "name": "蚁巢满级", "desc": "将蚁巢升级到4级", "reward_type": "title", "reward_value": "蚁群之主", "condition_type": "nest_level", "condition_value": 4, "unlocked": false },
	"survive_5": { "name": "生存专家", "desc": "在单次战斗中存活超过5分钟", "reward_type": "food", "reward_value": 30, "condition_type": "survival_time", "condition_value": 300, "unlocked": false },
	"no_damage": { "name": "完美主义", "desc": "无伤完成一次撤离", "reward_type": "food", "reward_value": 40, "condition_type": "no_damage_extraction", "condition_value": 1, "unlocked": false }
}

## 成就统计
var stats: Dictionary = {
	"kill_count": 0,
	"extraction_count": 0,
	"evolution_count": 0,
	"nest_level": 1,
	"survival_time": 0,
	"no_damage_extraction": 0,
	"total_play_time": 0
}

## 当前解锁的称号
var unlocked_titles: Array = []

## 多人匹配状态 (预留未来多人模式)
## 状态: "idle"=未匹配, "searching"=搜索中, "matched"=已匹配, "playing"=游戏中
var multiplayer_state: String = "idle"

## 好友系统 (预留)
var friends: Array = []

## 数据分析上报系统 (预留)
## 用于埋点数据收集和分析
var analytics_data: Dictionary = {
	"events": [],
	"screens": [],
	"session_start": "",
	"total_events": 0
}

## 追踪游戏事件
## event_name: 事件名称
## params: 事件参数 (可选)
func track_event(event_name: String, params: Dictionary = {}) -> void:
	var event_data = {
		"event": event_name,
		"params": params,
		"timestamp": Time.get_datetime_string_from_system()
	}
	analytics_data.events.append(event_data)
	analytics_data.total_events += 1
	print("GameManager: 埋点事件 - ", event_name, " | 参数: ", params)

## 追踪页面/屏幕访问
## screen_name: 屏幕名称
func track_screen(screen_name: String) -> void:
	var screen_data = {
		"screen": screen_name,
		"timestamp": Time.get_datetime_string_from_system()
	}
	analytics_data.screens.append(screen_data)
	print("GameManager: 埋点页面 - ", screen_name)

## 添加好友
func add_friend(id: String) -> bool:
	if id in friends:
		print("GameManager: %s 已在好友列表中" % id)
		return false
	friends.append(id)
	print("GameManager: 添加好友 %s" % id)
	save_game()
	return true

## 移除好友
func remove_friend(id: String) -> bool:
	if not id in friends:
		print("GameManager: %s 不在好友列表中" % id)
		return false
	friends.erase(id)
	print("GameManager: 移除好友 %s" % id)
	save_game()
	return true

## 获取好友列表
func get_friends() -> Array:
	return friends.duplicate()

## 检查是否为好友
func is_friend(id: String) -> bool:
	return id in friends

## 断线重连相关 (预留未来多人模式)
## 连接状态: true=已连接, false=已断开
var connection_connected: bool = false

## 重连计时器 (秒)
var reconnect_timer: float = 0.0

## 重连超时时间 (秒)
var reconnect_timeout: float = 30.0

## 重连尝试次数
var reconnect_attempts: int = 0

## 最大重连次数
var max_reconnect_attempts: int = 5

## 排行榜数据 (预留未来多人排行榜)
## 格式: { "score": 分数, "date": 日期 }
var leaderboard_data: Dictionary = {
	"score": 0,
	"date": ""
}

## 邮件系统
## 邮件类型: "system"=系统邮件, "event"=活动邮件, "gift"=礼物邮件
var emails: Array = []

## 首充礼包配置
var first_purchase_reward: Dictionary = {
	"name": "首充礼包",
	"cost": 1.0,
	"items": [
		{ "type": "food", "id": "food", "count": 200 },
		{ "type": "currency", "id": "gems", "count": 100 }
	],
	"description": "首次充值即可获得超值大礼包！"
}

## 是否已购买过首充礼包
var has_purchased_first: bool = false

## 氪金礼包列表 (预留)
var purchase_offers: Dictionary = {
	"starter_pack": { "name": "新手礼包", "cost": 0.99, "items": [{ "type": "food", "id": "food", "count": 100 }], "description": "新手必备" },
	"value_pack": { "name": "超值礼包", "cost": 4.99, "items": [{ "type": "food", "id": "food", "count": 500 }, { "type": "currency", "id": "gems", "count": 50 }], "description": "超值的选择" },
	"vip_pack": { "name": "VIP礼包", "cost": 9.99, "items": [{ "type": "food", "id": "food", "count": 1000 }, { "type": "currency", "id": "gems", "count": 200 }], "description": "VIP专属" }
}

## 新手礼包配置
var welcome_reward: Dictionary = {
	"name": "新手礼包",
	"items": [
		{ "type": "food", "id": "food", "count": 100 },
		{ "type": "beetle_remains", "id": "beetle_remains", "count": 5 },
		{ "type": "locust_remains", "id": "locust_remains", "count": 3 }
	],
	"description": "欢迎来到蚂蚁世界！这是给你的新手礼物。"
}

## 是否已领取过新手礼包
var has_claimed_welcome_reward: bool = false

## 教程跳过状态 - true表示跳过教程，直接进入游戏
var tutorial_skipped: bool = false

## 检查是否已购买过首充
func has_purchased() -> bool:
	return has_purchased_first

## 设置教程跳过状态
func set_tutorial_skipped(skipped: bool) -> void:
	tutorial_skipped = skipped
	save_game()
	print("GameManager: 教程跳过状态设置为 ", skipped)

## 检查教程是否已跳过
func is_tutorial_skipped() -> bool:
	return tutorial_skipped

## 执行教程跳过（跳过教程后直接进入游戏）
func skip_tutorial() -> void:
	tutorial_skipped = true
	# 标记新手礼包已领取，避免再次弹出
	has_claimed_welcome_reward = true
	save_game()
	print("GameManager: 已跳过教程，直接进入游戏")

## 领取首充礼包奖励
func claim_first_purchase_reward() -> bool:
	if has_purchased_first:
		print("GameManager: 首充礼包已领取过")
		return false

	# 发放首充礼包奖励
	for item in first_purchase_reward.items:
		var item_type = item.type
		var item_id = item.id
		var item_count = item.count
		if item_type == "food":
			inventory[item_id] = inventory.get(item_id, 0) + item_count
		elif item_type == "currency":
			# 钻石或其他货币暂存到 inventory
			if not inventory.has(item_id):
				inventory[item_id] = 0
			inventory[item_id] += item_count

	has_purchased_first = true
	print("GameManager: 领取首充礼包成功！")
	base_camp.update_display()
	save_game()
	return true

## 检查是否已领取过新手礼包
func has_claimed_welcome() -> bool:
	return has_claimed_welcome_reward

## 领取新手礼包奖励
func claim_welcome_reward() -> bool:
	if has_claimed_welcome_reward:
		print("GameManager: 新手礼包已领取过")
		return false

	# 发放新手礼包奖励
	for item in welcome_reward.items:
		var item_type = item.type
		var item_id = item.id
		var item_count = item.count
		if item_type == "food":
			inventory[item_id] = inventory.get(item_id, 0) + item_count
		elif item_type in ["beetle_remains", "locust_remains", "spider_remains", "mantis_remains"]:
			inventory[item_id] = inventory.get(item_id, 0) + item_count

	has_claimed_welcome_reward = true
	print("GameManager: 领取新手礼包成功！")
	base_camp.update_display()
	save_game()
	return true

## 获取氪金礼包列表
func get_purchase_offers() -> Dictionary:
	return purchase_offers.duplicate()

## 接收邮件
## type: 邮件类型 (system/event/gift)
## title: 邮件标题
## content: 邮件内容
## items: 附件物品 (可选), 格式: {"type": "food", "count": 100}
func receive_mail(type: String, title: String, content: String, items: Dictionary = {}) -> void:
	var mail = {
		"type": type,
		"title": title,
		"content": content,
		"items": items,
		"read": false,
		"time": Time.get_datetime_string_from_system()
	}
	emails.append(mail)
	print("GameManager: 收到邮件 [%s] - %s" % [type, title])

	# 通知UI显示新邮件提示
	if base_camp.has_method("show_mail_notification"):
		base_camp.show_mail_notification(title)

## 标记邮件为已读
func mark_as_read(index: int) -> bool:
	if index < 0 or index >= emails.size():
		print("GameManager: 无效的邮件索引: ", index)
		return false

	emails[index]["read"] = true
	print("GameManager: 邮件已读 - ", emails[index].title)
	return true

## 获取未读邮件数量
func get_unread_mail_count() -> int:
	var count = 0
	for mail in emails:
		if not mail.get("read", false):
			count += 1
	return count

## 获取所有邮件
func get_all_emails() -> Array:
	return emails.duplicate()

## 解锁成就
## 返回是否成功解锁（如果已经解锁则返回false）
func unlock_achievement(achievement_id: String) -> bool:
	if not achievements.has(achievement_id):
		print("GameManager: 未知成就 ", achievement_id)
		return false

	var achievement = achievements[achievement_id]
	if achievement.unlocked:
		return false

	# 解锁成就
	achievement.unlocked = true
	print("GameManager: 成就解锁! - ", achievement.name, ": ", achievement.desc)

	# 发放奖励
	match achievement.reward_type:
		"food":
			inventory["food"] = inventory.get("food", 0) + achievement.reward_value
			print("GameManager: 获得奖励: ", achievement.reward_value, " 食物")
		"title":
			if not achievement.reward_value in unlocked_titles:
				unlocked_titles.append(achievement.reward_value)
			print("GameManager: 获得称号: ", achievement.reward_value)
		"appearance":
			# 应用特殊外观（金蚂蚁）
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("apply_golden_appearance"):
				player.apply_golden_appearance()
			print("GameManager: 获得外观: ", achievement.reward_value)
		_:
			print("GameManager: 未知奖励类型 ", achievement.reward_type)

	# 通知UI显示成就提示
	show_achievement_popup(achievement.name, achievement.desc)

	# 更新UI并保存
	base_camp.update_display()
	save_game()
	return true

## 显示成就弹窗提示（需要在UI层实现）
func show_achievement_popup(achievement_name: String, desc: String) -> void:
	# 如果base_camp有成就提示方法则调用
	if base_camp.has_method("show_achievement_popup"):
		base_camp.show_achievement_popup(achievement_name, desc)
	else:
		print("GameManager: 成就解锁提示 - ", achievement_name, ": ", desc)

## 检查成就条件
## 根据条件类型和统计数值检查是否达成成就
func check_achievements() -> void:
	for achievement_id in achievements:
		var achievement = achievements[achievement_id]
		if achievement.unlocked:
			continue

		var condition_type = achievement.condition_type
		var condition_value = achievement.condition_value

		var should_unlock = false
		match condition_type:
			"kill_count":
				if stats.kill_count >= condition_value:
					should_unlock = true
			"extraction_count":
				if stats.extraction_count >= condition_value:
					should_unlock = true
			"evolution_count":
				if stats.evolution_count >= condition_value:
					should_unlock = true
			"nest_level":
				if stats.nest_level >= condition_value:
					should_unlock = true
			"survival_time":
				if stats.survival_time >= condition_value:
					should_unlock = true
			"no_damage_extraction":
				if stats.no_damage_extraction >= condition_value:
					should_unlock = true

		if should_unlock:
			unlock_achievement(achievement_id)

## 获取所有统计数据
func get_stats() -> Dictionary:
	return stats.duplicate()

## 增加指定统计值
## key: 统计项键名
## amount: 增量（默认为1）
func increment_stat(key: String, amount: int = 1) -> void:
	if stats.has(key):
		stats[key] += amount
		print("GameManager: 统计 %s +%d = %d" % [key, amount, stats[key]])
		check_achievements()
	else:
		print("GameManager: 未知统计项 ", key)

## 获取生涯数据描述字符串
func get_career_summary() -> String:
	var minutes = stats.total_play_time / 60
	var hours = minutes / 60
	var display_minutes = minutes % 60
	var time_str = "%.1f小时" % (float(stats.total_play_time) / 3600.0) if hours > 0 else "%d分钟" % display_minutes

	return (
		"生涯数据:\n" +
		"  总击杀: %d\n" % stats.kill_count +
		"  总撤离: %d\n" % stats.extraction_count +
		"  总进化: %d\n" % stats.evolution_count +
		"  蚁巢等级: Lv.%d\n" % stats.nest_level +
		"  无伤撤离: %d\n" % stats.no_damage_extraction +
		"  总游戏时间: %s" % time_str
	)

## 增加击杀计数并检查成就
func add_kill() -> void:
	increment_stat("kill_count")
	print("GameManager: 击杀数: ", stats.kill_count)
	check_achievements()

## 完成撤离并检查成就（was_interrupted=false表示成功撤离）
func complete_extraction(was_interrupted: bool) -> void:
	if not was_interrupted:
		stats.extraction_count += 1
		print("GameManager: 撤离次数: ", stats.extraction_count)
		# 检查无伤撤离
		if stats.no_damage_extraction < 1:
			stats.no_damage_extraction = 1
	check_achievements()

## 完成进化并检查成就
func complete_evolution() -> void:
	stats.evolution_count += 1
	print("GameManager: 进化次数: ", stats.evolution_count)
	check_achievements()

## 更新存活时间并检查成就
func update_survival_time(seconds: int) -> void:
	stats.survival_time = maxi(stats.survival_time, seconds)
	check_achievements()

## 获取所有已解锁成就列表
func get_unlocked_achievements() -> Array:
	var unlocked = []
	for achievement_id in achievements:
		if achievements[achievement_id].unlocked:
			unlocked.append(achievement_id)
	return unlocked

## 获取成就总数和已解锁数
func get_achievement_progress() -> Dictionary:
	var total = achievements.size()
	var unlocked = get_unlocked_achievements().size()
	return { "total": total, "unlocked": unlocked, "percentage": float(unlocked) / float(total) * 100 if total > 0 else 0.0 }

## 商店物品定义
## 格式: item_id: {name: 名称, cost_type: 消耗资源类型, cost: 消耗数量, effect_type: 效果类型, effect_value: 效果值, description: 描述}
var shop_items: Dictionary = {
	"speed_up": { "name": "生产加速", "cost_type": "beetle_remains", "cost": 5, "effect_type": "production_speed", "effect_value": 2.0, "description": "蚂蚁生产速度翻倍，持续60秒" },
	"damage_buff": { "name": "伤害提升", "cost_type": "locust_remains", "cost": 5, "effect_type": "damage_buff", "effect_value": 1.5, "description": "所有蚂蚁伤害+50%，持续60秒" },
	"health_buff": { "name": "生命加成", "cost_type": "spider_remains", "cost": 5, "effect_type": "health_buff", "effect_value": 1.5, "description": "所有蚂蚁生命+50%，持续60秒" },
	"evo_mantis": { "name": "螳螂进化", "cost_type": "mantis_remains", "cost": 3, "effect_type": "evolution", "effect_value": "mantis", "description": "消耗3个螳螂残骸进行进化" },
	"evo_spider": { "name": "蜘蛛进化", "cost_type": "spider_remains", "cost": 3, "effect_type": "evolution", "effect_value": "spider", "description": "消耗3个蜘蛛残骸进行进化" },
	"evo_bee": { "name": "蜜蜂进化", "cost_type": "bee_remains", "cost": 3, "effect_type": "evolution", "effect_value": "bee", "description": "消耗3个蜜蜂残骸进行进化" },
	"evo_beetle": { "name": "甲虫进化", "cost_type": "beetle_remains", "cost": 3, "effect_type": "evolution", "effect_value": "beetle", "description": "消耗3个甲虫残骸进行进化" }
}

## 当前激活的buff
var active_buffs: Dictionary = {
	"production_speed": 0.0,
	"damage_buff": 0.0,
	"health_buff": 0.0
}

## 每日任务系统
## 任务配置 - 类型、描述、目标数量、奖励
var quest_templates: Array = [
	{ "type": "kill_enemies", "desc": "击杀 %d 只敌人", "target_min": 5, "target_max": 15, "reward_type": "beetle_remains", "reward_count_min": 3, "reward_count_max": 8 },
	{ "type": "kill_enemies", "desc": "击杀 %d 只敌人", "target_min": 10, "target_max": 25, "reward_type": "locust_remains", "reward_count_min": 2, "reward_count_max": 6 },
	{ "type": "collect_remains", "desc": "收集 %d 个残骸", "target_min": 3, "target_max": 10, "reward_type": "spider_remains", "reward_count_min": 2, "reward_count_max": 5 },
	{ "type": "collect_remains", "desc": "收集 %d 个残骸", "target_min": 5, "target_max": 12, "reward_type": "mantis_remains", "reward_count_min": 1, "reward_count_max": 3 },
	{ "type": "extraction", "desc": "成功撤离 %d 次", "target_min": 2, "target_max": 5, "reward_type": "food", "reward_count_min": 20, "reward_count_max": 50 }
]

## 当前每日任务 (3个任务)
var daily_quests: Array = []

## 上次任务重置日期 (用于检测新的一天)
var last_quest_reset_date: String = ""

## 每日签到系统
## 签到数据: last_checkin_date=上次签到日期, current_streak=当前连续签到天数, total_checkins=总签到次数
var checkin_data: Dictionary = {
	"last_checkin_date": "",
	"current_streak": 0,
	"total_checkins": 0
}

## 签到奖励配置 (连续签到天数对应的奖励，第7天为大奖)
var checkin_rewards: Dictionary = {
	1: { "type": "food", "id": "food", "count": 20, "desc": "第1天 - 20食物" },
	2: { "type": "food", "id": "food", "count": 30, "desc": "第2天 - 30食物" },
	3: { "type": "beetle_remains", "id": "beetle_remains", "count": 2, "desc": "第3天 - 2甲虫残骸" },
	4: { "type": "food", "id": "food", "count": 40, "desc": "第4天 - 40食物" },
	5: { "type": "locust_remains", "id": "locust_remains", "count": 2, "desc": "第5天 - 2蝗虫残骸" },
	6: { "type": "food", "id": "food", "count": 50, "desc": "第6天 - 50食物" },
	7: { "type": "food", "id": "food", "count": 100, "desc": "第7天 - 100食物 (大奖)" }
}

## 检查今日是否可签到
## 返回true表示今日尚未签到
func can_checkin() -> bool:
	var today = Time.get_date_string_from_system()
	return checkin_data.get("last_checkin_date", "") != today

## 获取当前连续签到天数
func get_checkin_streak() -> int:
	return checkin_data.get("current_streak", 0)

## 执行每日签到
## 返回签到结果: {"success": bool, "reward": Dictionary, "streak": int}
func checkin() -> Dictionary:
	var today = Time.get_date_string_from_system()
	var last_date = checkin_data.get("last_checkin_date", "")

	# 检查今日是否已签到
	if last_date == today:
		print("GameManager: 今日已签到")
		return {"success": false, "reward": {}, "streak": get_checkin_streak()}

	# 计算连续签到天数
	var streak = checkin_data.get("current_streak", 0)
	if last_date != "":
		# 检查是否是昨天（中断连续签到）
		var yesterday = _get_yesterday()
		if last_date == yesterday:
			streak += 1
		else:
			streak = 1
	else:
		streak = 1

	# 获取奖励（每7天循环）
	var reward_day = ((streak - 1) % 7) + 1
	var reward = checkin_rewards[reward_day]

	# 更新签到数据
	checkin_data["last_checkin_date"] = today
	checkin_data["current_streak"] = streak
	checkin_data["total_checkins"] = checkin_data.get("total_checkins", 0) + 1

	# 发放奖励
	var reward_type = reward.type
	var reward_id = reward.id
	var reward_count = reward.count
	if reward_type == "food":
		inventory[reward_id] = inventory.get(reward_id, 0) + reward_count
	elif reward_type in ["beetle_remains", "locust_remains", "spider_remains", "mantis_remains"]:
		inventory[reward_id] = inventory.get(reward_id, 0) + reward_count

	print("GameManager: 签到成功! 连续签到 %d 天，获得 %s x%d" % [streak, reward_id, reward_count])

	# 更新UI并保存
	base_camp.update_display()
	save_game()

	return {"success": true, "reward": reward, "streak": streak, "day": reward_day}

## 获取昨天的日期字符串
func _get_yesterday() -> String:
	var date = Time.get_date_dict_from_system()
	date["day"] -= 1
	if date["day"] < 1:
		# 上个月
		var days_in_month = _get_days_in_month(date["month"] - 1, date["year"])
		date["day"] = days_in_month
		date["month"] -= 1
		if date["month"] < 1:
			date["month"] = 12
			date["year"] -= 1
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]

## 获取某月的天数
func _get_days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12: return 31
		4, 6, 9, 11: return 30
		2:
			if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
				return 29
			return 28
	return 30

## 获取签到奖励预览
func get_checkin_rewards_preview() -> Array:
	var preview = []
	for day in range(1, 8):
		preview.append({
			"day": day,
			"desc": checkin_rewards[day].desc,
			"type": checkin_rewards[day].type,
			"id": checkin_rewards[day].id,
			"count": checkin_rewards[day].count
		})
	return preview

## 设置巢穴等级
func set_nest_level(level: int) -> void:
	nest_level = clampi(level, 1, 4)
	print("GameManager: 巢穴等级提升至 Lv.", nest_level, ", 返还率: ", calculate_return_rate() * 100, "%")

## 获取巢穴等级
func get_nest_level() -> int:
	return nest_level

## 升级蚁巢
## 成功返回true，失败返回false（已达满级或资源不足）
func upgrade_nest() -> bool:
	if nest_level >= 4:
		print("GameManager: 蚁巢已达最高等级 Lv.4")
		return false

	var next_level = nest_level + 1
	if not nest_upgrade_config.has(next_level):
		print("GameManager: 未找到等级 ", next_level, " 的升级配置")
		return false

	var config = nest_upgrade_config[next_level]
	var cost = config.cost

	# 检查食物是否足够
	if inventory.get("food", 0) < cost:
		print("GameManager: 升级需要 ", cost, " 食物，当前不足")
		return false

	# 消耗食物
	inventory["food"] -= cost

	# 提升等级
	nest_level = next_level
	stats.nest_level = nest_level

	# 检查蚁巢升级成就
	check_achievements()

	# 解锁新的蚂蚁类型
	var new_unlocks = config.unlock
	for ant_type in new_unlocks:
		if not ant_type in available_ant_types:
			available_ant_types.append(ant_type)

	# 更新base_camp的按钮状态
	base_camp.update_nest_level_display(nest_level, available_ant_types)

	# 自动保存
	save_game()

	print("GameManager: 蚁巢升级至 Lv.", nest_level, " - ", config.desc)
	print("GameManager: 已解锁蚂蚁类型: ", available_ant_types)
	return true

## 获取当前可用的蚂蚁类型列表
func get_available_ant_types() -> Array:
	return available_ant_types.duplicate()

## 获取升级信息
func get_upgrade_info() -> Dictionary:
	if nest_level >= 4:
		return { "can_upgrade": false, "next_level": 4, "cost": 0, "desc": "已达满级" }

	var next_level = nest_level + 1
	var config = nest_upgrade_config[next_level]
	return {
		"can_upgrade": inventory.get("food", 0) >= config.cost,
		"next_level": next_level,
		"cost": config.cost,
		"desc": config.desc,
		"unlock": config.unlock
	}

## 根据巢穴等级计算资源返还率
func calculate_return_rate() -> float:
	match nest_level:
		1: return 0.0   # Lv.1: 0%
		2: return 0.20 # Lv.2: 20%
		3: return 0.40 # Lv.3: 40%
		4: return 0.60 # Lv.4: 60% (最高)
		_: return 0.0

func _ready() -> void:
	add_to_group("game_manager")  # 确保能被 get_first_node_in_group("game_manager") 找到
	print("GameManager: ready")
	print("GameManager: battle_scene=", battle_scene)
	print("GameManager: base_camp=", base_camp)
	base_camp.enter_battle.connect(_on_enter_battle)

	init_transition_layer_safe()

	# 自动加载存档
	var is_new_game = not load_game()
	print("GameManager: after load_game, inventory=", inventory, ", food=", inventory.get("food", 0))
	if is_new_game:
		print("GameManager: 启动新游戏...")

	# 检查并重置每日任务
	check_daily_quest_reset()

	print("GameManager: signals connected")

## 初始化过渡效果层
func init_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "TransitionLayer"
	transition_layer.layer = 999  # 最顶层
	add_child(transition_layer)

	# 创建黑色遮罩
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = Color(0, 0, 0, 0)
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_overlay)

	# 创建提示文字
	transition_label = Label.new()
	transition_label.name = "TransitionLabel"
	transition_label.text = "加载中..."
	transition_label.set_anchors_preset(Control.PRESET_CENTER)
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_label.add_theme_font_size_override("font_size", 24)
	transition_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	transition_label.modulate.a = 0
	transition_layer.add_child(transition_label)

	# 创建加载提示文字
	transition_tip = Label.new()
	transition_tip.name = "TransitionTip"
	transition_tip.text = "正在准备战场..."
	transition_tip.set_anchors_preset(Control.PRESET_CENTER)
	transition_tip.offset_top = 40
	transition_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_tip.add_theme_font_size_override("font_size", 16)
	transition_tip.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	transition_tip.modulate.a = 0
	transition_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_tip)

	# 创建进度条
	loading_progress = ProgressBar.new()
	loading_progress.name = "LoadingProgress"
	loading_progress.set_anchors_preset(Control.PRESET_CENTER)
	loading_progress.offset_left = -150.0
	loading_progress.offset_top = 80.0
	loading_progress.offset_right = 150.0
	loading_progress.offset_bottom = 100.0
	loading_progress.custom_minimum_size = Vector2(300, 20)
	loading_progress.max_value = 100.0
	loading_progress.value = 0.0
	loading_progress.show_percentage = false
	loading_progress.modulate.a = 0
	loading_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(loading_progress)

	# 创建蚂蚁动画容器
	ant_container = Node2D.new()
	ant_container.name = "AntContainer"
	ant_container.modulate.a = 0
	transition_layer.add_child(ant_container)

	# 创建蚂蚁动画播放器
	ant_animation = AnimationPlayer.new()
	ant_animation.name = "AntAnimation"
	transition_layer.add_child(ant_animation)

	# 创建蚂蚁身体（椭圆形）
	var ant_body = Polygon2D.new()
	ant_body.name = "AntBody"
	var body_points = PackedVector2Array([
		Vector2(-20, -8), Vector2(-10, -12), Vector2(10, -12),
		Vector2(20, -8), Vector2(20, 8), Vector2(10, 12),
		Vector2(-10, 12), Vector2(-20, 8)
	])
	ant_body.polygon = body_points
	ant_body.color = Color(0.2, 0.15, 0.1)
	ant_container.add_child(ant_body)

	# 创建蚂蚁头部
	var ant_head = Polygon2D.new()
	ant_head.name = "AntHead"
	var head_points = PackedVector2Array([
		Vector2(-8, -5), Vector2(-12, -6), Vector2(-12, 6),
		Vector2(-8, 5), Vector2(8, 5), Vector2(12, 3),
		Vector2(12, -3), Vector2(8, -5)
	])
	ant_head.polygon = head_points
	ant_head.color = Color(0.25, 0.18, 0.12)
	ant_head.position = Vector2(28, 0)
	ant_container.add_child(ant_head)

	# 创建蚂蚁触角
	var ant_antenna_l = Polygon2D.new()
	ant_antenna_l.name = "AntAntennaL"
	var antenna_l_points = PackedVector2Array([Vector2(0, 0), Vector2(-5, -15), Vector2(-3, -15), Vector2(2, 0)])
	ant_antenna_l.polygon = antenna_l_points
	ant_antenna_l.color = Color(0.2, 0.15, 0.1)
	ant_antenna_l.position = Vector2(35, -4)
	ant_container.add_child(ant_antenna_l)

	var ant_antenna_r = Polygon2D.new()
	ant_antenna_r.name = "AntAntennaR"
	var antenna_r_points = PackedVector2Array([Vector2(0, 0), Vector2(5, -15), Vector2(3, -15), Vector2(-2, 0)])
	ant_antenna_r.polygon = antenna_r_points
	ant_antenna_r.color = Color(0.2, 0.15, 0.1)
	ant_antenna_r.position = Vector2(35, 4)
	ant_container.add_child(ant_antenna_r)

	# 创建蚂蚁腿（6条腿）
	for i in range(3):
		var leg_l = Polygon2D.new()
		leg_l.name = "LegL%d" % i
		var leg_l_points = PackedVector2Array([Vector2(0, 0), Vector2(-15, -8), Vector2(-13, -6), Vector2(0, 0)])
		leg_l.polygon = leg_l_points
		leg_l.color = Color(0.2, 0.15, 0.1)
		leg_l.position = Vector2(-5 + i * 10, -10)
		ant_container.add_child(leg_l)

		var leg_r = Polygon2D.new()
		leg_r.name = "LegR%d" % i
		var leg_r_points = PackedVector2Array([Vector2(0, 0), Vector2(-15, 8), Vector2(-13, 6), Vector2(0, 0)])
		leg_r.polygon = leg_r_points
		leg_r.color = Color(0.2, 0.15, 0.1)
		leg_r.position = Vector2(-5 + i * 10, 10)
		ant_container.add_child(leg_r)

	# 创建蚂蚁尾巴
	var ant_abdomen = Polygon2D.new()
	ant_abdomen.name = "AntAbdomen"
	var abdomen_points = PackedVector2Array([
		Vector2(-15, -10), Vector2(-5, -15), Vector2(10, -15),
		Vector2(20, -10), Vector2(20, 10), Vector2(10, 15),
		Vector2(-5, 15), Vector2(-15, 10)
	])
	ant_abdomen.polygon = abdomen_points
	ant_abdomen.color = Color(0.15, 0.1, 0.08)
	ant_abdomen.position = Vector2(-35, 0)
	ant_container.add_child(ant_abdomen)

	# 创建蚂蚁动画
	var anim = Animation.new()
	anim.length = 1.0
	var track_index = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_index, NodePath("..:position"))
	anim.track_insert_key(track_index, 0.0, Vector2(540, 960))
	anim.track_insert_key(track_index, 0.5, Vector2(540, 940))
	anim.track_insert_key(track_index, 1.0, Vector2(540, 960))

	# 触角摆动
	var antenna_l_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(antenna_l_track, NodePath("AntAntennaL:rotation"))
	anim.track_insert_key(antenna_l_track, 0.0, 0.0)
	anim.track_insert_key(antenna_l_track, 0.25, -0.3)
	anim.track_insert_key(antenna_l_track, 0.5, 0.0)
	anim.track_insert_key(antenna_l_track, 0.75, 0.3)
	anim.track_insert_key(antenna_l_track, 1.0, 0.0)

	var antenna_r_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(antenna_r_track, NodePath("AntAntennaR:rotation"))
	anim.track_insert_key(antenna_r_track, 0.0, 0.0)
	anim.track_insert_key(antenna_r_track, 0.25, 0.3)
	anim.track_insert_key(antenna_r_track, 0.5, 0.0)
	anim.track_insert_key(antenna_r_track, 0.75, -0.3)
	anim.track_insert_key(antenna_r_track, 1.0, 0.0)

	ant_animation.add_animation("ant_walk", anim)
	ant_animation.play("ant_walk")

	print("GameManager: 过渡效果层初始化完成")

## 安全的过渡效果层初始化（简化版，无动画）
func init_transition_layer_safe() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "TransitionLayer"
	transition_layer.layer = 999
	add_child(transition_layer)

	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = Color(0, 0, 0, 0)
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_overlay)

	transition_label = Label.new()
	transition_label.name = "TransitionLabel"
	transition_label.text = "加载中..."
	transition_label.set_anchors_preset(Control.PRESET_CENTER)
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_label.add_theme_font_size_override("font_size", 24)
	transition_label.modulate.a = 0
	transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_label)

	transition_tip = Label.new()
	transition_tip.name = "TransitionTip"
	transition_tip.text = "正在准备战场..."
	transition_tip.set_anchors_preset(Control.PRESET_CENTER)
	transition_tip.offset_top = 40
	transition_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_tip.add_theme_font_size_override("font_size", 16)
	transition_tip.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	transition_tip.modulate.a = 0
	transition_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_tip)

	loading_progress = ProgressBar.new()
	loading_progress.name = "LoadingProgress"
	loading_progress.set_anchors_preset(Control.PRESET_CENTER)
	loading_progress.offset_left = -150.0
	loading_progress.offset_top = 80.0
	loading_progress.offset_right = 150.0
	loading_progress.offset_bottom = 100.0
	loading_progress.custom_minimum_size = Vector2(300, 20)
	loading_progress.max_value = 100.0
	loading_progress.value = 0.0
	loading_progress.show_percentage = false
	loading_progress.modulate.a = 0
	loading_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(loading_progress)

	ant_container = Node2D.new()
	ant_container.name = "AntContainer"
	ant_container.modulate.a = 0
	transition_layer.add_child(ant_container)

	print("GameManager: 简化过渡效果层初始化完成")

## 执行进入战场的过渡效果 - 淡入淡出
## duration: 过渡时长（秒）
## to_battle: true=进入战场, false=仅执行过渡动画（场景已切换）
func execute_transition(to_battle: bool, duration: float = 0.5) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# 设置提示文字
	transition_label.text = "加载中..."

	# 显示所有加载界面元素
	var show_tween = create_tween()
	show_tween.set_parallel(true)
	show_tween.tween_property(transition_overlay, "color:a", 1.0, duration)
	show_tween.tween_property(transition_label, "modulate:a", 1.0, duration * 0.5)
	show_tween.tween_property(transition_tip, "modulate:a", 1.0, duration * 0.5)
	show_tween.tween_property(loading_progress, "modulate:a", 1.0, duration * 0.5)
	show_tween.tween_property(ant_container, "modulate:a", 1.0, duration * 0.5)

	# 模拟加载进度
	var tips = ["正在生成敌人...", "正在放置资源...", "正在初始化天气...", "正在准备战场..."]
	for i in range(100):
		loading_progress.value = i as float
		if i % 25 == 0 and i < 100:
			transition_tip.text = tips[i / 25.0]
		await get_tree().create_timer(0.02).timeout

	loading_progress.value = 100.0
	transition_tip.text = "准备就绪!"

	# 等待一小段时间
	await get_tree().create_timer(0.3).timeout

	# 如果是进入战场，执行场景切换（只有返回基地时需要切换）
	if to_battle:
		base_camp.visible = false
		battle_scene.visible = true
		var main = battle_scene as Node2D
		if main:
			main.start_battle(inventory, ant_count)

	# 淡出所有元素
	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(transition_overlay, "color:a", 0.0, duration)
	fade_out.tween_property(transition_label, "modulate:a", 0.0, duration * 0.5)
	fade_out.tween_property(transition_tip, "modulate:a", 0.0, duration * 0.5)
	fade_out.tween_property(loading_progress, "modulate:a", 0.0, duration * 0.5)
	fade_out.tween_property(ant_container, "modulate:a", 0.0, duration * 0.5)

	await fade_out.chain().finished
	loading_progress.value = 0.0
	is_transitioning = false
	if to_battle:
		print("GameManager: 过渡完成 - 已进入战场")
	else:
		print("GameManager: 过渡完成")

## 显示新手礼包弹窗（需要在UI层实现）
func show_welcome_reward_popup() -> void:
	if base_camp.has_method("show_welcome_reward_popup"):
		base_camp.show_welcome_reward_popup()
	else:
		print("GameManager: 新手礼包弹窗 - base_camp缺少show_welcome_reward_popup方法")

## 检查是否需要重置每日任务 (每天凌晨重置)
func check_daily_quest_reset() -> void:
	var today = Time.get_date_string_from_system()
	if last_quest_reset_date != today:
		generate_daily_quests()
		last_quest_reset_date = today
		save_game()
		print("GameManager: 每日任务已重置!")

## 生成3个随机每日任务
func generate_daily_quests() -> void:
	daily_quests = []
	var used_templates: Array = []

	# 随机选择3个不同的任务模板
	for i in range(3):
		var available_templates: Array = []
		for j in range(quest_templates.size()):
			if not j in used_templates:
				available_templates.append(j)

		if available_templates.size() == 0:
			break

		var template_idx = available_templates[randi() % available_templates.size()]
		used_templates.append(template_idx)

		var template = quest_templates[template_idx]
		var target = randi() % (template.target_max - template.target_min + 1) + template.target_min
		var reward_count = randi() % (template.reward_count_max - template.reward_count_min + 1) + template.reward_count_min

		var quest = {
			"type": template.type,
			"description": template.desc % target,
			"target": target,
			"progress": 0,
			"completed": false,
			"reward_type": template.reward_type,
			"reward_count": reward_count
		}
		daily_quests.append(quest)

	print("GameManager: 生成了每日任务: ", daily_quests)

## 获取当前每日任务列表
func get_daily_quests() -> Array:
	return daily_quests.duplicate()

## 更新任务进度 (从战斗场景调用)
func update_quest_progress(quest_type: String, amount: int) -> void:
	check_daily_quest_reset()

	for quest in daily_quests:
		if quest.type == quest_type and not quest.completed:
			quest.progress = mini(quest.progress + amount, quest.target)
			print("GameManager: 任务进度更新 - ", quest.description, " (", quest.progress, "/", quest.target, ")")

## 完成任务并发放奖励
func complete_quest(index: int) -> bool:
	if index < 0 or index >= daily_quests.size():
		print("GameManager: 无效的任务索引: ", index)
		return false

	var quest = daily_quests[index]
	if quest.completed:
		print("GameManager: 任务已完成: ", quest.description)
		return false

	if quest.progress < quest.target:
		print("GameManager: 任务未完成: ", quest.description, " (", quest.progress, "/", quest.target, ")")
		return false

	# 标记为已完成
	quest.completed = true

	# 发放奖励
	var reward_type = quest.reward_type
	var reward_count = quest.reward_count
	if reward_type in inventory:
		inventory[reward_type] += reward_count
	else:
		inventory[reward_type] = reward_count

	print("GameManager: 任务完成! 获得奖励: ", reward_count, "个 ", reward_type)
	base_camp.update_display()
	save_game()
	return true

## 获取任务完成状态统计
func get_quest_completion_info() -> Dictionary:
	var completed = 0
	var total = daily_quests.size()
	for quest in daily_quests:
		if quest.completed:
			completed += 1
	return { "completed": completed, "total": total }

func _on_enter_battle() -> void:
	print("GameManager: _on_enter_battle called")
	print("GameManager: battle_scene=", battle_scene)
	print("GameManager: base_camp=", base_camp)
	if not battle_scene:
		print("GameManager: ERROR - battle_scene is null!")
		return
	if not battle_scene is Node2D:
		print("GameManager: ERROR - battle_scene is not Node2D!")
		return
	print("GameManager: current scene=", get_tree().current_scene)
	print("GameManager: base_camp visible BEFORE=", base_camp.visible)
	print("GameManager: battle_scene visible BEFORE=", battle_scene.visible)
	print("GameManager: battle_scene name=", battle_scene.name)

	# 简单的场景切换，不使用过渡效果
	base_camp.visible = false
	battle_scene.visible = true

	print("GameManager: base_camp visible AFTER=", base_camp.visible)
	print("GameManager: battle_scene visible AFTER=", battle_scene.visible)

	var main = battle_scene as Node2D
	if main:
		print("GameManager: calling main.start_battle")
		main.start_battle(inventory, ant_count)
		print("GameManager: main.start_battle completed")
	else:
		print("GameManager: ERROR - main is null after cast!")

	print("GameManager: scene switched, final state:")
	print("GameManager:   base_camp visible=", base_camp.visible)
	print("GameManager:   battle_scene visible=", battle_scene.visible)

func return_to_base(was_interrupted: bool = false) -> void:
	print("GameManager: return_to_base called, interrupted=", was_interrupted)
	game_was_interrupted = was_interrupted
	if _ensure_transition_layer():
		# 先执行过渡效果，完成后再切换场景
		execute_transition_to_base()
	else:
		print("GameManager: 过渡层不可用，直接返回基地")
		_apply_return_to_base_results()

func _ensure_transition_layer() -> bool:
	if _is_transition_layer_ready():
		return true
	init_transition_layer_safe()
	return _is_transition_layer_ready()

func _is_transition_layer_ready() -> bool:
	return transition_overlay != null and is_instance_valid(transition_overlay) \
		and transition_label != null and is_instance_valid(transition_label) \
		and transition_tip != null and is_instance_valid(transition_tip) \
		and loading_progress != null and is_instance_valid(loading_progress) \
		and ant_container != null and is_instance_valid(ant_container)

func _apply_return_to_base_results() -> void:
	battle_scene.visible = false
	base_camp.visible = true
	var main = battle_scene as Node2D
	if main:
		var collected = main.get_collected_resources()
		var return_rate = calculate_return_rate()
		for type in collected:
			var original_amount = collected[type]
			var returned_amount = int(original_amount * return_rate) if game_was_interrupted else original_amount
			if type in inventory:
				inventory[type] += returned_amount
			else:
				inventory[type] = returned_amount
		base_camp.update_display()
		if game_was_interrupted:
			print("GameManager: 撤离被中断! 返还率: ", return_rate * 100, "%")
		else:
			complete_extraction(false)
	save_game()

## 执行返回基地的过渡效果
func execute_transition_to_base() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	transition_label.text = "加载中..."

	# 显示所有加载界面元素
	var show_tween = create_tween()
	show_tween.set_parallel(true)
	show_tween.tween_property(transition_overlay, "color:a", 1.0, 0.5)
	show_tween.tween_property(transition_label, "modulate:a", 1.0, 0.25)
	show_tween.tween_property(transition_tip, "modulate:a", 1.0, 0.25)
	show_tween.tween_property(loading_progress, "modulate:a", 1.0, 0.25)
	show_tween.tween_property(ant_container, "modulate:a", 1.0, 0.25)

	# 模拟加载进度
	var tips = ["正在计算资源...", "正在保存进度...", "正在返回基地..."]
	for i in range(100):
		loading_progress.value = i as float
		if i % 35 == 0 and i < 100:
			transition_tip.text = tips[i / 35.0]
		await get_tree().create_timer(0.015).timeout

	loading_progress.value = 100.0
	transition_tip.text = "准备就绪!"

	await get_tree().create_timer(0.2).timeout

	# 执行场景切换和资源回收
	_apply_return_to_base_results()

	# 淡出所有元素
	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(transition_overlay, "color:a", 0.0, 0.5)
	fade_out.tween_property(transition_label, "modulate:a", 0.0, 0.25)
	fade_out.tween_property(transition_tip, "modulate:a", 0.0, 0.25)
	fade_out.tween_property(loading_progress, "modulate:a", 0.0, 0.25)
	fade_out.tween_property(ant_container, "modulate:a", 0.0, 0.25)

	await fade_out.chain().finished
	loading_progress.value = 0.0
	is_transitioning = false
	print("GameManager: 过渡完成 - 已返回基地")

## 执行吞噬融合进化
## 消耗对应昆虫残骸，永久改变玩家外观
func evolve_to(insect_type: String) -> bool:
	if not evolution_materials.has(insect_type):
		print("GameManager: 未知昆虫类型 ", insect_type)
		return false

	var evo_data = evolution_materials[insect_type]
	var material_name = evo_data["material"]
	var required_count = evo_data["count"]

	# 检查材料是否足够
	if inventory.get(material_name, 0) < required_count:
		print("GameManager: 材料不足，无法进化为 ", insect_type)
		return false

	# 消耗材料
	inventory[material_name] -= required_count
	base_camp.update_display()

	# 更新进化状态
	current_evolution = insect_type
	complete_evolution()

	# 获取玩家节点并应用外观变化
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_evolution_color(evo_data["color"])

	# 自动保存
	save_game()

	print("GameManager: 进化成功! 当前形态: ", insect_type)
	return true

## 获取进化状态描述
func get_evolution_description() -> String:
	if current_evolution == "":
		return "普通蚂蚁"
	match current_evolution:
		"mantis": return "螳螂蚂蚁"
		"spider": return "蜘蛛蚂蚁"
		"bee": return "蜜蜂蚂蚁"
		"beetle": return "甲虫蚂蚁"
	return current_evolution

## 购买商店物品
## 成功返回true，失败返回false
func purchase_item(item_id: String) -> bool:
	if not shop_items.has(item_id):
		print("GameManager: 未知物品 ", item_id)
		return false

	var item = shop_items[item_id]
	var cost_type = item.cost_type
	var cost = item.cost

	# 检查资源是否足够
	if inventory.get(cost_type, 0) < cost:
		print("GameManager: 资源不足，无法购买 ", item.name)
		return false

	# 消耗资源
	inventory[cost_type] -= cost

	# 应用效果
	match item.effect_type:
		"production_speed", "damage_buff", "health_buff":
			# 临时buff效果
			active_buffs[item.effect_type] = item.effect_value
			print("GameManager: 购买了 ", item.name, "，效果: ", item.description)
		"evolution":
			# 执行进化
			var insect_type = item.effect_value
			if evolution_materials.has(insect_type):
				inventory[evolution_materials[insect_type].material] -= evolution_materials[insect_type].count
				if evolve_to(insect_type):
					print("GameManager: 购买了进化物品 ", item.name)
				else:
					# 进化失败，返还资源
					inventory[cost_type] += cost
					return false
			else:
				print("GameManager: 未知进化类型 ", insect_type)
				inventory[cost_type] += cost
				return false
		_:
			print("GameManager: 未知效果类型 ", item.effect_type)
			inventory[cost_type] += cost
			return false

	# 同步到base_camp
	base_camp.update_display()

	# 自动保存
	save_game()

	return true

## 获取商店物品列表
func get_shop_items() -> Dictionary:
	return shop_items.duplicate()

## 检查是否有激活的buff
func has_active_buff(buff_type: String) -> bool:
	return active_buffs.has(buff_type) and active_buffs[buff_type] > 0.0

## 获取buff效果值
func get_buff_value(buff_type: String) -> float:
	if active_buffs.has(buff_type):
		return active_buffs[buff_type]
	return 1.0

## 保存游戏状态到 user://save_game.dat
func save_game() -> bool:
	var save_path = "user://save_game.dat"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		print("GameManager: 保存失败，无法打开文件: ", save_path)
		return false

	var save_data = {
		"inventory": inventory.duplicate(),  # 保存副本而不是引用
		"ant_count": ant_count.duplicate(),
		"nest_level": nest_level,
		"available_ant_types": available_ant_types.duplicate(),
		"current_evolution": current_evolution,
		"active_buffs": active_buffs.duplicate(),
		"daily_quests": daily_quests.duplicate(),
		"last_quest_reset_date": last_quest_reset_date,
		"achievements": achievements.duplicate(),
		"stats": stats.duplicate(),
		"unlocked_titles": unlocked_titles.duplicate(),
		"emails": emails.duplicate(),
		"has_purchased_first": has_purchased_first,
		"has_claimed_welcome_reward": has_claimed_welcome_reward,
		"tutorial_skipped": tutorial_skipped,
		"friends": friends.duplicate(),
		"checkin_data": checkin_data.duplicate(),
		"save_version": SAVE_VERSION
	}

	# 使用 var_to_str 进行序列化保存
	var json_string = JSON.stringify(save_data)
	file.store_line(json_string)
	file.close()

	print("GameManager: 游戏已保存到 ", save_path)
	print("GameManager: 保存数据 - inventory=", save_data["inventory"], ", food=", save_data["inventory"].get("food", 0))
	return true

## 迁移旧版存档数据
## 处理存档格式变化和数据清洗
func migrate_save_data(data: Dictionary, from_version: int) -> void:
	if from_version < 2:
		# v1 -> v2: 移除冗余的analytics_data（运行时数据不需要持久化）
		if data.has("analytics_data"):
			data.erase("analytics_data")
		# 清理空的好友请求列表
		if data.has("friends") and data["friends"].size() == 0:
			data["friends"] = []
		# 清理空的邮件列表
		if data.has("emails") and data["emails"].size() == 0:
			data["emails"] = []
	# 未来版本迁移添加在这里
	# if from_version < 3:
	#     ...

## 从 user://save_game.dat 加载游戏状态
func load_game() -> bool:
	var save_path = "user://save_game.dat"

	# 检查存档文件是否存在
	if not FileAccess.file_exists(save_path):
		print("GameManager: 未找到存档文件，将开始新游戏")
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		print("GameManager: 加载失败，无法打开文件: ", save_path)
		return false

	var json_string = file.get_line()
	file.close()

	print("GameManager: load_game - json_string=", json_string)

	# 解析 JSON 数据
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("GameManager: JSON解析失败")
		return false

	var save_data = json.get_data()
	if typeof(save_data) != TYPE_DICTIONARY:
		print("GameManager: 存档数据格式错误")
		return false

	# 存档版本检查和数据迁移
	var old_save_version = save_data.get("save_version", 1)
	if old_save_version < SAVE_VERSION:
		print("GameManager: 检测到旧版存档 (v%d)，正在迁移到 v%d..." % [old_save_version, SAVE_VERSION])
		migrate_save_data(save_data, old_save_version)
		print("GameManager: 存档迁移完成")

	# 恢复游戏状态
	if save_data.has("inventory"):
		inventory = save_data["inventory"]
		# 确保 inventory 有必要的键和合理的值
		if not inventory.has("food") or inventory.get("food", 0) <= 0:
			inventory["food"] = 100
		if not inventory.has("beetle_remains"):
			inventory["beetle_remains"] = 0
		print("GameManager: load_game - loaded inventory, food=", inventory.get("food", 0))
	if save_data.has("ant_count"):
		ant_count = save_data["ant_count"]
	if save_data.has("nest_level"):
		nest_level = save_data["nest_level"]
	if save_data.has("available_ant_types"):
		available_ant_types = save_data["available_ant_types"]
	if save_data.has("current_evolution"):
		current_evolution = save_data["current_evolution"]
	if save_data.has("active_buffs"):
		active_buffs = save_data["active_buffs"]
	if save_data.has("daily_quests"):
		daily_quests = save_data["daily_quests"]
	if save_data.has("last_quest_reset_date"):
		last_quest_reset_date = save_data["last_quest_reset_date"]
	if save_data.has("achievements"):
		achievements = save_data["achievements"]
	if save_data.has("stats"):
		stats = save_data["stats"]
	if save_data.has("unlocked_titles"):
		unlocked_titles = save_data["unlocked_titles"]
	if save_data.has("emails"):
		emails = save_data["emails"]
	if save_data.has("has_purchased_first"):
		has_purchased_first = save_data["has_purchased_first"]
	if save_data.has("has_claimed_welcome_reward"):
		has_claimed_welcome_reward = save_data["has_claimed_welcome_reward"]
	if save_data.has("tutorial_skipped"):
		tutorial_skipped = save_data["tutorial_skipped"]
	if save_data.has("friends"):
		friends = save_data["friends"]
	if save_data.has("checkin_data"):
		checkin_data = save_data["checkin_data"]

	# 重置运行时数据（不从存档恢复，避免冗余）
	analytics_data = { "events": [], "screens": [], "session_start": Time.get_datetime_string_from_system(), "total_events": 0 }

	# 更新 UI 显示
	base_camp.update_nest_level_display(nest_level, available_ant_types)
	base_camp.update_display()

	# 恢复进化外观
	if current_evolution != "" and evolution_materials.has(current_evolution):
		var evo_data = evolution_materials[current_evolution]
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.apply_evolution_color(evo_data["color"])

	print("GameManager: 游戏已从 ", save_path, " 加载")
	print("GameManager: 加载数据: ", save_data)
	return true

## 开始新游戏，清除存档
func new_game() -> bool:
	var save_path = "user://save_game.dat"

	# 重置所有游戏状态为默认值
	inventory = { "beetle_remains": 0, "locust_remains": 0, "spider_remains": 0, "mantis_remains": 0, "food": 100 }
	ant_count = { "worker": 5, "soldier": 2, "shooter": 0, "bomber": 0, "flyer": 0 }
	nest_level = 1
	available_ant_types = ["worker"]
	current_evolution = ""
	active_buffs = { "production_speed": 0.0, "damage_buff": 0.0, "health_buff": 0.0 }
	daily_quests = []
	last_quest_reset_date = ""

	# 重置成就系统
	for achievement_id in achievements:
		achievements[achievement_id].unlocked = false
	stats = { "kill_count": 0, "extraction_count": 0, "evolution_count": 0, "nest_level": 1, "survival_time": 0, "no_damage_extraction": 0, "total_play_time": 0 }
	unlocked_titles = []
	has_purchased_first = false
	has_claimed_welcome_reward = false
	tutorial_skipped = false
	friends = []
	checkin_data = { "last_checkin_date": "", "current_streak": 0, "total_checkins": 0 }
	analytics_data = { "events": [], "screens": [], "session_start": Time.get_datetime_string_from_system(), "total_events": 0 }

	# 删除存档文件
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open("user://")
		if dir != null:
			dir.remove(save_path)
			print("GameManager: 已删除存档文件: ", save_path)

	# 更新 UI 显示
	base_camp.update_nest_level_display(nest_level, available_ant_types)
	base_camp.update_display()

	# 恢复玩家原始外观
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_appearance"):
		player.reset_appearance()

	print("GameManager: 已开始新游戏")
	return true

## 开始匹配多人游戏 (预留接口)
## 返回是否成功开始匹配
func find_match() -> bool:
	if multiplayer_state == "searching":
		print("GameManager: 已在匹配中，无需重复搜索")
		return false
	if multiplayer_state == "playing":
		print("GameManager: 当前已在游戏中，请先结束当前对局")
		return false

	multiplayer_state = "searching"
	print("GameManager: 开始匹配多人游戏...")
	# TODO: 实现实际的匹配逻辑
	return true

## 取消匹配 (预留接口)
## 返回是否成功取消
func cancel_match() -> bool:
	if multiplayer_state != "searching":
		print("GameManager: 当前不在匹配状态，无法取消")
		return false

	multiplayer_state = "idle"
	print("GameManager: 已取消匹配")
	# TODO: 实现实际的取消匹配逻辑
	return true

## 检查是否处于多人模式 (预留接口)
## 返回true表示多人模式，false表示单人模式
func is_multiplayer() -> bool:
	return multiplayer_state == "playing" or multiplayer_state == "matched"

## 获取排行榜数据 (预留未来多人排行榜接口)
## type: 排行榜类型 ("daily"/"weekly"/"all")
## 返回占位数据，实际多人排行榜需要后端支持
func get_leaderboard(type: String) -> Array:
	print("GameManager: 获取排行榜 (占位) type=", type)
	# TODO: 实现实际的排行榜获取逻辑，连接后端API
	# 返回占位数据
	return [
		{ "rank": 1, "name": "玩家A", "score": 10000, "date": "2026-05-01" },
		{ "rank": 2, "name": "玩家B", "score": 8000, "date": "2026-05-02" },
		{ "rank": 3, "name": "玩家C", "score": 6000, "date": "2026-05-03" },
		{ "rank": 4, "name": "玩家D", "score": 4000, "date": "2026-05-04" },
		{ "rank": 5, "name": "玩家E", "score": 2000, "date": "2026-05-05" }
	]

## 提交分数 (预留未来多人排行榜接口)
## score: 要提交的分数
## 成功返回true，失败返回false
func submit_score(score: int) -> bool:
	if score <= 0:
		print("GameManager: 无效的分数: ", score)
		return false

	var current_score = leaderboard_data.get("score", 0)
	if score > current_score:
		leaderboard_data["score"] = score
		leaderboard_data["date"] = Time.get_date_string_from_system()
		print("GameManager: 新纪录! 分数: ", score)
		save_game()
		return true
	else:
		print("GameManager: 分数未超过当前纪录 (", current_score, ")")
		return false

## 获取玩家排名 (预留未来多人排行榜接口)
## 返回玩家的当前排名，未上榜返回-1
func get_player_rank() -> int:
	print("GameManager: 获取玩家排名 (占位)")
	# TODO: 实现实际的排名查询逻辑，连接后端API
	# 占位返回：假设本地玩家排名第10
	var local_score = leaderboard_data.get("score", 0)
	if local_score == 0:
		return -1
	# 计算排名：分数越高排名越靠前
	# 这里简化计算，实际需要根据后端数据计算
	if local_score >= 10000:
		return 1
	elif local_score >= 8000:
		return 2
	elif local_score >= 6000:
		return 3
	elif local_score >= 4000:
		return 4
	elif local_score >= 2000:
		return 5
	else:
		return 10

## 检查连接状态
## 返回true表示已连接，false表示已断开
func check_connection() -> bool:
	return connection_connected

## 触发断开连接 (预留接口)
## 由网络层调用以通知连接断开
func on_disconnect() -> void:
	if connection_connected:
		connection_connected = false
		reconnect_attempts = 0
		reconnect_timer = 0.0
		print("GameManager: 连接已断开，开始监听重连...")
		# TODO: 通知UI显示断线提示
		if base_camp.has_method("show_disconnect_notification"):
			base_camp.show_disconnect_notification()

## 触发重新连接 (预留接口)
## 由网络层调用以通知重连成功
func on_reconnect() -> void:
	connection_connected = true
	reconnect_attempts = 0
	reconnect_timer = 0.0
	print("GameManager: 重连成功!")
	# TODO: 通知UI关闭断线提示，恢复正常游戏
	if base_camp.has_method("hide_disconnect_notification"):
		base_camp.hide_disconnect_notification()
	if base_camp.has_method("show_reconnect_notification"):
		base_camp.show_reconnect_notification()

## 请求重新连接 (预留接口)
## 手动触发重连尝试
func reconnect() -> void:
	if connection_connected:
		print("GameManager: 已在连接状态，无需重连")
		return

	if reconnect_attempts >= max_reconnect_attempts:
		print("GameManager: 已达到最大重连次数 (", max_reconnect_attempts, ")，请稍后重试")
		# TODO: 通知UI显示重连失败提示
		return

	reconnect_attempts += 1
	reconnect_timer = 0.0
	print("GameManager: 发起第 ", reconnect_attempts, " 次重连尝试...")
	# TODO: 调用实际的重连逻辑，连接网络服务
	# 示例: Network.reconnect()

## 进程处理 (每帧调用)
## 处理重连计时器
func _process(delta: float) -> void:
	if not connection_connected and reconnect_attempts < max_reconnect_attempts:
		reconnect_timer += delta
		if reconnect_timer >= reconnect_timeout:
			reconnect_timer = 0.0
			reconnect()
