extends SceneTree
const Game=preload("res://scripts/main.gd")
const Doc=preload("res://scripts/stage_document.gd")
var game

func _initialize() -> void: call_deferred("run")

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var dir:=ProjectSettings.globalize_path("res://").path_join("../../work").simplify_path()
	root.get_texture().get_image().save_png(dir.path_join(name+".png"))

func run() -> void:
	game=Game.new(); game.save_enabled=false
	root.add_child(game)
	game.synth.enabled=false
	game.open_editor()
	game.editor_node.reset_document(Doc.generate(1001,1))
	await snap("editor-overview")
	game.editor_node.select_object(6)
	await snap("editor-terminal")
	game.editor_node.select_object(9)
	await snap("editor-bug")
	game.editor_node.test_document()
	await create_timer(3).timeout
	game.set_process(false)
	await snap("editor-playtest")
	game.show_screen("map")
	await snap("editor-locked-chapters")
	quit()
