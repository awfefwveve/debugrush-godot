extends SceneTree
const Doc=preload("res://scripts/stage_document.gd")
const Game=preload("res://scripts/main.gd")
var checks:=0
var failures:=0

func _initialize() -> void: call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL "+caption)

func run() -> void:
	var base:=Doc.base()
	check(Doc.validate(base).is_empty(),"base passes: %s"%[Doc.validate(base)])
	for seed_value in range(12):
		for difficulty in range(3):
			var generated:=Doc.generate(seed_value,difficulty)
			check(Doc.validate(generated).is_empty(),"seed %d difficulty %d: %s"%[seed_value,difficulty,Doc.validate(generated)])
			check(JSON.stringify(generated)==JSON.stringify(Doc.generate(seed_value,difficulty)),"seed deterministic")
	var wrong:=base.duplicate(true)
	wrong.chapter=2
	check(not Doc.validate(wrong).is_empty(),"chapter two documents rejected")
	check(not Doc.validate({}).is_empty(),"malformed document rejected")
	wrong=base.duplicate(true); wrong.objects[0].pos=[-100,20]
	check(not Doc.validate(wrong).is_empty(),"out of bounds rejected")
	wrong=base.duplicate(true); wrong.objects[6].orders=[[11]]
	check(not Doc.validate(wrong).is_empty(),"sludge request rejected")
	wrong=base.duplicate(true); wrong.objects[2].material=1
	check(not Doc.validate(wrong).is_empty(),"duplicate/missing resource rejected")
	wrong=base.duplicate(true); wrong.objects[0].pos=wrong.objects[1].pos.duplicate()
	check(not Doc.validate(wrong).is_empty(),"blocked spawn rejected")
	wrong=base.duplicate(true)
	wrong.objects=wrong.objects.filter(func(o): return o.kind!="bug")
	for x in range(16,865,32): wrong.objects.append(Doc.new_object("wall",Vector2(x,288)))
	check(Doc.validate(wrong).any(func(e): return "접근" in e),"closed route rejected")
	var game=Game.new()
	game.save_enabled=false
	game.save_path="user://editor_integration_save.json"
	root.add_child(game)
	game.set_process(false); game.synth.enabled=false
	game.unlocked=30
	game.show_screen("map")
	check(game.buttons[2].disabled and game.buttons[3].disabled,"chapters locked even with old completed save")
	game.start_stage(1,0)
	check(game.mode=="map","direct chapter2 start blocked")
	game.start_stage(0,9)
	game.finish(true)
	check(game.unlocked==10,"chapter1 win cannot unlock chapter2")
	check(not game.buttons.any(func(b): return b.text=="다음 스테이지   →"),"no next chapter bypass")
	game.open_editor()
	var editor=game.editor_node
	editor.reset_document(base)
	editor.tool="wall"
	editor.place_object(Vector2(190,240))
	check(editor.document.objects.back().pos==[176,240],"wall placement snaps to tile centers")
	var count: int=editor.document.objects.size()
	editor.undo()
	check(editor.document.objects.size()==count-1,"undo placement")
	editor.redo()
	check(editor.document.objects.size()==count,"redo placement")
	editor.tool="source"; editor.material_id=0
	editor.place_object(Vector2(180,64))
	check(editor.document.objects.size()==count,"unique material moved, not duplicated")
	editor.reset_document(base)
	editor.select_object(6)
	editor.set_round_count(3)
	editor.set_order(2,1,3)
	check(editor.document.objects[6].orders[2]==[5,3],"inspector multi-item round")
	editor.write_file("user://editor_test_stage.json")
	var loaded:=Doc.load_file("user://editor_test_stage.json")
	check(loaded.has("document") and loaded.document==editor.document,"JSON round trip")
	var before_records: Dictionary=game.records.duplicate(true)
	var before_achievements: Dictionary=game.achievements.duplicate(true)
	var before_unlock: int=game.unlocked
	game.start_custom_stage(loaded.document)
	check(game.is_custom and game.mode=="play" and not editor.visible,"designer play launch")
	check(game.bench_pos==Doc.position_of(base.objects[1])+Doc.OFFSET,"custom bench position")
	check(game.source_positions[0]==Doc.position_of(base.objects[2])+Doc.OFFSET,"custom resource position")
	game.enemies.clear()
	# Use real gameplay pickup/craft/delivery paths for every custom order.
	for t in game.terminals:
		while not t.done:
			var order: Array=t.orders[t.round].duplicate()
			for id in order:
				var materials: Array=[id] if id<4 else Game.Data.pair_for(id)
				for material_id in materials:
					game.player=game.source_positions[int(material_id)]+Vector2(0,65 if material_id in [0,2] else -65)
					game.interact()
				if id>=4:
					game.player=game.bench_pos+Vector2(0,70)
					game.interact()
					for i in range(100): game.update_game(0.025)
					game.interact()
				game.player=t.p+Vector2(65 if t.p.x<400 else -65,0)
				game.interact()
			check(t.upload>0,"custom requested item uploaded")
			if t.upload<=0: break
			for i in range(46): game.update_game(0.025)
	check(game.mode=="result" and game.victory,"custom stage completes")
	check(game.records==before_records and game.achievements==before_achievements and game.unlocked==before_unlock,"custom win does not touch campaign")
	game.retry_current()
	check(game.is_custom and game.mode=="play" and game.terminals[0].round==0,"retry resets same document")
	game.return_to_selection()
	check(game.mode=="editor" and editor.visible and editor.document==loaded.document,"return preserves document")
	var generated:=Doc.generate(66,2)
	game.start_custom_stage(generated)
	game.fire_pattern(0)
	check(game.bullets.size()>0,"custom pattern fires")
	game.walls.clear()
	game.walls.append(Rect2(game.player-Vector2(16,16),Vector2(32,32)))
	game.bullets=[{"p":game.player,"v":Vector2.ZERO,"pink":false,"owner":0,"life":1.0}]
	game.update_bullets(0.01)
	check(game.bullets.is_empty() and game.hp==5,"wall absorbs projectile before hit")
	var bank=Game.ArtBank.new()
	var art_dir:=ProjectSettings.globalize_path("user://art_test")
	DirAccess.make_dir_recursive_absolute(art_dir)
	var valid_png:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	valid_png.fill(Color.CORAL)
	valid_png.save_png(art_dir.path_join("wall.png"))
	valid_png.save_png(art_dir.path_join("player_idle.png"))
	bank.reload(art_dir)
	check(bank.textures.has("wall"),"correct-size art loaded")
	check(not bank.textures.has("player_idle") and bank.warnings.size()==1,"wrong-size art rejected with warning")
	check(bank.specs.size()==50,"art manifest covers 50 vector slots")
	var svg_file:=FileAccess.open(art_dir.path_join("wall.svg"),FileAccess.WRITE)
	svg_file.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><rect width="32" height="32" fill="#ffffff"/></svg>')
	svg_file.close()
	bank.reload(art_dir)
	check(bank.textures.wall.get_width()==128,"SVG preferred and rasterized at 4x")
	DirAccess.remove_absolute(art_dir.path_join("wall.svg"))
	check(Game.ArtBank.wall_variant(Vector2.ZERO,[Vector2.UP*32,Vector2.RIGHT*32])[0]=="wall_corner","wall corner chosen")
	check(Game.ArtBank.wall_variant(Vector2.ZERO,[Vector2.UP*32,Vector2.DOWN*32])[0]=="wall_straight","wall straight chosen")
	var decorated:=Doc.generate(19,0)
	check(Doc.structural_errors(JSON.parse_string(JSON.stringify(decorated))).is_empty(),"background JSON numbers round trip")
	var decor:=Doc.new_object("background",Doc.position_of(decorated.objects[0]))
	decorated.objects.append(decor)
	check(Doc.validate(decorated).is_empty(),"background has no collision with spawn")
	decor.rotation=45
	check(not Doc.validate(decorated).is_empty(),"invalid background rotation rejected")
	DirAccess.remove_absolute(art_dir.path_join("wall.png"))
	DirAccess.remove_absolute(art_dir.path_join("player_idle.png"))
	DirAccess.remove_absolute("user://editor_test_stage.json")
	game.queue_free()
	await process_frame
	print("EDITOR CHECKS %d / FAILURES %d"%[checks,failures])
	quit(0 if failures==0 else 1)
