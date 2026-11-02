extends SceneTree
## Integration tests exercise the actual game scene and delivery/crafting paths.
const Game = preload("res://scripts/main.gd")
const Data = preload("res://scripts/game_data.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+message)

func tick(seconds: float) -> void:
	for i in range(int(ceil(seconds/0.025))):
		game.update_game(0.025)

func pickup(id: int) -> void:
	game.player=Game.SOURCES[id]+Vector2(0,65 if id in [0,2] else -65)
	game.interact()

func walk_to(target: Vector2) -> void:
	var count:=0
	while game.player.distance_to(target)>6 and count<1200:
		var delta: Vector2=target-game.player
		for action in ["left","right","up","down"]: Input.action_release(action)
		if absf(delta.x)>4: Input.action_press("right" if delta.x>0 else "left")
		if absf(delta.y)>4: Input.action_press("down" if delta.y>0 else "up")
		game.update_game(0.016)
		count+=1
	for action in ["left","right","up","down"]: Input.action_release(action)
	check(count<1200,"walkable route to %s"%target)

func craft(id: int) -> void:
	var pair=Data.pair_for(id)
	pickup(pair[0])
	pickup(pair[1])
	game.player=Game.BENCH+Vector2(0,70)
	game.interact()
	check(game.craft_remaining>0,"craft timer starts")
	tick(2.4)
	check(game.craft_ready==id,"correct recipe output %d"%id)
	game.interact()
	check(game.inventory.has(id),"crafted item collected")

func run() -> void:
	game=Game.new()
	game.save_enabled=false
	game.save_path="user://debug_rush_test_save.json"
	root.add_child(game)
	game.set_process(false)
	game.synth.enabled=false
	game.synth.music_enabled=false
	check(Data.combine(0,1)==5 and Data.combine(1,0)==5,"recipes are commutative")
	check(Data.combine(0,2)==11 and Data.combine(3,3)==11,"invalid combinations yield sludge")
	game.start_stage(0,0)
	game.mode="play"
	game.enemies.clear()
	pickup(0)
	pickup(0)
	pickup(1)
	check(game.inventory==[0,0],"inventory capped at two")
	game.inventory.clear()
	game.player=Game.BENCH+Vector2(0,70)
	game.inventory=[0]
	game.interact()
	check(game.craft_slots==[0] and game.inventory.is_empty(),"single ingredient stored")
	game.inventory=[1]
	game.interact()
	tick(2.4)
	check(game.craft_ready==5,"sequential ingredient deposit")
	game.inventory=[2,3]
	game.interact()
	check(game.craft_ready==5 and game.inventory==[2,3],"full bag preserves finished craft")
	game.inventory.clear()
	game.interact()
	game.player=Game.TERMINAL_POS[0]+Vector2(55,0)
	game.interact()
	check(game.inventory==[5] and game.terminals[0].upload==0,"wrong delivery does not consume item")
	game.start_stage(0,4)
	game.enemies.clear()
	game.terminals[0].orders=[[5,0]]
	game.inventory=[5]
	game.deliver(0)
	check(game.terminals[0].orders[0]==[0] and game.terminals[0].upload==0,"partial two-item delivery")
	game.inventory=[0]
	game.deliver(0)
	check(game.terminals[0].upload>0,"second requirement starts upload")
	tick(1.2)
	check(game.terminals[0].done,"upload completes terminal")
	game.start_stage(0,0)
	game.player=Vector2(484,500)
	game.bullets=[{"p":game.player,"v":Vector2.ZERO,"pink":true,"owner":0,"life":2.0}]
	game.jump=0.4
	game.update_bullets(0.01)
	check(game.parries==1 and game.hp==5 and game.enemies[0].stun>3,"pink jump parry stuns source")
	game.invulnerable=0
	game.jump=0.4
	game.bullets=[{"p":game.player,"v":Vector2.ZERO,"pink":false,"owner":0,"life":2.0}]
	game.update_bullets(0.01)
	check(game.hp==4,"jump does not bypass normal bullets")
	game.take_hit()
	check(game.hp==4,"post-hit invulnerability")
	game.invulnerable=0
	game.dash=0.1
	game.bullets=[{"p":game.player,"v":Vector2.ZERO,"pink":false,"owner":0,"life":2.0}]
	game.update_bullets(0.01)
	check(game.hp==4,"dash evades bullets")
	game.start_stage(0,0)
	game.enemies.clear()
	game.player=Game.BENCH+Vector2(0,90)
	Input.action_press("up")
	tick(0.5)
	Input.action_release("up")
	check(game.player.y>=Game.BENCH.y+42,"workbench collision")
	var previous: float=game.time_left
	game.mode="pause"
	game._process(1.0)
	check(game.time_left==previous,"pause freezes timer")
	game.mode="help"
	game._process(1.0)
	check(game.time_left==previous,"recipe screen freezes timer")
	game.start_stage(0,0)
	game.enemies.clear()
	game.time_left=0.001
	game.update_game(0.02)
	check(game.mode=="result" and not game.victory,"timeout failure")
	game.start_stage(0,0)
	game.enemies.clear()
	game.hp=0
	game.update_game(0.02)
	check(game.mode=="result" and not game.victory,"health failure")
	# First stage using movement actions rather than position warps.
	game.start_stage(0,0)
	game.mode="play"
	game.enemies.clear()
	walk_to(Vector2(270,516))
	walk_to(Vector2(270,270))
	game.interact()
	walk_to(Vector2(163,314))
	game.interact()
	tick(1.2)
	walk_to(Vector2(270,270))
	game.interact()
	walk_to(Vector2(370,270))
	walk_to(Vector2(370,530))
	walk_to(Vector2(698,530))
	game.interact()
	walk_to(Vector2(560,530))
	walk_to(Vector2(484,473))
	game.interact()
	tick(2.4)
	game.interact()
	walk_to(Vector2(800,490))
	game.interact()
	tick(1.2)
	check(game.victory and game.mode=="result","first stage completes through movement and interactions")
	# Solve all authored orders through actual pickups, workbench and terminals.
	for c in range(1):
		for n in range(10):
			game.start_stage(c,n)
			game.mode="play"
			game.enemies.clear()
			for t in range(game.terminals.size()):
				while not game.terminals[t].done:
					var order=game.terminals[t].orders[game.terminals[t].round].duplicate()
					for id in order:
						if id<4: pickup(id)
						else: craft(id)
						game.player=Game.TERMINAL_POS[t]+Vector2(60 if t in [0,3] else -60,0)
						game.interact()
					check(game.terminals[t].upload>0,"stage %d-%d upload"%[c,n])
					tick(1.15)
			check(game.victory and game.mode=="result","stage %d-%d complete"%[c,n])
			check(game.inventory.is_empty(),"delivery consumed inventory")
	check(game.unlocked==10,"campaign unlocks ten stages; future chapters stay locked")
	check(game.achievements.has("chapter1"),"graduation achievement")
	# Simulate the last available campaign pattern for 20 seconds to exercise enemy/bullet lifetimes.
	game.start_stage(0,9)
	game.mode="play"
	game.hp=999
	tick(20)
	check(game.bullets.size()<=220 and game.bullets.size()>0,"bounded hard-mode projectile simulation")
	game.save_enabled=true
	game.save_progress()
	var loaded=Game.new()
	loaded.save_enabled=false
	loaded.save_path=game.save_path
	root.add_child(loaded)
	loaded.synth.enabled=false
	loaded.set_process(false)
	check(loaded.unlocked==10 and loaded.records.size()==10,"save/load retains whole campaign")
	check(loaded.achievements.has("chapter1"),"save/load retains achievements")
	DirAccess.remove_absolute(game.save_path)
	loaded.queue_free()
	print("CHECKS: %d / FAILURES: %d"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
