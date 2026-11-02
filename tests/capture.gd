extends SceneTree
const Game = preload("res://scripts/main.gd")
var game

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output_dir:=ProjectSettings.globalize_path("res://").path_join("../../work").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))

func run() -> void:
	game=Game.new()
	game.save_enabled=false
	root.add_child(game)
	game.synth.enabled=false
	await snap("menu")
	game.unlocked=30
	game.show_screen("map")
	await snap("map")
	game.start_stage(0,0)
	await snap("story")
	game.show_screen("help")
	await snap("help")
	game.show_screen("settings")
	await snap("settings")
	game.start_stage(2,9)
	game.mode="play"
	game.clear_buttons()
	game.inventory=[5,3]
	await create_timer(5.0).timeout
	game.set_process(false)
	game.invulnerable=0
	await snap("gameplay")
	game.show_screen("pause")
	await snap("pause")
	game.finish(true)
	await snap("result")
	game.show_screen("achievements")
	await snap("achievements")
	quit()
