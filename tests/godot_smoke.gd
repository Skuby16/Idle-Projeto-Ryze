extends SceneTree

const MAIN_SCENE = preload("res://godot/scenes/main.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var legacy_file := FileAccess.open("user://idle_ryze_godot_v1.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({
		"version": 1, "level": 1, "xp": 0, "gold": 7,
		"hp": 28, "mana": 30, "sword_level": 0, "scene": "village"
	}))
	legacy_file.close()
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_assert(game.active_scene == "village", "A Vila deve ser a cena inicial")
	_assert(int(game.state["gold"]) == 7, "O save v1 deve ser migrado sem perder ouro")
	_assert(int(game.state["dungeon_keys"]) == 0, "A migração inicia sem chaves")
	_assert(game.village_hero_sprite.texture != null, "O Espadachim deve carregar")
	_assert(game.hp_label.text.begins_with("VIDA") and game.xp_label.text.begins_with("XP"), "A HUD deve mostrar vida e XP")
	_assert(game.menu_button.text.contains("Menu"), "O menu deve aparecer no canto superior")
	_assert(game.direction_buttons.size() == 4, "O direcional de toque deve existir")
	var up_button: Button = game.direction_buttons["up"]
	up_button.button_down.emit()
	_assert(game.held_directions.get("up") == true, "O botão de toque deve pressionar a direção")
	up_button.button_up.emit()
	_assert(game.held_directions.get("up") == false, "O botão de toque deve soltar a direção")
	game.village_hero.position = Vector2(-260, 5)
	game._interact()
	_assert(game.panel.visible, "O Mercador deve abrir a loja")
	game._close_panel()
	game.village_hero.position = Vector2(140, -45)
	game._interact()
	_assert(game.panel.visible, "O Comandante deve abrir o diálogo")
	game._enter_skeleton_world()
	_assert(game.active_scene == "skeleton", "O portal deve abrir o Mundo dos Esqueletos")
	for index in range(140):
		game._tick_combat(0.1)
	_assert(int(game.state["gold"]) > 7, "O combate Idle deve recompensar o jogador")
	var enemy = game.enemies[0]
	if not enemy.alive:
		enemy.alive = true
		enemy.hp = 30
	game._hit_enemy(enemy, enemy.hp)
	_assert(enemy.respawn_left == 25.0, "O esqueleto deve iniciar 25 s de respawn")
	game.state["hp"] = 0
	game.death_left = 1000.0
	game._tick_combat(24.9)
	_assert(not enemy.alive, "O esqueleto não deve reviver antes dos 25 s")
	game._tick_combat(0.2)
	_assert(enemy.alive and enemy.hp == 30, "O esqueleto deve reviver após 25 s")
	game.state["hp"] = 28
	game.death_left = 3.0
	var keys_before: int = int(game.state["dungeon_keys"])
	game._grant_skeleton_rewards(0.0999)
	_assert(int(game.state["dungeon_keys"]) == keys_before + 1, "Chance abaixo de 10% deve dar chave")
	game._grant_skeleton_rewards(0.10)
	_assert(int(game.state["dungeon_keys"]) == keys_before + 1, "Chance em 10% não deve dar chave")
	game.menu_button.pressed.emit()
	_assert(game.panel.visible, "O menu deve abrir")
	var keys_for_boss: int = int(game.state["dungeon_keys"])
	game._enter_dungeon()
	_assert(game.active_scene == "dungeon", "A chave deve abrir a Dungeon")
	_assert(int(game.state["dungeon_keys"]) == keys_for_boss - 1, "A entrada deve consumir uma chave")
	game.dungeon_hero.position = game.dungeon_boss.position + Vector2(-70, 0)
	game._tick_dungeon(0.1)
	_assert(game.dungeon_boss.hp < 100, "O Espadachim deve atacar o boss automaticamente")
	game._hit_boss(999)
	_assert(game.active_scene == "skeleton" and int(game.state["boss_kills"]) == 1, "Derrotar o Rei deve encerrar a Dungeon")
	_assert(int(game.state["dungeon_keys"]) == keys_for_boss - 1, "Boss não deve gerar chaves")
	game.state["dungeon_keys"] = 1
	game._enter_dungeon()
	game.state["hp"] = 0
	game.death_left = 0.1
	game._tick_dungeon(0.2)
	_assert(game.active_scene == "skeleton" and int(game.state["dungeon_keys"]) == 0, "Perder o boss deve consumir a chave e retornar ao farm")
	var gold_before: int = int(game.state["gold"])
	game._return_village()
	_assert(game.active_scene == "village", "O botão deve retornar à Vila")
	root.size = Vector2i(390, 844)
	game._layout()
	_assert(game.ui.scale.x > 1.0, "A interface deve crescer na janela estreita")
	_assert(up_button.visible, "O direcional deve aparecer na janela estreita")
	game._set_scene("skeleton")
	game._layout()
	_assert(game.skill_button.position.y < game.return_button.position.y, "Os botões mobile não devem se sobrepor")
	game._return_village()
	game._save()
	_assert(FileAccess.file_exists(game.SAVE_PATH), "O save versionado deve existir")
	var save_data = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	_assert(save_data is Dictionary and int(save_data["version"]) == 2, "O save deve conter versão 2")
	_assert(int(save_data["gold"]) == gold_before, "O save deve manter o ouro")
	_assert(int(save_data["boss_kills"]) == 1, "O save deve manter a vitória na Dungeon")
	_assert(FileAccess.file_exists(game.LEGACY_SAVE_PATH), "A migração deve preservar o save v1")
	game.queue_free()
	await process_frame
	var invalid_text := "{\"version\":99,\"gold\":999}"
	var invalid_file := FileAccess.open("user://idle_ryze_godot_v2.json", FileAccess.WRITE)
	invalid_file.store_string(invalid_text)
	invalid_file.close()
	var guarded = MAIN_SCENE.instantiate()
	root.add_child(guarded)
	await process_frame
	_assert(not guarded.save_enabled, "Versão desconhecida deve impedir sobrescrita")
	guarded._save()
	_assert(FileAccess.get_file_as_string(guarded.SAVE_PATH) == invalid_text, "Save desconhecido deve permanecer intacto")
	if failures == 0:
		print("Godot smoke: farm, respawn 25 s, chave 10%, boss, HUD, menu, migração e save OK")
	quit(0 if failures == 0 else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
