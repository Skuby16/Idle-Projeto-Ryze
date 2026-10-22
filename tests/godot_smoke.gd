extends SceneTree

const MAIN_SCENE = preload("res://godot/scenes/main.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_assert(game.active_scene == "village", "A Vila deve ser a cena inicial")
	_assert(game.village_hero_sprite.texture != null, "O Espadachim deve carregar")
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
	_assert(int(game.state["gold"]) > 0, "O combate Idle deve recompensar o jogador")
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
	_assert(save_data is Dictionary and int(save_data["version"]) == 1, "O save deve conter versão")
	_assert(int(save_data["gold"]) == gold_before, "O save deve manter o ouro")
	if failures == 0:
		print("Godot smoke: vila, controles, NPCs, portal, combate, retorno e save OK")
	quit(0 if failures == 0 else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
