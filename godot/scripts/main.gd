extends Control

const Rules = preload("res://godot/scripts/game_rules.gd")
const Skeleton = preload("res://godot/scripts/skeleton.gd")
const SAVE_PATH := "user://idle_ryze_godot_v2.json"
const LEGACY_SAVE_PATH := "user://idle_ryze_godot_v1.json"
const SAVE_VERSION := 2

@onready var world: Node2D = $World
@onready var village: Node2D = $World/Village
@onready var village_hero: Node2D = $World/Village/Hero
@onready var village_hero_sprite: Sprite2D = $World/Village/Hero/Sprite
@onready var portal: Sprite2D = $World/Village/Portal
@onready var arena: Node2D = $World/SkeletonWorld
@onready var arena_hero: Node2D = $World/SkeletonWorld/Hero
@onready var arena_hero_sprite: Sprite2D = $World/SkeletonWorld/Hero/Sprite
@onready var dungeon: Node2D = $World/Dungeon
@onready var dungeon_boss: Node2D = $World/Dungeon/Boss
@onready var dungeon_hero: Node2D = $World/Dungeon/Hero
@onready var dungeon_hero_sprite: Sprite2D = $World/Dungeon/Hero/Sprite
@onready var ui: Control = $HUD/UI

var state: Dictionary = {
	"version": SAVE_VERSION, "level": 1, "xp": 0, "gold": 0,
	"hp": Rules.HERO_HP, "mana": Rules.HERO_MANA, "sword_level": 0,
	"dungeon_keys": 0, "boss_kills": 0,
	"scene": "village"
}
var rng := RandomNumberGenerator.new()
var save_enabled := true
var save_warning := ""
var active_scene := "village"
var target := Vector2.ZERO
var has_target := false
var pending_action := ""
var held_directions: Dictionary = {}
var enemies: Array = []
var attack_left := 0.0
var skill_left := 0.0
var mana_left := Rules.MANA_REGEN_SECONDS
var death_left := Rules.HERO_RESPAWN_SECONDS
var save_left := 5.0
var hud_left := 0.0
var toast_left := 0.0
var elapsed := 0.0

var top_bar: ColorRect
var title_plate: ColorRect
var brand_label: Label
var level_label: Label
var resources_label: Label
var hp_background: ColorRect
var hp_fill: ColorRect
var hp_label: Label
var mana_background: ColorRect
var mana_fill: ColorRect
var mana_label: Label
var xp_background: ColorRect
var xp_fill: ColorRect
var xp_label: Label
var scene_label: Label
var hint_label: Label
var toast_label: Label
var menu_button: Button
var interact_button: Button
var skill_button: Button
var return_button: Button
var direction_buttons: Dictionary = {}
var panel: PanelContainer
var panel_body: VBoxContainer

func _ready() -> void:
	rng.randomize()
	_load_save()
	_build_ui()
	_add_world_labels()
	_spawn_skeletons()
	_set_scene(str(state["scene"]))
	_layout()
	get_viewport().size_changed.connect(_layout)
	if save_warning != "":
		_toast(save_warning)

func _process(delta: float) -> void:
	elapsed += delta
	portal.modulate.a = 0.82 + 0.16 * sin(elapsed * 2.6)
	match active_scene:
		"village": _tick_village(delta)
		"skeleton": _tick_combat(delta)
		"dungeon": _tick_dungeon(delta)
	skill_left = maxf(0.0, skill_left - delta)
	save_left -= delta
	if save_left <= 0.0:
		save_left = 5.0
		_save()
	hud_left -= delta
	if hud_left <= 0.0:
		hud_left = 0.15
		_update_hud()
	if toast_left > 0.0:
		toast_left -= delta
		if toast_left <= 0.0:
			toast_label.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		panel.visible = false
	elif event.keycode == KEY_M:
		_open_menu()
	elif event.keycode == KEY_I:
		_open_inventory()
	elif event.keycode == KEY_E and active_scene == "village":
		_interact()
	elif event.keycode == KEY_SPACE and active_scene != "village":
		_cast_skill()

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible or active_scene != "village":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_walk_or_interact(world.to_local(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		_walk_or_interact(world.to_local(event.position))

func _walk_or_interact(point: Vector2) -> void:
	if absf(point.x - 340.0) < 88.0 and point.y > -255.0 and point.y < 20.0:
		target = Vector2(300, -30)
		pending_action = "portal"
	elif absf(point.x + 260.0) < 48.0 and point.y > -107.0 and point.y < 51.0:
		target = Vector2(-260, 5)
		pending_action = "merchant"
	elif absf(point.x - 140.0) < 48.0 and point.y > -157.0 and point.y < 1.0:
		target = Vector2(140, -45)
		pending_action = "commander"
	else:
		target = point
		pending_action = ""
	has_target = true
	if pending_action != "" and village_hero.position.distance_to(target) < Rules.INTERACTION_RADIUS:
		var action := pending_action
		has_target = false
		pending_action = ""
		_run_action(action)

func _tick_village(delta: float) -> void:
	if panel.visible:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or held_directions.get("left", false):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or held_directions.get("right", false):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or held_directions.get("up", false):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or held_directions.get("down", false):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		has_target = false
		pending_action = ""
	elif has_target:
		direction = target - village_hero.position
		if direction.length() < 5.0:
			has_target = false
			direction = Vector2.ZERO
	if direction != Vector2.ZERO:
		var step := direction.normalized() * Rules.HERO_MOVE_SPEED * delta
		if has_target and step.length() > direction.length():
			step = direction
		var next_position: Vector2 = village_hero.position + step
		var diamond := absf(next_position.x) / 410.0 + absf(next_position.y) / 205.0
		if diamond > 0.91:
			next_position *= 0.91 / diamond
		village_hero.position = next_position
		village_hero_sprite.flip_h = direction.x < 0.0
	if pending_action != "" and village_hero.position.distance_to(target) < Rules.INTERACTION_RADIUS:
		var action := pending_action
		pending_action = ""
		has_target = false
		_run_action(action)

func _interact() -> void:
	var landmarks := [
		{"point": Vector2(-260, 5), "action": "merchant"},
		{"point": Vector2(140, -45), "action": "commander"},
		{"point": Vector2(300, -30), "action": "portal"}
	]
	var closest: Dictionary = {}
	var distance := INF
	for entry in landmarks:
		var current: float = village_hero.position.distance_to(entry["point"])
		if current < distance:
			distance = current
			closest = entry
	if distance < Rules.INTERACTION_RADIUS:
		_run_action(str(closest["action"]))
	else:
		_toast("Aproxime-se de um personagem ou do portal.")

func _run_action(action: String) -> void:
	match action:
		"merchant": _open_shop()
		"commander": _open_commander()
		"portal": _enter_skeleton_world()

func _spawn_skeletons() -> void:
	for point in [Vector2(-30, -55), Vector2(155, -80), Vector2(200, 85)]:
		var enemy = Skeleton.new()
		enemy.position = point
		arena.add_child(enemy)
		enemies.append(enemy)

func _tick_combat(delta: float) -> void:
	mana_left -= delta
	if mana_left <= 0.0:
		mana_left += Rules.MANA_REGEN_SECONDS
		state["mana"] = mini(Rules.HERO_MANA, int(state["mana"]) + 1)
	for enemy in enemies:
		if not enemy.alive:
			enemy.respawn_left -= delta
			if enemy.respawn_left <= 0.0:
				enemy.alive = true
				enemy.hp = Rules.SKELETON_HP
				enemy.attack_left = Rules.SKELETON_ATTACK_SECONDS
				enemy.display_seconds = 0
				enemy.queue_redraw()
			else:
				var shown := ceili(enemy.respawn_left)
				if shown != enemy.display_seconds:
					enemy.display_seconds = shown
					enemy.queue_redraw()
	if int(state["hp"]) <= 0:
		death_left -= delta
		if death_left <= 0.0:
			state["hp"] = Rules.max_hp(int(state["level"]))
			arena_hero.position = Vector2(-215, 80)
			arena_hero.visible = true
			death_left = Rules.HERO_RESPAWN_SECONDS
			_toast("O Espadachim renasceu.")
		return
	var nearest = _nearest_enemy()
	if nearest == null:
		return
	var to_enemy: Vector2 = nearest.position - arena_hero.position
	if to_enemy.length() > 50.0:
		arena_hero.position += to_enemy.normalized() * minf(Rules.HERO_MOVE_SPEED * delta, to_enemy.length() - 50.0)
		arena_hero_sprite.flip_h = to_enemy.x < 0.0
	else:
		attack_left -= delta
		if attack_left <= 0.0:
			attack_left = Rules.HERO_ATTACK_SECONDS
			_hit_enemy(nearest, Rules.damage(int(state["level"]), int(state["sword_level"])))
	for enemy in enemies:
		if not enemy.alive:
			continue
		if arena_hero.position.distance_to(enemy.position) < 65.0:
			enemy.attack_left -= delta
			if enemy.attack_left <= 0.0:
				enemy.attack_left = Rules.SKELETON_ATTACK_SECONDS
				state["hp"] = maxi(0, int(state["hp"]) - Rules.SKELETON_DAMAGE)
				if int(state["hp"]) == 0:
					arena_hero.visible = false
					death_left = Rules.HERO_RESPAWN_SECONDS
					_toast("Espadachim derrotado. Renascendo...")
					_save()
					break

func _nearest_enemy():
	var best = null
	var best_distance := INF
	for enemy in enemies:
		if enemy.alive:
			var distance: float = arena_hero.position.distance_squared_to(enemy.position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best

func _hit_enemy(enemy, damage: int) -> void:
	enemy.hp = maxi(0, enemy.hp - damage)
	enemy.queue_redraw()
	if enemy.hp == 0:
		enemy.alive = false
		enemy.respawn_left = Rules.SKELETON_RESPAWN_SECONDS
		enemy.display_seconds = ceili(enemy.respawn_left)
		enemy.queue_redraw()
		_grant_skeleton_rewards(rng.randf())
		_save()
	else:
		var original: Color = enemy.modulate
		enemy.modulate = Color("#ffffff")
		create_tween().tween_property(enemy, "modulate", original, 0.18)

func _grant_skeleton_rewards(drop_roll: float) -> void:
	state["gold"] = int(state["gold"]) + Rules.KILL_GOLD
	state["xp"] = int(state["xp"]) + Rules.KILL_XP
	state["hp"] = mini(Rules.max_hp(int(state["level"])), int(state["hp"]) + Rules.KILL_HEAL)
	var leveled := false
	while int(state["xp"]) >= Rules.xp_needed(int(state["level"])):
		state["xp"] = int(state["xp"]) - Rules.xp_needed(int(state["level"]))
		state["level"] = int(state["level"]) + 1
		state["hp"] = mini(Rules.max_hp(int(state["level"])), int(state["hp"]) + 3)
		leveled = true
	if drop_roll < Rules.DUNGEON_KEY_DROP_CHANCE:
		state["dungeon_keys"] = int(state["dungeon_keys"]) + 1
		_toast("Chave da Dungeon encontrada!  ·  Total: %d" % int(state["dungeon_keys"]))
	else:
		_toast("Nível %d!" % int(state["level"]) if leveled else "+%d ouro  ·  +%d XP" % [Rules.KILL_GOLD, Rules.KILL_XP])

func _tick_dungeon(delta: float) -> void:
	mana_left -= delta
	if mana_left <= 0.0:
		mana_left += Rules.MANA_REGEN_SECONDS
		state["mana"] = mini(Rules.HERO_MANA, int(state["mana"]) + 1)
	if int(state["hp"]) <= 0:
		death_left -= delta
		if death_left <= 0.0:
			state["hp"] = Rules.max_hp(int(state["level"]))
			death_left = Rules.HERO_RESPAWN_SECONDS
			_set_scene("skeleton")
			_toast("Derrotado pelo Rei Esqueleto. A chave foi consumida.")
			_save()
		return
	if not dungeon_boss.alive:
		return
	var to_boss: Vector2 = dungeon_boss.position - dungeon_hero.position
	if to_boss.length() > 78.0:
		dungeon_hero.position += to_boss.normalized() * minf(Rules.HERO_MOVE_SPEED * delta, to_boss.length() - 78.0)
		dungeon_hero_sprite.flip_h = to_boss.x < 0.0
	else:
		attack_left -= delta
		if attack_left <= 0.0:
			attack_left = Rules.HERO_ATTACK_SECONDS
			_hit_boss(Rules.damage(int(state["level"]), int(state["sword_level"])))
	if dungeon_boss.alive and dungeon_hero.position.distance_to(dungeon_boss.position) < 94.0:
		dungeon_boss.attack_left -= delta
		if dungeon_boss.attack_left <= 0.0:
			dungeon_boss.attack_left = Rules.BOSS_ATTACK_SECONDS
			state["hp"] = maxi(0, int(state["hp"]) - Rules.BOSS_DAMAGE)
			if int(state["hp"]) == 0:
				dungeon_hero.visible = false
				death_left = Rules.HERO_RESPAWN_SECONDS
				_toast("Espadachim derrotado na Dungeon...")

func _hit_boss(damage: int) -> void:
	if not dungeon_boss.alive:
		return
	dungeon_boss.hp = maxi(0, dungeon_boss.hp - damage)
	dungeon_boss.queue_redraw()
	if dungeon_boss.hp == 0:
		dungeon_boss.alive = false
		dungeon_boss.visible = false
		state["boss_kills"] = int(state["boss_kills"]) + 1
		_set_scene("skeleton")
		_toast("Rei Esqueleto derrotado! Vitórias: %d" % int(state["boss_kills"]))
		_save()

func _cast_skill() -> void:
	if active_scene == "village" or int(state["hp"]) <= 0:
		return
	if skill_left > 0.0:
		_toast("Golpe saltado em recarga.")
		return
	if int(state["mana"]) < Rules.SKILL_MANA_COST:
		_toast("Mana insuficiente.")
		return
	var enemy = dungeon_boss if active_scene == "dungeon" else _nearest_enemy()
	if enemy == null or not enemy.alive:
		_toast("Nenhum esqueleto disponível.")
		return
	state["mana"] = int(state["mana"]) - Rules.SKILL_MANA_COST
	skill_left = Rules.SKILL_COOLDOWN_SECONDS
	if active_scene == "dungeon":
		dungeon_hero.position = enemy.position + Vector2(-72, 10)
		_hit_boss(Rules.SKILL_DAMAGE)
	else:
		arena_hero.position = enemy.position + Vector2(-39, 10)
		_hit_enemy(enemy, Rules.SKILL_DAMAGE)
	_save()

func _enter_skeleton_world() -> void:
	panel.visible = false
	_set_scene("skeleton")
	_save()
	_toast("Combate automático iniciado.")

func _enter_dungeon() -> void:
	if int(state["dungeon_keys"]) < 1:
		_toast("Você precisa de uma Chave da Dungeon.")
		return
	state["dungeon_keys"] = int(state["dungeon_keys"]) - 1
	panel.visible = false
	dungeon_boss.reset_boss()
	dungeon_hero.position = Vector2(-215, 80)
	dungeon_hero.visible = int(state["hp"]) > 0
	_set_scene("dungeon")
	_save()
	_toast("Dungeon do Rei Esqueleto · 1 chave consumida.")

func _return_village() -> void:
	panel.visible = false
	_set_scene("village")
	_save()

func _set_scene(scene_name: String) -> void:
	active_scene = scene_name if scene_name in ["village", "skeleton", "dungeon"] else "village"
	state["scene"] = active_scene
	village.visible = active_scene == "village"
	arena.visible = active_scene == "skeleton"
	dungeon.visible = active_scene == "dungeon"
	if active_scene == "skeleton":
		arena_hero.visible = int(state["hp"]) > 0
		attack_left = 0.0
	elif active_scene == "dungeon":
		dungeon_hero.visible = int(state["hp"]) > 0
		attack_left = 0.0
	else:
		has_target = false
		pending_action = ""
	_update_hud()

func _build_ui() -> void:
	top_bar = ColorRect.new()
	top_bar.color = Color("#101d25")
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top_bar)
	brand_label = _make_label("✦  IDLE RYZE", 20, Color("#f2dfb4"))
	ui.add_child(brand_label)
	level_label = _make_label("", 18, Color("#e7bd69"))
	ui.add_child(level_label)
	for bar_name in ["hp", "mana", "xp"]:
		var background := ColorRect.new()
		background.color = Color("#25333a")
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(background)
		var fill := ColorRect.new()
		fill.color = Color("#c74962") if bar_name == "hp" else Color("#4c91d1") if bar_name == "mana" else Color("#d1a95c")
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(fill)
		var value := _make_label("", 15, Color("#fff8ed"))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		background.add_child(value)
		match bar_name:
			"hp":
				hp_background = background
				hp_fill = fill
				hp_label = value
			"mana":
				mana_background = background
				mana_fill = fill
				mana_label = value
			"xp":
				xp_background = background
				xp_fill = fill
				xp_label = value
	resources_label = _make_label("", 16, Color("#edce90"))
	ui.add_child(resources_label)
	title_plate = ColorRect.new()
	title_plate.color = Color(0.06, 0.12, 0.15, 0.78)
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_plate)
	scene_label = _make_label("", 30, Color("#f3e8d6"))
	ui.add_child(scene_label)
	hint_label = _make_label("", 13, Color("#9db9b8"))
	ui.add_child(hint_label)
	toast_label = _make_label("", 16, Color("#86f0dd"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.visible = false
	ui.add_child(toast_label)
	menu_button = _make_button("☰  Menu", _open_menu)
	menu_button.add_theme_color_override("font_color", Color("#f2dfb4"))
	interact_button = _make_button("Interagir [E]", _interact)
	skill_button = _make_button("Golpe saltado", _cast_skill)
	return_button = _make_button("Voltar à vila", _return_village)
	for direction in ["up", "left", "down", "right"]:
		var button := Button.new()
		button.text = {"up": "▲", "left": "◀", "down": "▼", "right": "▶"}[direction]
		button.button_down.connect(_set_direction.bind(direction, true))
		button.button_up.connect(_set_direction.bind(direction, false))
		ui.add_child(button)
		direction_buttons[direction] = button
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172b34")
	style.border_color = Color("#65817d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(panel)
	panel_body = VBoxContainer.new()
	panel_body.add_theme_constant_override("separation", 8)
	panel.add_child(panel_body)

func _make_label(value: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _make_button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	ui.add_child(result)
	return result

func _set_direction(direction: String, pressed: bool) -> void:
	held_directions[direction] = pressed

func _add_world_labels() -> void:
	for entry in [
		{"text": "Mercador", "position": Vector2(-315, -118)},
		{"text": "Comandante", "position": Vector2(80, -165)},
		{"text": "Portal", "position": Vector2(300, -245)}
	]:
		var text_label := _make_label(str(entry["text"]), 17, Color("#f3e8d6"))
		text_label.position = entry["position"]
		text_label.size = Vector2(120, 30)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		village.add_child(text_label)

func _layout() -> void:
	if not is_node_ready():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var window_size: Vector2 = Vector2(get_window().size)
	var compact := window_size.x < 700.0
	var interface_scale := clampf(viewport_size.x / maxf(window_size.x, 1.0) * 0.9, 1.0, 3.0) if compact else 1.0
	ui.scale = Vector2.ONE * interface_scale
	var size: Vector2 = viewport_size / interface_scale
	world.scale = Vector2.ONE * clampf(minf(viewport_size.x / 900.0, viewport_size.y / 530.0), 0.52, 1.2)
	world.position = viewport_size / 2.0 + Vector2(0, 22)
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(size.x, 150 if compact else 122)
	brand_label.position = Vector2(14, 9)
	brand_label.size = Vector2(230, 32)
	var bar_width := size.x - 32.0 if compact else 430.0
	level_label.position = Vector2(size.x - 218.0, 9) if compact else Vector2(bar_width - 80.0, 9)
	level_label.size = Vector2(80, 30)
	for entry in [
		{"background": hp_background, "fill": hp_fill, "label": hp_label, "y": 39.0},
		{"background": mana_background, "fill": mana_fill, "label": mana_label, "y": 67.0},
		{"background": xp_background, "fill": xp_fill, "label": xp_label, "y": 95.0}
	]:
		entry["background"].position = Vector2(16, entry["y"])
		entry["background"].size = Vector2(bar_width, 22)
		entry["fill"].position = Vector2.ZERO
		entry["fill"].size.y = 22
		entry["label"].position = Vector2(5, 1)
		entry["label"].size = Vector2(bar_width - 12, 20)
	resources_label.position = Vector2(16, 122) if compact else Vector2(470, 53)
	resources_label.size = Vector2(size.x - 32 if compact else maxf(200, size.x - 610), 25)
	menu_button.position = Vector2(size.x - 118, 9)
	menu_button.size = Vector2(102, 36)
	title_plate.position = Vector2(8, 160 if compact else 132)
	title_plate.size = Vector2(minf(445.0, size.x - 16.0), 80)
	scene_label.position = Vector2(16, 171 if compact else 140)
	scene_label.size = Vector2(size.x - 32, 45)
	hint_label.position = Vector2(17, 208 if compact else 180)
	hint_label.size = Vector2(size.x - 34, 30)
	toast_label.position = Vector2(12, 248 if compact else 220)
	toast_label.size = Vector2(size.x - 24, 52 if compact else 35)
	interact_button.position = Vector2(size.x - 145, size.y - 58)
	interact_button.size = Vector2(130, 43)
	skill_button.position = Vector2(12, size.y - 106) if compact else Vector2(size.x - 385, size.y - 58)
	skill_button.size = Vector2(size.x - 24, 43) if compact else Vector2(205, 43)
	return_button.position = Vector2(12, size.y - 56) if compact else Vector2(size.x - 160, size.y - 58)
	return_button.size = Vector2(size.x - 24, 43) if compact else Vector2(145, 43)
	var positions := {
		"up": Vector2(64, size.y - 112), "left": Vector2(16, size.y - 62),
		"down": Vector2(64, size.y - 62), "right": Vector2(112, size.y - 62)
	}
	for direction in direction_buttons:
		var button: Button = direction_buttons[direction]
		button.position = positions[direction]
		button.size = Vector2(45, 45)
		button.visible = compact and active_scene == "village"
	var panel_width := minf(460, size.x - 24)
	var panel_height := minf(350, size.y - 40)
	panel.position = (size - Vector2(panel_width, panel_height)) / 2.0
	panel.size = Vector2(panel_width, panel_height)
	_update_hud()

func _update_hud() -> void:
	if hp_label == null:
		return
	var max_hp: int = Rules.max_hp(int(state["level"]))
	var xp_goal: int = Rules.xp_needed(int(state["level"]))
	level_label.text = "NÍVEL %d" % int(state["level"])
	hp_label.text = "VIDA    %d / %d" % [int(state["hp"]), max_hp]
	mana_label.text = "MANA    %d / %d" % [int(state["mana"]), Rules.HERO_MANA]
	xp_label.text = "XP    %d / %d" % [int(state["xp"]), xp_goal]
	hp_fill.size.x = hp_background.size.x * clampf(float(state["hp"]) / max_hp, 0.0, 1.0)
	mana_fill.size.x = mana_background.size.x * clampf(float(state["mana"]) / Rules.HERO_MANA, 0.0, 1.0)
	xp_fill.size.x = xp_background.size.x * clampf(float(state["xp"]) / xp_goal, 0.0, 1.0)
	resources_label.text = "◆ %d OURO    CHAVES %d" % [int(state["gold"]), int(state["dungeon_keys"])]
	scene_label.text = "Vila de Ryze" if active_scene == "village" else "Mundo dos Esqueletos" if active_scene == "skeleton" else "Dungeon do Rei Esqueleto"
	hint_label.text = "WASD / setas / toque · E para interagir" if active_scene == "village" else "Farm automático · Respawn em 25 s" if active_scene == "skeleton" else "Boss: combate automático · Espaço para golpe saltado"
	interact_button.visible = active_scene == "village"
	skill_button.visible = active_scene != "village"
	return_button.visible = active_scene != "village"
	if active_scene != "village":
		skill_button.text = "Golpe saltado · %ds" % int(ceilf(skill_left)) if skill_left > 0.0 else "Golpe saltado · %d mana" % Rules.SKILL_MANA_COST
		skill_button.disabled = skill_left > 0.0 or int(state["mana"]) < Rules.SKILL_MANA_COST or int(state["hp"]) <= 0
	for direction in direction_buttons:
		direction_buttons[direction].visible = get_window().size.x < 700 and active_scene == "village"

func _clear_panel() -> void:
	for child in panel_body.get_children():
		panel_body.remove_child(child)
		child.queue_free()

func _panel_label(value: String, font_size: int = 15) -> void:
	var text_label := _make_label(value, font_size, Color("#e9ede4"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(text_label)

func _panel_button(value: String, callback: Callable, disabled := false) -> void:
	var button := Button.new()
	button.text = value
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 37)
	button.pressed.connect(callback)
	panel_body.add_child(button)

func _open_shop() -> void:
	_clear_panel()
	_panel_label("MERCADOR", 24)
	_panel_label("Aço para sua jornada e um tônico para as feridas.")
	_panel_button("Reforçar espada · %d ouro" % Rules.SWORD_COST, _buy_sword, int(state["gold"]) < Rules.SWORD_COST)
	_panel_button("Tônico de cura · %d ouro" % Rules.POTION_COST, _buy_potion, int(state["gold"]) < Rules.POTION_COST or int(state["hp"]) >= Rules.max_hp(int(state["level"])))
	_panel_label("Dano básico: %d" % Rules.damage(int(state["level"]), int(state["sword_level"])))
	_panel_button("Fechar", _close_panel)
	panel.visible = true

func _buy_sword() -> void:
	if int(state["gold"]) < Rules.SWORD_COST:
		return
	state["gold"] = int(state["gold"]) - Rules.SWORD_COST
	state["sword_level"] = int(state["sword_level"]) + 1
	_save()
	_open_shop()
	_toast("Espada reforçada!")

func _buy_potion() -> void:
	if int(state["gold"]) < Rules.POTION_COST or int(state["hp"]) >= Rules.max_hp(int(state["level"])):
		return
	state["gold"] = int(state["gold"]) - Rules.POTION_COST
	state["hp"] = mini(Rules.max_hp(int(state["level"])), int(state["hp"]) + Rules.POTION_HEAL)
	_save()
	_open_shop()
	_toast("Vida restaurada.")

func _open_commander() -> void:
	_clear_panel()
	_panel_label("COMANDANTE DO PORTAL", 23)
	_panel_label("Os esqueletos avançam além do limiar.")
	_panel_button("Entrar no Mundo dos Esqueletos", _enter_skeleton_world)
	_panel_label("Dungeon do Rei Esqueleto · %d chave(s)" % int(state["dungeon_keys"]))
	_panel_button("Usar 1 chave e enfrentar o Rei", _enter_dungeon, int(state["dungeon_keys"]) < 1)
	_panel_label("Mundo dos Centauros: planejado para nível 5.")
	_panel_button("Fechar", _close_panel)
	panel.visible = true

func _open_menu() -> void:
	_clear_panel()
	_panel_label("MENU · IDLE RYZE", 25)
	_panel_label("Nível %d  ·  Ouro %d  ·  Chaves %d" % [int(state["level"]), int(state["gold"]), int(state["dungeon_keys"])])
	_panel_button("Continuar jogando", _close_panel)
	_panel_button("Mochila e equipamentos [I]", _open_inventory)
	_panel_button("Dungeon do Rei Esqueleto · 1 chave", _enter_dungeon, int(state["dungeon_keys"]) < 1)
	if active_scene != "village":
		_panel_button("Voltar à Vila", _return_village)
	_panel_label("O farm avança enquanto o jogo está aberto.")
	panel.visible = true

func _open_inventory() -> void:
	_clear_panel()
	_panel_label("INVENTÁRIO · ESPADACHIM", 23)
	_panel_label("Arma: Espada reforçada +%d" % int(state["sword_level"]) if int(state["sword_level"]) > 0 else "Arma: Espada gasta")
	_panel_label("Capacete: vazio     Botas: vazio     Peitoral: vazio")
	_panel_label("Mochila: □  □  □  □  □  □  □  □")
	_panel_label("Chave da Dungeon do Rei Esqueleto: %d" % int(state["dungeon_keys"]))
	_panel_label("Os outros equipamentos chegam depois.")
	_panel_button("Voltar ao menu", _open_menu)
	_panel_button("Fechar", _close_panel)
	panel.visible = true

func _close_panel() -> void:
	panel.visible = false

func _toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	toast_label.visible = true
	toast_left = 2.7

func _load_save() -> void:
	var source_path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else LEGACY_SAVE_PATH
	if not FileAccess.file_exists(source_path):
		return
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if typeof(loaded) != TYPE_DICTIONARY:
		save_enabled = false
		save_warning = "Save antigo ou inválido preservado. Sessão temporária."
		return
	var legacy := source_path == LEGACY_SAVE_PATH and int(loaded.get("version", -1)) == 1
	if not legacy and int(loaded.get("version", -1)) != SAVE_VERSION:
		save_enabled = false
		save_warning = "Save de versão desconhecida preservado. Sessão temporária."
		return
	for key in ["level", "xp", "gold", "hp", "mana", "sword_level"]:
		if not loaded.has(key) or (typeof(loaded[key]) != TYPE_INT and typeof(loaded[key]) != TYPE_FLOAT):
			save_enabled = false
			save_warning = "Save incompleto preservado. Sessão temporária."
			return
	if not legacy:
		for key in ["dungeon_keys", "boss_kills"]:
			if not loaded.has(key) or (typeof(loaded[key]) != TYPE_INT and typeof(loaded[key]) != TYPE_FLOAT):
				save_enabled = false
				save_warning = "Save incompleto preservado. Sessão temporária."
				return
	var allowed_scenes := ["village", "skeleton"] if legacy else ["village", "skeleton", "dungeon"]
	if not loaded.get("scene", "") in allowed_scenes:
		save_enabled = false
		save_warning = "Save inválido preservado. Sessão temporária."
		return
	state["level"] = maxi(1, int(loaded["level"]))
	state["xp"] = maxi(0, int(loaded["xp"]))
	state["gold"] = maxi(0, int(loaded["gold"]))
	state["hp"] = clampi(int(loaded["hp"]), 0, Rules.max_hp(int(state["level"])))
	state["mana"] = clampi(int(loaded["mana"]), 0, Rules.HERO_MANA)
	state["sword_level"] = maxi(0, int(loaded["sword_level"]))
	state["dungeon_keys"] = 0 if legacy else maxi(0, int(loaded["dungeon_keys"]))
	state["boss_kills"] = 0 if legacy else maxi(0, int(loaded["boss_kills"]))
	state["scene"] = loaded["scene"]

func _save() -> void:
	if not save_enabled:
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_enabled = false
		_toast("Não foi possível salvar nesta sessão.")
		return
	file.store_string(JSON.stringify(state))
	file.close()

func _exit_tree() -> void:
	_save()
