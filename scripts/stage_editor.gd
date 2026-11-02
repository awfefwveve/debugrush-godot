extends Control
## In-game authoring UI. Also works in exported Windows builds without Godot.
signal test_requested(document: Dictionary)
signal exit_requested
signal art_reload_requested
const Doc = preload("res://scripts/stage_document.gd")
const Data = preload("res://scripts/game_data.gd")
const AREA = Rect2(48,152,872,500)
const INK = Color("e6f0ff")
const MUTED = Color("91aac3")
const GREEN = Color("65edcc")
var font: Font
var document: Dictionary=Doc.base()
var selected := -1
var tool := "select"
var material_id := 0
var dragging := false
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
var drag_snapshot: Dictionary={}
var undo_stack: Array=[]
var redo_stack: Array=[]
var active_path := ""
var saved_text := ""
var issues: Array[String]=[]
var inspector: VBoxContainer
var file_label: Label
var status: Label
var selection_label: Label
var palette_buttons: Array[Button]=[]
var dialog: FileDialog
var report: AcceptDialog
var report_text: TextEdit
var difficulty: OptionButton
var seed_edit: SpinBox
var canvas: Control
var built := false
var art
var brush_module := "floor_grid"
var brush_rotation := 0
var painting := false
var last_stamp := Vector2(-999,-999)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_font_override("font",font)
	var theme_style:=Theme.new()
	theme_style.default_font=font
	theme_style.default_font_size=15
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("1b3047") if state!="hover" else Color("30516b")
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color=GREEN if state=="focus" or state=="pressed" else Color("36516a")
		theme_style.set_stylebox(state,"Button",style)
		theme_style.set_stylebox(state,"OptionButton",style)
	theme=theme_style
	label("STAGE BUILDER",Vector2(32,13),Vector2(310,40),25,GREEN)
	var actions: Array=[["새로",func(): guard_changes(func(): reset_document(Doc.base()))],["열기",func(): guard_changes(open_file)],["저장",save_current],["다른 이름",save_as],["검사",show_validation],["테스트 ▶",test_document],["메인으로",func(): autosave(); exit_requested.emit()]]
	for i in range(actions.size()): button(actions[i][0],Rect2(390+i*122,20,112,38),actions[i][1])
	file_label=label("",Vector2(34,62),Vector2(1190,28),13,MUTED)
	file_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var tools: Array=[["선택","select",0],["시작점","spawn",0],["기획함","source",0],["코드함","source",1],["아트함","source",2],["QA함","source",3],["제작대","bench",0],["단말기","terminal",0],["버그","bug",0],["벽","wall",0],["배경","background",0],["삭제","erase",0]]
	for i in range(tools.size()):
		var entry: Array=tools[i]
		var b:=button(entry[0],Rect2(32+i*75,100,69,36),func(): tool=entry[1]; material_id=entry[2]; refresh_palette(); rebuild_inspector())
		palette_buttons.append(b)
	canvas=Control.new()
	canvas.position=AREA.position
	canvas.size=AREA.size
	canvas.focus_mode=Control.FOCUS_ALL
	canvas.mouse_default_cursor_shape=Control.CURSOR_CROSS
	canvas.gui_input.connect(canvas_input)
	add_child(canvas)
	selection_label=label("스테이지 설정",Vector2(959,109),Vector2(290,32),19,GREEN)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(958,153)
	scroll.size=Vector2(290,472)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	inspector=VBoxContainer.new()
	inspector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation",9)
	scroll.add_child(inspector)
	button("스테이지 설정",Rect2(958,641,142,34),func(): select_object(-1))
	button("선택 삭제",Rect2(1109,641,139,34),delete_selected)
	button("↶ 취소",Rect2(32,673,104,35),undo)
	button("↷ 복구",Rect2(145,673,104,35),redo)
	label("시드",Vector2(270,675),Vector2(50,30),15,MUTED)
	seed_edit=SpinBox.new()
	seed_edit.position=Vector2(320,675)
	seed_edit.size=Vector2(145,33)
	seed_edit.min_value=0
	seed_edit.max_value=2147483647
	seed_edit.value=1001
	add_child(seed_edit)
	difficulty=OptionButton.new()
	difficulty.position=Vector2(477,675)
	difficulty.size=Vector2(106,33)
	for name in ["입문","보통","도전"]: difficulty.add_item(name)
	add_child(difficulty)
	button("자동 생성",Rect2(595,673,127,35),func(): checkpoint(); document=Doc.generate(int(seed_edit.value),difficulty.selected); selected=-1; changed(); rebuild_inspector(); validate_document())
	button("저장 폴더",Rect2(735,673,119,35),func(): OS.shell_open(ProjectSettings.globalize_path("user://stages")))
	var reload_button:=button("아트 ↻",Rect2(865,673,68,35),func(): art_reload_requested.emit(); queue_redraw())
	reload_button.tooltip_text="실행 파일 옆 art 폴더의 SVG 벡터 에셋을 다시 읽습니다."
	status=label("",Vector2(35,720),Vector2(1200,67),14,MUTED)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.filters=PackedStringArray(["*.json ; 디버그 러시 스테이지"])
	dialog.file_selected.connect(file_chosen)
	dialog.size=Vector2i(960,600)
	add_child(dialog)
	report=AcceptDialog.new()
	report.title="스테이지 검사"
	report_text=TextEdit.new()
	report_text.custom_minimum_size=Vector2(740,410)
	report_text.editable=false
	report.add_child(report_text)
	add_child(report)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://stages"))
	if FileAccess.file_exists("user://stage_editor_draft.json"):
		var result:=Doc.load_file("user://stage_editor_draft.json")
		if result.has("document"): document=result.document
	saved_text=""
	built=true
	refresh_palette()
	rebuild_inspector()
	validate_document()

func button(caption: String, rect: Rect2, action: Callable) -> Button:
	var b:=Button.new()
	b.text=caption
	b.position=rect.position
	b.size=rect.size
	b.pressed.connect(action)
	add_child(b)
	return b

func label(caption: String, pos: Vector2, dimensions: Vector2, size_px: int, color: Color) -> Label:
	var l:=Label.new()
	l.text=caption
	l.position=pos
	l.size=dimensions
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func refresh_palette() -> void:
	for i in range(palette_buttons.size()):
		var index:=0
		match tool:
			"spawn": index=1
			"source": index=2+material_id
			"bench": index=6
			"terminal": index=7
			"bug": index=8
			"wall": index=9
			"background": index=10
			"erase": index=11
		palette_buttons[i].modulate=GREEN if i==index else Color.WHITE
	queue_redraw()

func canvas_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
		var local: Vector2=event.position
		if event.pressed:
			canvas.grab_focus()
			var index:=hit(local)
			if event.button_index==MOUSE_BUTTON_RIGHT or tool=="erase":
				if index>=0: select_object(index); delete_selected()
				return
			if event.button_index!=MOUSE_BUTTON_LEFT: return
			if tool=="select":
				select_object(index)
				if index>=0:
					dragging=true
					drag_origin=Doc.position_of(document.objects[index])
					drag_offset=drag_origin-local
					drag_snapshot=document.duplicate(true)
			else:
				if tool in ["background","wall"]:
					checkpoint()
					painting=true
					last_stamp=Vector2(-999,-999)
					stamp(local)
				else: place_object(local)
		elif event.button_index==MOUSE_BUTTON_LEFT and dragging:
			dragging=false
			if selected>=0 and Doc.position_of(document.objects[selected])!=drag_origin:
				undo_stack.append(drag_snapshot)
				if undo_stack.size()>60: undo_stack.pop_front()
				redo_stack.clear()
				changed()
				rebuild_inspector()
				validate_document()
		elif event.button_index==MOUSE_BUTTON_LEFT and painting:
			painting=false
			changed(); rebuild_inspector(); validate_document()
	elif event is InputEventMouseMotion and dragging and selected>=0:
		var p:=snap_position(event.position+drag_offset,document.objects[selected].kind)
		document.objects[selected].pos=[p.x,p.y]
		queue_redraw()
	elif event is InputEventMouseMotion and painting:
		if Rect2(Vector2.ZERO,AREA.size).has_point(event.position): stamp(event.position)

func stamp(pos: Vector2) -> void:
	var snapped:=snap_position(pos)
	if snapped==last_stamp: return
	last_stamp=snapped
	place_object(snapped,false)

func hit(pos: Vector2) -> int:
	for i in range(document.objects.size()-1,-1,-1):
		if document.objects[i].kind!="background" and Doc.bounds(document.objects[i]).grow(5).has_point(pos): return i
	for i in range(document.objects.size()-1,-1,-1):
		if document.objects[i].kind=="background" and Doc.bounds(document.objects[i]).has_point(pos): return i
	return -1

func snap_position(pos: Vector2, kind_override:="") -> Vector2:
	var kind:=tool if kind_override.is_empty() else kind_override
	if kind=="wall" or kind=="background": return Vector2(clampf(snappedf(pos.x-16,32)+16,16,848),clampf(snappedf(pos.y-16,32)+16,16,480))
	return Vector2(clampf(snappedf(pos.x,16),16,856),clampf(snappedf(pos.y,16),16,480))

func place_object(pos: Vector2, record:=true) -> void:
	if document.objects.size()>=1000: status.text="전체 모듈은 최대 1000개입니다."; return
	var p:=snap_position(pos)
	if tool in ["background","wall"]:
		for o in document.objects:
			if o.kind==tool and Doc.position_of(o)==p and (tool=="wall" or (o.module==brush_module and int(o.rotation)==brush_rotation)): return
	if record: checkpoint()
	# Unique modules move instead of duplicating by accident.
	var index:=-1
	if tool in ["spawn","bench","source"]:
		for i in range(document.objects.size()):
			var o: Dictionary=document.objects[i]
			if o.kind==tool and (tool!="source" or int(o.material)==material_id): index=i; break
	if index>=0: document.objects[index].pos=[p.x,p.y]
	else:
		var object:=Doc.new_object(tool,p,material_id)
		if tool=="background": object.module=brush_module; object.rotation=brush_rotation
		document.objects.append(object)
		index=document.objects.size()-1
	selected=index
	if record: changed(); rebuild_inspector(); validate_document()
	else: queue_redraw()

func select_object(index: int) -> void:
	selected=index
	rebuild_inspector()
	queue_redraw()

func delete_selected() -> void:
	if selected<0: return
	checkpoint()
	document.objects.remove_at(selected)
	selected=-1
	changed()
	rebuild_inspector()
	validate_document()

func checkpoint() -> void:
	undo_stack.append(document.duplicate(true))
	if undo_stack.size()>60: undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(document.duplicate(true))
	document=undo_stack.pop_back()
	selected=-1
	changed(); rebuild_inspector(); validate_document()

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(document.duplicate(true))
	document=redo_stack.pop_back()
	selected=-1
	changed(); rebuild_inspector(); validate_document()

func changed() -> void:
	file_label.text=("● 수정됨   " if JSON.stringify(document)!=saved_text else "저장됨   ")+(active_path if not active_path.is_empty() else "파일 미지정 · 임시 초안 자동 보관")
	autosave()
	queue_redraw()

func autosave() -> void:
	var f:=FileAccess.open("user://stage_editor_draft.json",FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(document,"\t"))

func guard_changes(action: Callable) -> void:
	if JSON.stringify(document)==saved_text: action.call(); return
	var confirm:=ConfirmationDialog.new()
	confirm.title="저장하지 않은 변경 사항"
	confirm.dialog_text="현재 초안을 바꾸기 전에 파일로 저장하는 것을 권장합니다.\n저장하지 않고 계속할까요?"
	confirm.confirmed.connect(func(): action.call(); confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered(Vector2i(600,180))

func reset_document(value: Dictionary) -> void:
	document=value.duplicate(true)
	seed_edit.value=document.seed
	difficulty.selected=int(document.get("generation_difficulty",0))
	active_path=""
	saved_text=""
	undo_stack.clear(); redo_stack.clear()
	selected=-1
	changed(); rebuild_inspector(); validate_document()

func open_file() -> void:
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.current_dir=ProjectSettings.globalize_path("user://stages")
	dialog.popup_centered(Vector2i(960,600))

func save_as() -> void:
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	dialog.current_dir=active_path.get_base_dir() if not active_path.is_empty() else ProjectSettings.globalize_path("user://stages")
	dialog.current_file="stage_%d.json"%int(document.seed)
	dialog.popup_centered(Vector2i(960,600))

func save_current() -> void:
	if active_path.is_empty(): save_as()
	else: write_file(active_path)

func file_chosen(path: String) -> void:
	if dialog.file_mode==FileDialog.FILE_MODE_SAVE_FILE: write_file(path); return
	var result:=Doc.load_file(path)
	if result.has("error"): show_report("불러오기 실패",result.error); return
	reset_document(result.document)
	active_path=path
	saved_text=JSON.stringify(document)
	changed()
	validate_document()

func write_file(path: String) -> void:
	var format_errors:=Doc.structural_errors(document)
	if not format_errors.is_empty(): show_report("파일 형식 확인","\n".join(format_errors)); return
	if not path.to_lower().ends_with(".json"): path+=".json"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if not f: show_report("저장 실패","폴더 쓰기 권한과 경로를 확인하세요."); return
	f.store_string(JSON.stringify(document,"\t"))
	f.close()
	active_path=path
	saved_text=JSON.stringify(document)
	changed()
	validate_document()
	status.text="저장 완료: "+path+("  /  초안 오류 %d개: 검사 후 테스트하세요."%issues.size() if not issues.is_empty() else "  /  테스트 가능")

func validate_document() -> void:
	issues=Doc.validate(document)
	status.text="검사 통과 · 이동 동선과 모든 상호작용 지점에 접근 가능합니다.\n드래그 이동 / 16px 스냅 / 우클릭 삭제 / Ctrl+Z 취소 / Ctrl+S 저장 · 현재 챕터 1 전용"
	if not issues.is_empty(): status.text="검사 오류 %d개 · %s\n[검사]에서 전체 목록을 확인하세요. 초안 저장은 가능하지만 테스트는 차단됩니다."%[issues.size(),issues[0]]
	if file_label.text.is_empty(): changed()

func show_report(title: String, message: String) -> void:
	report.title=title
	report_text.text=message
	report.popup_centered(Vector2i(780,465))

func show_validation() -> void:
	validate_document()
	show_report("스테이지 검사", "통과!\n필수 모듈, 수리 요구, 배치 겹침, 시작점, 이동 동선을 확인했습니다.\n난이도와 클리어 시간은 실제 테스트로 조정하세요." if issues.is_empty() else "\n".join(issues))

func test_document() -> void:
	validate_document()
	if not issues.is_empty(): show_validation(); return
	autosave()
	test_requested.emit(document.duplicate(true))

func hint(caption: String) -> void:
	var l:=Label.new()
	l.text=caption
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color",MUTED)
	inspector.add_child(l)

func field_number(caption: String, value: float, low: float, high: float, step: float, action: Callable) -> void:
	hint(caption)
	var n:=SpinBox.new()
	n.min_value=low; n.max_value=high; n.step=step; n.value=value
	n.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	n.value_changed.connect(action)
	inspector.add_child(n)

func field_options(caption: String, names: Array, value: int, action: Callable) -> void:
	hint(caption)
	var option:=OptionButton.new()
	for name in names: option.add_item(name)
	option.selected=value
	option.item_selected.connect(action)
	inspector.add_child(option)

func set_property(key: String, value: Variant) -> void:
	var target: Dictionary=document if selected<0 else document.objects[selected]
	if target.get(key)==value: return
	checkpoint()
	target[key]=value
	changed()

func set_coordinate(axis: int, value: float) -> void:
	if selected<0: return
	checkpoint()
	document.objects[selected].pos[axis]=int(value)
	changed()
	validate_document()

func rebuild_inspector() -> void:
	if not built: return
	for child in inspector.get_children(): inspector.remove_child(child); child.queue_free()
	if tool=="background":
		selection_label.text="벡터 배경 브러시"
		var keys: Array=Doc.Art.BACKGROUND_MODULES.keys()
		var names: Array=keys.map(func(k): return Doc.Art.BACKGROUND_MODULES[k][1])
		field_options("모듈 선택",names,keys.find(brush_module),func(v): brush_module=keys[v]; rebuild_inspector())
		field_options("회전 (R)",["0°","90°","180°","270°"],brush_rotation/90,func(v): brush_rotation=v*90)
		hint("SVG 기준 크기: %s"%str(Doc.Art.BACKGROUND_MODULES[brush_module][0]))
		hint("클릭하거나 드래그해 반복 배치합니다.\n배경은 충돌하지 않습니다.\n벽 도구는 주변 벽에 맞춰 직선·코너·T자를 자동 연결합니다.\n이미 놓은 배경을 옮기거나 수정하려면 선택 도구를 사용하세요.")
		return
	if selected<0:
		selection_label.text="스테이지 설정 · CH.1"
		hint("이름 (32자)")
		var name_input:=LineEdit.new()
		name_input.max_length=32; name_input.text=document.name
		name_input.text_changed.connect(func(value): set_property("name",value))
		inspector.add_child(name_input)
		hint("시작 안내 (300자)")
		var description:=TextEdit.new()
		description.custom_minimum_size=Vector2(250,112)
		description.text=document.description
		description.text_changed.connect(func(): set_property("description",description.text))
		inspector.add_child(description)
		field_number("제한 시간 (초)",document.time_limit,30,900,5,func(v): set_property("time_limit",v))
		field_number("스테이지 시드",document.seed,0,2147483647,1,func(v): set_property("seed",int(v)))
		hint("챕터 2·3은 현재 미해금입니다.\n같은 시드 + 난이도는 같은 자동 배치를 만듭니다.\n테스트 플레이는 캠페인 기록을 바꾸지 않습니다.")
		return
	var o: Dictionary=document.objects[selected]
	selection_label.text="%02d / %s"%[selected+1,Doc.LABELS[o.kind]]
	field_number("X · 왼쪽에서 (px)",o.pos[0],16,856,16,func(v): set_coordinate(0,v))
	field_number("Y · 위쪽에서 (px)",o.pos[1],16,480,16,func(v): set_coordinate(1,v))
	match o.kind:
		"background":
			var keys: Array=Doc.Art.BACKGROUND_MODULES.keys()
			field_options("배경 모듈",keys.map(func(k): return Doc.Art.BACKGROUND_MODULES[k][1]),keys.find(o.module),func(v): set_property("module",keys[v]); validate_document())
			field_options("회전",["0°","90°","180°","270°"],int(o.rotation)/90,func(v): set_property("rotation",v*90); validate_document())
			hint("배경 전용: 충돌 없음. 벽·시설·캐릭터보다 뒤에 그려집니다.")
		"source": field_options("재료 종류",Data.MATERIALS,int(o.material),func(v): set_property("material",v); validate_document())
		"terminal":
			field_number("수리 라운드 수",o.orders.size(),1,3,1,set_round_count)
			var names: Array=[]
			for id in range(11): names.append(Data.item_name(id))
			for r in range(o.orders.size()):
				var round_index:=r
				field_options("%d라운드 · 요청 1"%(r+1),names,int(o.orders[r][0]),func(v): set_order(round_index,0,v))
				field_options("%d라운드 · 요청 2 (선택)"%(r+1),["없음"]+names,int(o.orders[r][1])+1 if o.orders[r].size()>1 else 0,func(v): set_order(round_index,1,v-1))
		"bug":
			field_options("탄막 패턴",["조준 부채꼴","전방위 원형","정밀 조준"],["fan","ring","aim"].find(o.pattern),func(v): set_property("pattern",["fan","ring","aim"][v]))
			field_number("발사 간격 (초)",o.interval,0.8,8,0.1,func(v): set_property("interval",v))
			field_number("탄속 (px/초)",o.speed,60,300,5,func(v): set_property("speed",v))
			field_number("탄 개수 (정밀 조준은 1개)",o.shots,1,16,1,func(v): set_property("shots",int(v)))
			field_number("부채꼴 탄 사이 각도 (도)",o.spread,5,60,1,func(v): set_property("spread",v))
			field_number("좌우 이동 반경 (px)",o.move_radius,0,32,8,func(v): set_property("move_radius",v); validate_document())
			var parry:=CheckButton.new()
			parry.text="2회마다 분홍 탄 포함"
			parry.button_pressed=o.parry
			parry.toggled.connect(func(v): set_property("parry",v))
			inspector.add_child(parry)
		"wall": hint("32×32 충돌 벽. 플레이어와 탄환을 막습니다.\n통로 폭은 최소 48px를 권장합니다.")
		"spawn": hint("시작점 1개 필수.\n버그 이동 범위와 최소 70px 간격을 두세요.")
		"bench": hint("제작대 1개 필수. 모든 재료함과 왕복할 수 있게 배치하세요.")
	hint("충돌 크기: %d × %d px"%[Doc.footprint(o).x,Doc.footprint(o).y])

func set_round_count(value: float) -> void:
	checkpoint()
	var o: Dictionary=document.objects[selected]
	while o.orders.size()<int(value): o.orders.append([5])
	o.orders.resize(int(value))
	changed()
	rebuild_inspector()
	validate_document()

func set_order(round_index: int, slot: int, value: int) -> void:
	checkpoint()
	var order: Array=document.objects[selected].orders[round_index]
	if slot==0: order[0]=value
	elif value<0: order.resize(1)
	elif order.size()==1: order.append(value)
	else: order[1]=value
	changed()
	validate_document()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.keycode==KEY_S: save_current(); get_viewport().set_input_as_handled(); return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.ctrl_pressed and event.keycode==KEY_Z: undo()
	elif event.ctrl_pressed and event.keycode==KEY_Y: redo()
	elif event.keycode==KEY_DELETE: delete_selected()
	elif event.keycode==KEY_R and tool=="background": brush_rotation=(brush_rotation+90)%360; rebuild_inspector()

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color("080f1c"))
	draw_rect(Rect2(944,96,315,599),Color("101e30"))
	draw_rect(AREA,Color("142938"))
	if art!=null and art.textures.has("floor_tile"):
		for x in range(0,872,32):
			for y in range(0,500,32):
				var size_px:=Vector2(mini(32,872-x),mini(32,500-y))
				draw_texture_rect_region(art.textures.floor_tile,Rect2(AREA.position+Vector2(x,y),size_px),Rect2(Vector2.ZERO,size_px*art.textures.floor_tile.get_width()/32.0))
	for x in range(0,873,16): draw_line(AREA.position+Vector2(x,0),AREA.position+Vector2(x,500),Color(0.3,0.6,0.7,0.1))
	for y in range(0,501,16): draw_line(AREA.position+Vector2(0,y),AREA.position+Vector2(872,y),Color(0.3,0.6,0.7,0.1))
	draw_rect(AREA,GREEN,false,1)
	var indices: Array=range(document.objects.size())
	var draw_order: Array=indices.filter(func(i): return document.objects[i].kind=="background")+indices.filter(func(i): return document.objects[i].kind!="background")
	var wall_centers: Array=document.objects.filter(func(o): return o.kind=="wall").map(func(o): return Doc.position_of(o))
	for i in draw_order:
		var o: Dictionary=document.objects[i]
		var p:=Doc.position_of(o)+AREA.position
		var r:=Doc.bounds(o); r.position+=AREA.position
		var color:=Color("8caac8")
		var caption: String=Doc.LABELS[o.kind]
		match o.kind:
			"background": caption=""; color=Color("4a6c80")
			"source": color=[Color("ffcc79"),Color("71c7ff"),Color("c5a0ff"),GREEN][int(o.material)]; caption=Data.item_name(int(o.material))
			"spawn": color=GREEN; caption="시작"
			"bench": color=Color("91b9ed")
			"terminal": color=Color("ffcc79"); caption="단말기\n%d라운드"%o.orders.size()
			"bug": color=Color("ff7dca"); caption={"fan":"부채꼴","ring":"원형","aim":"조준"}[o.pattern]
			"wall": caption=""; color=Color("6c7e9c")
		if o.kind=="bug" and float(o.move_radius)>0: draw_circle(p,22+float(o.move_radius),Color(color,0.08))
		draw_rect(r,Color(color,0.17))
		var key: String={"spawn":"player_idle","source":"source_%d"%int(o.get("material",0)),"bench":"bench_idle","terminal":"terminal_error","bug":"bug_idle","wall":"wall","background":str(o.get("module","floor_grid"))}[o.kind]
		var angle:=deg_to_rad(float(o.get("rotation",0)))
		if o.kind=="wall":
			var variant: Array=Doc.Art.wall_variant(Doc.position_of(o),wall_centers)
			if art!=null and not art.resolved(variant[0]).is_empty(): key=variant[0]; angle=variant[1]
		if art!=null and not art.resolved(key).is_empty():
			key=art.resolved(key)
			draw_set_transform(p,angle)
			draw_texture_rect(art.textures[key],Rect2(-art.specs[key][1],Vector2(art.specs[key][0])),false)
			draw_set_transform(Vector2.ZERO)
		if o.kind!="background" or selected==i: draw_rect(r,color,false,2)
		var lines:=caption.split("\n")
		for n in range(lines.size()):
			var size_px:=12 if o.kind in ["bug","spawn"] else 14
			var width:=font.get_string_size(lines[n],HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
			draw_string(font,p+Vector2(-width/2,-(lines.size()-1)*8+n*17+5),lines[n],HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,INK)
		if selected==i:
			draw_rect(r.grow(5),Color.WHITE,false,2)
			draw_string(font,r.position+Vector2(0,-10),"%d · (%d, %d)"%[i+1,o.pos[0],o.pos[1]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
