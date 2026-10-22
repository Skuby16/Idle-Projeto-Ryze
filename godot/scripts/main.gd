extends Control

const Rules = preload("res://godot/scripts/game_rules.gd")
const Skeleton = preload("res://godot/scripts/skeleton.gd")
const SAVE_PATH := "user://idle_ryze_godot_v1.json"
const SAVE_VERSION := 1

@onready var world: Node2D = $World
@onready var village: Node2D = $World/Village
@onready var village_hero: Node2D = $World/Village/Hero
@onready var village_hero_sprite: Sprite2D = $World/Village/Hero/Sprite
@onready var portal: Sprite2D = $World/Village/Portal
@onready var arena: Node2D = $World/SkeletonWorld
@onready var arena_hero: Node2D = $World/SkeletonWorld/Hero
@onready var arena_hero_sprite: Sprite2D = $World/SkeletonWorld/Hero/Sprite
@onready var ui: Control = $HUD/UI

var state: Dictionary = {
	"version": SAVE_VERSION, "level": 1, "xp": 0, "gold": 0,
	"hp": Rules.HERO_HP, "mana": Rules.HERO_MANA, "sword_level": 0,
	"scene": "village"
}
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
var status_label: Label
var scene_label: Label
var hint_label: Label
var toast_label: Label
var inventory_button: Button
var interact_button: Button
var skill_button: Button
var return_button: Button
var direction_buttons: Dictionary = {}
var panel: PanelContainer
var panel_body: VBoxContainer

func _ready() -> void:
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
	if active_scene == "village":
		_tick_village(delta)
	else:
		_tick_combat(delta)
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
	elif event.keycode == KEY_I:
		_open_inventory()
	elif event.keycode == KEY_E and active_scene == "village":
		_interact()
	elif event.keycode == KEY_SPACE and active_scene == "skeleton":
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
		enemy.queue_redraw()
		state["gold"] = int(state["gold"]) + Rules.KILL_GOLD
		state["xp"] = int(state["xp"]) + Rules.KILL_XP
		state["hp"] = mini(Rules.max_hp(int(state["level"])), int(state["hp"]) + Rules.KILL_HEAL)
		var leveled := false
		while int(state["xp"]) >= Rules.xp_needed(int(state["level"])):
			state["xp"] = int(state["xp"]) - Rules.xp_needed(int(state["level"]))
			state["level"] = int(state["level"]) + 1
			state["hp"] = mini(Rules.max_hp(int(state["level"])), int(state["hp"]) + 3)
			leveled = true
		_toast("Nível %d!" % int(state["level"]) if leveled else "+%d ouro  ·  +%d XP" % [Rules.KILL_GOLD, Rules.KILL_XP])
		_save()
	else:
		var original: Color = enemy.modulate
		enemy.modulate = Color("#ffffff")
		create_tween().tween_property(enemy, "modulate", original, 0.18)

func _cast_skill() -> void:
	if active_scene != "skeleton" or int(state["hp"]) <= 0:
		return
	if skill_left > 0.0:
		_toast("Golpe saltado em recarga.")
		return
	if int(state["mana"]) < Rules.SKILL_MANA_COST:
		_toast("Mana insuficiente.")
		return
	var enemy = _nearest_enemy()
	if enemy == null:
		_toast("Nenhum esqueleto disponível.")
		return
	state["mana"] = int(state["mana"]) - Rules.SKILL_MANA_COST
	skill_left = Rules.SKILL_COOLDOWN_SECONDS
	arena_hero.position = enemy.position + Vector2(-39, 10)
	_hit_enemy(enemy, Rules.SKILL_DAMAGE)
	_save()

func _enter_skeleton_world() -> void:
	panel.visible = false
	_set_scene("skeleton")
	_save()
	_toast("Combate automático iniciado.")

func _return_village() -> void:
	panel.visible = false
	_set_scene("village")
	_save()

func _set_scene(scene_name: String) -> void:
	active_scene = scene_name if scene_name == "skeleton" else "village"
	state["scene"] = active_scene
	village.visible = active_scene == "village"
	arena.visible = active_scene == "skeleton"
	if active_scene == "skeleton":
		arena_hero.visible = int(state["hp"]) > 0
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
	brand_label = _make_label("✦  IDLE RYZE 2.0", 20, Color("#f2dfb4"))
	ui.add_child(brand_label)
	status_label = _make_label("", 15, Color("#e9ede4"))
	ui.add_child(status_label)
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
	toast_label.visible = false
	ui.add_child(toast_label)
	inventory_button = _make_button("Mochila [I]", _open_inventory)
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
	var interface_scale := clampf(viewport_size.x / maxf(window_size.x, 1.0) * 0.8, 1.0, 3.0) if compact else 1.0
	ui.scale = Vector2.ONE * interface_scale
	var size: Vector2 = viewport_size / interface_scale
	world.scale = Vector2.ONE * clampf(minf(viewport_size.x / 900.0, viewport_size.y / 530.0), 0.52, 1.2)
	world.position = viewport_size / 2.0 + Vector2(0, 22)
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(size.x, 84 if compact else 66)
	brand_label.position = Vector2(14, 9)
	brand_label.size = Vector2(270, 32)
	status_label.position = Vector2(14 if compact else 335, 47 if compact else 21)
	status_label.size = Vector2(size.x - 25 if compact else maxf(300, size.x - 500), 27)
	title_plate.position = Vector2(8, 85 if compact else 77)
	title_plate.size = Vector2(minf(445.0, size.x - 16.0), 80)
	scene_label.position = Vector2(16, 99 if compact else 82)
	scene_label.size = Vector2(size.x - 32, 45)
	hint_label.position = Vector2(17, 138 if compact else 125)
	hint_label.size = Vector2(size.x - 34, 30)
	toast_label.position = Vector2(size.x * 0.25, 170 if compact else 110)
	toast_label.size = Vector2(size.x * 0.5, 35)
	inventory_button.position = Vector2(size.x - 132, 12)
	inventory_button.size = Vector2(116, 39)
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
	panel.position = (size - Vector2(panel_width, 310)) / 2.0
	panel.size = Vector2(panel_width, 310)
	_update_hud()

func _update_hud() -> void:
	if status_label == null:
		return
	status_label.text = "NV %d    VIDA %d/%d    MANA %d/%d    XP %d/%d    ◆ %d" % [
		int(state["level"]), int(state["hp"]), Rules.max_hp(int(state["level"])),
		int(state["mana"]), Rules.HERO_MANA, int(state["xp"]),
		Rules.xp_needed(int(state["level"])), int(state["gold"])
	]
	scene_label.text = "Vila de Ryze" if active_scene == "village" else "Mundo dos Esqueletos"
	hint_label.text = "WASD / setas / toque para mover · E para interagir" if active_scene == "village" else "Combate automático · Espaço para golpe saltado"
	interact_button.visible = active_scene == "village"
	skill_button.visible = active_scene == "skeleton"
	return_button.visible = active_scene == "skeleton"
	if active_scene == "skeleton":
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
	_panel_label("Mundo dos Centauros: planejado para nível 5.")
	_panel_button("Fechar", _close_panel)
	panel.visible = true

func _open_inventory() -> void:
	_clear_panel()
	_panel_label("INVENTÁRIO · ESPADACHIM", 23)
	_panel_label("Arma: Espada reforçada +%d" % int(state["sword_level"]) if int(state["sword_level"]) > 0 else "Arma: Espada gasta")
	_panel_label("Capacete: vazio     Botas: vazio     Peitoral: vazio")
	_panel_label("Mochila: □  □  □  □  □  □  □  □")
	_panel_label("Os outros equipamentos chegam depois.")
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
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(loaded) != TYPE_DICTIONARY or int(loaded.get("version", -1)) != SAVE_VERSION:
		save_enabled = false
		save_warning = "Save antigo ou inválido preservado. Sessão temporária."
		return
	for key in ["level", "xp", "gold", "hp", "mana", "sword_level"]:
		if not loaded.has(key) or (typeof(loaded[key]) != TYPE_INT and typeof(loaded[key]) != TYPE_FLOAT):
			save_enabled = false
			save_warning = "Save incompleto preservado. Sessão temporária."
			return
	if loaded.get("scene", "") != "village" and loaded.get("scene", "") != "skeleton":
		save_enabled = false
		save_warning = "Save inválido preservado. Sessão temporária."
		return
	state["level"] = maxi(1, int(loaded["level"]))
	state["xp"] = maxi(0, int(loaded["xp"]))
	state["gold"] = maxi(0, int(loaded["gold"]))
	state["hp"] = clampi(int(loaded["hp"]), 0, Rules.max_hp(int(state["level"])))
	state["mana"] = clampi(int(loaded["mana"]), 0, Rules.HERO_MANA)
	state["sword_level"] = maxi(0, int(loaded["sword_level"]))
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
