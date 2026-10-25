extends Control
## کنترل لمسی چندانگشتی: جوی‌استیک شناور سمت چپ، دکمه‌های تعامل/دویدن/چراغ‌قوه/دفترچه/توقف سمت راست.
## روی کامپیوتر: WASD یا جهت‌ها، Shift دویدن، E تعامل، F چراغ، N دفترچه، Esc توقف.

signal interact_pressed
signal flash_pressed
signal notebook_pressed
signal pause_pressed

var move_vec = Vector2.ZERO
var run_held = false
var prompt = ""
var flash_on = false

var _joy_idx = -1
var _joy_center = Vector2.ZERO
var _joy_pos = Vector2.ZERO
var _btn_touch = {}
var _buttons = {}
var _radius = 95.0
var _default_center = Vector2(160, 560)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_layout()


func reset():
	_joy_idx = -1
	_btn_touch = {}
	move_vec = Vector2.ZERO
	run_held = false
	queue_redraw()


func _layout():
	var vs = get_viewport_rect().size
	var s = float(Global.settings["ui_scale"])
	_radius = 95.0 * s
	_default_center = Vector2(170.0 * s, vs.y - 160.0 * s)
	_buttons = {
		"interact": {"c": Vector2(vs.x - 130.0 * s, vs.y - 130.0 * s), "r": 82.0 * s, "t": "تعامل"},
		"run": {"c": Vector2(vs.x - 310.0 * s, vs.y - 90.0 * s), "r": 60.0 * s, "t": "دویدن"},
		"flash": {"c": Vector2(vs.x - 100.0 * s, vs.y - 300.0 * s), "r": 56.0 * s, "t": "چراغ"},
		"notebook": {"c": Vector2(vs.x - 70.0 * s, 70.0 * s), "r": 46.0 * s, "t": "دفترچه"},
		"pause": {"c": Vector2(70.0 * s, 70.0 * s), "r": 42.0 * s, "t": "توقف"}
	}


func _hit(pos):
	for k in _buttons:
		var b = _buttons[k]
		if pos.distance_to(b["c"]) <= b["r"] * 1.2:
			return k
	return ""


func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			interact_pressed.emit()
		elif event.keycode == KEY_F:
			flash_pressed.emit()
		elif event.keycode == KEY_N or event.keycode == KEY_TAB:
			notebook_pressed.emit()
		elif event.keycode == KEY_ESCAPE:
			pause_pressed.emit()


func _down(idx, pos):
	var k = _hit(pos)
	if k != "":
		_btn_touch[idx] = k
		Global.vibrate(15)
		if k == "run":
			run_held = true
		elif k == "interact":
			interact_pressed.emit()
		elif k == "flash":
			flash_pressed.emit()
		elif k == "notebook":
			notebook_pressed.emit()
		elif k == "pause":
			pause_pressed.emit()
		queue_redraw()
		return
	if _joy_idx == -1 and pos.x < get_viewport_rect().size.x * 0.5 and pos.y > 120.0:
		_joy_idx = idx
		_joy_center = pos
		_joy_pos = pos
		move_vec = Vector2.ZERO
		queue_redraw()


func _up(idx):
	if idx == _joy_idx:
		_joy_idx = -1
		move_vec = Vector2.ZERO
	if _btn_touch.has(idx):
		if _btn_touch[idx] == "run":
			run_held = false
		_btn_touch.erase(idx)
	queue_redraw()


func _drag(idx, pos):
	if idx != _joy_idx:
		return
	var off = pos - _joy_center
	if off.length() > _radius * 1.6:
		_joy_center = pos - off.normalized() * _radius * 1.6
		off = pos - _joy_center
	_joy_pos = pos
	var sens = float(Global.settings["joy_sens"])
	var v = off / (_radius / sens)
	if v.length() < 0.12:
		v = Vector2.ZERO
	move_vec = v.limit_length(1.0)
	queue_redraw()


func _process(_delta):
	_layout()
	if _joy_idx == -1:
		var kv = Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		if kv != Vector2.ZERO:
			move_vec = kv.normalized()
			run_held = Input.is_key_pressed(KEY_SHIFT)
		elif not _btn_touch.values().has("run"):
			move_vec = Vector2.ZERO
			run_held = false
	queue_redraw()


func _draw():
	var font = Global.get_font()
	var s = float(Global.settings["ui_scale"])
	var base_center = _default_center
	var knob = _default_center
	var alpha = 0.22
	if _joy_idx != -1:
		base_center = _joy_center
		knob = _joy_center + (_joy_pos - _joy_center).limit_length(_radius)
		alpha = 0.4
	draw_circle(base_center, _radius, Color(0.25, 0.02, 0.04, alpha))
	draw_arc(base_center, _radius, 0.0, TAU, 40, Color(0.8, 0.1, 0.15, alpha + 0.2), 3.0)
	draw_circle(knob, _radius * 0.42, Color(0.8, 0.1, 0.15, alpha + 0.3))
	for k in _buttons:
		var b = _buttons[k]
		var pressed = _btn_touch.values().has(k)
		var col = Color(0.3, 0.03, 0.05, 0.5)
		if pressed:
			col = Color(0.75, 0.08, 0.12, 0.8)
		if k == "flash" and flash_on:
			col = Color(0.6, 0.5, 0.1, 0.7)
		draw_circle(b["c"], b["r"], col)
		draw_arc(b["c"], b["r"], 0.0, TAU, 36, Color(0.9, 0.2, 0.25, 0.85), 3.0)
		draw_string(font, b["c"] + Vector2(-b["r"], 9.0 * s), b["t"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, int(24.0 * s), Color(1, 0.92, 0.9, 0.95))
