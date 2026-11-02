extends RefCounted
## Portable designer document. Coordinates are arena-local pixels, never UI pixels.
const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art_bank.gd")
const SIZE = Vector2(872,500)
const OFFSET = Vector2(48,152)
const GRID = 16
const KINDS = ["spawn","source","bench","terminal","bug","wall","background"]
const LABELS = {"spawn":"시작점","source":"재료함","bench":"제작대","terminal":"단말기","bug":"버그","wall":"벽","background":"배경"}

static func position_of(object: Dictionary) -> Vector2:
	return Vector2(float(object.pos[0]),float(object.pos[1]))

static func footprint(object: Dictionary) -> Vector2:
	match object.kind:
		"background":
			var dimensions: Vector2=Art.BACKGROUND_MODULES[object.module][0]
			return Vector2(dimensions.y,dimensions.x) if int(object.rotation)%180!=0 else dimensions
		"source": return Vector2(72,50)
		"bench": return Vector2(106,60)
		"terminal": return Vector2(58,64)
		"wall": return Vector2(32,32)
		"bug": return Vector2(44,44)
	return Vector2(28,28)

static func solid(object: Dictionary) -> bool:
	return object.kind in ["source","bench","terminal","wall"]

static func bounds(object: Dictionary) -> Rect2:
	return Rect2(position_of(object)-footprint(object)/2,footprint(object))

static func new_object(kind: String, pos: Vector2, material := 0) -> Dictionary:
	var o := {"kind":kind,"pos":[int(pos.x),int(pos.y)]}
	match kind:
		"background": o.merge({"module":"floor_grid","rotation":0})
		"source": o["material"]=material
		"terminal": o["orders"]=[[5]]
		"bug":
			o.merge({"pattern":"fan","interval":2.5,"speed":135.0,"shots":3,"spread":12.0,"parry":true,"move_radius":0.0})
	return o

static func base() -> Dictionary:
	var objects: Array=[]
	objects.append(new_object("spawn",Vector2(432,368)))
	objects.append(new_object("bench",Vector2(432,240)))
	var positions := [Vector2(224,64),Vector2(656,448),Vector2(656,64),Vector2(224,448)]
	for i in range(4): objects.append(new_object("source",positions[i],i))
	var a:=new_object("terminal",Vector2(64,160))
	a.orders=[[0],[5]]
	objects.append(a)
	var b:=new_object("terminal",Vector2(800,336))
	b.orders=[[7]]
	objects.append(b)
	objects.append(new_object("bug",Vector2(368,128)))
	objects.append(new_object("bug",Vector2(592,320)))
	return {"format":"debug-rush-stage","version":1,"chapter":1,"name":"나의 첫 스테이지","description":"재료를 조합해 모든 단말기를 복구하세요.","seed":1001,"time_limit":200.0,"objects":objects}

static func structural_errors(value: Variant) -> Array[String]:
	var errors: Array[String]=[]
	if not value is Dictionary: return ["JSON 최상위 값은 객체여야 합니다."]
	if value.get("format")!="debug-rush-stage" or value.get("version")!=1: errors.append("지원 형식: debug-rush-stage / version 1")
	if value.get("chapter")!=1: errors.append("현재 제작 가능 챕터는 1입니다. 챕터 2·3은 잠겨 있습니다.")
	if not value.get("name") is String or str(value.get("name","")).length() not in range(1,33): errors.append("이름은 1~32자입니다.")
	if not value.get("description","") is String or str(value.get("description","")).length()>300: errors.append("설명은 300자 이내입니다.")
	if not number_in(value.get("seed"),0,2147483647): errors.append("시드는 0~2147483647입니다.")
	if not number_in(value.get("time_limit"),30,900): errors.append("제한 시간은 30~900초입니다.")
	if not value.get("objects") is Array: errors.append("objects 배열이 필요합니다."); return errors
	if value.objects.size()>1000: errors.append("전체 모듈은 최대 1000개입니다."); return errors
	for i in range(value.objects.size()):
		var o=value.objects[i]
		var prefix:="오브젝트 %d: "%[i+1]
		if not o is Dictionary: errors.append(prefix+"객체 형식이 아닙니다."); continue
		if not o.get("kind") in KINDS: errors.append(prefix+"알 수 없는 종류"); continue
		var p=o.get("pos")
		if not p is Array or p.size()!=2: errors.append(prefix+"pos는 [x,y]입니다."); continue
		if not number_in(p[0],0,SIZE.x) or not number_in(p[1],0,SIZE.y): errors.append(prefix+"좌표 범위 밖입니다.")
		match o.kind:
			"background":
				if not o.get("module") in Art.BACKGROUND_MODULES: errors.append(prefix+"알 수 없는 배경 모듈입니다.")
				if not number_in(o.get("rotation"),0,270) or fmod(float(o.get("rotation",-1)),90.0)!=0.0: errors.append(prefix+"배경 회전은 0/90/180/270도입니다.")
			"source":
				if not number_in(o.get("material"),0,3) or float(o.get("material",-1))!=int(o.get("material",-1)): errors.append(prefix+"재료 ID는 0~3 정수입니다.")
			"terminal":
				if not o.get("orders") is Array: errors.append(prefix+"orders 배열이 필요합니다."); continue
				if o.orders.size()<1 or o.orders.size()>3: errors.append(prefix+"수리 라운드는 1~3개입니다.")
				for order in o.orders:
					if not order is Array or order.size()<1 or order.size()>2: errors.append(prefix+"라운드별 요청은 1~2개입니다."); continue
					for id in order:
						if not number_in(id,0,10): errors.append(prefix+"요청 아이템은 0~10입니다. 오류뭉텅이 요청은 불가합니다.")
						elif float(id)!=int(id): errors.append(prefix+"아이템 ID는 정수입니다.")
			"bug":
				if not o.get("pattern") in ["fan","ring","aim"]: errors.append(prefix+"탄막 패턴은 fan / ring / aim입니다.")
				for field in [["interval",0.8,8.0],["speed",60,300],["shots",1,16],["spread",5,60],["move_radius",0,32]]:
					if not number_in(o.get(field[0]),field[1],field[2]): errors.append(prefix+"%s 범위 %s~%s"%field)
				if not o.get("parry") is bool: errors.append(prefix+"parry는 true/false입니다.")
	return errors

static func number_in(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func validate(value: Variant, paths := true) -> Array[String]:
	var errors:=structural_errors(value)
	if not errors.is_empty(): return errors
	var objects: Array=value.objects
	var counts: Dictionary={}
	var materials: Array=[]
	var spawn:=Vector2.ZERO
	for i in range(objects.size()):
		var o: Dictionary=objects[i]
		counts[o.kind]=counts.get(o.kind,0)+1
		if o.kind=="source": materials.append(int(o.material))
		if o.kind=="spawn": spawn=position_of(o)
		var r:=bounds(o)
		if o.kind=="bug": r=r.grow(float(o.move_radius))
		if not Rect2(Vector2.ZERO,SIZE).encloses(r): errors.append("%d %s: 크기/이동 범위가 맵 밖입니다."%[i+1,LABELS[o.kind]])
		if o.kind=="background": continue
		for j in range(i):
			var other: Dictionary=objects[j]
			if other.kind=="background": continue
			if solid(o) and solid(other) and r.intersects(bounds(other)):
				errors.append("%d번과 %d번 구조물이 겹칩니다."%[j+1,i+1])
			if o.kind=="bug" and solid(other) and r.grow(2).intersects(bounds(other)):
				errors.append("버그 %d의 이동 범위가 구조물과 겹칩니다."%[i+1])
			if other.kind=="bug" and solid(o) and bounds(other).grow(float(other.move_radius)+2).intersects(r):
				errors.append("버그 %d의 이동 범위가 구조물과 겹칩니다."%[j+1])
	if counts.get("spawn",0)!=1: errors.append("시작점은 정확히 1개여야 합니다.")
	if counts.get("bench",0)!=1: errors.append("제작대는 정확히 1개여야 합니다.")
	for id in range(4):
		if materials.count(id)!=1: errors.append("%s 재료함은 정확히 1개여야 합니다."%Data.item_name(id))
	if counts.get("terminal",0)<1 or counts.get("terminal",0)>4: errors.append("단말기는 1~4개입니다.")
	if counts.get("bug",0)>8: errors.append("버그는 최대 8마리입니다.")
	if counts.get("wall",0)>80: errors.append("벽은 최대 80개입니다.")
	if counts.get("background",0)>900: errors.append("배경 모듈은 최대 900개입니다.")
	if objects.size()-counts.get("background",0)>100: errors.append("게임플레이 오브젝트는 최대 100개입니다.")
	for o in objects:
		if solid(o) and bounds(o).grow(14).has_point(spawn): errors.append("시작점이 구조물 안에 있습니다.")
		if o.kind=="bug" and spawn.distance_to(position_of(o))<70+float(o.move_radius): errors.append("시작점과 버그 이동 범위는 70px 이상 떨어뜨리세요.")
	if errors.is_empty() and paths: errors.append_array(path_errors(objects,spawn))
	return errors

static func path_errors(objects: Array, spawn: Vector2) -> Array[String]:
	# Flood fill with a 28px character body. 8px samples check narrow corridors.
	var errors: Array[String]=[]
	var step:=8
	var width:=int(SIZE.x/step)
	var height:=int(SIZE.y/step)
	var blocked:=PackedByteArray()
	blocked.resize(width*height)
	var boxes: Array[Rect2]=[]
	var interactables: Array=[]
	for o in objects:
		if solid(o): boxes.append(bounds(o).grow(14))
		if o.kind in ["source","bench","terminal"]: interactables.append(o)
	for y in range(height):
		for x in range(width):
			var p:=Vector2(x*step+4,y*step+4)
			var blocked_here:=p.x<18 or p.x>SIZE.x-18 or p.y<18 or p.y>SIZE.y-18
			for r in boxes:
				if r.has_point(p): blocked_here=true; break
			blocked[y*width+x]=1 if blocked_here else 0
	var start:=Vector2i(clampi(int(spawn.x/step),0,width-1),clampi(int(spawn.y/step),0,height-1))
	if blocked[start.y*width+start.x]==1: return ["시작점 주변 이동 공간이 부족합니다."]
	var queue: Array[Vector2i]=[start]
	blocked[start.y*width+start.x]=2
	var reached: Dictionary={}
	var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor]
		cursor+=1
		var p:=Vector2(cell)*step+Vector2(4,4)
		var best:=-1
		var distance:=90.0
		for i in range(interactables.size()):
			var d:=p.distance_to(position_of(interactables[i]))
			if d<distance: distance=d; best=i
		if best>=0: reached[best]=true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
			var index:=next.y*width+next.x
			if blocked[index]==0: blocked[index]=2; queue.append(next)
	for i in range(interactables.size()):
		if not reached.has(i): errors.append("%s (%d,%d)에 접근/상호작용할 수 없습니다."%[LABELS[interactables[i].kind],interactables[i].pos[0],interactables[i].pos[1]])
	return errors

static func generate(seed_number: int, difficulty: int) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_number
	var doc:=base()
	doc.seed=seed_number
	doc.generation_difficulty=difficulty
	doc.name="생성 %d · %s"%[seed_number,["입문","보통","도전"][difficulty]]
	doc.time_limit=[220,200,180][difficulty]
	var source_slots: Array=[Vector2(192,64),Vector2(672,64),Vector2(192,448),Vector2(672,448)]
	# Fisher-Yates uses local RNG, so the same seed reproduces the entire document.
	for i in range(source_slots.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var old=source_slots[i]; source_slots[i]=source_slots[j]; source_slots[j]=old
	for i in range(4): doc.objects[2+i].pos=[source_slots[i].x,source_slots[i].y]
	doc.objects=doc.objects.slice(0,6)
	var terminal_slots: Array=[Vector2(64,160),Vector2(800,336),Vector2(800,160),Vector2(64,336)]
	for i in range(2+difficulty):
		var t:=new_object("terminal",terminal_slots[i])
		t.orders=[]
		for r in range(1+int(difficulty>0)):
			var order: Array=[rng.randi_range(4,10)]
			if difficulty==2 and r==1: order.append(rng.randi_range(0,3))
			t.orders.append(order)
		doc.objects.append(t)
	var bug_slots: Array=[Vector2(336,112),Vector2(608,304),Vector2(336,448),Vector2(544,112)]
	for i in range(2+difficulty):
		var b:=new_object("bug",bug_slots[i])
		b.pattern=["fan","aim","ring"][rng.randi_range(0,mini(2,difficulty+1))]
		b.speed=110+difficulty*35
		b.interval=3.0-difficulty*0.5
		b.shots=3+difficulty*2 if b.pattern!="ring" else 10
		doc.objects.append(b)
	# Fixed obstacle slots preserve wide paths; randomized subsets give usable layouts.
	for pos in [Vector2(192,240),Vector2(688,240),Vector2(528,416),Vector2(192,336),Vector2(688,336)]:
		if rng.randf()<0.3+difficulty*0.2: doc.objects.append(new_object("wall",pos))
	for pos in [Vector2(80,64),Vector2(800,64),Vector2(80,448),Vector2(800,448)]:
		var module:=new_object("background",pos)
		module.module=["deco_vent","deco_light","deco_warning","deco_grate"][rng.randi_range(0,3)]
		doc.objects.append(module)
	return doc

static func load_file(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file: return {"error":"파일을 열 수 없습니다."}
	if file.get_length()>524288: return {"error":"스테이지 파일은 512KB 이하만 지원합니다."}
	var json:=JSON.new()
	if json.parse(file.get_as_text())!=OK: return {"error":"JSON %d행: %s"%[json.get_error_line(),json.get_error_message()]}
	var issues:=structural_errors(json.data)
	if not issues.is_empty(): return {"error":"\n".join(issues)}
	return {"document":normalize(json.data)}

static func normalize(value: Dictionary) -> Dictionary:
	# Godot JSON parses numbers as floats; Array.find requires matching item types.
	var doc:=value.duplicate(true)
	doc.version=int(doc.version)
	doc.chapter=int(doc.chapter)
	doc.seed=int(doc.seed)
	doc.time_limit=float(doc.time_limit)
	for o in doc.objects:
		o.pos=[int(o.pos[0]),int(o.pos[1])]
		if o.kind=="source": o.material=int(o.material)
		elif o.kind=="background": o.rotation=int(o.rotation)
		elif o.kind=="terminal":
			for order in o.orders:
				for i in range(order.size()): order[i]=int(order[i])
		elif o.kind=="bug":
			o.shots=int(o.shots)
			for key in ["speed","interval","spread","move_radius"]: o[key]=float(o[key])
	return doc
