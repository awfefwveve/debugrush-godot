extends Node2D
## A complete scene-driven campaign. Positions use a fixed 1280 x 800 canvas.
const Data = preload("res://scripts/game_data.gd")
const Synth = preload("res://scripts/synth.gd")
const StageDoc = preload("res://scripts/stage_document.gd")
const StageEditor = preload("res://scripts/stage_editor.gd")
const ArtBank = preload("res://scripts/art_bank.gd")
const BG = Color("080f1c")
const PANEL = Color("101e30")
const INK = Color("e6f0ff")
const MUTED = Color("879bb6")
const PINK = Color("ff7dca")
const RED = Color("ff6e7d")
const GOLD = Color("ffcc79")
const GREEN = Color("65edcc")
const MAT_COLORS = [Color("ffcd78"), Color("71c7ff"), Color("c5a0ff"), Color("65edcc")]
const ARENA = Rect2(48, 152, 872, 500)
const BENCH = Vector2(484, 402)
const SOURCES = [Vector2(270,206), Vector2(698,598), Vector2(698,206), Vector2(270,598)]
const TERMINAL_POS = [Vector2(101,314), Vector2(867,490), Vector2(867,314), Vector2(101,490)]
const SAVE = "user://debug_rush_save.json"

var font: Font
var synth: Node
var ui: Control
var mode := "menu"
var return_mode := "menu"
var buttons: Array[Button] = []
var chapter := 0
var level := 0
var map_chapter := 0
var unlocked := 0
var records: Dictionary = {}
var achievements: Dictionary = {}
var clock := 0.0
var toast := ""
var toast_time := 0.0
var player := Vector2(484,520)
var facing := Vector2.DOWN
var hp := 5
var time_left := 180.0
var elapsed := 0.0
var hits := 0
var parries := 0
var score := 0
var combo := 0
var combo_time := 0.0
var invulnerable := 0.0
var jump := 0.0
var jump_cd := 0.0
var dash := 0.0
var dash_cd := 0.0
var dash_direction := Vector2.DOWN
var inventory: Array = []
var craft_slots: Array = []
var craft_remaining := 0.0
var craft_ready := -1
var terminals: Array = []
var enemies: Array = []
var bullets: Array = []
var particles: Array = []
var floaters: Array = []
var stage_config: Dictionary = {}
var rng := RandomNumberGenerator.new()
var wave_index := 0
var flash := 0.0
var shake := 0.0
var reduced_motion := false
var assist := false
var victory := false
var fail_reason := ""
var tutorial := 0
var save_enabled := true
var save_path := SAVE
var bench_pos := BENCH
var source_positions: Array = SOURCES.duplicate()
var walls: Array[Rect2] = []
var background_modules: Array=[]
var is_custom := false
var custom_document: Dictionary = {}
var stage_title := ""
var stage_intro := ""
var editor_node: Control
var art = ArtBank.new()


func _ready() -> void:
	art.reload()
	if ResourceLoader.exists("res://assets/NotoSansKR-Medium.ttf"):
		font = load("res://assets/NotoSansKR-Medium.ttf")
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
		font = system_font
	synth = Synth.new()
	add_child(synth)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	load_progress()
	make_inputs()
	show_screen("menu")
	if "--verify-build" in OS.get_cmdline_user_args():
		save_enabled = false
		call_deferred("verify_distribution")
	elif "--verify-editor" in OS.get_cmdline_user_args():
		save_enabled=false
		call_deferred("verify_editor_distribution")

func verify_editor_distribution() -> void:
	synth.enabled=false
	open_editor()
	editor_node.reset_document(StageDoc.generate(2026,1))
	editor_node.write_file("user://stages/release_check.json")
	var loaded:=StageDoc.load_file("user://stages/release_check.json")
	if not loaded.has("document") or not StageDoc.validate(loaded.document).is_empty():
		printerr("EDITOR_BUILD_FAILED: stage round trip")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://release-editor.png")
	start_custom_stage(loaded.document)
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://release-custom.png")
	return_to_selection()
	if mode!="editor" or not editor_node.visible:
		printerr("EDITOR_BUILD_FAILED: return to editor")
		get_tree().quit(1)
		return
	print("EDITOR_BUILD_OK: generate / save / load / validate / play / return")
	get_tree().quit()

func verify_distribution() -> void:
	# Optional release smoke check: normal double-click launches never enter this.
	synth.enabled = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://build-menu.png")
	start_stage(0, 0)
	mode = "play"
	clear_buttons()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://build-game.png")
	print("STANDALONE_BUILD_OK: embedded scene, Korean font, gameplay rendered")
	get_tree().quit()

func make_inputs() -> void:
	var bindings := {"left": [KEY_A,KEY_LEFT], "right": [KEY_D,KEY_RIGHT], "up": [KEY_W,KEY_UP], "down": [KEY_S,KEY_DOWN], "interact": [KEY_E,KEY_ENTER], "jump": [KEY_SPACE], "dash": [KEY_SHIFT], "discard": [KEY_Q], "pause_game": [KEY_ESCAPE], "recipe": [KEY_TAB], "retry": [KEY_R]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var value = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not value is Dictionary:
		return
	unlocked = clampi(int(value.get("unlocked",0)),0,10)
	records = value.get("records",{}) if value.get("records",{}) is Dictionary else {}
	achievements = value.get("achievements",{}) if value.get("achievements",{}) is Dictionary else {}
	assist = bool(value.get("assist",false))
	reduced_motion = bool(value.get("reduced_motion",false))
	synth.enabled = bool(value.get("sound",true))
	synth.music_enabled = bool(value.get("music",true))

func save_progress() -> void:
	if not save_enabled:
		return
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"records":records,"achievements":achievements,"assist":assist,"reduced_motion":reduced_motion,"sound":synth.enabled,"music":synth.music_enabled}))
	else:
		notify("저장하지 못했습니다. 저장 폴더 권한을 확인하세요.")

func unlock_achievement(id: String) -> void:
	if is_custom: return
	if achievements.has(id):
		return
	achievements[id] = true
	for a in Data.ACHIEVEMENTS:
		if a[0] == id:
			notify("업적 달성  /  " + a[1])
	save_progress()

func notify(message: String) -> void:
	toast = message
	toast_time = 3.2

func clear_buttons() -> void:
	for b in buttons:
		b.hide()
		b.queue_free()
	buttons.clear()

func add_button(label: String, rect: Rect2, callback: Callable, primary := false, disabled := false) -> void:
	var b := Button.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GREEN if primary else Color("182b40")
		if state == "hover": style.bg_color = Color("a0ffe6") if primary else Color("28455f")
		if state == "pressed": style.bg_color = Color("49baa2")
		if state == "disabled": style.bg_color = Color("132032")
		if state == "focus": style.bg_color = Color(0,0,0,0)
		style.set_corner_radius_all(9)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.border_color = GREEN if state == "focus" else Color("2b435a")
		b.add_theme_stylebox_override(state,style)
	b.add_theme_color_override("font_color",BG if primary else INK)
	b.add_theme_color_override("font_hover_color",BG if primary else INK)
	b.add_theme_color_override("font_pressed_color",BG)
	b.add_theme_color_override("font_focus_color",BG if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("4b5a6d"))
	b.pressed.connect(func(): synth.cue("click"); callback.call())
	ui.add_child(b)
	buttons.append(b)
	if buttons.size()==1: b.grab_focus()

func show_screen(next: String) -> void:
	if next=="map": map_chapter=0
	mode = next
	clear_buttons()
	match mode:
		"menu":
			add_button("프로젝트 시작   →",Rect2(84,446,350,58),func(): map_chapter = 0; show_screen("map"),true)
			add_button("플레이 방법",Rect2(84,520,168,48),func(): return_mode = "menu"; show_screen("help"))
			add_button("업적",Rect2(266,520,168,48),func(): show_screen("achievements"))
			add_button("설정",Rect2(84,582,168,48),func(): return_mode = "menu"; show_screen("settings"))
			add_button("나가기",Rect2(266,582,168,48),func(): get_tree().quit())
			add_button("스테이지 제작기   ◇",Rect2(84,644,350,48),open_editor)
		"map":
			add_button("← 메인",Rect2(60,38,130,42),func(): show_screen("menu"))
			for c in range(3):
				var selected := c
				add_button(Data.SUBTITLES[c] if c==0 else "챕터 %d · 미해금"%(c+1),Rect2(60+c*390,118,368,54),func(): map_chapter = selected; show_screen("map"),c == map_chapter,c>0)
			for n in range(10):
				var picked := n
				var index := map_chapter*10+n
				add_button("다시 도전" if records.has(str(index)) else ("시작  →" if index<=unlocked else "잠김"),Rect2(80+(n%5)*235,352+(n/5 as int)*234,185,40),func(): start_stage(map_chapter,picked),index==unlocked,index>unlocked)
		"story":
			add_button("디버깅 시작   →",Rect2(810,575,240,52),func(): mode="play"; clear_buttons(),true)
			add_button("← 스테이지",Rect2(226,575,190,52),func(): show_screen("map"))
		"pause":
			add_button("계속하기",Rect2(475,310,330,52),func(): mode="play"; clear_buttons(),true)
			add_button("조합표 / 조작법",Rect2(475,378,330,48),func(): return_mode="pause"; show_screen("help"))
			add_button("설정",Rect2(475,442,156,48),func(): return_mode="pause"; show_screen("settings"))
			add_button("다시 시도",Rect2(649,442,156,48),retry_current)
			add_button("제작기로 돌아가기" if is_custom else "스테이지 선택",Rect2(475,506,330,48),return_to_selection)
		"help","settings","achievements":
			add_button("← 돌아가기",Rect2(60,38,165,44),func(): show_screen(return_mode if mode!="achievements" else "menu"))
			if mode == "settings":
				add_button("사운드  " + ("ON" if synth.enabled else "OFF"),Rect2(740,244,280,52),func(): synth.enabled=not synth.enabled; save_progress(); show_screen("settings"))
				add_button("배경음악  " + ("ON" if synth.music_enabled else "OFF"),Rect2(740,326,280,52),func(): synth.music_enabled=not synth.music_enabled; save_progress(); show_screen("settings"))
				add_button("화면 흔들림  " + ("OFF" if reduced_motion else "ON"),Rect2(740,408,280,52),func(): reduced_motion=not reduced_motion; save_progress(); show_screen("settings"))
				add_button("연습 보조  " + ("ON" if assist else "OFF"),Rect2(740,490,280,52),func(): assist=not assist; save_progress(); show_screen("settings"))
		"result":
			if is_custom:
				add_button("제작기로 돌아가기",Rect2(664,586,340,52),open_editor,true)
			elif victory and level<9:
				add_button("다음 스테이지   →",Rect2(664,586,340,52),func(): var index=chapter*10+level+1; start_stage(index/10,index%10),true)
			else:
				add_button("다시 도전",Rect2(664,586,340,52),retry_current,true)
			add_button("다시 테스트" if is_custom else "스테이지 선택",Rect2(278,586,340,52),retry_current if is_custom else return_to_selection)
	queue_redraw()

func start_stage(c: int, n: int) -> void:
	if c!=0:
		notify("챕터 2·3은 현재 미해금 상태입니다.")
		show_screen("map")
		return
	is_custom=false
	custom_document={}
	bench_pos=BENCH
	source_positions=SOURCES.duplicate()
	walls.clear()
	background_modules.clear()
	stage_title=Data.STAGE_NAMES[c][n]
	stage_intro=Data.INTRO[c][n]
	chapter=c
	level=n
	stage_config=Data.stage(c,n)
	rng.seed=90421+c*100+n
	player=Vector2(484,516)
	facing=Vector2.DOWN
	hp=5
	time_left=stage_config.time
	elapsed=0
	hits=0
	parries=0
	score=0
	combo=0
	combo_time=0
	invulnerable=0
	jump=0
	jump_cd=0
	dash=0
	dash_cd=0
	craft_remaining=0
	craft_ready=-1
	flash=0
	shake=0
	wave_index=0
	tutorial=0
	inventory.clear()
	craft_slots.clear()
	terminals.clear()
	enemies.clear()
	bullets.clear()
	particles.clear()
	floaters.clear()
	for i in range(stage_config.orders.size()):
		terminals.append({"p":TERMINAL_POS[i],"orders":stage_config.orders[i].duplicate(true),"round":0,"upload":0.0,"done":false})
	for i in range(stage_config.enemies):
		var pos := Vector2(410+i*135,276) if i<3 else Vector2(380+(i-3)*200,553)
		enemies.append({"p":pos,"origin":pos,"cooldown":2.6+i*0.65,"stun":0.0,"warning":0.0,"aim":Vector2.DOWN,"phase":i*1.6,"pattern":i%3})
	show_screen("story")

func open_editor() -> void:
	clear_buttons()
	mode="editor"
	if not is_instance_valid(editor_node):
		editor_node=StageEditor.new()
		editor_node.font=font
		editor_node.art=art
		editor_node.art_reload_requested.connect(func(): art.reload(); editor_node.show_report("아트 새로고침","%d개 벡터/이미지 적용\n"%art.textures.size()+"\n".join(art.warnings)); queue_redraw())
		editor_node.test_requested.connect(start_custom_stage)
		editor_node.exit_requested.connect(func(): editor_node.hide(); show_screen("menu"))
		add_child(editor_node)
	editor_node.show()

func return_to_selection() -> void:
	if is_custom: open_editor()
	else: show_screen("map")

func retry_current() -> void:
	if is_custom: start_custom_stage(custom_document.duplicate(true))
	else: start_stage(chapter,level)

func start_custom_stage(document: Dictionary) -> void:
	var errors:=StageDoc.validate(document)
	if not errors.is_empty(): notify("스테이지 오류: "+errors[0]); return
	document=StageDoc.normalize(document)
	start_stage(0,0)
	is_custom=true
	custom_document=document.duplicate(true)
	stage_title=document.name
	stage_intro=document.description
	rng.seed=int(document.seed)
	stage_config.time=float(document.time_limit)
	time_left=stage_config.time
	terminals.clear()
	enemies.clear()
	walls.clear()
	for object in document.objects:
		var p: Vector2=StageDoc.position_of(object)+StageDoc.OFFSET
		match object.kind:
			"background": background_modules.append({"p":p,"module":object.module,"rotation":int(object.rotation)})
			"spawn": player=p
			"bench": bench_pos=p
			"source": source_positions[int(object.material)]=p
			"wall": walls.append(Rect2(p-Vector2(16,16),Vector2(32,32)))
			"terminal": terminals.append({"p":p,"orders":object.orders.duplicate(true),"round":0,"upload":0.0,"done":false})
			"bug":
				var e: Dictionary=object.duplicate(true)
				e.merge({"p":p,"origin":p,"cooldown":2.6+enemies.size()*0.65,"stun":0.0,"warning":0.0,"aim":Vector2.DOWN,"phase":enemies.size()*1.6,"custom_pattern":object.pattern,"shot_wave":0})
				enemies.append(e)
	if is_instance_valid(editor_node): editor_node.hide()
	clear_buttons()
	mode="play"

func _unhandled_input(event: InputEvent) -> void:
	if mode=="editor": return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause_game"):
		if mode=="play": show_screen("pause")
		elif mode=="pause": mode="play"; clear_buttons()
		elif mode in ["help","settings"]: show_screen(return_mode)
		elif mode=="story": show_screen("map")
		elif mode in ["map","achievements","result"]: show_screen("menu")
		return
	if mode=="story" and event.is_action_pressed("interact"):
		mode="play"
		clear_buttons()
		return
	if mode!="play":
		return
	if event.is_action_pressed("interact"): interact()
	if event.is_action_pressed("jump") and jump_cd<=0:
		jump=0.55
		jump_cd=0.68
		synth.cue("jump")
	if event.is_action_pressed("dash") and dash_cd<=0:
		dash=0.16
		dash_cd=1.35
		dash_direction=facing
		synth.cue("dash")
	if event.is_action_pressed("discard"):
		if not inventory.is_empty():
			inventory.pop_back()
			notify("마지막 소지품을 비웠습니다. 재료는 다시 획득할 수 있어요.")
		elif player.distance_to(bench_pos)<92 and craft_remaining<=0:
			craft_slots.clear()
			craft_ready=-1
			notify("제작대를 비웠습니다.")
	if event.is_action_pressed("recipe"):
		return_mode="pause"
		show_screen("help")

func _process(dt: float) -> void:
	clock+=dt
	toast_time=maxf(0,toast_time-dt)
	if mode=="play":
		update_game(minf(dt,0.05))
	queue_redraw()

func update_game(dt: float) -> void:
	elapsed+=dt
	time_left-=dt*(0.75 if assist else 1.0)
	invulnerable=maxf(0,invulnerable-dt)
	jump=maxf(0,jump-dt)
	jump_cd=maxf(0,jump_cd-dt)
	dash=maxf(0,dash-dt)
	dash_cd=maxf(0,dash_cd-dt)
	flash=maxf(0,flash-dt*2)
	shake=maxf(0,shake-dt*20)
	combo_time=maxf(0,combo_time-dt)
	if combo_time<=0: combo=0
	var movement:=Input.get_vector("left","right","up","down")
	if movement.length()>0.1: facing=movement
	var velocity:=dash_direction*690 if dash>0 else movement*245
	var target:=player+velocity*dt
	target.x=clampf(target.x,ARENA.position.x+18,ARENA.end.x-18)
	target.y=clampf(target.y,ARENA.position.y+18,ARENA.end.y-18)
	var obstacles: Array = [Rect2(bench_pos-Vector2(53,30),Vector2(106,60))]
	for p in source_positions: obstacles.append(Rect2(p-Vector2(36,25),Vector2(72,50)))
	for t in terminals: obstacles.append(Rect2(t.p-Vector2(29,32),Vector2(58,64)))
	obstacles.append_array(walls)
	for obstacle in obstacles:
		var expanded: Rect2=obstacle.grow(13)
		if expanded.has_point(Vector2(target.x,player.y)): target.x=player.x
		if expanded.has_point(Vector2(target.x,target.y)): target.y=player.y
	player=target
	if dash>0:
		particles.append({"p":player,"v":Vector2.ZERO,"life":0.2,"max":0.2,"color":GREEN,"size":12.0})
	if craft_remaining>0:
		craft_remaining-=dt
		if craft_remaining<=0:
			craft_ready=Data.combine(craft_slots[0],craft_slots[1])
			craft_slots.clear()
			synth.cue("ready")
			burst(bench_pos,GREEN,22)
			floating(bench_pos+Vector2(0,-40),"제작 완료!",GREEN)
			if craft_ready==11: unlock_achievement("secret")
	for t in terminals:
		if t.upload>0:
			t.upload-=dt
			if t.upload<=0:
				t.round+=1
				if t.round>=t.orders.size(): t.done=true
				repair_reward(t.p)
	if terminals.all(func(t): return t.done):
		finish(true)
		return
	update_enemies(dt)
	update_bullets(dt)
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]
		p.life-=dt
		p.p+=p.v*dt
		p.v*=0.96
		if p.life<=0: particles.remove_at(i)
	for i in range(floaters.size()-1,-1,-1):
		floaters[i].life-=dt
		floaters[i].p.y-=dt*26
		if floaters[i].life<=0: floaters.remove_at(i)
	if hp<=0: finish(false,"체력이 모두 소진됐습니다.")
	elif time_left<=0: finish(false,"제출 시간이 초과됐습니다.")

func nearest() -> Dictionary:
	var result: Dictionary={}
	var distance:=90.0
	var candidates: Array=[{"p":bench_pos,"kind":"bench","id":0}]
	for i in range(4): candidates.append({"p":source_positions[i],"kind":"source","id":i})
	for i in range(terminals.size()): candidates.append({"p":terminals[i].p,"kind":"terminal","id":i})
	for candidate in candidates:
		var d:=player.distance_to(candidate.p)
		if d<distance:
			distance=d
			result=candidate
	return result

func interact() -> void:
	var target:=nearest()
	if target.is_empty():
		notify("재료함, 제작대, 오류 단말기 가까이에서 E를 누르세요.")
		return
	match target.kind:
		"source":
			if inventory.size()>=2:
				notify("소지품은 2개까지! 제작대에 넣거나 Q로 마지막 칸을 비우세요.")
			else:
				inventory.append(target.id)
				synth.cue("pick")
				floating(player+Vector2(0,-36),"+ "+Data.item_name(target.id),MAT_COLORS[target.id])
		"bench":
			if craft_remaining>0:
				notify("제작 중입니다. 잠시 뒤 완성 아이콘이 나타납니다.")
			elif craft_ready>=0:
				if inventory.size()<2:
					inventory.append(craft_ready)
					craft_ready=-1
					synth.cue("pick")
					tutorial=maxi(tutorial,3)
				else: notify("완성품을 받을 빈 칸이 필요해요. Q로 한 칸을 비우세요.")
			else:
				for i in range(inventory.size()-1,-1,-1):
					if inventory[i]<4 and craft_slots.size()<2:
						craft_slots.append(inventory[i])
						inventory.remove_at(i)
				if craft_slots.size()==2:
					craft_remaining=2.3
					synth.cue("craft")
					tutorial=maxi(tutorial,2)
				else: notify("제작대: 재료 두 개를 넣으세요. 같은 재료 2개도 조합할 수 있어요.")
		"terminal": deliver(target.id)

func deliver(index: int) -> void:
	var t=terminals[index]
	if t.done: notify("이미 복구된 단말기입니다."); return
	if t.upload>0: notify("패치를 전송하고 있습니다."); return
	var wanted: Array=t.orders[t.round]
	var transferred:=false
	for i in range(inventory.size()-1,-1,-1):
		var found:=wanted.find(inventory[i])
		if found>=0:
			wanted.remove_at(found)
			inventory.remove_at(i)
			transferred=true
	if wanted.is_empty():
		t.upload=1.1
		floating(t.p+Vector2(0,-45),"PATCH UPLOADING",GREEN)
	elif transferred:
		notify("일부 전달 완료! 남은 재료를 가져오세요.")
	else:
		notify("요구: "+order_text(wanted)+"  /  오른쪽 목록과 조합표를 확인하세요.")

func repair_reward(pos: Vector2) -> void:
	combo+=1
	combo_time=30
	score+=500+100*mini(combo,5)
	bullets.clear()
	for e in enemies:
		e.stun=maxf(e.stun,2.0)
		e.warning=0.0
	burst(pos,GREEN,42)
	flash=0.12
	synth.cue("repair")
	floating(pos+Vector2(0,-35),"복구 완료! +%d" % (500+100*mini(combo,5)),GREEN)
	tutorial=1 if not is_custom and chapter==0 and level==0 and terminals[0].done and not terminals[1].done else 4

func update_enemies(dt: float) -> void:
	for i in range(enemies.size()):
		var e=enemies[i]
		if e.stun>0:
			e.stun-=dt
			continue
		var radius: float=e.get("move_radius",40.0)
		e.p=e.origin+Vector2(sin(elapsed*0.6+e.phase)*radius,cos(elapsed*0.8+e.phase)*radius*0.575)
		if e.warning>0:
			e.warning-=dt
			if e.warning<=0:
				fire_pattern(i)
				e.cooldown=e.get("interval",stage_config.interval)+(0.0 if is_custom else rng.randf_range(0.1,0.7))
		else:
			e.cooldown-=dt
			if e.cooldown<=0:
				e.warning=0.65
				e.aim=(player-e.p).normalized()
		if player.distance_to(e.p)<28 and dash<=0 and jump<=0: take_hit()

func fire_pattern(owner: int) -> void:
	var e=enemies[owner]
	wave_index+=1
	if e.has("custom_pattern"):
		e.shot_wave=e.get("shot_wave",0)+1
		var shot_count: int=1 if e.custom_pattern=="aim" else int(e.shots)
		for i in range(shot_count):
			var angle: float=e.aim.angle()+(i-(shot_count-1)*0.5)*deg_to_rad(float(e.spread))
			if e.custom_pattern=="ring": angle=TAU*i/shot_count+elapsed*0.2
			bullets.append({"p":e.p,"v":Vector2.from_angle(angle)*float(e.speed),"pink":bool(e.parry) and i==shot_count/2 as int and e.shot_wave%2==0,"owner":owner,"life":8.0})
		if bullets.size()>220: bullets=bullets.slice(bullets.size()-220)
		return
	var count:=3+chapter*2+int(level>=5)*2
	var radial: bool=chapter>0 and e.pattern==1 and wave_index%2==0
	if radial: count=10+chapter*2
	for i in range(count):
		var angle: float=e.aim.angle()+(i-(count-1)*0.5)*0.20
		if radial: angle=i*TAU/count+elapsed*0.2
		var pink: bool=i==count/2 as int and wave_index%2==0
		bullets.append({"p":e.p,"v":Vector2.from_angle(angle)*stage_config.speed,"pink":pink,"owner":owner,"life":8.0})
	if bullets.size()>220: bullets=bullets.slice(bullets.size()-220)

func update_bullets(dt: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b=bullets[i]
		b.p+=b.v*dt*(0.72 if assist else 1.0)
		b.life-=dt
		if not ARENA.grow(20).has_point(b.p) or b.life<=0 or walls.any(func(w): return w.grow(6).has_point(b.p)):
			bullets.remove_at(i)
			continue
		var d:=player.distance_to(b.p)
		if b.pink and jump>0.12 and d<43:
			parries+=1
			score+=250
			time_left=minf(time_left+2,stage_config.time)
			invulnerable=0.65
			jump=0.46
			jump_cd=0.1
			var e=enemies[b.owner]
			e.stun=3.3
			e.warning=0.0
			burst(b.p,PINK,26)
			floating(player+Vector2(0,-50),"PARRY!  +2초",PINK)
			synth.cue("parry")
			unlock_achievement("parry")
			bullets.remove_at(i)
		elif d<18 and invulnerable<=0 and dash<=0:
			take_hit()
			bullets.remove_at(i)

func take_hit() -> void:
	if invulnerable>0: return
	hp-=1
	hits+=1
	combo=0
	invulnerable=1.7
	shake=6.0
	burst(player,RED,22)
	synth.cue("hurt")
	floating(player+Vector2(0,-45),"-1 HP",RED)

func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var life:=rng.randf_range(0.3,0.7)
		particles.append({"p":pos,"v":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(50,190),"life":life,"max":life,"color":color,"size":rng.randf_range(2,5)})

func floating(pos: Vector2, message: String, color: Color) -> void:
	floaters.append({"p":pos,"text":message,"color":color,"life":1.4})

func finish(won: bool, reason: String = "") -> void:
	victory=won
	fail_reason=reason
	if won:
		score+=int(time_left)*10+hp*200
		if is_custom:
			synth.cue("win")
			show_screen("result")
			return
		var index:=chapter*10+level
		unlocked=mini(10,maxi(unlocked,index+1))
		var key:=str(index)
		var stars:=1+int(hits==0)+int(elapsed<90)
		var old: Dictionary=records.get(key,{})
		records[key]={"score":maxi(score,int(old.get("score",0))),"stars":maxi(stars,int(old.get("stars",0))),"time":minf(elapsed,float(old.get("time",99999)))}
		unlock_achievement("first")
		if hits==0: unlock_achievement("clean")
		if elapsed<60: unlock_achievement("fast")
		if level==9: unlock_achievement("chapter%d"%(chapter+1))
		save_progress()
		synth.cue("win")
	else:
		synth.cue("hurt")
	show_screen("result")

func order_text(order: Array) -> String:
	var names:=PackedStringArray()
	for id in order: names.append(Data.item_name(id))
	return " + ".join(names)

func box(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.border_color=border
	style.set_border_width_all(1)
	draw_style_box(style,rect)

func text_at(value: String, pos: Vector2, size: int=18, color: Color=INK) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(value: String, pos: Vector2, size: int=18, color: Color=INK) -> void:
	text_at(value,pos-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.5,0),size,color)

func wrapped_text(value: String, pos: Vector2, width: float, size: int=18, color: Color=INK, line_height: float=30) -> float:
	var line:=""
	var y:=pos.y
	for ch in value:
		if ch=="\n" or font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			text_at(line,Vector2(pos.x,y),size,color)
			y+=line_height
			line="" if ch=="\n" else ch
		else: line+=ch
	text_at(line,Vector2(pos.x,y),size,color)
	return y+line_height

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),BG)
	for x in range(0,1280,40): draw_line(Vector2(x,0),Vector2(x,800),Color(0.1,0.22,0.3,0.16))
	for y in range(0,800,40): draw_line(Vector2(0,y),Vector2(1280,y),Color(0.1,0.22,0.3,0.16))
	match mode:
		"menu": draw_menu()
		"map": draw_map()
		"story": draw_story()
		"play","pause":
			draw_game()
			if mode=="pause":
				draw_rect(Rect2(0,0,1280,800),Color(0.015,0.025,0.05,0.84))
				box(Rect2(425,205,430,390),PANEL,Color("35506b"),20)
				centered("잠깐 쉬어 가도 괜찮아",Vector2(640,263),26)
		"help": draw_help()
		"settings": draw_settings()
		"achievements": draw_achievements()
		"result": draw_result()
	if toast_time>0:
		var w:=minf(1160,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+48)
		box(Rect2(640-w/2,744,w,42),Color("223d50"),GREEN,10)
		centered(toast,Vector2(640,772),17)

func draw_menu() -> void:
	text_at("CK GAME SCHOOL   /   STUDENT PROJECT 001",Vector2(84,112),16,GREEN)
	text_at("청강",Vector2(79,207),64)
	text_at("디버그 러시",Vector2(79,290),72)
	text_at("DEBUG RUSH",Vector2(86,337),26,GREEN)
	wrapped_text("버그가 삼킨 우리 게임.\n피하고, 조합하고, 끝내 완성하자.",Vector2(86,388),450,21,MUTED,32)
	text_at("CHAPTER 01  /  DESIGNER STAGE BUILDER",Vector2(84,721),14,MUTED)
	box(Rect2(600,118,597,540),Color("0e1d2e"),Color("244258"),24)
	text_at("LIVE BUILD",Vector2(630,156),14,GREEN)
	text_at("STATUS / CORRUPTED",Vector2(937,156),13,PINK)
	for i in range(8):
		var y:=202+i*47
		draw_line(Vector2(628,y),Vector2(1170,y),Color("172d41"))
		draw_line(Vector2(640+i*69,180),Vector2(640+i*69,624),Color("172d41"))
	for i in range(3):
		var p:=Vector2(710+i*164,255+(i%2)*255)
		draw_line(p,Vector2(896,408),Color("2c726d"),2)
		draw_circle(p,35,Color("182e42"))
		draw_circle(p,26,Color("233d52"))
		centered(["{ }","QA","</>"][i],p+Vector2(0,6),20,GREEN)
	draw_player(Vector2(898,414),3.5,0)
	draw_enemy(Vector2(1080,259),0,false,1.6)
	draw_enemy(Vector2(697,515),1,false,1.3)
	for i in range(8):
		var p:=Vector2(1072-i*34,285+i*28+sin(clock*2+i)*6)
		draw_circle(p,10,Color(PINK,0.12))
		draw_circle(p,4,PINK if i%3==0 else RED)
	box(Rect2(690,579,415,46),Color("172c40"),Color("32566c"))
	centered("[ E ]  고장 난 세계를 복구하세요",Vector2(897,609),18,GREEN)

func draw_map() -> void:
	text_at("PROJECT SELECT",Vector2(225,68),24)
	text_at("챕터 1 진행   %02d / 10"%mini(unlocked,10),Vector2(945,66),16,GREEN)
	var names: Array=Data.STAGE_NAMES[map_chapter]
	for i in range(10):
		var p:=Vector2(60+(i%5)*235,206+(i/5 as int)*234)
		var index:=map_chapter*10+i
		var open:=index<=unlocked
		var record: Dictionary=records.get(str(index),{})
		box(Rect2(p,Vector2(225,204)),PANEL,Data.THEMES[map_chapter] if index==unlocked else Color("23394f"))
		text_at("%02d — %02d"%[map_chapter+1,i+1],p+Vector2(20,34),15,Data.THEMES[map_chapter] if open else MUTED)
		wrapped_text(names[i],p+Vector2(20,77),190,22,INK if open else MUTED)
		text_at("★".repeat(int(record.get("stars",0))) if not record.is_empty() else ("READY TO DEBUG" if open else "이전 스테이지 완료 필요"),p+Vector2(20,124),14,GOLD if not record.is_empty() else MUTED)
	text_at("별 3개: 클리어 + 무피해 + 90초 이내  /  완료한 스테이지는 언제든 다시 플레이",Vector2(65,733),16,MUTED)

func draw_story() -> void:
	var accent: Color=Data.THEMES[chapter]
	box(Rect2(180,130,920,540),PANEL,Color("2b445b"),24)
	text_at(Data.CHAPTERS[chapter],Vector2(226,190),18,accent)
	text_at(("TEST / "+stage_title) if is_custom else "%d-%02d  %s"%[chapter+1,level+1,stage_title],Vector2(226,257),36)
	wrapped_text(stage_intro,Vector2(226,320),816,23,INK,39)
	box(Rect2(226,415,824,124),Color("0c1828"),Color("233d50"))
	text_at("MISSION BRIEF",Vector2(250,450),14,accent)
	wrapped_text("재료 획득 → 제작대에서 조합 → 단말기에 전달.\n모든 단말기를 복구하세요. 분홍 탄환은 SPACE 점프로 패링!",Vector2(250,484),770,18,MUTED,29)

func draw_game() -> void:
	var accent: Color=Data.THEMES[chapter]
	text_at("DEBUG / RUSH",Vector2(32,42),24,accent)
	text_at(("TEST / "+stage_title) if is_custom else "%d-%02d  %s"%[chapter+1,level+1,stage_title],Vector2(32,76),18,INK)
	for i in range(5):
		box(Rect2(434+i*32,28,24,25),RED if i<hp else Color("243246"),Color.TRANSPARENT,7)
	text_at("INTEGRITY",Vector2(434,76),12,MUTED)
	text_at("%02d:%02d"%[int(maxf(time_left,0))/60,int(maxf(time_left,0))%60],Vector2(656,60),36,RED if time_left<30 else INK)
	text_at("%06d"%score,Vector2(815,58),27,accent)
	box(Rect2(32,112,904,562),Color("101f2e"),Color("284558"),16)
	var fixed:=terminals.filter(func(t): return t.done).size()
	var restored:=float(fixed)/maxi(1,terminals.size())
	draw_rect(ARENA,Color("122535").lerp(Color("1c373f"),restored))
	if art.textures.has("floor_tile"):
		for x in range(0,872,32):
			for y in range(0,500,32):
				var size_px:=Vector2(mini(32,872-x),mini(32,500-y))
				var resolution_scale: float=art.textures.floor_tile.get_width()/32.0
				draw_texture_rect_region(art.textures.floor_tile,Rect2(ARENA.position+Vector2(x,y),size_px),Rect2(Vector2.ZERO,size_px*resolution_scale))
	for x in range(48,920,36):
		draw_line(Vector2(x,152),Vector2(x,652),Color(accent,0.07+restored*0.05))
	for y in range(152,653,36):
		draw_line(Vector2(48,y),Vector2(920,y),Color(accent,0.07+restored*0.05))
	draw_environment(restored)
	for decoration in background_modules:
		draw_set_transform(decoration.p,deg_to_rad(decoration.rotation))
		draw_art(decoration.module,Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	text_at(Data.CHAPTERS[chapter],Vector2(57,137),12,accent)
	text_at("RESTORATION  %d%%"%int(restored*100),Vector2(742,137),12,accent)
	for t in terminals:
		var color: Color=GREEN if t.done else Color("2c4b5c")
		draw_polyline(PackedVector2Array([t.p,Vector2(t.p.x,bench_pos.y),bench_pos]),Color(color,0.42),3)
	for wall in walls:
		var variant: Array=ArtBank.wall_variant(wall.get_center(),walls.map(func(w): return w.get_center()))
		draw_set_transform(wall.get_center(),variant[1])
		var painted:=draw_art(variant[0],Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		if not painted and not draw_art("wall",wall.get_center()): box(wall,Color("344b62"),Color("7489a6"),3)
	for i in range(4): draw_source(i)
	draw_bench()
	for i in range(terminals.size()): draw_terminal(i)
	for e in enemies:
		if e.warning>0 and e.stun<=0:
			draw_line(e.p,e.p+e.aim*260,Color(RED,0.23),2)
			draw_arc(e.p,33,0,TAU,32,Color(RED,0.6),2)
		draw_enemy(e.p,chapter,e.stun>0)
	for b in bullets:
		var color: Color=PINK if b.pink else RED
		draw_line(b.p-b.v.normalized()*13,b.p,Color(color,0.35),5)
		draw_circle(b.p,11,Color(color,0.1))
		if draw_art("bullet_parry" if b.pink else "bullet_red",b.p): continue
		if b.pink:
			draw_colored_polygon(PackedVector2Array([b.p+Vector2(0,-9),b.p+Vector2(9,0),b.p+Vector2(0,9),b.p+Vector2(-9,0)]),PINK)
		else: draw_circle(b.p,6,color)
		draw_circle(b.p-Vector2(1,2),2,Color("fff0df"))
	for p in particles:
		draw_circle(p.p,p.size,Color(p.color,clampf(p.life/p.max,0,1)))
	var offset:=Vector2.ZERO if reduced_motion else Vector2(sin(clock*90),cos(clock*75))*shake
	if invulnerable<=0 or int(clock*14)%2==0:
		draw_player(player+offset,1.0,sin(jump/0.55*PI)*27 if jump>0 else 0.0)
	if jump>0:
		draw_arc(player,36,0,TAU,40,PINK,2)
	if dash>0: draw_arc(player,24,0,TAU,30,GREEN,3)
	for i in range(inventory.size()):
		var p:=player+Vector2(-13+i*26,-46-sin(jump/0.55*PI)*27)
		draw_item(p,inventory[i],0.65)
	var near:=nearest()
	if not near.is_empty():
		var label:="E  "+("재료 획득" if near.kind=="source" else ("제작 / 받기" if near.kind=="bench" else "패치 전달"))
		var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+22
		var p: Vector2=near.p+Vector2(-width/2,48)
		box(Rect2(p,Vector2(width,28)),Color("284757"),GREEN,6)
		text_at(label,p+Vector2(11,20),14)
	for f in floaters: centered(f.text,f.p,18,f.color)
	if flash>0: draw_rect(ARENA,Color(GREEN,flash))
	draw_sidebar()
	box(Rect2(32,690,904,45),PANEL,Color("263b51"),9)
	text_at("WASD 이동    E 상호작용    SPACE 점프·패링    SHIFT 대시    Q 비우기    TAB 조합표",Vector2(50,719),15,MUTED)
	text_at("ESC 일시정지",Vector2(35,767),13,MUTED)
	var tip:="분홍 ◆ 탄환은 점프로 패링! 성공하면 발사한 버그가 3초간 멈춥니다."
	if chapter==0 and level==0 and not is_custom:
		tip=["첫 수리: 왼쪽 위 기획함에서 E → 왼쪽 단말기 A에 E로 전달하세요.","시스템 기획서: 기획 + 프로그래밍을 모아 가운데 제작대에서 E.","제작 중에도 이동할 수 있어요. 완료 아이콘이 뜨면 E로 받으세요.","완성품을 오른쪽 단말기 B에 전달하면 첫 빌드 복구 완료!","좋아요! 다음 요구 사항을 확인하세요."][mini(tutorial,4)]
	text_at(tip,Vector2(193,767),14,GREEN)

func draw_source(index: int) -> void:
	var p: Vector2=source_positions[index]
	var color: Color=MAT_COLORS[index]
	if draw_art("source_%d"%index,p):
		centered(Data.MATERIALS[index],p+Vector2(0,-48),16,INK)
		return
	box(Rect2(p-Vector2(38,23)+Vector2(0,6),Vector2(76,48)),Color("091421"),Color.TRANSPARENT,8)
	box(Rect2(p-Vector2(38,28),Vector2(76,50)),Color("233347"),Color(color,0.65),8)
	draw_rect(Rect2(p-Vector2(29,20),Vector2(58,5)),color)
	centered(["PLAN","CODE","ART","QA"][index],p+Vector2(0,9),16,color)
	centered(Data.MATERIALS[index],p+Vector2(0,-40),16,INK)

func draw_bench() -> void:
	if not draw_art("bench_ready" if craft_ready>=0 else ("bench_busy" if craft_remaining>0 else "bench_idle"),bench_pos):
		box(Rect2(bench_pos-Vector2(60,33)+Vector2(0,8),Vector2(120,66)),Color("07111e"),Color.TRANSPARENT,12)
		box(Rect2(bench_pos-Vector2(60,33),Vector2(120,66)),Color("2c4057"),Color("7095ae"),12)
		box(Rect2(bench_pos-Vector2(43,24),Vector2(86,34)),Color("112a39"),Color("376474"),5)
	if craft_ready>=0:
		draw_item(bench_pos+Vector2(0,-10-sin(clock*3)*3),craft_ready,1.1)
		centered("완료! E로 받기",bench_pos+Vector2(0,-51),17,GREEN)
	elif craft_remaining>0:
		centered("COMPILING"+".".repeat(int(clock*3)%4),bench_pos+Vector2(0,-4),12,GOLD)
		draw_arc(bench_pos+Vector2(0,-7),18,clock*4,clock*4+PI*1.4,20,GOLD,2)
	else:
		centered("제작대",bench_pos+Vector2(0,-48),16,INK)
		for i in range(2):
			var p:=bench_pos+Vector2(-21+i*42,-7)
			if i<craft_slots.size(): draw_item(p,craft_slots[i],0.65)
			else: centered("+",p+Vector2(0,5),19,MUTED)
	centered("WORKBENCH",bench_pos+Vector2(0,26),10,MUTED)

func draw_terminal(index: int) -> void:
	var t=terminals[index]
	var p: Vector2=t.p
	var color: Color=GREEN if t.done else GOLD
	var custom_art:=draw_art("terminal_online" if t.done else ("terminal_upload" if t.upload>0 else "terminal_error"),p)
	if not custom_art:
		box(Rect2(p-Vector2(29,34)+Vector2(0,7),Vector2(58,68)),Color("07111e"),Color.TRANSPARENT,8)
		box(Rect2(p-Vector2(29,34),Vector2(58,68)),Color("203247"),color,8)
		box(Rect2(p-Vector2(21,25),Vector2(42,34)),Color("0a1c2a"),Color.TRANSPARENT,4)
	centered("OK" if t.done else ("↑" if t.upload>0 else "!"),p+Vector2(0,1),24,color)
	for i in range(t.orders.size()):
		draw_rect(Rect2(p+Vector2(-19+i*13,18),Vector2(9,5)),GREEN if i<t.round else Color("4b5461"))
	centered("NODE "+char(65+index),p+Vector2(0,-68 if custom_art else -48),12,color)
	if not t.done and t.upload<=0:
		var order: Array=t.orders[t.round]
		for i in range(order.size()): draw_item(p+Vector2(-10+i*24,-90 if custom_art else -72),order[i],0.6)
	if t.upload>0:
		draw_arc(p,42,-PI/2,-PI/2+TAU*(1.0-t.upload/1.1),40,GREEN,3)

func draw_item(p: Vector2, id: int, scale_factor: float=1.0) -> void:
	if draw_art("item_%d"%id,p,scale_factor): return
	var color: Color=MAT_COLORS[id] if id<4 else (RED if id==11 else GOLD)
	box(Rect2(p-Vector2(14,16)*scale_factor,Vector2(28,32)*scale_factor),Color("132235"),color,4)
	centered(["P","C","A","Q"][id] if id<4 else ("!" if id==11 else "✓"),p+Vector2(0,6)*scale_factor,int(18*scale_factor),color)

func draw_player(p: Vector2, s: float, height: float) -> void:
	draw_set_transform(p,0,Vector2(s,s))
	draw_circle(Vector2(0,11),15,Color(0,0,0,0.28))
	var h:=Vector2(0,-height)
	var key:="player_hurt" if invulnerable>0 else ("player_dash" if dash>0 else ("player_jump" if jump>0 else "player_idle"))
	if draw_art(key,h): draw_set_transform(Vector2.ZERO); return
	draw_line(h+Vector2(-6,12),h+Vector2(-7,21),Color("8199d9"),7)
	draw_line(h+Vector2(6,12),h+Vector2(7,21),Color("8199d9"),7)
	box(Rect2(h+Vector2(-14,-7),Vector2(28,26)),Color("8378d8"),Color("b8b1fc"),7)
	draw_line(h+Vector2(-16,0),h+Vector2(-18,11),Color("b2abf0"),6)
	draw_line(h+Vector2(16,0),h+Vector2(18,11),Color("b2abf0"),6)
	draw_circle(h+Vector2(0,-17),14,Color("ffd8bc"))
	draw_arc(h+Vector2(0,-19),13,PI,TAU,14,Color("283442"),7)
	draw_circle(h+Vector2(-5,-17),1.6,BG)
	draw_circle(h+Vector2(5,-17),1.6,BG)
	draw_rect(Rect2(h+Vector2(-4,0),Vector2(8,9)),GREEN)
	draw_line(h+Vector2(-2,4),h+Vector2(2,4),BG,2)
	draw_set_transform(Vector2.ZERO)

func draw_enemy(p: Vector2, theme: int, stunned: bool, s: float=1.0) -> void:
	var color: Color=Color("576f87") if stunned else [PINK,Color("c597ff"),Color("ff9977")][theme]
	draw_set_transform(p,0,Vector2(s,s))
	draw_circle(Vector2(0,12),22,Color(0,0,0,0.25))
	var key:="bug_stunned" if stunned else ("bug_warning" if enemies.any(func(e): return e.p==p and e.warning>0) else "bug_idle")
	if draw_art(key,Vector2.ZERO):
		if stunned: draw_arc(Vector2(0,-30),15,clock*3,clock*3+PI*1.6,20,GOLD,2)
		draw_set_transform(Vector2.ZERO)
		return
	for side in [-1,1]:
		for i in range(3):
			draw_polyline(PackedVector2Array([Vector2(side*14,-8+i*8),Vector2(side*25,-14+i*11),Vector2(side*30,-11+i*13)]),color,2)
	if theme==1:
		draw_colored_polygon(PackedVector2Array([Vector2(-22,-5),Vector2(-30,-31),Vector2(-4,-15),Vector2(4,-15),Vector2(30,-31),Vector2(22,-5)]),color.darkened(0.4))
	box(Rect2(-18,-21,36,39),color.darkened(0.64),color,8 if theme!=2 else 2)
	if theme==0:
		draw_line(Vector2(-9,-22),Vector2(-15,-31),color,2)
		draw_line(Vector2(9,-22),Vector2(15,-31),color,2)
	elif theme==2:
		draw_rect(Rect2(-12,-28,24,7),color)
	draw_rect(Rect2(-11,-10,8,7),GOLD if stunned else color)
	draw_rect(Rect2(3,-10,8,7),GOLD if stunned else color)
	draw_line(Vector2(-5,7),Vector2(5,7),color,2)
	if stunned:
		draw_arc(Vector2(0,-30),15,clock*3,clock*3+PI*1.6,20,GOLD,2)
	draw_set_transform(Vector2.ZERO)

func draw_art(key: String, p: Vector2, scale_factor:=1.0) -> bool:
	var resolved: String=art.resolved(key)
	if resolved.is_empty(): return false
	var spec: Array=art.specs[resolved]
	draw_texture_rect(art.textures[resolved],Rect2(p-spec[1]*scale_factor,Vector2(spec[0])*scale_factor),false)
	return true

func draw_sidebar() -> void:
	box(Rect2(958,28,290,707),PANEL,Color("263b51"),14)
	text_at("PATCH QUEUE",Vector2(978,64),18,GREEN)
	text_at("모든 단말기를 복구하세요",Vector2(978,90),14,MUTED)
	var y:=111.0
	for i in range(terminals.size()):
		var t=terminals[i]
		box(Rect2(975,y,256,82),Color("0b1727"),Color("274653") if t.done else Color("28384d"),8)
		text_at("%s  /  %s"%[char(65+i),"복구 완료" if t.done else "오류 단말기"],Vector2(989,y+24),14,GREEN if t.done else GOLD)
		if not t.done:
			var label: String="전송 중…" if t.upload>0 else order_text(t.orders[t.round])
			wrapped_text(label,Vector2(989,y+48),226,15,INK,21)
			if t.upload<=0 and t.orders[t.round].size()==1:
				var id: int=t.orders[t.round][0]
				if id>=4 and id<=10:
					var pair: Array=Data.pair_for(id)
					text_at(Data.item_name(pair[0])+" + "+Data.item_name(pair[1]),Vector2(989,y+70),12,MUTED)
		else: text_at("ONLINE",Vector2(989,y+51),16,GREEN)
		text_at("%d/%d"%[t.round,t.orders.size()],Vector2(1191,y+24),12,MUTED)
		y+=91
	y=maxf(y+8,320)
	text_at("소지품  %d / 2"%inventory.size(),Vector2(978,y+16),15,MUTED)
	for i in range(2):
		box(Rect2(978+i*129,y+30,120,62),Color("14293a"),Color("304b60"),8)
		if i<inventory.size():
			draw_item(Vector2(995+i*129,y+60),inventory[i],0.55)
			wrapped_text(Data.item_name(inventory[i]),Vector2(1011+i*129,y+57),78,12,INK,17)
		else: text_at("비어 있음",Vector2(999+i*129,y+66),13,MUTED)
	y+=115
	text_at("SPACE  점프·패링",Vector2(978,y),14,PINK)
	text_at("SHIFT  긴급 대시",Vector2(978,y+27),14,GREEN)
	draw_rect(Rect2(978,y+38,250,5),Color("2c3b4d"))
	draw_rect(Rect2(978,y+38,250*(1.0-dash_cd/1.35),5),GREEN)
	text_at("대시 준비" if dash_cd<=0 else "충전 중",Vector2(978,y+64),12,MUTED)
	if combo>1: text_at("REPAIR CHAIN ×%d"%combo,Vector2(978,714),16,GOLD)
	elif assist: text_at("연습 보조 ON",Vector2(978,714),14,GOLD)

func draw_environment(restored: float) -> void:
	# Decorative data architecture stays below characters and projectiles.
	var accent: Color=Data.THEMES[chapter]
	for i in range(8):
		var p:=Vector2(172+i*90,171)
		draw_rect(Rect2(p,Vector2(25,3)),Color(accent,0.22+restored*0.2))
		draw_rect(Rect2(p+Vector2(0,461),Vector2(25,3)),Color(accent,0.22+restored*0.2))
	match chapter:
		0:
			for i in range(4):
				var p:=Vector2(370+i*76,182)
				draw_rect(Rect2(p,Vector2(40,18)),Color("1d3545"),false,1)
				text_at(["01","10","01","11"][i],p+Vector2(9,13),10,Color(accent,0.4))
		1:
			for p in [Vector2(185,404),Vector2(782,404)]:
				draw_arc(p,36,0,TAU,6,Color(accent,0.22),2)
				draw_arc(p,45,0,TAU,6,Color(accent,0.12),1)
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-27),p+Vector2(15,0),p+Vector2(0,23),p+Vector2(-15,0)]),Color(accent,0.15+restored*0.15))
		2:
			for x in [188,770]:
				for y in range(260,570,44):
					draw_rect(Rect2(x,y,9,23),Color(accent,0.15))
			for x in [341,593]:
				box(Rect2(x,180,33,46),Color("1c3040"),Color(accent,0.2),3)
				for y in range(3): draw_circle(Vector2(x+16,189+y*13),3,GREEN if restored>0.5 else Color(RED,0.35))

func draw_help() -> void:
	text_at("FIELD MANUAL / 플레이 방법",Vector2(260,69),28)
	box(Rect2(60,117,540,582),PANEL,Color("2b4056"))
	text_at("01  살아남으며 수리하기",Vector2(88,158),23,GREEN)
	var lines: Array=["WASD / 방향키  ·  이동", "E / ENTER  ·  재료 획득, 제작, 전달", "SPACE  ·  점프해서 분홍 ◆ 탄환 패링", "SHIFT  ·  짧은 무적 대시 (재사용 1.35초)", "Q  ·  마지막 소지품 삭제", "TAB  ·  조합표 (시간이 멈춥니다)", "ESC  ·  일시정지"]
	for i in range(lines.size()): text_at(lines[i],Vector2(88,205+i*37),17,INK)
	wrapped_text("붉은 탄환은 점프로 피할 수 없습니다. 이동하거나 대시하세요. 패링에 성공하면 발사한 적이 멈추고 2초를 돌려받습니다.",Vector2(88,488),480,17,PINK,28)
	wrapped_text("소지품은 2칸. 제작대에 재료 2개를 넣고 완성품을 받아 단말기로! 빈손일 때 제작대 옆에서 Q를 누르면 잘못 넣은 재료나 완성품을 지웁니다.",Vector2(88,598),480,16,MUTED,26)
	box(Rect2(623,117,597,582),PANEL,Color("2b4056"))
	text_at("02  두 재료, 하나의 패치",Vector2(651,158),23,GOLD)
	for i in range(7):
		var y:=203+i*58
		var pair: Array=Data.RECIPE_PAIRS[i]
		text_at(Data.item_name(pair[0])+" + "+Data.item_name(pair[1]),Vector2(651,y),16,MUTED)
		text_at("→  "+Data.item_name(i+4),Vector2(923,y),17,INK)
		draw_line(Vector2(651,y+18),Vector2(1190,y+18),Color("24374b"))
	text_at("다른 조합은 오류뭉텅이가 됩니다. Q로 비워 주세요.",Vector2(651,652),16,PINK)
	text_at("수리 성공 시 주변 탄막이 사라집니다. 다음 이동을 준비할 기회!",Vector2(65,742),17,GREEN)

func draw_settings() -> void:
	text_at("OPTIONS / 설정",Vector2(260,69),28)
	box(Rect2(220,159,840,480),PANEL,Color("2a4056"))
	var rows: Array=[["사운드", "효과음과 배경음악 전체 켜기 / 끄기"],["배경음악", "오리지널 신스 루프 켜기 / 끄기"],["화면 효과", "피격 시 흔들림 줄이기"],["연습 보조", "탄속 28% 감소 · 제한 시간 소모 25% 감소"]]
	for i in range(4):
		text_at(rows[i][0],Vector2(258,264+i*82),23)
		text_at(rows[i][1],Vector2(258,293+i*82),15,MUTED)
	text_at("설정과 스테이지 진행은 자동 저장됩니다.",Vector2(258,597),16,GREEN)

func draw_achievements() -> void:
	text_at("ACHIEVEMENTS / 업적",Vector2(260,69),28)
	text_at("%d / %d"%[achievements.size(),Data.ACHIEVEMENTS.size()],Vector2(1070,68),22,GREEN)
	for i in range(Data.ACHIEVEMENTS.size()):
		var a: Array=Data.ACHIEVEMENTS[i]
		var got:=achievements.has(a[0])
		var p:=Vector2(60+(i%2)*594,125+(i/2 as int)*144)
		box(Rect2(p,Vector2(566,124)),PANEL,GREEN if got else Color("28394d"))
		box(Rect2(p+Vector2(20,24),Vector2(65,65)),Color("203c47") if got else Color("202b3d"),Color.TRANSPARENT,12)
		centered("✓" if got else "?",p+Vector2(52,68),31,GREEN if got else MUTED)
		text_at(a[1] if a[0]!="secret" or got else "비밀 업적",p+Vector2(104,43),22,INK if got else MUTED)
		wrapped_text("잘못된 조합도 배움의 일부!" if a[0]=="secret" and got else a[2],p+Vector2(104,76),430,16,MUTED,25)

func draw_result() -> void:
	box(Rect2(230,105,820,580),PANEL,GREEN if victory else RED,24)
	centered("BUILD SUCCESS" if victory else "BUILD FAILED",Vector2(640,177),20,GREEN if victory else RED)
	centered("현실로 돌아왔습니다!" if victory and chapter==2 and level==9 else ("프로젝트 복구 완료" if victory else "한 번 더, 고칠 수 있어"),Vector2(640,242),38)
	centered(("TEST / "+stage_title) if is_custom else "%d-%02d  %s"%[chapter+1,level+1,stage_title],Vector2(640,282),18,MUTED)
	if victory:
		centered("★".repeat(1+int(hits==0)+int(elapsed<90)),Vector2(640,344),38,GOLD)
		var ending: String="모니터가 켜졌다. 팀원들의 목소리가 들린다. ‘돌아왔구나. 제출하자!’" if chapter==2 and level==9 else ("첫 세계를 복구했다. 문 너머에서 다음 프로젝트의 신호가 온다." if level==9 else "단말기의 불빛이 돌아왔다. ‘"+stage_title+"’ 복구 기록 저장 완료.")
		if is_custom: ending="테스트 완료! 캠페인 기록은 변경하지 않았습니다. 제작기로 돌아가 배치와 난이도를 조정하세요."
		elif level==9: ending="챕터 1 복구 완료! 챕터 2·3은 현재 미해금입니다. 스테이지 제작기로 새로운 도전을 만들어 보세요."
		wrapped_text(ending,Vector2(284,403),710,19,INK,30)
	else:
		centered(fail_reason,Vector2(640,351),23,RED)
		wrapped_text("제작 중엔 기다리기보다 다음 동선을 준비하세요. 분홍 탄환을 패링하고, 위급하면 SHIFT로 빠져나오세요.",Vector2(284,403),710,19,MUTED,30)
	for i in range(3):
		var p:=Vector2(280+i*247,475)
		box(Rect2(p,Vector2(226,78)),Color("0b1727"),Color("273c50"),9)
		text_at(["SCORE","TIME","PARRIES"][i],p+Vector2(18,26),12,MUTED)
		text_at([str(score),"%.1f s"%elapsed,str(parries)][i],p+Vector2(18,61),27,GREEN)
