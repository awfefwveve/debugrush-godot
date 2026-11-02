extends RefCounted
## Optional art overrides. Exact canvases keep gameplay and collision unchanged.
const BACKGROUND_MODULES = {
	"floor_grid":[Vector2i(32,32),"격자 바닥"],"floor_panel":[Vector2i(64,64),"대형 바닥 패널"],"floor_damaged":[Vector2i(32,32),"손상 바닥"],
	"circuit_straight":[Vector2i(32,32),"직선 회로"],"circuit_corner":[Vector2i(32,32),"꺾인 회로"],
	"deco_vent":[Vector2i(64,32),"환기구"],"deco_cable":[Vector2i(64,32),"바닥 케이블"],"deco_light":[Vector2i(64,32),"조명 띠"],
	"deco_warning":[Vector2i(64,32),"주의 표식"],"deco_screen":[Vector2i(96,64),"스크린 장식"],"deco_hologram":[Vector2i(64,64),"홀로그램"],"deco_grate":[Vector2i(64,64),"바닥 그레이팅"]}
var textures: Dictionary={}
var warnings: Array[String]=[]
var specs: Dictionary={}

func _init() -> void:
	specs={"floor_tile":[Vector2i(32,32),Vector2(16,16)],"wall":[Vector2i(32,32),Vector2(16,16)],
		"player_idle":[Vector2i(64,64),Vector2(32,43)],"player_jump":[Vector2i(64,64),Vector2(32,43)],
		"player_dash":[Vector2i(64,64),Vector2(32,43)],"player_hurt":[Vector2i(64,64),Vector2(32,43)],
		"bug_idle":[Vector2i(64,64),Vector2(32,32)],"bug_warning":[Vector2i(64,64),Vector2(32,32)],"bug_stunned":[Vector2i(64,64),Vector2(32,32)],
		"bullet_red":[Vector2i(16,16),Vector2(8,8)],"bullet_parry":[Vector2i(24,24),Vector2(12,12)]}
	for i in range(4): specs["source_%d"%i]=[Vector2i(96,80),Vector2(48,40)]
	for state in ["idle","busy","ready"]: specs["bench_"+state]=[Vector2i(128,96),Vector2(64,48)]
	for state in ["error","upload","online"]: specs["terminal_"+state]=[Vector2i(80,112),Vector2(40,56)]
	for i in range(12): specs["item_%d"%i]=[Vector2i(32,32),Vector2(16,16)]
	for key in BACKGROUND_MODULES:
		var size_px: Vector2i=BACKGROUND_MODULES[key][0]
		specs[key]=[size_px,Vector2(size_px)/2]
	for variant in ["end","straight","corner","tee","cross"]: specs["wall_"+variant]=[Vector2i(32,32),Vector2(16,16)]

func reload(directory_override := "") -> void:
	textures.clear()
	warnings.clear()
	for key in specs:
		var paths: Array=[]
		var directories: Array=[OS.get_executable_path().get_base_dir().path_join("art"),"res://art"]
		if not directory_override.is_empty(): directories=[directory_override]
		for directory in directories:
			for extension in ["svg","png"]: paths.append(directory.path_join(key+"."+extension))
		for path in paths:
			if not FileAccess.file_exists(path): continue
			var image: Image
			if path.ends_with(".svg"):
				image=Image.new()
				if image.load_svg_from_string(FileAccess.get_file_as_string(path),4.0)!=OK: warnings.append(key+": SVG를 읽을 수 없습니다."); break
			else: image=Image.load_from_file(path)
			if image==null or image.is_empty(): warnings.append(key+": 이미지를 읽을 수 없습니다."); break
			var expected: Vector2i=specs[key][0]*(4 if path.ends_with(".svg") else 1)
			if image.get_size()!=expected: warnings.append(key+": 원본 크기는 %s여야 합니다."%str(specs[key][0])); break
			textures[key]=ImageTexture.create_from_image(image)
			break

func resolved(key: String) -> String:
	if textures.has(key): return key
	if key.begins_with("player_") and textures.has("player_idle"): return "player_idle"
	if key.begins_with("bug_") and textures.has("bug_idle"): return "bug_idle"
	return ""

static func wall_variant(center: Vector2, centers: Array) -> Array:
	# Reference orientation: end=N, straight=N/S, corner=N/E, tee=N/E/W.
	var connected: Array[int]=[]
	var directions: Array=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
	for i in range(4):
		if centers.any(func(p): return p.distance_to(center+directions[i]*32)<0.5): connected.append(i)
	match connected.size():
		0: return ["wall",0.0]
		1: return ["wall_end",connected[0]*PI/2]
		2:
			if (connected[1]-connected[0])==2: return ["wall_straight",connected[0]*PI/2]
			for i in range(4):
				if i in connected and (i+1)%4 in connected: return ["wall_corner",i*PI/2]
		3:
			for i in range(4):
				if i not in connected: return ["wall_tee",((i+2)%4)*PI/2]
		4: return ["wall_cross",0.0]
	return ["wall",0.0]
